#!/usr/bin/perl
use strict;
use warnings;

my $num_args = $#ARGV + 1;
if ($num_args == 0) {
  PrintUsage();
  exit 1;
}

use File::Basename;
use lib dirname($0);

use File::Find;
use File::Copy;
use Cwd;

#use Error qw( :try );
#use Exception;
use Getopt::Long;
use LibraryWriters;
use Components;
use Filter;

my $help = 0;
my $language = 'vhdl';
my $library = 'unisim';
my $sourcepath;
my @sourcepaths;
my $outputfile;
my $filterfile;
my @filters;
my @translates;
my $cwd = cwd();
my $debug = 0;

if (!(GetOptions( "help"    => \$help,
				  'f=s'  => \$filterfile,
				  'l=s'  => \$language,
				  's=s'  => \$sourcepath,
				  'o=s'  => \$outputfile,
				  'debug'=> \$debug) ))
{
  PrintUsage();
  exit (1);
} 

# help
if ($help)
{
  PrintUsage();
  exit 1;
}

# use filter file
if (defined $filterfile)
{
  if ( -e $filterfile)
  {
    CreateFilters($filterfile, \@filters, \@translates);
  }
  else
  {
    print "$filterfile is not a valid file.\n";
    exit 1;
  }
}

# language
if ($language =~ /:/)
{
  ($language, $library) = split /:/, $language;

  if (($language !~ /^verilog$/i) && ($language !~ /^vhdl$/i))
  {
    die "Error: Invalid language $language specified.\n";
  }

  if ($library =~ /^u/i)
  {
    $library = 'unisim';
  }
  elsif ($library =~ /^s/i)
  {
    $library = 'simprim';
  }
  else
  {
    die "Error: Invalid library $library specified.\n";
  }
}

# fetch source paths from XILINX
if (!defined $sourcepath)
{
  my @xilinxs = $ENV{XILINX};
  foreach my $xilinx (@xilinxs)
  {
    die "No \$XILINX defined.\n" if (!defined $xilinx);
    my $path = "$xilinx/$language/src/${library}s";
    if (-d $path)
    {
      push @sourcepaths, $path;
      print "The source files path is set to @sourcepaths\n" if ($debug);
      last;
    }
  }
}
else
{
  @sourcepaths = split /#/, $sourcepath;
}

# does source path exist?
foreach $sourcepath (@sourcepaths)
{
  die "Invalid source path $sourcepath.\n" if (! -d $sourcepath);  

}

# output component filename
if (!defined $outputfile)
{
  if ($language eq 'vhdl')
  {
    $outputfile = $library . "_component.vhd";
  }
  else
  {
    $outputfile = $library . "_component.v";
  }
}

# find simulation library files
my @files = @ARGV;
if (@files == 0)
{
  foreach $sourcepath (@sourcepaths)
  {
    if ($language eq 'verilog')
    {
      find sub {push @files, (grep /\.v$/, $File::Find::name);}, $sourcepath;
    }
    elsif ($language eq 'vhdl')
    {
      find sub {push @files, (grep /\.vhd$/, $File::Find::name);}, $sourcepath;
    }
  }
}
else
{
  my @cfiles = @files;
  @files = ();
   
  foreach my $file (@cfiles)
  {
    foreach $sourcepath (@sourcepaths)
    {
      my $fullfile = "$sourcepath/$file";
      if (-e $fullfile)
      {
        push @files, $fullfile;
      }
      else
      {
        print "Error: File $file does not exist in the source path $sourcepath.\n";
      }
    }
  }
}

die "No $language source files were found under the source path $sourcepath.\n" if (@files == 0);

# sort the files
@files = sort @files;
print "$language source files: (@files).\n" if ($debug);

