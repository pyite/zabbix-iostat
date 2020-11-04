#!/usr/bin/perl -w
#
#  Collect per-second disk stats and push into Zabbix
#
#  Complicated because iostat doesn't appear to be able to detect newly-attached devices
#
use strict;

use Date::Parse;
use Regexp::Common qw/ net number /;
 
our $conf = build_conf();

while( 1 ) {
    #
    #  Run the loop
    #
    print STDERR "Starting iostat...\n";
    die "Error running iostat\n" if run_iostat();
    
}

die "ERROR: loop should never terminate\n";

#
#  ==================================================================================================
#

sub run_iostat {
    #
    #  states are: NONE, DEVS, STATS
    #
    #
    #  echo "- hw.serial.number 1287872261 SQ4321ASDF" | zabbix_sender -c /usr/local/etc/zabbix_agentd.conf -T -i -
    #  Send a timestamped value from the commandline to Zabbix server, specified in the agent configuration file.  Dash in
    #  the input data indicates that hostname also should be used from the same configuration file.
    #
    my $iostat_cmd = sprintf( "iostat -mtxy 1 %d", $conf->{DEV_REREAD_INTERVAL} );
    print STDERR "Attempting to execute: $iostat_cmd\n";
    open( IOSTAT, "$iostat_cmd |" ) or die "Error executing iostat with $iostat_cmd\n";

    my $zabbix_cmd = "| zabbix_sender -vv -c /etc/zabbix/zabbix_agentd.conf -T -i -";
    print STDERR "Attempting to execute: $zabbix_cmd\n";
    open( SENDER, $zabbix_cmd ) or die "Error executing zabbix command: $zabbix_cmd\n\n";

    my $current_timestamp;
    my $state = 'NONE';
    my @devindex;  #  save the key order so any iostat version should work

    while( <IOSTAT> ) {
	my $line = $_;
	chomp( $line );
	next if $line =~ /^$/;

#	print STDERR "Working on: $line\n";

	#
	#  Check for a date, set the state to STATS
	#
	my $dt = str2time( $line );
	if ( defined( $dt ) ) {
	    $state = 'STATS';
	    $current_timestamp = $dt;
	    next;
	}

	#
	#  Collect the headings, remove the ones we don't want to try sending
	#
	if ( $line =~ /^Device:{0,1}/ ) {
	    $state = 'DEVS';
	    next if ( defined( $devindex[0] ) );
	    $devindex[0] = 'skipnexttime';
	    my @header = split( /\s+/, $line );
	    for( my $i = 1; $i <= $#header; $i ++ ) {
#		print STDERR "Saving heading $header[$i] to $i\n";
		$header[$i] =~ s/%//g;  #  Zabbix doesn't particularly care for % symbols
		if ( $header[$i] eq 'aqu-sz' ) {
		    $header[$i] = 'avgqu-sz';       #   why
		}
		$devindex[$i] = $header[$i];
	    }
	    next;
	}

	if ( $state eq 'DEVS' ) {
	    my %devstats;
	    my @devinfo = split( /\s+/, $line );
	    my $devname = $devinfo[0];
	    $devname =~ s/!/_/g;  #  Excelero... why did you choose !
	    for( my $i = 1; $i <= $#devinfo; $i ++ ) {
		if ( defined( $conf->{SKIPITEMS}->{$devindex[$i]} ) ) {
#		    print STDERR "Skipping item $devindex[$i]\n";
		    next;
		}
		my $data = $devinfo[$i];
		my $key = $devindex[$i] . '-hr';
#		print STDERR "Saving $devinfo[$i] to key $devindex[$i]\n";
		$devinfo[$i] =~ s/%//g;  #  Zabbix doesn't particularly care for % symbols
#		$devstats{$devindex[$i]} = $devinfo[$i];
#		store_dev_stats( $current_timestamp, $devinfo[0], \%devstats );
		my $send_line = sprintf( "%s iostat.metric[%s,%s] %s %s\n",
					 $conf->{HOSTNAME},
					 $devname,
					 $key,
					 $current_timestamp,
					 $data );
#		print STDERR "Sending: $send_line\n";
		print SENDER $send_line;
	    }				  
	}
    }

    close( IOSTAT );
    close( SENDER );

    return 0;
}


sub store_dev_stats {
    my ( $stamp, $device, $data ) = @_;
    print STDERR "Saving to zabbix server $conf->{ZABBIX_ADDRESS}: " .
                 "device $device, timestamp $stamp, data sample $data->{'rMB/s'}\n";
    return 0;
}


sub read_zabbix_address {
    #
    #   Read this from /etc/zabbix/zabbix_agentd.conf
    #
    #       # $RE{net}{IPv6}
    #       # $RE{net}{IPv4}
    #
    #       if ( $ip =~ m/$RE{net}{IPv4}/ ){
    #           print 'match!'
    #       }
    #
    my $conffile = `grep ^Server= /etc/zabbix/zabbix_agentd.conf`;
    if ( !( $conffile =~ /^Server.(.+)$/ ) ) {
	die "Error: couldn't read Zabbix server IP address from /etc/zabbix/zabbix_agentd.conf\n\n";
    } else {
	my $ip = $1;
	if ( $ip =~ m/$RE{net}{IPv4}/ ){
	    return $ip;
        } else {
	    die "Error: badly-formed IPv4 address ($ip) in /etc/zabbix/zabbix_agentd.conf\n\n";
	}
    }
    die "Logic error - should never reach this line\n";
    return 666;
}


sub build_conf {
    #
    #
    #
    my %conf;

    $conf{DEV_REREAD_INTERVAL} = 300;
    $conf{ZABBIX_ADDRESS} = read_zabbix_address();
    $conf{HOSTNAME} = `hostname -s`;
    chomp( $conf{HOSTNAME} );

    $conf{SKIPITEMS} = {
#	'rrqm/s' => 1,
#	'wrqm/s' => 1,
#	'r/s' => 1,
#	'w/s' => 1,
#	'await' => 1,
#	'r_await' => 1,
#	'w_await' => 1,
    };

    return \%conf;
}

