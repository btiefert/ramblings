# nsrlu.rb = Ruby reverse nslookup
# ---
# This script takes STDIN and performs a search/replace of IP addresses with DNS canonical names via reverse lookup
# Each IP address is only looked up once per run of this script
# Items that fail a reverse lookup remain as IP addresses
#
# Copyright 2014 (C) Benjamin K. Tiefert
# ---

require 'resolv'

NAME_CACHE = { "127.0.0.1" => "localhost" }

def main()
    regex_ipaddr = %r/(([0-9]{1,3}\.){3}[0-9]{1,3})/ # Matches any four part IPv4 ip address 

    # Build hash of IP addresses to replace
    sr_hash = Hash.new()
    ARGF.each_line do |line|

        # Find all IP addresses in the line and look each up in a cached way to build a search/replace hash
        line.scan(regex_ipaddr).each do |regex_groups|
            ipaddr = regex_groups[0]
            #puts "found #{ipaddr} in line #{line}"
            sr_hash[ipaddr] = getName_cached(ipaddr).to_s if ! sr_hash.has_key?(ipaddr)
        end
        # Replace each IPAddr with it's lookup
        sr_hash.each do |key, value|
            line.gsub!(key, value)
        end
        puts line        
        $stdout.flush
    end

end

def test()
    ip_addr = "10.1.88.210"
    lookup = getName(ip_addr)
    puts "Name of #{ip_addr} is #{lookup}"
end

def getName(ipaddr)
    begin
        @dnsName = Resolv.getname(ipaddr.to_s)
    rescue
        # puts "nslookup fail of #{ipaddr.to_s}"
        @dnsName = ipaddr.to_s
    end
    return @dnsName
end

def getName_cached(ipaddr)
    if ! NAME_CACHE.has_key?(ipaddr.to_s)
        NAME_CACHE[ipaddr.to_s] = getName(ipaddr.to_s).to_s
    end
    return NAME_CACHE[ipaddr.to_s]
end

main()
