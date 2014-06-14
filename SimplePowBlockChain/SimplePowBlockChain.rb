#!/usr/bin/env ruby
####################################################################################################################
# SimplePowBlockChain.rb
# ---
# Simplified Proof-of-Work based block chain for use as a learning exercise
# * Intended as a learning exercise
# * Not safe for use as a currency, due to lack of attention to things such as denial of service attack protections
# * Depends upon the 'bunny" gem from RabbitMQ (gem install "bunny")
# * Depends on the "yaml" gem for serialization (gem install "yaml")
# * Assumes the local machine has a default install of RabbitMQ server running (logs in as default guest user)
# * NOT intended to by Bitcoin compatible.  
# * Ruby handles extremely large integers very gracefully, which alleviates a lot of programming headaches 
# 
# Usage
# ---
# * Start RabbitMQ server on the local host
# * Start as one more more instances of SimplePowBlockChain.rb and watch each instance compete to mine and converge to 
#   concensus
# * SimplePowBlockChain.rb will create a RabbitMQ fanout exchange called "blockannouncer" and will setup temporary queues
#   for each SimplePowerChain.rb process bound to that fan exchange
# * On exit, each process writes it's persective of the blockchain to myblocks.yaml.<PID>
# * On startup, myblocks.yaml is read, so overlay the myblocks.yaml.PID to myblocks.yaml if you want to persist
#   Blockchain progress after stopping an entire test network
# * If no myblocks.yaml is found on startup, mining will start from the hard-coded genesis block.  Can uncomment
#   the "generateGenesisBlock" subroutine to make a new one to then paste over the hard-coded value to start
#   a new blockchain and see how multiple networks might interact when they differ only by genesis block.
#
# To-Do
# ---
# * Replace string "hi" payload with a merkle tree root
# * Replace difficulty with something that allows the Target to move with more granularity (not just powers of 2)
# * Add clock date/time stamping of new blocks
# * Add block rumouring so new nodes can bootstrap without waiting upon the cheesy every Nth mined block broadcasting
#   a whole node's blockchain
# * Cleanup the class model for BlockStore vs BlockChain
# * Improve the logic for detecting when a block race is in progress.  Needs more explicity detection of when
#   the best block in the BlockChain is tied with it's own last mined block, and show preference for it's own.
#   This sort of happens as-implemented only because of the order the blocks show up in the BlockChain.blocks array
# * Fix (rare) bug where time spent mining isn't correct if incrementNonce wraps around MAX_NONCE to 0
# * Integrate the graphviz dot file output into the BlockStore class
# * Review addBlock() logic with a fine toothed comb to ensure we're not trusting the validity of anything
#   such as the peer's opinion of its block height, or the block height as recorded on disk durin load()
# * Consolidate the main block index in BlockChain with the blocks array in BlockStore.  No need for both.
# * Perhaps add the optimization of simply dropping blocks from the BlockChain if they're not part of the longest
#   chain.  Bitcoin does this, but for very small scale networks proof of concepts it might be best to keep
#   all chains the node has seen regardless of length, as long as they're otherwise valid
# * Add difficulty adjustments (being careful that it will reach consensus, but simplifying some things for clariy
#   such as (perhaps) trusting timestamps from peer to a pretty tight tolerance.   To keep things clear as a 
#   learning exercise.  Once difficulties change, be sure the correct difficulty is checked for each block being
#   validated!
# * Change block height calculation to a sum of difficulties
# * This does PoW of sha256(BlockHeader).  Unclear yet what the advantage of bitcoin's sha256(sha256(BlockHeader)) alg is.
# * Actually interupt mining with an event when better base block is found
# * The big one: actually add a rudimentary transaction so this is closer to a Coin!
# * Move away from RabbitMQ message queues and towards node to node point to point communications
# * Add output on exit that summarizes things like # of blocks mined, and what portion of them were lost to 
#   longer blocks.  (I hate using the word orphaned for this since they have parents, just no children)
#   Perhaps the term "spinster blocks" is more appropriate?
# * Add command line parameters for the myblock.yaml block store that is read and/or written
# * Add command line parameters for allow for "misconfigured" or malicious nodes for fun simulation
#    e.g.: it's fun to run 7 processes with proper difficulty and 1 process that underestimates required difficulty
#          by a factor of 4
# * Add block (protocol) versioning, so PoW algorithm can easily be changed in backwards compatible fashion
# * Improve lag simulation by withholding the block announcement but without waiting to resume mining atop it
####################################################################################################################

