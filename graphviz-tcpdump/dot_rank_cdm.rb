# dot_rank_cdm.rb - Takes a dot file as input and ranks nodes vertically based on tier in the application, using CDM naming conventions
# ---


def create_fromto_dot_string(from, to)
    return "\"#{from}\" -> \"#{to}\";" 
end

def main()
    regex_ipaddr = %r/(([0-9]{1,3}\.){3}[0-9]{1,3})/ # Matches any four part IPv4 ip address
    regex_cdmhost = %r/dencdm[abcw][sdp][0-9]*/
    regex_host = %r/"[^"]*"/

    hosts = Hash.new()
    # Build hash of IP addresses to replace
    #puts "digraph tcpdump-ranked {"
    #puts "   overlap = false;"
    #puts "   concentrate = true;"
    ARGF.each_line do |line|
        if line.match(/ -> /)
            if line.match(regex_cdmhost)
                # rank and cluster tiers
                line.scan(regex_cdmhost).each do |host|
                    rank = 0
                    if host.match( /c[dsp][0-9]/ ) # content manager
                        rank = "content manager" 
                    elsif host.match( /b[dsp][0-9]/ ) # manager
                        rank = "job manager"
                    elsif host.match( /a[dsp][0-9]/ ) # agent
                        rank = "agent"
                    elsif host.match( /w[dsp][0-9]/ ) # webservices
                        rank = "web service"
                    end 
                    #puts "H:#{host}"
                    hosts[host] = rank
                end
            end
            if line.match(regex_host)
                line.scan(regex_host).each do |host|
                    if !  host.match( regex_cdmhost)
                        if host.match(/SNAT/) 
                            hosts[host] = "perimeter"
                        else
                            hosts[host] = "infrastructure"
                        end
                    end
                end 
            end
        end
        puts line
    end
    # ranks
    puts "{ node [shape=plaintext, fontsize=16];"
    ["perimeter", "web service", "agent", "job manager", "content manager", "infrastructure"].each do |rank|
        print "\"#{rank}\" -> "
    end
    puts
    ["perimeter", "content manager", "job manager", "agent", "web service", "infrastructure"].each do |rank|
        thisrank = hosts.select { |key, value| value == rank } 
        print "{ rank = same; \"#{rank}\" ; "
        thisrank.each do |host, rank| 
            print "#{host}; "
        end
        puts "}"
    end

end

main
