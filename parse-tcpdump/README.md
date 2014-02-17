parse-tcpdump-new.pl
--------------------

Parses default STDOUT of tcpdump to reduce the volume to significant new events.
Significant new events are defined as any packets to or from a newly witnessed end-point (host:port)

Useful for monitoring "new" traffic without having to initiate new connections (Does not simply
look for CONNECT or syn traffic).

Sample Output
-------------
    Sun Feb 16 23:57:17 2014 ip1b-lb3-prd.iad.github.com.https is new out from mars.35798 type seq
    Sun Feb 16 23:57:19 2014 87-194-212-21.bethere.co.uk.50527 is new in to mars.8333 type seq
    Sun Feb 16 23:57:47 2014 ip1d-lb3-prd.iad.github.com.https is new out from mars.49186 type seq
    Sun Feb 16 23:57:48 2014 87-194-212-21.bethere.co.uk.51025 is new in to mars.8333 type seq
    Sun Feb 16 23:58:16 2014 87-194-212-21.bethere.co.uk.51522 is new in to mars.8333 type seq
    Sun Feb 16 23:58:39 2014 crawl-194-14-179-206.bitnodes.io.34308 is new in to mars.8333 type seq
    Sun Feb 16 23:58:44 2014 pD9543543.dip0.t-ipconnect.de.60830 is new in to mars.8333 type seq
    Sun Feb 16 23:58:55 2014 dslb-178-010-252-062.pools.arcor-ip.net.60830 is new in to mars.8333 type seq
    Sun Feb 16 23:59:54 2014 172.56.35.251.12210 is new in to mars.8333 type seq
    Sun Feb 16 23:59:54 2014 crawl-88-198-62-174.bitnodes.io.6202 is new in to mars.8333 type seq
    Mon Feb 17 00:01:00 2014 pool-108-29-57-51.nycmny.fios.verizon.net.39114 is new in to mars.8333 type seq
    Mon Feb 17 00:01:04 2014 vps7135.xlshosting.net.46139 is new in to mars.8333 type seq
    Mon Feb 17 00:01:48 2014 24.114.83.249.4844 is new in to mars.8333 type seq
    Mon Feb 17 00:03:24 2014 crawl-88-198-62-174.bitnodes.io.9635 is new in to mars.8333 type seq
    Mon Feb 17 00:04:12 2014 user-24-96-53-80.knology.net.53538 is new in to mars.8333 type seq
    Mon Feb 17 00:05:13 2014 h112.179.38.24.cable.wrrn.fullchannel.net.55314 is new in to mars.8333 type seq
    Mon Feb 17 00:05:19 2014 114.23.246.49.39573 is new in to mars.8333 type seq
    Mon Feb 17 00:07:05 2014 d216-232-166-213.bchsia.telus.net.45133 is new in to mars.8333 type seq
    Mon Feb 17 00:07:17 2014 crawl-88-198-62-174.bitnodes.io.12840 is new in to mars.8333 type seq
