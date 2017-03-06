#!/usr/bin/perl
# Each line in syn_check.txt is a pattern we want to search in realTime.log.00.
# If all patterns are found, return 0, otherwise, return 1.

if (scalar(@ARGV) != 2) {
  print "Usage : perl syn_check.pl log_file pattern_file\n";
  exit -1;
}

open(logfile, $ARGV[0]) or die "Can't open $ARGV[0]!\n";
open(inputfile, $ARGV[1]) or die "Can't open $ARGV[1]!\n";

# Store patterns in an array, each line in the patternfile is a pattern to search
$count = 0;
while (<inputfile>) {
  $patterns[$count] = $_;
  $patterns[$count] =~ s/\n//;
  $count++;
}

# Search through log file for patterns, mark found patterns.
while ($line = <logfile>) {
  for ($j = 0; $j < $count; $j++) {
    if ($line =~ $patterns[$j]) {
      $found[$j] = 1;
    }
  }
}

close logfile;
close inputfile;

# Is there unmatched pattern?
for ($j = 0; $j < $count; $j++) {
  if (!$found[$j]) {
    $unmatched = 1;
  }
}

# If there are unmatched patterns, print them out and exit with non-zero value.
if ($unmatched) {
  print "Patterns not matched : \n";
  for ($j = 0; $j < $count; $j++) {
    if (!$found[$j]) {
      print $patterns[$j]."\n";
    }
  }
  exit 1;
} else {
  exit 0;
}


# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
