# tcpdump_to_dot.rb - Converts tcpdump to GraphViz dot file
# ---
# Works with the output of tcpdump -a -nn -S

SEEN_HASH = Hash.new()

def create_fromto_dot_string(from, to)
    return "\"#{from}\" -> \"#{to}\";" 
end

def main()
    at_exit { puts "}" }
    regex_ipaddr = %r/(([0-9]{1,3}\.){3}[0-9]{1,3})/ # Matches any four part IPv4 ip address
    # Build hash of IP addresses to replace
    puts "digraph tcpdump {"
    #puts "   overlap = scale;"
    puts "   overlap = false;"
    puts "   concentrate = true;"
    ARGF.each_line do |line|
        if line.match(/ IP /)
            columns = line.split(" ") 
            if columns.count >= 5
                from = columns[2].match(regex_ipaddr).to_s
                to = columns[4].match(regex_ipaddr).to_s
                next if from.length == 0 or to.length == 0
                path = create_fromto_dot_string(from, to)
                if ! SEEN_HASH.has_key?(path)
                    puts "  " + path
                    $stdout.flush
                end
                SEEN_HASH[path] = 1
            end
        end
    end
    #puts "}" # no longer necessary because of at_exit
end

main