my $components;
if ($language eq 'verilog')
{
  $components = CreateComponents(\@files, $library);
  $components->FilterIt(\@filters);
  $components->WriteVerilogComponentsFile($outputfile, $library, \@translates);
}
elsif ($language eq 'vhdl')
{
  $components = CreateComponents(\@files, $library);
  $components->FilterIt(\@filters);
  $components->WriteVhdlComponentsFile($outputfile, $library, \@translates);
}

sub CreateFilters
{
  my ($file, $filters, $translates) = @_;
   
  open(IN, "$file")  or die "Unable to open file <$file> for output\n";

  my $filter;
  #PrintStdOut("Parsing filter file $file...\n");
  while (my $line = <IN>)
  {
    chomp $line;
    if ($line =~ /^\s*(\S+)\s*:\s*translate_off_on/ )
    {
      my ($module) = split /\.v/, $1;
      my $found = 0;
      foreach my $translate (@$translates)
      {
        if ($translate eq $module)
        {
          $found = 1;
          last;
        }                   
      }
         
      if ($found == 1)
      {
        print "Filter $module has translate_off_on value & empty exist filter (line:$line).\n" if ($debug);
      }
      else
      {
        print "Filter $module has translate_off_on value & Create new translate (line:$line).\n" if ($debug);
        push @$translates, $module;
      }
    }
    elsif ($line =~ /^\s*(\S+)\s*:\s*ignore_module/ )
    {
      my ($module) = split /\.v/, $1;
      my $found = 0;
      foreach $filter (@$filters)
      {
        my $name = $filter->GetName();
        if ($name eq $module)
        {
          $found = 1;
          last;
        }                   
      }
         
      if ($found == 1)
      {
        print "Filter $module has ignore_module value & empty exist filter (line:$line).\n" if ($debug);
        my $properties = $filter->GetProperties();
        @$properties = ();
        #$filter->Dump();
      }
      else
      {
        print "Filter $module has ignore_module value & Create new filter (line:$line).\n" if ($debug);
        $filter = new Filter($module, undef);
        #$filter->Dump();
        push @$filters, $filter;
      }
    }
    elsif ($line =~ /^\s*(\S+)\s*:(\s*(\S+))/)
    {
      my ($vfile, $property) = split /\s*:\s*/, $line;
      my ($module) = split /\.v/, $vfile;
      ($property) = split /;/, $property;
      my @properties = split /\s+/, $property;
      $property = join ' ', @properties;
      @properties = split /\s+/, $property;
      print "Filter property '@properties'\n" if ($debug);
         
      my $found = 0;
      foreach $filter (@$filters)
      {
        my $name = $filter->GetName();
        if ($name eq $module)
        {
          $found = 1;
          last;
        }                   
      }
         
      if ($found == 1)
      {
        print "Adding new property to existing filter $module (line:$line).\n" if ($debug);
        foreach $property (@properties)
        {
          my $prop = new Property($property, undef, undef, undef);
          $filter->AddProperty($prop);
        }
        #$filter->Dump();
      }
      else
      {
        print "Create new filter $module with new porperty (line:$line).\n" if ($debug);
        $filter = new Filter($module, undef);
        foreach $property (@properties)
        {
          my $prop = new Property($property, undef, undef, undef);
          $filter->AddProperty($prop);
        }            
        #$filter->Dump();
        push @$filters, $filter;
      }
    }   
  }
      
  close(IN);

  if ($debug)
  {
    print "*********************** Dumping FILTER Definitions ***********************\n";
    foreach $filter (@$filters)
    {
      $filter->Dump();
    }
  }
   
  return $components;
}

sub CreateComponents
{
  my ($files, $library) = @_;
   
  my $property = new Property("Name", "Type", "Default");
  my $port = new Port("Name", "Type");
  my $component = new Component("Vhdl", "Name", $property, $port);
  my $components = new Components("VHDL", $component);

  $components->DeleteComponent($component);
  $component->DeleteProperty($property);   
  $component->DeletePort($port);
   
  foreach my $file (@$files)
  {
    my ($base, $path, $ext) = fileparse($file, ('\.vhd', '\.v'));
    if ($base eq "test_comp") {
    }
    elsif ($ext eq '.vhd')
    {
      CreateComponentsFromVhdlFile($components, $file, $library);
    }
    elsif ($ext eq '.v')
    {
      CreateComponentsFromVerilogFile($components, $file, $library);
    }
    else
    {
      print "Invalid file extension '$ext' in file '$file'.";
    }
  }
   
  return $components;
}

