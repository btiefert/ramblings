parse-bitcoind-debug-clientvers.pl
===

Parses a bitcoind debug.log to produce the following type of output:

    --- Sum of Clients ---
    Satoshi = 93
    BitCoinJ = 32
    bitcoinseeder = 4
    BQS = 3
    getaddr.bitnodes.io = 2
    Snoopy = 1
    coinstats.com = 1
    libbitcoin = 1
    
    --- Sum of ClientVers ---
    Satoshi:0.8.6 = 58
    BitCoinJ:0.11 = 26
    Satoshi:0.8.5 = 23
    Satoshi:0.8.1 = 7
    bitcoinseeder:0.01 = 4
    BQS:0.0.1 = 3
    BitCoinJ:0.10.3 = 3
    Satoshi:0.8.4 = 2
    getaddr.bitnodes.io:0.1 = 2
    BitCoinJ:0.10.1 = 1
    BitCoinJ:0.10.2 = 1
    BitCoinJ:0.11SNAPSHOT = 1
    Satoshi:0.8.0 = 1
    Satoshi:0.8.99 = 1
    Satoshi:0.9.0 = 1
    Snoopy:0.1 = 1
    coinstats.com:0.0.3 = 1
    libbitcoin:2.0.0 = 1
    
    --- Counts ---
    137 unique addresses.
    137 unique presumed installations.
    
