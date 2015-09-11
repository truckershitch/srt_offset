#!/usr/bin/perl
# srt_offset.pl: correct .srt file with linear offset
# syntax: srt_offset.pl <srtfile.srt> <time 1> <time 1 offset (seconds)> <time2> <time2 offset (seconds)>

use strict;
use warnings;
use POSIX;

if (scalar( @ARGV ) != 5) {
	die( "This script creates a linear shifted .srt file from a source .srt file\n", 
	     "given two times and two offsets in seconds.\n\n",
	     "Use: perl $0 <srtfile.srt> <time 1> <time 1 offset (s)> <time2> <time2 offset (s)>\n",
	     "Time format: HH:MM:SS,xyz where xyz is three digits (ms).\n" );
}

my $x1_time = $ARGV[1];
my $y1_time = $ARGV[2];
my $x2_time = $ARGV[3];
my $y2_time = $ARGV[4];

my $slope = 0;
my $intercept = 0;

my $separator = ' --> ';
my @lines = ();

open my $srtinfile, $ARGV[0] or die "I couldn't open $ARGV[0]\n $!";
open my $srtoutfile, ">", $ARGV[0] . "\.synched"  or die "I couldn't write to the out file $!";

while(<$srtinfile>) { 
	chomp; 
	push @lines, $_;
} 
close $srtinfile;

&Calculate_eq();

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

sub Parse_time {
	my $blob = $_[0];
	my ($hours, $mins, $secs, $msecs) = ();
		if ($blob =~ /((\d{2}):(\d{2}):(\d{2}),(\d{3}))/) {
			($hours, $mins, $secs, $msecs) = ($2, $3, $4, $5);
		}
		else {
			die "bad time format: " . $blob . "\n";
		}
	my $time_in_msecs = 3600000 * $hours + 60000 * $mins + 1000 * $secs + $msecs;
	return ($time_in_msecs, $hours, $mins, $secs, $msecs);
}
sub Calculate_eq {
	
	my $x1 = (&Parse_time($x1_time))[0];
	my $x2 = (&Parse_time($x2_time))[0];
	my $y1 = 1000 * $y1_time;
	my $y2 = 1000 * $y2_time;

	$slope = ($y2 - $y1) / ($x2 - $x1);
	$intercept = $y1 - $slope * $x1;
}

sub Add_offset {
	my @timeblob = ();
	my $offset = 0;
	my ($time_in_msecs, $hours, $mins, $secs, $msecs) = ();
	
	for (my $i = 0; $i < @_; $i++) {
		($time_in_msecs, $hours, $mins, $secs, $msecs) = &Parse_time ($_[$i]);
		
		$offset = ceil($slope * $time_in_msecs + $intercept);
		$msecs = $msecs + $offset;
		
		if ($offset >= 0) { #positive offset
			if ($msecs >= 1000) { #this probably isn't necessary
				$secs += int($msecs / 1000);
				$msecs %= 1000;
			}
			if ($secs >= 60) { #this if probably isn't necessary
				$mins += int($secs / 60);
				$secs %= 60;
			}
			if ($mins >= 60) { #this if probably isn't necessary
				$hours += int($mins / 60);
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
				die "Bad offset.  Time value: $_[$i]\n";
			}
		}
		$timeblob[$i] = sprintf("%02d", $hours) . ':' . sprintf("%02d", $mins) . ':' . sprintf("%02d", $secs) . ',' . sprintf("%03d", $msecs);
	}
	return @timeblob;
}

close ($srtoutfile);
