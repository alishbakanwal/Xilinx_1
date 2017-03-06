#!/usr/bin/perl
package LibraryWriters;

# Export public functions from this module.
require Exporter;
@LibraryWriters::ISA = qw(Exporter);
@LibraryWriters::EXPORT = qw(
  GetGold
  Push Unshift UpIndent DownIndent IndentStdOut PrintStdOut IndentFH PrintFH IndentString
  GetInputBuses GetOutputBuses IsBusVisible GetInputPins GetOutputPins
  GetValueNames GetAttributeEncodings GetAttributeValues GetMin GetMax
  GetBlockName IsSwiftModel GetBlockDelayRecords
  GetParams CheckPrimitive
  GetVerilogLibraryFiles GetVhdlLibraryFiles
  DumpDelaysOnBlock DumpDelay
  CreatePFDFromVhdlFiles CreatePFDFromVhdlComponents 
  CreatePFDFromVerilogFiles CreatePFDFromVerilogModules
  CreatePFDFromGoldSites CreatePFDFromGoldBlocks CreatePFDFromGoldBlock
  CreatePFDFromPropertyFilteringACDFiles
  CreateLibraryPFD GetLibraryCells GetEnvACDFiles GetRtfACDFiles
  CheckPFDs
);

use strict;
use warnings;

#use lib "/build/xfndry/HEAD/env/Misc/BuildTools/export/lib";
use File::Basename;
use File::Find;
use File::Basename;
#use Exception;

my $indent = 0;

sub Push
{
  my ($records, $record) = @_;

  return if (!(defined $record) || ($record eq ''));
      
  my $duplicated = 0;
  foreach my $rec (@$records)
  {
    if ($rec eq $record)
    {
      return;
    }	  
  }

  push @$records, $record;
}

sub Unshift
{
  my ($records, $record) = @_;

  return if (!(defined $record) || ($record eq ''));
      
  my $duplicated = 0;
  foreach my $rec (@$records)
  {
    if ($rec eq $record)
    {
      return;
    }	  
  }

  unshift @$records, $record;
}

sub UpIndent
{
  $indent++;
}

sub DownIndent
{
  $indent--;
}

sub IndentStdOut
{
  my $count = 0;
  while ($count < $indent)
  {
    print '  ';
    $count++;
  }
}

sub PrintStdOut
{
  my ($str, $log) = @_;
  
  if (defined $log)
  {
    IndentFH($log);
    PrintFH($log, $str);
  }
  IndentStdOut();
  print $str;
}

sub IndentFH
{
  my $FH = shift;
  my $count = 0;
  while ($count < $indent)
  {
    print $FH '  ';
    $count++;
  }
}

sub PrintFH
{
  my ($FH, $str) = @_;
  IndentFH($FH);
  print $FH $str;
}

sub IndentString
{
  my $str = shift;
  my $count = 0;
  while ($count < $indent)
  {
    $$str .= '  ';
    $count++;
  }
}

sub GetInputBuses
{
  my $block = shift;
  my @inBuses;

  my @buses = $block->GetBuses();
  foreach my $bus (@buses)
  {	  
    push @inBuses, $bus if ($bus->GetIoType() eq 'input');
  }

  return @inBuses;
}

sub GetOutputBuses
{
  my $block = shift;
  my @outBuses;

  my @buses = $block->GetBuses();
  foreach my $bus (@buses)
  {	  
    push @outBuses, $bus if ($bus->GetIoType() eq 'output');
  }

  return @outBuses;
}

sub GetInputPins
{
  my $block = shift;
  my @inPins;

  my @pins = $block->GetPins();
  foreach my $pin (@pins)
  {	  
    push @inPins, $pin if ($pin->GetIoType() eq 'input');
  }

  return @inPins;
}

sub GetOutputPins
{
  my $block = shift;
  my @outPins;

  my @pins = $block->GetPins();
  foreach my $pin (@pins)
  {	  
    push @outPins, $pin if ($pin->GetIoType() eq 'output');
  }

  return @outPins;
}

