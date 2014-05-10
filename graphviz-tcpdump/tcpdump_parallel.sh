#!/bin/bash
# Dumps 100 packets usign tcpdump from each cdm dev host in the file cdmdev.hosts
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
