#!/bin/bash
# Dumps 500 packets using tcpdump from each host listed on a line in the file $1
# Does this in parallel using GNU parallel
if [ $# -eq 0 ]; then
    echo "ERROR: Expected filename as parameter #1, containing list of hosts to tcpdump in parallel over ssh"
    exit 1
fi
if [ ! -f $1 ]; then
    echo "ERROR: $1 does not exist as a file"
    exit 2
fi
parallel --no-notice -a $1 ssh -q {} sudo /usr/sbin/tcpdump -a -nn -S -c 500