require 'Digest'
require 'yaml'
require 'bunny' # Using RabbitMQ for node to node communication to keep things simple compared to bootstrapping a network over IP

DIG = Digest::SHA256.new()
MAX_BLOCK_HASH = 2 ** 256
MIN_BLOCK_HASH_EXPONENT = 234 # drives a very simple version of difficulty
MAX_NONCE = 2 ** 128 # enough to scale to high difficulty and ensure all blocks have a solution? 
BLOCK_ANNOUNCEMENT_HEIGHT = 10 # spam block announcements if we find a block at a multiple of this height
CHUNK = 20000 # number of hashes performed per batch before stopping for housekeeping and to output progress to STDOUT
PID = Process.pid
NODE_ID = PID.to_s + "." + '127.0.0.1' # multi-process support, but deliberately no multi-computer support for now.
BLOCKSTORE='myblocks.yaml'
MAX_LAG = 5 # seconds of network lag to simulate (maximume of random range)
MIN_LAG = 0 # seconds of network lag to simulate (minimum of random range)
APPVERSION='0.2'

# Output verbosity flags
DEBUG_BLOCKCHAIN_MGT = true
DEBUG_BLOCK_ANNOUNCEMENTS = true
DEBUG_BLOCK_RECEIVED = false
DEBUG_MINING_FOCUS = true

class Block

    attr_accessor :previous_block_hash, :payload, :nonce, :hash, :nodeid, :heightInSteps

    # Constructor
    def initialize(previous_block_hash, payload, nonce = 0, hash = nil)
        @previous_block_hash = previous_block_hash
        @payload = payload
        @nonce = nonce 
        @nodeid = NODE_ID  # we keep this around just so we can see which process found each block
        @heightInSteps = -2
        if hash.nil? then
            self.updateStoredHash!()
        else
            @hash = hash
            if hash != self.calculateHash() then
                puts "WARNING WARNING WARNING CLAIMED HASH MISMATCH " 
                puts self.blockInfo(0)
            end 
        end
    end

    def incrementNonce()
        @nonce = @nonce + 1
        @nonce = 0 if @nonce > MAX_NONCE
        self.updateStoredHash!() # This caused hashes to be calculated twice per block
    end

    def validateClaimedHash?()
        # Checks if the calculated hash matches the stored hash
        return (self.calculateHash() == @hash)
    end

    def lowEnoughHash?(target)
        # checks if the hash is difficult enough
        return @hash <= target
    end

    def serializeHeader()
        return padded_hex_notation(@previous_block_hash) + ":" + @payload + ":" +  @nonce.to_s(16)
        #return @previous_block_hash.to_s(16) + ":" + @payload + ":" +  @nonce.to_s(16)
    end
    
    def calculateHash()
        thingToHash = self.serializeHeader()
        return DIG.reset().update(thingToHash).hexdigest.hex # returns a big integer
    end

    def updateStoredHash!()
        @hash = self.calculateHash()
    end

    def blockInfo(target)
        # Returns a string with information about this block.
        out = ""
        out += "HexHeader  = #{self.serializeHeader().to_s}\n"
        out += "HexDigest  = #{self.hexHash}\n"
        out += "DecDigest  = #{@hash}\n"
        out += "DecNonce   = #{@nonce}\n"
        out += "Difficulty = #{scientific_notation(@hash)}\n"
        #out += "LowEnough  = #{self.lowEnoughHash?(target) ? "YES" : "NO"}\n"
        out += "Validity   = #{self.validateClaimedHash?() ? "VALID" : "INVALID"}\n"
        #out += "CalcHexHash= #{ padded_hex_notation(self.calculateHash())}\n"
        #out += "CalcDecHash= #{ self.calculateHash()}\n"
        out += "Height     = #{@heightInSteps}\n"
        return out
    end

    def hexHash
        return padded_hex_notation(@hash)
    end

    def announce()
        # announces this block to other nodes via RabbitMQ exchange
        conn = Bunny.new
        conn.start
        ch = conn.create_channel
        x = ch.fanout("blockannouncer") 
        x.publish(self.to_yaml)
        puts "<<< Announced block #{self.hexHash} >>>" if DEBUG_BLOCK_ANNOUNCEMENTS
        conn.close
    end
