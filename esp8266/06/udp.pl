#!/usr/bin/perl
#
# udp.pl - listen on UDP port and dump out whatever has been received

use strict;
use warnings;
use Socket;

die "Usage: udp.pl <port>" if (!defined($ARGV[0]));

socket(UDP, PF_INET, SOCK_DGRAM, getprotobyname("udp"));
bind(UDP, sockaddr_in($ARGV[0], INADDR_ANY));
print $_ while (<UDP>);