sub CreateComponent
{
  my ($language, $name) = @_;
   
  my $property = new Property("Name", "Type", "Default");
  my $port = new Port("Name", "Type");
  my $component = new Component($language, $name, $property, $port);

  $component->DeleteProperty($property);
  $component->DeletePort($port);

  #$component->Dump();
  return $component;
}
   
sub CreatePropertiesFromVhdlFile
{
  my ($component, $FH, $library) = @_;
   
  while (my $line = <$FH>)
  {
    if ($line =~ /^\s*(\w+)\s*:\s*(\w+)\s*(\(\d+\s+\w+\s+\d+\)\s*)*:=\s*/i)
    {
      my $name = $1;
      my $type = $2;
      # Skip generic MsgOn Xon, TimingCkecksOn, InstancePath, LOC
      next if ((($name =~ /^MsgOn$/i) || ($name =~ /^Xon$/i) || ($name =~ /^TimingChecksOn$/i) ||
               ($name =~ /^InstancePath$/i) || ($name =~ /^LOC$/i)  || ($type =~ /^VitalDelay/i)) &&
               ($library eq 'unisim'));
         
      if ($line =~ /--/)
      {
        print "Before trimming : $line" if ($debug);
        ($line) = split /--/, $line;
        print "After trimmign : $line\n" if ($debug);
      }
      my $property = new Property($name, $type, undef, $line);
      $component->AddProperty($property);
    }     
    elsif ($line =~ /^\s*port\s*\(/i)
    {
      CreatePortsFromVhdlFile($component, $FH);
      last;
    }
    elsif ($line =~ /^\s*\)\;/)
    {
      last;
    }
  }
}

sub CreatePortsFromVhdlFile
{
  my ($component, $FH) = @_;
   
  while (my $line = <$FH>)
  {
    #if ($line =~ /^\s*(\w+)\s*:\s+([in|out|inout])\s+(\w+)\s*(\(*\))*\s*;/)
    if ($line =~ /^\s*(\w+)\s*:\s+(\w+)\s+(\w+)\s*(\((\d+)\s+(\w+)\s+(\d+)\))*\s*/i)
    {
      my $port;
      if (defined $4)
      {
        $port = new Port($1, $2, $3, $5, $7, $line);
      }
      else
      {
        $port = new Port($1, $2, $3, undef, undef, $line);
      }
      $component->AddPort($port);
    }
    elsif ($line =~ /^\s*\)\;/)
    {
       last;
    }
  }
}