end

class BlockStore
    # This class stores an Array of block objects, and facilitates writing them to disk (save), reading from disk (load), and writing to STDOUT (printChain)
    # management functions like storing the array on disk
    attr_accessor :blocks
    def initialize()
        @blocks = Array.new()
    end
    def addBlock(newBlock)
       @blocks.push(newBlock) 
    end
    def printChain(target)
        @blocks.each do |b|
            #puts b.serializeHeader()
            puts b.blockInfo(target)
        end
    end
    def save()
        # Just overwrite the same blockstore file with the current BlockChain.blocks
        # Obviously very risky for data loss.
        serialized_data = @blocks.to_yaml
        File.open(BLOCKSTORE + "." + PID.to_s, 'w') do |file|
            file.write(serialized_data)
        end
    end
    def load()
        raw_yaml = File.read(BLOCKSTORE)
        temp_blocks = YAML.load(raw_yaml)
        temp_blocks.each do |block_to_add| 
            self.addBlock(block_to_add)
        end
    end
end

class BlockChain < BlockStore

    attr_accessor :indexed_blocks

    # inherits the very basic storage mechanics of a BlockStore, but structures blocks into a chain, enforces consensus logic (only adds valid blocks), manages a pool of orphan blocks, and maintains a very simple block index
    def initialize(target)
        super()
        @orphan_blocks = Hash.new() 
        @indexed_blocks = Hash.new() # index of block objects based on their hash
        @target=target
        # add genesis block
        self.addBlock getGenesisBlock, true
    end

    def addBlock(newBlock, is_genesis_block = false)
        # If we already have a block in the chain with this hash, discard the new one (don't add duplicates)
        # If the block's hash isn't valid, discard the block
        # If the block's hash is valid, but we can't find the previous hash in our copy of the chain, put it in a pool of orphans (@orphan_blocks)
        # If the block's hash is valid, and we have the parent block, add it to the pool, then re-evaluate @orphan_blocks to see 
        #   if they're still orphans.  (We might have just found one of their parents, which in turn might have it's own orphaned children)
        if isBlockInChain?(newBlock.hash)
            puts "... already have block #{newBlock.hexHash}" if DEBUG_BLOCKCHAIN_MGT
            return
        end
        if ! newBlock.validateClaimedHash? then
            puts "WARNING: Block's claimed hash is not valid.  Dropping from pool:" if DEBUG_BLOCKCHAIN_MGT
            puts newBlock.blockInfo(@target)
            return
        end
        if ! newBlock.lowEnoughHash?(@target) and ! is_genesis_block then
            puts "... DISCARDING block - not difficult enough" if DEBUG_BLOCKCHAIN_MGT
            return
        end
        if isBlockInChain?(newBlock.previous_block_hash) or is_genesis_block then
            #puts "... adding block #{newBlock.hash}" if DEBUG_BLOCKCHAIN_MGT
            # not an orphan, since we know the parent; call overloaded function to add it to @blocks
            newBlock.heightInSteps = self.getHeightOfBlockInSteps(newBlock)
            super(newBlock)
            @indexed_blocks[newBlock.hash] = newBlock # add block to blockchain hash index
            # remove from the orphan pool if this was previously indexed as an orphan
            if isBlockInOrphanPool?(newBlock.hash) then
                puts "... removing orphaned block since we found its parent" if DEBUG_BLOCKCHAIN_MGT
                @orphan_blocks.delete(newBlock.hash)
            end

            # Reconsider all orphans in the pool in case this newly added block is one of their parents
            @orphan_blocks.each do |orphanhash, orphan|
                self.addBlock(orphan) # for each block in the orphan pool, recurse to see if it now fits in the chain
            end
            #if @orphan_blocks.length > 0 then
            #    puts "... re-evaluated orphans.  #{@orphan_blocks.length} orphans remain" if DEBUG_BLOCKCHAIN_MGT
            #end
        elsif ! isBlockInOrphanPool?(newBlock.hash) then 
            # orphaned block, add to @orphan_blocks pool instead
            puts "... adding block to orphan pool #{newBlock.hexHash}" if DEBUG_BLOCKCHAIN_MGT
            @orphan_blocks[newBlock.hash] = newBlock
        end
    end

    def getHeightOfBlockInSteps(block)
        return walkBlockAncestory(block)
    end

    def walkBlockAncestory(block, steps = 1)
        # Yes this bloats the stack, but recursion is fun for exercises like this
        return 0 if block.hash == getGenesisBlock.hash
        # return -1 if ! @indexed_blocks.has_key?(block.hash)
        blockparent = block.previous_block_hash
        if blockparent == getGenesisBlock.hash
            return steps
        end
        return -1 if ! @indexed_blocks.has_key?(blockparent)
        return walkBlockAncestory(@indexed_blocks[blockparent], steps + 1)
    end

    def isBlockInChain?(blockHash)
        return @indexed_blocks.has_key?(blockHash) 
    end

    def isBlockInOrphanPool?(blockHash) 
        return @orphan_blocks.has_key?(blockHash)
    end

    def bestBlock()
        heighest = -3
        bestblock = nil
        @indexed_blocks.each do |blockhash, block|
            if block.heightInSteps > heighest  then
                heighest = block.heightInSteps
                bestblock = block
            end
        end
        return bestblock
    end

    def announceAllBlocks()
        self.blocks.each do |knownBlock|
            knownBlock.announce
        end 
    end

    def writeDotFile()
        # We can visualize the blockChain with graphViz using .dot files
        strDot = ""
        strDot += "digraph blockChain {\n"
        self.blocks.each do |block|
            parentblock = self.indexed_blocks[block.previous_block_hash]
            if ! parentblock.nil?
                strDot += "   \"#{block.hash}(H=#{block.heightInSteps}) from #{block.nodeid}\" -> \"#{parentblock.hash}(H=#{parentblock.heightInSteps}) from #{parentblock.nodeid}\";\n"
            end
        end
        strDot += "}\n"
        puts "Writing dot file"
        File.open(BLOCKSTORE + "." + PID.to_s + ".dot", 'w') do |file|
            file.write(strDot)
        end
        return strDot
    end