sub IsBusVisible
{
  my $bus = shift;
  return 0 if (!defined $bus);
   
  my $block = $bus->GetBlock();
  return 0 if (!defined $block);
   
  my $isTestPin = 0;
  my @pins = $bus->GetPins();
  foreach my $pin (@pins)
  {	 
    if ($pin->IsTest())
    {
      $isTestPin = 1;
    }
  }

  my $isTestBlock = $block->IsTest();
  $isTestBlock = 0 if (!defined $isTestBlock);
  my $visible = (!$isTestPin || $isTestBlock);
  return $visible;
}

sub GetValueNames
{
  my ($attr, $attrType, $attrName) = @_;
  my $valueNames;
  my $default = 'UNKNOWN';
  my @values;
  my $min = $attr->GetMin();
  my $max = $attr->GetMax();
  my $storageMethod = $attr->GetStorageMethod();
  if (($storageMethod =~ /MODES/ixms) ||
     (($storageMethod =~ /DESIGN_PROPERTY/ixms) &&
     (($attrType =~ /string/ixms) || ($attrType =~ /boolean/ixms) ||
      ($attrType =~ /decimal/ixms) || ($attrType =~ /float/ixms))))
  {
    $default = $attr->GetDefaultValue({asEntered => 1});
    if ($attrType =~ /binary/ixms)
    {
      my $numBits = $attr->GetNumEncodingBits();
      $default = sprintf("%d\'b%s", $numBits, $default);
    }
    my @enums = $attr->GetValueEnums();
    my $names = '';
    for my $enum (@enums)
    {
      if ($enum->IsDefault()){
          $default = $enum->GetValue();
          push @values, $default;
      }
      else {
        $names .= ',' if ($names ne '');
        $names .= $enum->GetValue();
        push @values, $enum->GetValue();
      }
    }
    $valueNames = $default unless ($default eq 'UNKNOWN');
    if ($names ne '') {
      $valueNames .= ',' if (defined $valueNames);
      $valueNames .= $names;
    }
    if (@enums > 2 and $attrType =~ /integer/ixms) {
# See if we can express the set with the compressed n..m form
      my @vals = map { int($_) } sort { $a <=> $b }
      (split /,/, $valueNames);
      if ($vals[-1] - $vals[0] + 1 == @vals) {
        $valueNames = $vals[0] . '..' . $vals[-1];
      }
    }
  }
  elsif (($storageMethod =~ /GCD/isxm) ||
        (($storageMethod =~ /DESIGN_PROPERTY/ixms) &&
        (($attrType =~ /binary/ixms) || ($attrType =~ /hex/ixms)))){
    my $numBits = $attr->GetNumEncodingBits();
    $default = $attr->GetDefaultValue({asEntered => 1});
    if (defined $default) {
      if ($attrType =~ /hex/ixms) {
        (undef, $default) = split /0x/, $default if ($default =~ /0x/);
        if ($numBits == 0)
        {
          $numBits = (length $default) * 4;
        }
        #$default = sprintf("%d\'h%0${digits}x", $numBits, $default);
        $default = sprintf("%d\'h%s", $numBits, $default) if (($default !~ /^(\d+)'h/) && ($default !~ /^0x/));
        #$valueNames = $numBits . '-bit ' . $attrType;
        $valueNames = $attr->GetMin() . '..' . $attr->GetMax();
        push @values, $valueNames;
      }
      elsif ($attrType =~ /binary/ixms) {
        $default = sprintf("%d\'b%s", $numBits, $default) if ($default !~ /(\d+)'b/);
        #$valueNames = $numBits . '-bit ' . $attrType;
        $valueNames = $attr->GetMin() . '..' . $attr->GetMax();
        push @values, $valueNames;
      }
      elsif ($attrType =~ /float/ixms) {
        #$default = sprintf("%1.1F", $default); # 09022009:chen:this caused truncation 
        $valueNames = $attr->GetMin() . '..' . $attr->GetMax();
        push @values, $valueNames;
      }
      elsif ($attrType =~ /integer/ixms ||
             $attrType =~ /decimal/ixms)
      {
        $default = sprintf("%d", $default);
        if (defined $min && defined $max)
        {
          $valueNames = int($min) . '..' . int($max);
          for (my $i = $min; $i <= $max; $i++)
          {
            push @values, $i;
          }
        }
        push @values, $default if (@values == 0);  
      }
      elsif (($attrType =~ /string/ixms) || ($attrType =~ /boolean/ixms))
      {
        if ((defined $min) && (defined $max))
        {
          $valueNames = $min . '..' . $max;
          push @values, $valueNames;
        }
      }
      else
      {
        print STDERR "Unknown type $attrType in attr $attrName\n";
      }
    }
    else {
      $default = "*UNKNOWN*";
    }
  }
  else {
    $default = $attr->GetDefaultValue();
    $valueNames = $default;
    push @values, $default;
  }
   
  return ($valueNames, $default, @values);
}

sub GetAttributeEncodings
{
  my $attr      = shift;
  my $encodings = '';
  my @enumValues = ();
  my $numBits = 0;
  my $attrName = $attr->GetName();
  my $attrType = $attr->GetType();
  my $storageMethod = $attr->GetStorageMethod();
  if (($storageMethod =~ /MODES/ixms) ||
     (($storageMethod =~ /DESIGN_PROPERTY/ixms) &&
     (($attrType =~ /string/ixms) || ($attrType =~ /boolean/ixms) || 
      ($attrType =~ /decimal/ixms) || ($attrType =~ /float/ixms))))
  {
    my @enums = $attr->GetValueEnums();
    @enumValues = map { $_->GetEncoding() } @enums;
    $encodings = join("\t", @enumValues);
  }
  elsif (($storageMethod =~ /GCD/ixms) ||
        (($storageMethod =~ /DESIGN_PROPERTY/ixms) &&
        (($attrType =~ /binary/ixms) || ($attrType =~ /hex/ixms))))
  {
    my $min = $attr->GetMin({asInteger => 1});
    my $max = $attr->GetMax({asInteger => 1});
    $numBits = $attr->GetNumEncodingBits();
    $numBits = 0 if (!defined $numBits);
    if ((defined $min) && (defined $max))
    {
      $encodings = $attr->GetEncodingForValue($min) . '..'
            . $attr->GetEncodingForValue($max);
      @enumValues = split /\t/, $encodings;
    }
  }
  else
  {     
    print STDERR "Bogus attribute ($attrName) storage method $storageMethod\n";
  }
   
  return ($numBits, @enumValues);
}

sub GetAttributeValues
{
  my ($attr, $attrType, $attrName) = @_;
  my $valueNames;
  my $default = 'UNKNOWN';
  my @values;
  my $encodings = '';
  my @enumValues = ();
  my $numBits = 0;
  my $storageMethod = $attr->GetStorageMethod();
  if (($storageMethod =~ /MODES/ixms) ||
     (($storageMethod =~ /DESIGN_PROPERTY/ixms) &&
     (($attrType =~ /string/ixms) || ($attrType =~ /boolean/ixms) || 
     ($attrType =~ /decimal/ixms) || ($attrType =~ /float/ixms))))
  {
    my @enums = $attr->GetValueEnums();
    my $names = '';
    for my $enum (@enums)
    {
      if ($enum->IsDefault())
      {
        $default = $enum->GetValue();
        $valueNames .= ',' if ($valueNames ne '');
        $valueNames .= $default;
        push @values, $default;
      }
      else
      {
        $valueNames .= ',' if ($valueNames ne '');
        $valueNames .= $enum->GetValue();
        push @values, $enum->GetValue();
      }
    }
# See if we can express the set with the compressed n..m form
    if (@enums > 2 and $attrType =~ /integer/ixms)
    {
      my @vals = map { int($_) } sort { $a <=> $b }
      (split /,/, $valueNames);
      if ($vals[-1] - $vals[0] + 1 == @vals)
      {
        $valueNames = $vals[0] . '..' . $vals[-1];
      }
    }

    @enumValues = map { $_->GetEncoding() } @enums;
    $encodings = join("\t", @enumValues);
  }
  elsif (($storageMethod =~ /GCD/ixms) ||
        (($storageMethod =~ /DESIGN_PROPERTY/ixms) &&
        (($attrType =~ /binary/ixms) || ($attrType =~ /hex/ixms))))
  {
    $numBits = $attr->GetNumEncodingBits();
    $numBits = 0 if (!defined $numBits);
    $default = $attr->GetDefaultValue();
    if (defined $default)
    {
      if ($attrType =~ /hex/ixms)
      {
        my $digits = $numBits/4;
#$default = sprintf("%d\'h%0${digits}x", $numBits, $default);
        $default = sprintf("%d\'h%0x", $numBits, $default);
        $valueNames = $numBits . '-bit ' . $attrType;
        push @values, $valueNames;
      }
      elsif ($attrType =~ /binary/ixms)
      {
        $default = sprintf("%d\'b%0${numBits}b", $numBits, $default);
        $valueNames = $numBits . '-bit ' . $attrType;
        push @values, $valueNames;
      }
      elsif ($attrType =~ /float/ixms)
      {
        $default = sprintf("%1.1F", $default);
        $valueNames = $attr->GetMin() . '..' . $attr->GetMax();
        push @values, $valueNames;
      }
      elsif ($attrType =~ /integer/ixms ||
             $attrType =~ /decimal/ixms)
      {
        $default = sprintf("%d", $default);
        $valueNames = int($attr->GetMin()) . '..' . int($attr->GetMax());
        for (my $i = $attr->GetMin(); $i < $attr->GetMax(); $i++)
        {
          push @values, $i;
        }
      }
      elsif (($attrType =~ /string/ixms) || ($attrType =~ /boolean/ixms))
      {
        $valueNames = $attr->GetMin() . '..' . $attr->GetMax();
        push @values, $valueNames;
      }
      else
      {
        print STDERR "Unknown type $attrType in attr $attrName\n";
      }
    }
    else
    {
      $default = "*UNKNOWN*";
    }

    $encodings = $attr->GetEncodingForValue($attr->GetMin({asInteger => 1})) . '..'
               . $attr->GetEncodingForValue($attr->GetMax({asInteger => 1}));
    @enumValues = split /\t/, $encodings;
  }
  else
  {
    print STDERR "Bogus attribute storage method $storageMethod for $attrName\n";
  }
 
  return ($valueNames, @values, $encodings, @enumValues, $default, $numBits);
}

sub IsSwiftModel
{
  my $blockName = shift;
  if ($blockName =~ /GT11/ || $blockName =~ /PCIE/ ||
      $blockName =~ /EMAC/ || $blockName =~ /PPC/ ||
      $blockName =~ /GTP/)
  {
     return 1;
  }
  else
  {
    return 0;
  }   
}

sub GetBlockName
{
  my $block = shift;
  my $blockName = "UNKNOWN";
  return $blockName if (!defined $block);
  if ($block->IsSimprimBlock() && ($block->GetName() !~ /X_/ixms))
  {
    $blockName = "X_" . $block->GetName();
  }
  else
  {
    $blockName = $block->GetName();
  }
  #$blockName = $block->GetName();
  return $blockName;
}

sub GetParams
{
#--------------------------------------------------------------------------
#@Description: Get the required inputs for program operations
#@Scope:       Private
#@Return:      The database name, and a list of block names.
#--------------------------------------------------------------------------
  my @blocks = @ARGV;
  return (@blocks);
}

sub DumpDelaysOnBlock
{
  my ($block, $dly, $FH) = @_;
  my $blockName = $block->GetName();
  my $blockType = $block->GetBlockType();

  PrintStdOut('{Block:' . $blockName . ' {Type:' . $blockType . "}\n", $FH);

  UpIndent();
  my @delays = GetBlockDelayRecords($block, $dly);
  my $delayCount = 0;
  foreach my $delay (@delays)
  {
    $delayCount++;
    PrintStdOut("Dly# $delayCount:\n", $FH);
    DumpDelay($delay, $FH);
  }
  DownIndent();

  PrintStdOut("}\n", $FH);

  return undef;
}

sub DumpDelay
{
  my ($delay, $FH) = @_;
  my $delayType = $delay->GetDelayType();
  my $belDelayName = $delay->GetBelDelayName();
  $belDelayName = 'NONE' if (!defined $belDelayName);
  my $pathDelayName = $delay->GetPathDelayName();
  $pathDelayName = "NONE" if (!defined $pathDelayName);  
  my $dataPin;
  my $dataPinName;
  my $refPin;
  my $refPinName;
  my $isBus;
  if ($delay->IsBusLevel())
  {
    $isBus = 1;
    $dataPin = $delay->GetTargetBus();
    $refPin = $delay->GetReferenceBus();
    $refPinName = $refPin->GetNameWithRange();
    $dataPinName = $dataPin->GetNameWithRange();
  }
  else
  {
    $isBus = 0;
    $dataPin = $delay->GetTargetPin();
    $refPin = $delay->GetReferencePin();
    $refPinName = $refPin->GetName();
    $dataPinName = $dataPin->GetName();
  }
  my $dataEdge = $delay->GetTargetEdgeSense();
  my $refEdge = $delay->GetReferenceEdgeSense();
  my $line = '{Dly:' . $delayType . '} {isBus:' . $isBus . '}';
  if (defined $refPin)
  {
    #my $refPinName = $refPin->GetName();
    $line .= " {RefPin:$refPinName} {RefEdge:$refEdge}";
  }
  if (defined $dataPin)
  {
    #my $dataPinName = $dataPin->GetName();
    $line .= " {DataPin:$dataPinName} {DataEdge:$dataEdge}";
  }
  $line .= ' {BelDlyName:' . $belDelayName . '} {pathDlyName:' . $pathDelayName .  "}}\n";

  PrintStdOut($line, $FH);

  return undef;
}

sub CreatePFDFromPropertyFilteringACDFiles
{
  my ($files, $outfile, $pm, $modules) = @_;

  my $prop = new Property("Name", "Type", "Default");
  my $pfd = new PropertyFilterDefinition("ACD_PFD", "Cell", $prop);
  my $pfds = new PfdTable($outfile, $pfd, $pm);
  $pfds->DeletePfd($pfd);

  my $record;
  my @records = ();

  foreach my $infile (@$files)
  {
    PrintStdOut("Parsing file $infile ...\n");
    my $ismodule = 0;
    my ($base, $dir, $ext) = fileparse($infile, '\.v');

    open(IN, "$infile")  or die "Unable to open file <$infile> for output\n";

    my $moduleName;

    while (my $line = <IN>)
    {
      if ($ismodule == 0)
      {
        if ($line =~ /^\s*#::PM\s*=/)
        {
          (undef, $moduleName) = split /=/, $line;
          ($moduleName) = split /;;/, $moduleName;
          $ismodule = 1;
          $pfds->SetPM($moduleName);
        }
      }
      else
      {
        my ($flow_cell, $properties) = split /=/, $line;
        next if ((!defined $flow_cell) || (!defined $properties));

        my ($flow, $cell) = split /:/, $flow_cell;
        next if ((!defined $flow) || (!defined $cell));

        if (@$modules != 0)
        {
          my $found = 0;
          foreach my $module (@$modules)
          {
            if ($module eq $cell)
            {
              $found = 1;
              last;
            }
          }
          next if ($found == 0);
        }

        $prop = new Property("Name", "Type", "Default");
        $pfd = new PropertyFilterDefinition($flow, $cell, $prop);
        $pfd->DeleteProperty($prop);

        ($properties) = split /;/, $properties;
        my @properties = split /,/, $properties;
        next if ((scalar @properties) == 0);

        foreach my $property (@properties)
        {
          my ($name, $type, $default) = split /:/, $property;
          next if ((!defined $name) || (!defined $type) || (!defined $default));

          $prop = new Property($name, $type, $default);
          $pfd->AddProperty($prop);
        }

        my $props = $pfd->{Properties};
        if ((scalar keys %$props) > 0)
        {
          $pfds->AddPfd($pfd);
        }
      }
    }

    close(IN);
  }

  return $pfds;
}

sub GetBlockDelayRecords
{
  my ($block, $dly) = @_;
  #my @busDelayRecords = ();
  #my @pinDelayRecords = ();
  my @delayRecords = ();
   
  if ((defined $dly) && ($dly =~ /bus/ixms))
  {
    print "DLY = bus\n";
    @delayRecords = $block->GetBusLevelDelayRecords(), $block->GetPinLevelDelayRecords();
  }
  else
  {
    print "DLY = bit\n";
    @delayRecords = $block->GetDelayRecords();
  }
   
  return @delayRecords;
}

sub GetMin
{
  my ($values) = @_;
  my $min;
  
  foreach my $value (@$values)
  {
     $min = $value if (!defined $min || $min > $value) ;
  }
  return $min;
}

sub GetMax
{
  my ($values) = @_;
  my $max;
  
  foreach my $value (@$values)
  {
     $max = $value if (!defined $max || $max < $value) ;
  }
  return $max;
}

1;
