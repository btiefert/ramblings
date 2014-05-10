#!/bin/bash

# $1 should be a file containing a list of hosts to tcpdump and graph
if [ $# -eq 0 ]; then
    echo "ERROR: No filename passed as arguement #1"
    exit 1
fi

./tcpdump_parallel.sh $1 | \
    ruby ./tcpdump_to_dot.rb | \
    ruby ./nsrlu.rb | \
    dot -Tsvg -odev.svg ; open dev.svg