end

def mineGenesisBlock(target)
    puts "Mining Genesis Block..."
    genesis_block = findBlock(0, "Hi", target)
    puts "GENESIS BLOCK:"
    puts genesis_block.blockInfo(target)
    return genesis_block
end

def getGenesisBlock
    return Block.new(0, "Hi", 2404365, 44207463176812595723259730143977648014435136939446764175223014434125480)
end

def main

    ## Set the target hash below which all valid mined hashes must be
    target = 2 ** current_difficulty()

    ## Mine the genesis block.  (Usually not needed, since it was mined once and hard coded in getGenesisBlock()
    #mineGenesisBlock(target)

    puts "SimplePowBlockChain.rb " + APPVERSION.to_s
    puts "---"
    puts "Difficulty = " + current_difficulty().to_s
    puts "Target = " + (2 ** current_difficulty()).to_s
    puts "Target = " + scientific_notation(2 ** current_difficulty())

    bc = BlockChain.new(target)
    puts "Loading block chain from #{BLOCKSTORE}..."
    begin
        bc.load()
    rescue
        puts "ERROR: Could not load #{BLOCKSTORE}.  Starting with empty blockchain instead.  (Genesis block only)" 
    end
    
    # Set event to write blockchain to disk on exit (this is trapped on a CTRL-C or other SIGTERM)
    at_exit do
        puts "Saving block chain to #{BLOCKSTORE}..."
        bc.save()
        bc.writeDotFile()
        puts "Done."
    end

    # Connect to your "network" via RabbitMQ.  This will receive block announcements
    mq_listen(bc)

    # Find blocks!
    generateBlocks( bc, target)
    exit 0

