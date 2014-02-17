parse-bitcoind-debug-clientvers.pl
===

Parses a bitcoind debug.log to produce the following type of output:

    -- Summary of unique addresses where a version was seen --
    Satoshi:0.8.6 = 57
    BitCoinJ:0.11 = 24
    Satoshi:0.8.5 = 22
    Satoshi:0.8.1 = 6
    bitcoinseeder:0.01 = 4
    BQS:0.0.1 = 2
    BitCoinJ:0.10.3 = 2
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
    -----------
    130 unique addresses.
    130 unique presumed installations.
    -----------
