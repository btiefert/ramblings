#!/usr/bin/perl

# ------------------------------------------------------------------------------------------------------------
# Description:
# Parses interesting content from a bitcoind debug.log as STDIN (as of 0.8.6, at least)
# Counts how many unique times it sees each client version
# Summarizes the distribution of client versions
# Will output a summary every N lines parsed, when receiving SIG INT or SIG TERM, or at end of STDIN
#
# Usage: 
# tail -f ~/.bitcoin/debug.log | ./parse-bitcoind-debug-clientvers.pl
# Change $ANNOUNCE_NEW_CLIENTS = 1 to get a STDOUT message for each newly seen client (IP Addr)
# Change $ACCOUNT_NEW_VERS = 1 to get a STDOUT message for ecah newly seen clientversion (e.g.: Satoshi:0.9.0)
# Change $SUMMARIZE_EVERY to change how frequently a summary is output (in units of lines parsed)
#
# ------------------------------------------------------------------------------------------------------------

use strict;

my $ANNOUNCE_NEW_CLIENTS = 0;# 1 turns on STOUT print each time a new address is seen for the first time
my $ANNOUNCE_NEW_VERS = 0;   # 1 turns on STDOUT print each time a ClientVersion is seen for the first time.
my $SUMMARIZE_EVERY=100000; # Defines the frequency (in lines parsed) that a summary is output to STDOUT

my $ipAddrRegex = qr/[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/;
my $ipPortRegex = qr/[0-9]{0,5}/;
my $clientVerRegex = qr/($ipAddrRegex):$ipPortRegex \/(Satoshi:)\//;
my %addrCounter; # hash of unique ip addresses seen, value is count seen
my %addrVerCounter; # hash of permutations $addr:$version, value is count seen
my %verCounter; # hash of unique client versions seen, value is count seen
my %lastSeenAt; # hash of with versions as keys, value as the last seen address

$SIG{TERM} = \&sighand;
$SIG{INT} = \&sighand;

sub sighand {
	summarize();
	exit 0;
}

sub summarize {
	print "\n-- Summary of unique addresses where a version was seen --\n";
	for (sort keys %verCounter) 
	{
		print $_ . " = " . $verCounter{$_} . "\n";
	}
	# print "--- Rare versions last seen ---\n";
	# foreach ( sort { ($verCounter{$a} cmp $verCounter{$b}) || ($a cmp $b) } keys %verCounter )
	# {
 	# 	print $_ . " last seen at " . $lastSeenAt{$_} . "\n";
	# }
	print "-----------\n";
	print scalar(keys %addrCounter) . " unique addresses.\n";
	print scalar(keys %addrVerCounter) . " unique presumed installations.\n";
	print "-----------\n";
}

sub countIfNewAddr {
	my $addr = shift;
	my $ver = shift;
	$addrCounter{$addr}++;
	$lastSeenAt{$ver} = $addr;
	if ( ++$addrVerCounter{$addr . ":" . $ver} == 1 )
	{
		# First time we've seen this version from this address, 
		# so increment the version counter for it's version
		$verCounter{$ver}++;
		print localtime . " Saw a new $ver at $addr\n" if $ANNOUNCE_NEW_CLIENTS;

		if ( $verCounter{$ver} == 1 ) {
			print localtime . " First time seeing a $ver\n" if $ANNOUNCE_NEW_VERS;
		}
	}
}

$|=1; # hot buffering, the better for tailing

my $linecounter = 0;
while(<>) {
	chomp;
	$linecounter++ if $SUMMARIZE_EVERY > 0; # if condition to prevent overflow $linecounter
	if ( /receive version message/ ) {
		my $addr = "";
		my $ver = "";
		$addr = $1 if /peer=($ipAddrRegex):?$ipPortRegex/ ;
		$ver = $1 if /\/([^\/]*)\// ;
		countIfNewAddr($addr, $ver) if ($addr ne "" and $ver ne "") 
	}
	elsif( /($ipAddrRegex):?$ipPortRegex \/(Satoshi:.*)\// )
	{ 
		my $addr = $1;
		my $ver = $2;
		countIfNewAddr($addr, $ver);
	}
	if ($SUMMARIZE_EVERY > 0 && $linecounter >= $SUMMARIZE_EVERY) {
		$linecounter = 0;
		summarize();
	}
}
summarize();