end

def generateBlocks( blockChain, target )
    blocksMined = 0
    bestblock = blockChain.bestBlock()
    puts "Mining atop this block:"
    puts bestblock.blockInfo(target)
    lastBlockHash = bestblock.hash # start with the best block found in the chain
    while ( true ) do

        newBlock = findBlock( blockChain, lastBlockHash, "Hi", target ) # keep out of this variant of findBlock until it learns to abandon old base blocks
        # newBlock = findBlock_with_progress( blockChain, lastBlockHash, "Hi", target )
        blocksMined = blocksMined + 1
        blockChain.addBlock(newBlock)

        puts ""
        puts "Found block!"
        puts newBlock.blockInfo(target)
        puts ""

        sleep(MIN_LAG + rand(MAX_LAG-MIN_LAG)) # simulate network lag, so we get interesting things like block races
        newBlock.announce()

        # Calculate best block to continue working on
        bestblock = blockChain.bestBlock()
        if bestblock.heightInSteps > newBlock.heightInSteps
            # switch!
            lastBlockHash = bestblock.hash
            puts "::: I LOST A BLOCK RACE :::" if DEBUG_MINING_FOCUS
        elsif bestblock.hash != newBlock.hash
            # A different block was received at around the same time I found my block.  It's a block race!
            puts "!!! IT'S A BLOCK RACE !!!" if DEBUG_MINING_FOCUS
            lastBlockHash = newBlock.hash
        else
            puts "!!! Mining atop my own block !!!" if DEBUG_MINING_FOCUS
            lastBlockHash = newBlock.hash
        end
          
        if newBlock.heightInSteps % BLOCK_ANNOUNCEMENT_HEIGHT  == 0 then
            # If we just found a block at a height easily divisible by BLOCK_ANNOUNCEMENT_HEIGHT, spam everyone with a copy of all blocks in our chain
            blockChain.announceAllBlocks
        end
    end
end

def findBlock( blockChain, prevBlockHash, payload, target )
    # start with a random nonce between 0 and MAX_NONCE, because we're very likely
    # going to be working on candidate block headers that the exact same as our peer's candidates
    # it pays to cover unqiue territory, especially if everyone is using the same payload
    startingNonce = rand(MAX_NONCE)
    block = Block.new(prevBlockHash, payload, startingNonce)
    while ( ! block.lowEnoughHash?(target) ) do
            block.incrementNonce()
            # to-do: add logic to interrupt mining if a better base block arrives
            # using findBlock() will blindly keep going for it's own next block
            # without checking for newly arrived ones, unlike findBlock_with_progress, which
            # is capable of stopping every CHUNK blocks for housekeeping
            if ( block.nonce % CHUNK == 0 )  then
                # Check to see if a better block has been received
                theBestBlock = blockChain.bestBlock
                if( theBestBlock.heightInSteps >= blockChain.getHeightOfBlockInSteps(block) )
                    puts ">>> Switching to mine atop received block at height #{theBestBlock.heightInSteps} (#{theBestBlock.hexHash}) <<<" if DEBUG_MINING_FOCUS
                    block.previous_block_hash = theBestBlock.hash
                end      
            end
    end
    return block
