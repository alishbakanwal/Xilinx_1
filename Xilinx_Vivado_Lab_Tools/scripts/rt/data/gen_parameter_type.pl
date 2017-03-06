#!/usr/bin/perl
# Create a cell-parameter-type table.  Input is from ./parameter_type.v,
# output to the file named as ARGV[0] (typically parameter_type.txt).
# The input file parameter_type.v should be a concantenation of all Verilog
# source files which need to be included to create parameter_type.txt.
# Currently this list is: unisim_comp.v fuji.v olympus_comp.v
# The first module definition found will be used to create the parameter types
# so there can be overlapping defintions in the files included although there
# is no error checking to verify that the parameter types match!
$input_file = "./parameter_type.v";
open INFILE, $input_file or die "cannot open input file".$input_file."\n";
open OUTFILE, ">".$ARGV[0] or die "cannot open output file ".$ARGV[0]."\n";

%module_processed = ();
$skip = 0;
$verbose = 0;
# only print out module with parameters. 
$module_name;
while ($line = <INFILE>) {
  if ($line =~ /module\s+(.*)\s+\(/) {
    $module_name = $1;
    $flag = 1;
    if (defined $module_processed{$module_name}) {
      $skip = 1;
      printf STDERR "Module $module_name already processed!\n" if ($verbose);
    } else {
      $module_processed{$module_name} = 1;
    }
  } elsif ($line =~ /endmodule/) {
    $skip = 0;
  } elsif ($skip) {
    next;
  } elsif ($line =~ /parameter\s+(.*)\s+=\s*(.*);/) {
    $name = $1;
    $value = $2;
    if ($flag) {
      printf OUTFILE "module,".$module_name.",\n";
      $flag = 0;
    }
    if ($value =~ /\"/) {
      if ($value =~ /\"TRUE\"/) {
	# bool
	printf OUTFILE $name.",b,\n"; 
      } elsif ($value =~ /\"FALSE\"/) {
	# bool
	printf OUTFILE $name.",b,\n"; 
      } else {
	# string
	printf OUTFILE $name.",s,\n"; 
      }
    } elsif($value =~ /(\d+)\'h/) {
      # bit vector in hex
      $len = $1;
      if ($name =~ /\[.*\]\s+(.*)/) {
	printf OUTFILE $1.",h".$len.",\n";
      } else {
	printf OUTFILE $name.",h".$len.",\n";
      }
    } elsif($value =~ /(\d+)\'b/) {
      # bit vector in binary
      $len = $1;
      if ($name =~ /\[.*\]\s+(.*)/) {
	printf OUTFILE $1.",v".$len.",\n";
      } else {
	printf OUTFILE $name.",v".$len.",\n";
      }
    } elsif($name =~ /real\s+(.*)/) {
      #real
      printf OUTFILE $1.",r,\n";
    } elsif($value =~ /\d+\.\d+/) {
      # real
      printf OUTFILE $name.",r,\n";
    } elsif($name =~ /integer\s+(.*)/) {
      #integer
      printf OUTFILE $1.",i,\n";
    } elsif($value =~ /\d+/) {
      #integer
      printf OUTFILE $name.",i,\n";
    } else {
      die "unrecognized parameter type: ".$line;
    }
  }
}

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
