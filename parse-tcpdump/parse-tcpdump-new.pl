#!/usr/bin/perl

# Parses default output of tcpdump
# Writes to STDOUT the first time it sees a foreign endpoint
# Writes to STDOUT every 1000th time it sees a particular foreign endpoint
# Builds a hash counting how many times each foreign end-point is seen

# use strict;

my $domesticRegex = qr/^mars\.?[0-9a-z]*$/;
my $EVERY = 1000;
my $arpcounter = 0;

$|=1;
while(<>) {
	chomp;
	if( m/(?<=IP )([^>< ]*)[ ><]* ([^ :]*)/i ) 
	{ 
		my $from = "";
		my $to = "";
		my $foreign = "";
		my $domestic = "";
		my $direction = ""; # in or out
		
		$from = $1;
		$to = $2;

		# Establish direction of traffic
		if ( $from =~ /$domesticRegex/ ) 
		{
			$domestic = $from;
			$foreign = $to;
			$direction = "out";
		}
		elsif ( $to =~ /$domesticRegex/ )
		{
			$domestic = $to;
			$foreign = $from;
			$direction = "in";
		}
		else
		{
			# Error!
			print localtime . " ERROR: Not sufficiently clever to deduce foreign vs domestic for $_\n";
		}

		# Packet type
		my $packtype = "";
		if ( m/\b(syn|ack|seq|PTR|NXDomain|NTPv4)\b/ ) 
		{
			$packtype = $1;
		} else {
			$packtype = "other";
			print localtime . " WARNING: unrecognized packtype here: $_\n";
		}

		# See if it's new or noisy and output if it is
		$countseen = ++$hashofnodes{$foreign};
		if( $countseen == 1 ) # New?
		{
			$preposition = ( $direction eq "in" ) ? "to" : "from";
			print localtime . " $foreign is new $direction $preposition $domestic type $packtype\n";
		} 
		elsif( ! $countseen % $EVERY ) # Noisy? 
		{
			print localtime . " $foreign seen $countseen times.\n";
		}
	}
	else 
	{
		# Ignore ARP packets; complain about other uncaught ones
		if( ! m/ARP/ ) {
			$arpcounter++;
			print localtime . " WARNING: no match for $_\n";
		}
	}
}
