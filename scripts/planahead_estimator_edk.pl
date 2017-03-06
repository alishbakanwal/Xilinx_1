#!/usr/local/bin/perl
# This script runs the PlanAhead resource estimator on 
# a given EDK project.  This script should be run from
# an estimation directory from the top-level of an EDK 
# project. 
# 5/7/2008
# Author: Paul Schumacher (Xilinx Research Labs)

# Check arguments
unless ($#ARGV == -1 or $#ARGV == 1) {
	die "Usage: xilperl planahead_estimator_edk.pl [-p <PART>]";
}
unless ( -e "../synthesis" ) {
	die "Cannot find ../synthesis directory";	
}

#
# Script settings
#
my $Debug = 0;
my $UseGold = 1;
my $Version = "10.1.4";

my $PlanAheadPath = "/group/hd/public/install/hdi/planAhead$Version/bin";
if ($UseGold == 1) {
	$PlanAheadPath = "/group/hd/builds/gold/RUNNING_BUILD/packages/planAhead-10.2.KPA0-lnx24/prep/hdi/planAhead10.2.KPA0/bin";
}

my $TopDesignName = "system";

#my $RunDir = "estimation";
my $ProjectFileName = "all.prj";
my $TclFileName = "all.tcl";

#
# Concatenate XST project files
#
#if ( not -e "$RunDir" ) {
#	`mkdir $RunDir`;
#	`chmod 770 $RunDir`;
#}

if ( -e "$ProjectFileName" ) {
	`rm -f $ProjectFileName`;
}
	
`cat ../synthesis/*xst.prj > $ProjectFileName`;

#
# Get FPGA family name
#
my $FamilyName = "virtex4";
if ($#ARGV == 1) {
	$PartName = @ARGV[1];
	
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
# Create Tcl script & decrypt source files
#
sub CreateTclFile() {
  if ($Debug>0) {print("Generating $TclFileName...\n");}
  
  open(TCL_FILE, ">$TclFileName") || die "ERROR: Can't open $TclFileName : $!.\n";
  #binmode(TCL_FILE); # Write in binary mode to avoid windows issues  

	my $TmpDir = "tmp";
	if ( -e "$TmpDir" ) {
		`rm -rf $TmpDir/*`;
	} else {
    `mkdir $TmpDir`;
    `chmod 770 $TmpDir`;
  }
    
  # Introductory stuff...
	print(TCL_FILE "hdi::param set -name rest.run -bvalue yes\n");
	print(TCL_FILE "hdi::param set -name rest.report -bvalue yes\n");
	#print(TCL_FILE "hdi::param set -name rest.quickEstimate -bvalue yes\n");
	#print(TCL_FILE "hdi::param set -name rest.estimateOnly -bvalue yes\n");
	
	print(TCL_FILE "hdi::project new -dir . -name project_1\n");
	print(TCL_FILE "hdi::project setArch -name project_1 -arch \"$FamilyName\"\n\n");
	
  # Second, we need to list the source code for planAhead 
  # NOTE: copy from the concatenated XST project file
  my $FileNum = 0;
  my $SourceFileName;
  my $SourceType;
  my $LibName;
  
  if ($Debug>0) {print("Opening XST project file: $ProjectFileName...\n");}
  open(PRJ_FILE, "<$ProjectFileName") || die "ERROR: Can't open $ProjectFileName : $!.\n";
  
  while (my $line = <PRJ_FILE>) {
  	$FileNum++;
    ($SourceType, $LibName, $SourceFileName) = split(/\s+/, $line, 3);
    chomp($SourceFileName);
    my $FileExt = "v";
    if ($SourceType =~ /vhdl/i) {
    	$FileExt = "vhd";
    }
    
    if ( not -e "$TmpDir/$LibName" ) {
    	`mkdir $TmpDir/$LibName`;
    	`chmod 770 $TmpDir/$LibName`;
    	print(TCL_FILE "hdi::design addSource -project project_1 -source $TmpDir/$LibName -library $LibName\n");
  	}
  
    my $NewFileName = "$TmpDir/$LibName/file$FileNum.$FileExt";
    if ($Debug>0) {print("original filename: $SourceFileName\n  new filename: $NewFileName\n");}
    `xilzip $SourceFileName $NewFileName`;
  }
  close(PRJ_FILE);
  
  # Next, include any cores, ngc files, etc.
  if ( -e "../implementation" ) {
  	print(TCL_FILE "hdi::design addSource -project project_1 -source ../implementation\n");	
  }
  
  # Finally, request elaboration and stats file then close
  if ($Debug>0) {print("Using $TopDesignName as top-level for elaboration...\n");}
  print(TCL_FILE "hdi::design elaborate -project project_1 -top $TopDesignName\n");
  print(TCL_FILE "hdi::report stats -project project_1 -netlist yes -rtl yes -fileName $TopDesignName\_stats.txt\n");
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
  
  if ( -e "transcript.txt" ) {
		`rm -f transcript.txt`;
	}
	
  if ("$OperatingSystem" =~ /linux/i) {
		`$PlanAheadPath/planAhead -mode batch -regress yes -source $TclFileName > transcript.txt`;
	} else {
		`$PlanAheadPath/planAhead.bat -mode batch -regress yes -source $TclFileName > transcript.txt`;
	}
}
RunResourceEstimator();
	
# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
