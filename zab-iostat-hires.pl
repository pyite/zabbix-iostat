#!/usr/bin/perl -w
#
#  Collect per-second disk stats and push into Zabbix
#
#  To enable debugging, edit the appropriate line in build_conf()
#
#  Different distro versions use different columns, so if there are failures you may need to edit the zabbix IOSTAT template
#  or change the column names such as the aqu-sz hack below.
#
#  Note that iostat doesn't appear to be able to detect newly-attached devices so maybe restart after reconfiguration
#
use strict;

use Date::Parse;
use Regexp::Common qw/ net number /;
 
our $conf = build_conf();

while( 1 ) {
    #
    #  Run the loop - restart iostat if it dies somehow
    #
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
    if ( defined( $conf->{DEBUG} ) && $conf->{DEBUG} ) {
	print STDERR "Attempting to execute: $iostat_cmd\n";
    }
    open( IOSTAT, "$iostat_cmd |" ) or die "Error executing iostat with $iostat_cmd\n";

    my $zabbix_cmd = "| zabbix_sender -vv -c /etc/zabbix/zabbix_agentd.conf -T -i -";
    if ( defined( $conf->{DEBUG} ) && $conf->{DEBUG} ) {
	print STDERR "Attempting to execute: $zabbix_cmd\n";
    } else {
	$zabbix_cmd .= " > /dev/null 2> /dev/null";
    }
    open( SENDER, $zabbix_cmd ) or die "Error executing zabbix command: $zabbix_cmd\n\n";

    my $current_timestamp;
    my $state = 'NONE';
    my @devindex;  #  save the key order so any iostat version should work

    while( <IOSTAT> ) {
	my $line = $_;
	chomp( $line );
	next if $line =~ /^$/;

	if ( defined( $conf->{DEBUG} ) && $conf->{DEBUG} ) {
	    print STDERR "Working on iostat output line: $line\n";
	}

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
		if ( defined( $conf->{DEBUG} ) && $conf->{DEBUG} ) {
		    print STDERR "Saving heading $header[$i] to $i\n";
		}
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
		    if ( defined( $conf->{DEBUG} ) && $conf->{DEBUG} ) {
			print STDERR "Skipping item $devindex[$i]\n";
		    }
		    next;
		}
		my $data = $devinfo[$i];
		my $key = $devindex[$i] . '-hr';
		if ( defined( $conf->{DEBUG} ) && $conf->{DEBUG} ) {
		    print STDERR "Saving $devinfo[$i] to key $devindex[$i]\n";
		}
		$devinfo[$i] =~ s/%//g;  #  Zabbix doesn't particularly care for % symbols
		my $send_line = sprintf( "%s iostat.metric[%s,%s] %s %s\n",
					 $conf->{HOSTNAME},
					 $devname,
					 $key,
					 $current_timestamp,
					 $data );
		if ( defined( $conf->{DEBUG} ) && $conf->{DEBUG} ) {
		    print STDERR "Sending: $send_line\n";
		}
		print SENDER $send_line;
	    }				  
	}
    }

    close( IOSTAT );
    close( SENDER );

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


sub lookup_zabbix_hostname {
    #
    #  In the rare case where we run this on the Zabbix server, we need to use 'Zabbix server' as the
    #  hostname in zabbix_sender instead of hostname -s
    #
    my $zabbix_agentd_conf;

    foreach my $conffile ( '/etc/zabbix_agentd.conf', '/etc/zabbix/zabbix_agentd.conf' ) {
	if ( -f $conffile ) {
	    $zabbix_agentd_conf = $conffile;
	    last;
	}
    }
    my $agent_hostname = `hostname -s`;
    chomp( $agent_hostname );

    open( ZABAGENT, "< $zabbix_agentd_conf" ) or die "Error opening zabbix config\n";
    while( <ZABAGENT> ) {
	if ( $_ =~ /^Hostname=Zabbix server/i ) {
	    $agent_hostname = 'Zabbix server';
	}
    }
    return $agent_hostname;
}


sub build_conf {
    #
    #  This should be used more to reduce failures and wasted bandwidth
    #
    my %conf;

    $conf{DEBUG} = 0;

    $conf{DEV_REREAD_INTERVAL} = 300;
    $conf{ZABBIX_ADDRESS} = read_zabbix_address();
    $conf{HOSTNAME} = lookup_zabbix_hostname();

    #   should probably move this to a config file some day
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

