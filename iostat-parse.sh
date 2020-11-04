#!/usr/bin/perl -w
#
#   Return the requested metric
#
#   Painful because different systems will have different versions of iostat with different headers
#
#   FIXME - will need to deal with Excelero's ! characters at some point
#
use strict;

my ( $iostatoutput, $disk, $metric ) = @ARGV;

#open( WTF, "> /tmp/wtf.out" );
#print WTF "iostat-parse called with $iostatoutput / $disk / $metric\n";
#close( WTF );

my $columnarray = build_column_array();

if ( !defined( $columnarray->{$metric} ) ) {
    die "Error: metric $metric is not defined in iostat -mtxy 1\n\n";
}

#
#  FIXME - get rid of this sh nastiness
#
#  Command to collect the data for the specified drive:
#
#  grep -w $DISK $FROMFILE | tail -n +2 | tr -s ' ' |awk -v N=$NUMBER 'BEGIN {sum=0.0;count=0;} {sum=sum+$N;count=count+1;} END {printf("%.2f\n", sum/count);}'

my $cmd = sprintf( "grep -w %s %s | tail -n +2 | tr -s ' ' |awk -v N=%d 'BEGIN {sum=0.0;count=0;} {sum=sum+\$N;count=count+1;} END {printf(\"%%.2f\\n\", sum/count);}'", $disk, $iostatoutput, $columnarray->{$metric} );

print STDOUT `$cmd`;


exit 0;


#
# ============================================================================================================================
#

sub build_column_array {
    #
    #   Change to 1 based for later use with awk
    #
    my $columns = `iostat -mtx 1 1 | grep Device`;
    chomp( $columns );
    my @columns = split( /\s+/, $columns );

    my %header;

    for( my $i = 1; $i <= $#columns; $i ++ ) {
	$columns[$i] =~ s/%//g;  #  Zabbix doesn't particularly care for % symbols
	if ( $columns[$i] eq 'aqu-sz' ) {   #  change to the old header name
	    $columns[$i] = 'avgqu-sz';
	}
	$header{$columns[$i]} = $i +1;
    }
    return \%header
}

