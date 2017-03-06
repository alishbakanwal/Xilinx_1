#!/usr/local/bin/perl
# This script runs the PlanAhead resource estimator given an XST project file 
# 4/29/2008
# Author: Paul Schumacher (Xilinx Research Labs)

# Check arguments
unless ($#ARGV == 0 or $#ARGV == 2) {
	die "Usage: xilperl planahead_estimator.pl <XST project file>.prj [-p <PART>]";
}

my $Debug = 0;
my $Version = "10.1.4";
my $PlanAheadPath = "/group/hd/public/install/hdi/planAhead$Version/bin";

# XST project file and Tcl script names
$ProjectFileName = @ARGV[0];
$ProjectFileName =~ tr/A-Z/a-z/;

if (not $ProjectFileName =~ m/.prj/){
	print("Expecting .prj extension - is this an XST project file?\n");
	exit(-1);
}
my $TclFileName = $ProjectFileName;
$TclFileName =~ s/.prj/.tcl/;

#
# Get FPGA family name
#
$FamilyName = "virtex4";
if ($#ARGV == 2) {
	$PartName = @ARGV[2];
	
	if ("$PartName" =~ /xc2v/i or "$PartName" =~ /2v/i) {
		$FamilyName = "virtex2";
	}
	elsif ("$PartName" =~ /xc4v/i or "$PartName" =~ /4v/i) {
		$FamilyName = "virtex4";
	}
	elsif ("$PartName" =~ /xc5v/i or "$PartName" =~ /5v/i) {
		$FamilyName = "virtex5";
	}
	elsif ("$PartName" =~ /xc3s/i or "$PartName" =~ /3s/i) {
		$FamilyName = "spartan3";
	}
}

#
# Create Tcl Script File
#
sub CreateTclFile() {
  if ($Debug>0) {print("Generating $TclFileName...\n");}
  
  open(TCL_FILE, ">$TclFileName") || die "ERROR: Can't open $TclFileName : $!.\n";
  binmode(TCL_FILE); # Write in binary mode to avoid windows issues  

  # Introductory stuff...
	print(TCL_FILE "hdi::param set -name rest.run -bvalue yes\n");
	print(TCL_FILE "hdi::param set -name rest.report -bvalue yes\n");
	#print(TCL_FILE "hdi::param set -name rest.verbose -ivalue 0\n");
	#print(TCL_FILE "hdi::param set -name rest.reportHierLevel -ivalue 2\n\n");
	
	print(TCL_FILE "hdi::project new -dir . -name project_1\n");
	print(TCL_FILE "hdi::project setArch -name project_1 -arch \"$FamilyName\"\n\n");
	
  # Second, we need to list the source code for planAhead 
  # NOTE: If an XST project file is available, then let's cut and paste!
  my $SourceFileName;
  my $SourceType;
  my $LibName;
  if ( -r "$ProjectFileName" ) {
    if ($Debug>0) {print("Opening XST project file: $ProjectFileName...\n");}
    open(PRJ_FILE, "<$ProjectFileName") || die "ERROR: Can't open $ProjectFileName : $!.\n";
    
    while (my $line = <PRJ_FILE>) {
      ($SourceType, $LibName, $SourceFileName) = split(/\s+/, $line);
      print(TCL_FILE "hdi::design addSource -project project_1 -source $SourceFileName -library $LibName\n");
    }
    close(PRJ_FILE);
  }
  else {
    print("Error: XST project file not found\n");
    exit(-1);
  }
  
  # Next, we need to find the top-level design.
	# Let's make a guess based on the last file read
	#chop($SourceFileName);
	$SourceFileName =~ s/\"//g;
	my $label1;
	my $label2;
	my $TopDesignName = $SourceFileName;
	$TopDesignName =~ s/.vhd//;
	$TopDesignName =~ s/.v//;
	
	if ( -r "$SourceFileName" ) {
		if ($Debug>0) {print("Getting top-level entity name from: $SourceFileName...\n");}
		open(LAST_FILE, "$SourceFileName") || die "ERROR: Can't open $SourceFileName : $!.\n";
		
		while (my $line2 = <LAST_FILE>) {
			if ($line2 =~ /^entity\b/i or $line2 =~ /^module\b/i){
	      ($label1, $TopDesignName, $label2) = split(/\s+/, $line2);
	    } 
		}
		close(LAST_FILE);
	}
	if ($Debug>0) {print("Using $TopDesignName as top-level for elaboration...\n");}
	
  # Finally, request elaboration of design then close
  print(TCL_FILE "hdi::design elaborate -project project_1 -top $TopDesignName\n");
  close(TCL_FILE);
  `chmod 770 $TclFileName`;
} 
CreateTclFile();

#
# Run PlanAhead resource estimator
#
sub RunResourceEstimator() {
	my $OperatingSystem = $^O;
	if ($Debug>0) {print("OS = $OperatingSystem\n");}
  
  if ("$OperatingSystem" =~ /linux/i) {
		`$PlanAheadPath/planAhead -mode batch -regress yes -source $TclFileName > transcript.txt`;
	} else {
		`$PlanAheadPath/planAhead.bat -mode batch -regress yes -source $TclFileName > transcript.txt`;
	}
}
RunResourceEstimator();
	
# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
