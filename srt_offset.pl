#!/usr/bin/perl
# srt_offset.pl: correct .srt file with offset in seconds
# syntax: srt_offset.pl <srtfile.srt> <offset in seconds>

use strict;
use warnings;

if (scalar( @ARGV ) != 5) {
        die( "This script adds an offset to an .srt.synched file from a source .srt file.\n",
             "Use: perl $0 <srtfile.srt> <offset (s)>\n" );
}

my $arg1 = $ARGV[0];
my $offset = $ARGV[1];

open my $srtinfile, $arg1 or die "I couldn't open $arg1 $!";
open my $srtoutfile, ">", $arg1 . "\.synched"  or die "I couldn't write to the out file $!";

my $separator = ' --> ';

$offset = int($offset * 1000); #convert to msecs, also take care of any comedians :)

my @lines = ();

while(<$srtinfile>) { 
    chomp; 
    push @lines, $_;
} 
close $srtinfile;

my $j = 0;

while ($j < @lines) {
	print $srtoutfile $lines[$j++] . "\n";
	my @subtimes = split($separator, $lines[$j++]); #two values like 00:00:00,222
	@subtimes = &Add_offset(@subtimes);
	print $srtoutfile $subtimes[0] . $separator . $subtimes[1] . "\r\n";
	print $srtoutfile $lines[$j++] . "\n"; #in case of blank subtitle line (seen in GOT S01E02)
	while ($j < @lines && $lines[$j] ne "\r") { #chomped empty Windows line
		print $srtoutfile $lines[$j++] . "\n"; #subtitle
	}
	if($j < @lines) {
		print $srtoutfile "\r\n"; #blank line (Windows)
	}
	$j++;
}

sub Add_offset {
	my @timeblob = ();

	for (my $i = 0; $i < @_; $i++) {
		my $blob = $_[$i];
		my ($hours, $mins, $secs, $msecs) = ();

		if ($blob =~ /((\d{2}):(\d{2}):(\d{2}),(\d{3}))/) {
			($hours, $mins, $secs, $msecs) = ($2, $3, $4, $5);
		}
		else {
			die "bad subtitle time format in srtinfile!\n" . $blob . "\n";
		}
		
		$msecs = $msecs + $offset;
		
		if ($offset >= 0) { #positive offset
			if ($msecs >= 1000) { #this probably isn't necessary
				$secs += ($msecs / 1000);
				$msecs %= 1000;
			}
			if ($secs >= 60) { #this if probably isn't necessary
				$mins += ($secs / 60);
				$secs %= 60;
			}
			if ($mins >= 60) { #this if probably isn't necessary
				$hours += ($mins / 60);
				$mins %= 60;
			}
		}
		else { #negative offset
			if ($msecs < 0) { #have to borrow from secs
				$secs = $secs + int($msecs / 1000); #($msecs / 1000) should be negative
				$msecs = -(-$msecs % 1000); #full msecs remainder (probably negative)
				if ($msecs < 0) { #fix msecs, decrement secs
					$msecs += 1000;
					$secs--;
				}
			}
			if ($secs < 0) { #have to borrow from minutes
				$mins = $mins + int($secs / 60); #($secs / 60) should be negative
				$secs = -(-$secs % 60); #full seconds remainder (probably negative)
				if ($secs < 0) { #fix secs, decrement mins
					$secs += 60;
					$mins--;
				}
			}
			if ($mins < 0) { #have to borrow from hours
				$hours = $hours + int($mins / 60); #($mins / 60) should be negative
				$mins = -(-$mins % 60);
				if ($mins < 0) { #fix mins, decrement hours
					$mins += 60;
					$hours--; 
				}
			}
			if ($hours < 0) {
				die "Bad offset.  Time value: $blob\n";
			}
		}
		$timeblob[$i] = sprintf("%02d", $hours) . ':' . sprintf("%02d", $mins) . ':' . sprintf("%02d", $secs) . ',' . sprintf("%03d", $msecs);
	}
	return @timeblob;
}

close ($srtoutfile);