end

def findBlock_with_progress( blockChain, prevBlockHash, payload, target )
    # This is a varient of findBlock(), which does the same thing but is cluttered
    # with intermittant outputs and a lame way of checking if a newly received block
    # is a better block to build on.
    startingNonce = rand(MAX_NONCE)
    best_hash = MAX_BLOCK_HASH # reset our best
    best_nonce = nil
    block = Block.new(prevBlockHash, payload, startingNonce)
    block.incrementNonce
    t0 = Time.now()
    t1 = Time.now()
    while ( ! block.lowEnoughHash?(target) ) do
            # Note the best hash found thus far in this CHUNK
            if block.hash() < best_hash then
                best_hash = block.hash()
                best_nonce = block.nonce()
            end
            # Output some progress every Nth hash attempt (N defined by CHUNK constant)
            if ( block.nonce % CHUNK == 0 )  then
                t2 = Time.now()
                elapsed = (t2 - t1) # seconds
                # puts "Hashrate is " + ( CHUNK / elapsed ).to_s + " hash/sec"

                puts "Best hash in last chunk was #{scientific_notation(best_hash)} (#{padded_hex_notation(best_hash)} from nonce #{best_nonce.to_s})"
                # Stop for a moment to listen for block announcements

                # Check to see if a better block has been received
                theBestBlock = blockChain.bestBlock
                if( theBestBlock.heightInSteps >= blockChain.getHeightOfBlockInSteps(block) )
                    puts ">>> Switching to mine atop received block at height #{theBestBlock.heightInSteps} (#{theBestBlock.hexHash}) <<<" if DEBUG_MINING_FOCUS
                    block.previous_block_hash = theBestBlock.hash
                end      
    
                # Reset local bests and timer
                best_hash = MAX_BLOCK_HASH # reset our best
                best_nonce = nil;
                t1 = Time.now()

            end
            block.incrementNonce()
    end
    t2 = Time.now()
    block_elapsed_time = (t2 - t0) # seconds
    puts "Overall hash rate for this block is " + (( block.nonce - startingNonce ) / block_elapsed_time ).to_s + " hash/sec"
    puts "Elapsed time to mine this block is #{block_elapsed_time} seconds."
    return block
end

def current_difficulty
    # To-Do: should not call this bit count a difficulty.   Using bitcounts as difficulty means we can only change in powers of 2!
    return MIN_BLOCK_HASH_EXPONENT
end

def scientific_notation(input_number)
    return ("%.3E" % input_number).to_s
end

def padded_hex_notation(input_number)
    return sprintf("%065x", input_number)
end

def mq_listen(blockChain)
    # Sets up a temporary queue that is pumped messages from the blockannouncer fanout exchange
    # Credit to http://www.rabbitmq.com/tutorials/tutorial-three-ruby.html
    conn = Bunny.new
    conn.start
    ch = conn.create_channel
    q = ch.queue("", :exclusive => true)
    x = ch.fanout("blockannouncer") # create the blockannouncer if it doesn't already exist
    q.bind("blockannouncer") # bind this temporary queue to the blockannouncer 
    q.subscribe(:block => false) do |delivery_info, properties, body|
        # to-do: Cause  mining to stop if this is a better base block by more directly raising an event
        receivedBlock = YAML.load(body)
        if receivedBlock.nodeid != NODE_ID then
            blockChain.addBlock(receivedBlock)
            puts "=== BLOCK RECEIVED AT HEIGHT #{blockChain.getHeightOfBlockInSteps(receivedBlock)} HEADER #{receivedBlock.serializeHeader} from #{receivedBlock.nodeid}" if DEBUG_BLOCK_RECEIVED
        end
    end
end

main