sub CreateComponentsFromVhdlFile
{
  my ($components, $file, $library) = @_;
  my $isEntity = 0;
  my $component;
  my $entityName;

  open(IN, "$file")  or die "Unable to open file <$file> for output\n";

  #PrintStdOut("Parsing file $file...\n");
  while (my $line = <IN>)
  {
    chomp $line;
    if ($isEntity == 0)
    {
      if ($line =~ /^\s*entity\s+(\w+)\s+/i)
      {
        #($entityName, undef) = split / */, $line;
        $entityName = $1;
        $isEntity = 1;
			
        $component = $components->FindComponentByName($entityName);
			
        if (!$component)
        {
          print "______________________________________________________________________________________\n" if ($debug);
          print "Start of component creation for VHDL component $entityName\n" if ($debug);
          $component = CreateComponent("vhdl", $entityName);
          $components->AddComponent($component);
        }
        else
        {
          print "______________________________________________________________________________________\n" if ($debug);
          print "Find existing VHDL component $entityName\n" if ($debug);
        } 
      }
    }
    else
    {
      if ($line =~ /generic\s*\(/i)
      {
        print "Creating properties for component $entityName\n" if ($debug);
        CreatePropertiesFromVhdlFile($component, *IN, $library);
      }   
      elsif ($line =~ /^\s*port\s*\(/i)
      {
        print "Creating ports for component $entityName\n" if ($debug);
        CreatePortsFromVhdlFile($component, *IN);
      }
      elsif ($line =~ /end\s+$entityName\s*;/i)
      {
        $isEntity = 0;         
        if ($debug)
        {     
          print "End of component creation for component $entityName\n" if ($debug);
          #$component->Dump();
          print "______________________________________________________________________________________\n" if ($debug);
        }
      }
    }
  }

  close(IN);

  #my $record = $components->DumpToVhdlString();
  #print $record;
  return $components;
}

sub CreatePropertyFromVerilogFile
{
  my ($component, $line) = @_;
   
  if ($line =~ /^\s*parameter(\s+\w+)*(\s+\[\d+\s*:\s*\d+\])*\s+(\w+)\s*=\s*(\S+)/)
  {
    my $property;
    $property = new Property($3, undef, $4, $line);
    $component->AddProperty($property);
  }
}

sub CreatePortFromVerilogFile
{
  my ($component, $line) = @_;
   
  my $port;
  if ($line =~ /^\s*(\w+)\s+(reg|wire)\s+\[(\d+):(\d+)\]\s+((\w+)(\s*,\s*\w+)*)/ )
  {
    my @ports = split /\s*,\s*/, $5;
    foreach my $name (@ports)
    {
      $port = new Port($name, $1, $2, $3, $4, $line);
      $component->AddPort($port);
    }
  }
  elsif ($line =~ /^\s*(\w+)\s+\[(\d+):(\d+)\]\s+((\w+)(\s*,\s*\w+)*)/ )
  {
    my @ports = split /\s*,\s*/, $4;
    foreach my $name (@ports)
    {
      $port = new Port($name, $1, undef, $2, $3, $line);
      $component->AddPort($port);
    }
  }
  elsif ($line =~ /^\s*(\w+)\s+(reg|wire)\s+((\w+)(\s*,\s*\w+)*)/ )
  {
    my @ports = split /\s*,\s*/, $3;
    foreach my $name (@ports)
    {
      $port = new Port($name, $1, $2, undef, undef, $line);
      $component->AddPort($port);
    }   
  }
  elsif ($line =~ /^\s*(\w+)\s+((\w+)(\s*,\s*\w+)*)/ )
  {
    my @ports = split /\s*,\s*/, $2;
    foreach my $name (@ports)
    {
      $port = new Port($name, $1, undef, undef, undef, $line);
      $component->AddPort($port);
    }   
  }
}

sub CreateComponentsFromVerilogFile
{
  my ($components, $file, $library) = @_;
  my $isModule = 0;
  my $component;
  my $moduleName;

  open(IN, "$file")  or die "Unable to open file <$file> for output\n";

  #PrintStdOut("Parsing file $file...\n");
  while (my $line = <IN>)
  {
    chomp $line;
    if ($isModule == 0)
    {
      if ($line =~ /^\s*module\s+(\w+)\s*/)
      {
        $moduleName = $1;
        $isModule = 1;
			
        $component = $components->FindComponentByName($moduleName);
			
        if (!$component)
        {
          print "______________________________________________________________________________________\n" if ($debug);
          print "Start of component creation for VERILOG component $moduleName\n" if ($debug);
          $component = CreateComponent("verilog", $moduleName);
          $components->AddComponent($component);
        }
        else
        {
          print "______________________________________________________________________________________\n" if ($debug);
          print "Find existing VERILOG component $moduleName\n" if ($debug);
        }
      }
    }
    else
    {
      if ($line =~ /^\s*parameter\s+/)
      {
        if ($debug)
        {
          print "Creating property for component $moduleName ($line)\n" if ($debug);
        }   
        CreatePropertyFromVerilogFile($component, $line);
      }   
      elsif (($line =~ /^\s*input/) || ($line =~ /^\s*output/) || ($line =~ /^\s*inout/))
      {
        print "Creating port for component $moduleName ($line)\n" if ($debug);
        CreatePortFromVerilogFile($component, $line);
      }
      elsif ($line =~ /^\s*endmodule\s*/ ||
             $line =~ /^\s*task\s*/ ||
             $line =~ /^\s*function\s*/) # 06092009:chen
      {
        $isModule = 0;              
        print "End of component creation for component $moduleName\n" if ($debug);
        #$component->Dump();
        print "______________________________________________________________________________________\n" if ($debug);
      }
    }
  }

  close(IN);

  #my $record = $components->DumpToVerilogString();
  #print $record;
  return $components;
}

sub PrintUsage 
{  
  PrintStdOut("usage:  gencomp.pl [-f <FilterFile>] [-help] -l <Language>[:<Library>] [-s <SourcePath>[:<SourcePath>]] [-o <OutputFile>] [<VhdlVerilgFile>] [<VhdlVerilgFile>...]\n");
  PrintStdOut("--------------------------------------------------------\n"); 
  PrintStdOut("   -l <Language>          : Specify the language type. Valid types are vhdl verilog.\n");
  PrintStdOut("                            Specify unisims or simprims with the optional <Library> modifier.\n");
  PrintStdOut("                            Valid values for <Library> are u or s. If <Library> is not specified\n");
  PrintStdOut("                            then by default gencomp will pick unisim (u).\n");
  PrintStdOut("                            This is required option.\n");
  PrintStdOut("   -f <FilterFile>        : Specify the name of file containing list of parameters to be \n");
  PrintStdOut("                            removed from component. See below an example of filter\n");
  PrintStdOut("                            file (filter.lst)..\n");
  PrintStdOut("   -o <OutputFile>        : Specify the output file. By default the output file is\n");
  PrintStdOut("                            [unisim|simprim]_component.vhd (VHDL) and [unisim|simprim]_component.v\n");
  PrintStdOut("                            (VERILOG) in current directory.\n");
  PrintStdOut("   -s <SourcePath>        : Specify the source files path.\n");
  PrintStdOut("                            By default the source path is \$XILINX/<Language>/src/<Library>.\n");
  PrintStdOut("   -help                  : Print the help usage.\n\n");
   
  print <<HEADER;
Example: 

   # gencomp -l verilog

    This command will extract the unisim components from
    \$XILINX/verilog/src/unisims and creates unisim_component.v file
    in the current directory.

   # gencomp -l verilog -s \$XILINX/verilog/src

    This command will extract the unisim components from
    \$XILINX/verilog/src and creates unisim_components.v file
    in the current directory.

   # gencomp -l verilog -s \$MYAREA/src -o /tmp/unisims/unisim_component.v -f filter.list

    This command will extract the unisim components from
    \$MYAREA/src and creates unisim_component.v file in 
    /tmp/unisims/unisim_component.v. The parameters specified in filter.list will be
    removed from the components.

   # gencomp -l vhdl:s -s /my/local/vhdl -o .

    This command will extract the simprim components from
    /my/local/vhdl and creates simprim_component.vhd
    in the current directory.

Example : filter.lst

    BUFGCTRL.v: parameter SIM_X_INPUT = "GENERATE_X";
    CLKDLL.v:parameter MAXPERCLKIN = 100000;
    CLKDLLE.v:parameter MAXPERCLKIN = 100000;
    CLKDLLHF.v:parameter MAXPERCLKIN = 100000;
    DCM.v:parameter MAXPERCLKIN = 1000000;
    DCM.v:parameter MAXPERPSCLK = 100000000;
HEADER
}


# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
