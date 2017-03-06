#!/usr/bin/perl
package Component;

use Property;
use Port;
use LibraryWriters;

sub new
{
  my $class = shift;
  my ($laungauge, $name, $property, $port) = @_;
  my $properties;
  if (defined $property)
  {
    $propkey = $property->GetName();
    $properties = {$propkey, $property};
  }
  my $ports;
  if (defined $port)
  {
    $portkey = $port->GetName();
    $ports = {$portkey, $port};
  }
  my $component =	{	Language	=> $laungauge,
						Name		=> $name,
						Properties	=> $properties,
						Ports		=> $ports
					};

  bless($component);
  return $component;
}

sub GetLanguage
{
  my $self = shift;
  return $self->{Language};
}

sub GetName
{
  my $self = shift;
  return $self->{Name};
}

sub GetProperties
{
  my $self = shift;
  return $self->{Properties};
}

sub GetPorts
{
  my $self = shift;
  return $self->{Ports};
}

sub AddProperty
{
  my $self = shift;
  my $property = shift;

  $properties = $self->{Properties};
  $key = $property->GetName();
  $prop = $properties->{$key};

  if (defined $prop)
  {
    print "Replacing existing property $key with new one.\n" if ($debug);
    print "Old property:\n" if ($debug);
    $prop->Dump();
    print "\nNew property:\n" if ($debug);
    $property->Dump();
    print "\n" if ($debug);
  }
  $properties->{$key} = $property;
}

sub DeleteProperty
{
  my $self = shift;
  my $property = shift;

  $properties = $self->{Properties};
  $key = $property->GetName();
  delete $properties->{$key};
}

sub FindProperty
{
  my $self = shift;
  my $property = shift;

  $properties = $self->{Properties};
  $key = $property->GetName();
  $prop = $properties->{$key};
  if (defined $prop)
  {
    if ($prop->Compare($property) == 0)
    {
      return 1;
    }
    else
    {
      return 0;
    }
  }   
  else
  {
    return 0;
  }
}

sub AddPort
{
  my $self = shift;
  my $port = shift;

  $ports = $self->{Ports};
  $key = $port->GetName();
  $pt = $ports->{$key};
  if (defined $pt)
  {
    print "Replacing existing port $key with new one.\n" if ($debug);
    print "Old port:\n" if ($debug);
    $pt->Dump();
    print "\nNew port:\n" if ($debug);
    $port->Dump();
    print "\n" if ($debug);
  }
  $ports->{$key} = $port;
}

sub DeletePort
{
  my $self = shift;
  my $port = shift;

  $ports = $self->{Ports};
  $key = $port->GetName();
  delete $ports->{$key};
}

sub FindPort
{
  my $self = shift;
  my $port = shift;

  $ports = $self->{Ports};
  $key = $port->GetName();
  $pt = $ports->{$key};
  if (defined $pt)
  {
    if ($pt->Compare($port) == 0)
    {
      return 1;
    }
    else
    {
      return 0;
    }
  }   
  else
  {
    return 0;
  }
}

sub Compare
{
  my $self = shift;
  my $component = shift;
  my $components = shift;
  my $language1 = $self->{Language};
  my $name1 = $self->{Name};
  my $language2 = $component->{Language};
  my $name2 = $pfd->{Name};

  my $rc = 0;
  my $component1;

  if ($language1 ne $language2)
  {
    print "* Error: Different languages for component $name1 detected: ($language1) vs ($language2) *\n" if ($debug);
    $rc += 1;
  }
  if ($name1 ne $name2)
  {
    print "* Error: Different names for component $language1 detected: ($name1) vs ($name2) *\n" if ($debug);
    $rc += 1;
  }
  $properties1 = $self->{Properties};
  $properties2 = $component->{Properties};

  print "-----------------------------------------------------------------------\n" if ($debug);
  print "* COMPARING $language1:$name1 component WITH $language2:$name2 component *\n" if ($debug);
  while (($key, $property1) = each %$properties1)
  {
    $property2 = $properties2->{$key};
    if (defined $property2)
    {
      my $errors;
      if ($errors = $property1->Compare($property2))
      {
        $rc += $errors;
        print "* Error: Different properties detected *\n" if ($debug);
        my $record = sprintf("component %20s:%20s\t=\t(", $language1, $name1);
        print $record if ($debug);
        $property1->Dump();
        $record = sprintf(")\ncomponent %20s:%20s\t=\t(", $language2, $name2);
        print $record if ($debug);
        $property2->Dump();
        print ")\n" if ($debug);
        if (!defined $component1)
        {
          $component1 = new Component($language1, $name1, $property1);
        }
        else
        {
          $component1->AddProperty($property1);
        }
      }
    }
    else
    {
      print "* Error: component $language1:$name1 has property $key, but component $language2:$name2 does not have property $key. *\n" if ($debug);
      if (!defined $component1)
      {
        $component1 = new Component($language1, $name1, $property1);
      }
      else
      {
        $component1->AddProperty($property1);
      }
      $rc += 1;
    }
  }

  print "\n" if ($debug);

  if ((defined $components) && (defined $component1))
  {
    $components->AddPfd($component1);
  }

  print "* COMPARING $language2:$name2 component WITH $language1:$name1 component *\n" if ($debug);
  my $component2;
  while (($key, $property2) = each %$properties2)
  {
    $property1 = $properties1->{$key};
    if (defined $property1)
    {
      my $errors;
      if ($errors = $property2->Compare($property1))
      {
        $rc += $errors;
        print "* Error: Different properties detected *\n" if ($debug);
        my $record = sprintf("component %20s:%20s\t=\t(", $language2, $name2);
        print $record if ($debug);
        $property1->Dump();
        $record = sprintf(")\ncomponent %20s:%20s\t=\t(", $language1, $name1);
        print $record if ($debug);
        $property2->Dump();
        print ")\n" if ($debug);
        if (!defined $component2)
        {
          $component2 = new Component($language2, $name2, $property2);
        }
        else
        {
          $component2->AddProperty($property2);
        }
      }
    }
    else
    {
      print "* Error: component $language2:$name2 has property $key, but component $language1:$name1 does not have property $key. *\n" if ($debug);
      if (!defined $component2)
      {
        $component2 = new Component($language2, $name2, $property2);
      }
      else
      {
        $component2->AddProperty($property2);
      }
      $rc += 1;
    }
  }
  if ((defined $components) && (defined $component2))
  {
    $components->AddPfd($component2);
  }

  print "-----------------------------------------------------------------------\n" if ($debug);
  return $rc;
}

sub Dump
{
  my $self = shift;
  print "Component:$self->{Language}:$self->{Name}=\n" if ($debug);

  my $propCount = 0;
  $properties = $self->{Properties};
  foreach $key (sort keys %$properties)
  {
    print ",\n" if (($propCount++ > 0) && ($debug));
    $property = $properties->{$key};
    $property->Dump();
  }
  print "\n" if (($propCount > 0) && ($debug));
   
  my $portCount = 0;
  $ports = $self->{Ports};
  foreach $key (sort keys %$ports)
  {
    print ",\n" if (($portCount++ > 0) && ($debug));
    $port = $ports->{$key};
    $port->Dump();
  }
  print "\n" if (($portCount > 0) && ($debug));
   
  print ";\n" if ($debug);
}

sub DumpToFile
{
  my $self = shift;
  my $FH = shift;
  print $FH "Component:$self->{Language}:$self->{Name}=\n" if ($debug);

  my $propCount = 0;
  $properties = $self->{Properties};
  foreach $key (sort keys %$properties)
  {
    print $FH ",\n" if (($propCount++ > 0) && ($debug));
    $property = $properties->{$key};
    $property->Dump();
  }
  print $FH "\n" if (($propCount > 0) && ($debug));

  my $portCount = 0;
  $ports = $self->{Ports};
  foreach $key (sort keys %$ports)
  {
    print $FH ",\n" if (($portCount++ > 0) && ($debug));
    $port = $ports->{$key};
    $port->Dump();
  }
  print $FH "\n" if (($portCount > 0) && ($debug));
   
  print $FH ";\n" if ($debug);
}

sub DumpToString
{
  my $self = shift;
  my $record = "";

  $properties = $self->{Properties};
  @propkeys = sort keys %$properties;
  $ports = $self->{Ports};
  @portkeys = sort keys %$ports;
  return $record if ((@propkeys == 0) && (@portkeys == 0));

  $record  = "Component:$self->{Language}:$self->{Name}=\n";
   
  my $propCount = 0;
  foreach $key (@propkeys)
  {
    $record  .= ",\n" if ($propCount++ > 0);
    $property = $properties->{$key};
    $record  .= $property->DumpToString();
  }
  $record .= "\n" if ($propCount > 0);
   
  my $portCount = 0;
  foreach $key (@portkeys)
  {
    $record  .= ",\n" if ($portCount++ > 0);
    $port = $ports->{$key};
    $record  .= $port->DumpToString();
  }
  $record .= "\n" if ($portCount > 0);   
   
  $record  .= ";\n";
}

sub DumpToVhdlString
{
  my $self = shift;
  my $library = shift;
  my $translate_offon = shift;
  my $record = "";
  my $name = $self->{Name};
   
  $record  = "----- component $name -----\n";
  if ($translate_offon)
  {
    $record .= "-- translate_off\n";
  }
  $record .= "component $name\n";
  UpIndent();
   
  $properties = $self->{Properties};
  @propkeys = sort keys %$properties;
  @props = ();
  foreach $key (@propkeys)
  {
    $property = $properties->{$key};
    my $line = $property->DumpToVhdlString();
    Push(\@props, $line);
  }
  my $propCount = 0;
  if (@props > 0)
  {
    IndentString(\$record);
    $record .= "generic (\n";
    UpIndent();
    foreach my $line (@props)
    {
      $record  .= ";\n" if ($propCount++ > 0);
      IndentString(\$record);
      $record .= "$line";	
    }
    $record .= "\n";
    DownIndent();
    IndentString(\$record);
    $record .= ");\n";
  }
   
  $ports = $self->{Ports};
  @portkeys = sort keys %$ports;
  @pts = ();
  foreach $key (@portkeys)
  {
    $port = $ports->{$key};
    if ($port->GetType() eq 'out')
    {
      my $line = $port->DumpToVhdlString();
      Push(\@pts, $line);
    }
  }
  foreach $key (@portkeys)
  {
    $port = $ports->{$key};
    if ($port->GetType() eq 'inout')
    {
      my $line = $port->DumpToVhdlString();
      Push(\@pts, $line);
    }
  }
  foreach $key (@portkeys)
  {
    $port = $ports->{$key};
    if ($port->GetType() eq 'in')
    {
      my $line = $port->DumpToVhdlString();
      Push(\@pts, $line);
    }
  }
  my $portCount = 0;
  if (@pts > 0)
  {
    IndentString(\$record);
    $record .= "port (\n";
    UpIndent();
    foreach my $line (@pts)
    {
      $record  .= ";\n" if ($portCount++ > 0);
      IndentString(\$record);
      $record .= "$line";	
    }
    $record .= "\n";
    DownIndent();
    IndentString(\$record);
    $record .= ");\n";
  }

  DownIndent();
  IndentString(\$record);
  $record  .= "end component;\n";
  if ($library eq 'unisim')
  {
    IndentString(\$record);
    $record .= "attribute BOX_TYPE of\n";
    UpIndent();
    IndentString(\$record);
    $record .= "$name : component is \"PRIMITIVE\";\n";
    DownIndent();
  }
  if ($translate_offon)
  {
    $record .= "-- translate_on\n";
  }
  $record .= "\n";
      
  return $record;
}

sub DumpToVerilogString
{
  my $self = shift;
  my $translate_offon = shift;
  my $record = "";
  my $name = $self->{Name};
  my $verilogansiports = $ENV{GENCOMP_VERILOG_ANSI_PORT};
   
  $record  = "///// component $name ////\n";
  if ($translate_offon)
  {
    $record .= "// translate_off\n";
  }
  $record .= "(* BOX_TYPE=\"PRIMITIVE\" *) // Verilog-2001\n";
  $record .= "module $name (\n";
  UpIndent();
   
  $ports = $self->{Ports};
  @portkeys = sort keys %$ports;
   
  @pts = ();
  @ps = ();
  foreach $key (@portkeys)
  {
    $port = $ports->{$key};
    if ($port->GetType() eq 'output')
    {
      my $line;
      if ($verilogansiports)
      {
        $line = $port->DumpToVerilogString();
      }
      else
      {
        $line = $port->GetName();
      }
      Push(\@ps, $line);
    }
  }
  foreach my $p (sort @ps)
  {
    Push(\@pts, $p);
  }
  @ps = ();
  foreach $key (@portkeys)
  {
    $port = $ports->{$key};
    if ($port->GetType() eq 'inout')
    {
      my $line;
      if ($verilogansiports)
      {
        $line = $port->DumpToVerilogString();
      }
      else
      {
        $line = $port->GetName();
      }
      Push(\@ps, $line);
    }
  }
  foreach my $p (sort @ps)
  {
    Push(\@pts, $p);
  }
  @ps = ();
  foreach $key (@portkeys)
  {
    $port = $ports->{$key};
    if ($port->GetType() eq 'input')
    {
      my $line;
      if ($verilogansiports)
      {
        $line = $port->DumpToVerilogString();
      }
      else
      {
        $line = $port->GetName();
      }
      Push(\@ps, $line);
    }
  }
  foreach my $p (sort @ps)
  {
    Push(\@pts, $p);
  }
  my $portCount = 0;
  if (@pts > 0)
  {
    foreach my $line (@pts)
    {
      $record  .= ",\n" if ($portCount++ > 0);
      IndentString(\$record);
      $record .= "$line";	
    }
    $record .= "\n";
  }
   
  DownIndent();
  IndentString(\$record);
  $record .= ");\n";
  UpIndent();
   
  $properties = $self->{Properties};
  @propkeys = sort keys %$properties;
  @props = ();
  @sorted_params = ();
  foreach $key (@propkeys)
  {
    $property = $properties->{$key};
    my $line = $property->DumpToVerilogString();
    Push(\@props, $line);
    Push(\@sorted_params, $key);
  }
  my $propCount = 0;
  if (@props > 0)
  {
    foreach my $param (sort @sorted_params)
    {
      foreach my $line (@props)
      {
        $line =~ s/^\s+|\s+$//g;
        $line_str = $line;
        if ($line_str =~ /=/) {
          my ($name, $value) = split /=/, $line_str;
          $line_str = $name;
        }

        if ($line_str =~ m/\b$param\b/) {
          $record  .= ";\n" if ($propCount++ > 0);
          IndentString(\$record);
          $record .= "$line";	
        }
      }
    }
    $record .= ";\n";
  }
  if (!$verilogansiports)
  {   
    @pts = ();
    @ps = ();
    foreach $key (@portkeys)
    {
      $port = $ports->{$key};
      if ($port->GetType() eq 'output')
      {
        my $line = $port->DumpToVerilogString();
        Push(\@ps, $line);
      }
    }
    foreach my $p (sort @ps)
    {
      Push(\@pts, $p);
    }
    @ps = ();
    foreach $key (@portkeys)
    {
      $port = $ports->{$key};
      if ($port->GetType() eq 'inout')
      {
        my $line = $port->DumpToVerilogString();
        Push(\@ps, $line);
      }
    }
    foreach my $p (sort @ps)
    {
      Push(\@pts, $p);
    }
    @ps = ();
    foreach $key (@portkeys)
    {
      $port = $ports->{$key};
      if ($port->GetType() eq 'input')
      {
        my $line = $port->DumpToVerilogString();
        Push(\@ps, $line);
      }
    }
    foreach my $p (sort @ps)
    {
      Push(\@pts, $p);
    }
    my $portCount = 0;
    if (@pts > 0)
    {
      foreach my $line (@pts)
      {
        IndentString(\$record);
        $record .= "$line;\n";	
      }
    }
  }
   
  DownIndent();
  IndentString(\$record);
  $record  .= "endmodule\n";
  if ($translate_offon)
  {
    $record .= "// translate_on\n";
  }
  $record  .= "\n";
      
  return $record;
}

sub MergeComponent
{
  my $self = shift;
  my $component = shift;
  my $language1 = $self->{Language};
  my $name1 = $self->{Name};
  my $language2 = $component->{Language};
  my $name2 = $component->{Name};

  my $rc = 0;

  if ($language1 ne $language2)
  {
    print "Different component languages detected: ($language1) vs ($language2)\n" if($debug);
    $self->Dump();
    print "\n" if($debug);
    $component->Dump();
    print "\n" if($debug);
    $rc = 1;
  }
  else
  {
    if ($name1 ne $name2)
    {
      print "Different names for component $language1 detected: ($name1) vs ($name2)\n" if($debug);
      $rc = 1;
    }
    $properties1 = $self->{Properties};
    $properties2 = $component->{Properties};

    while (($key, $property2) = each %$properties2)
    {
      $property1 = $properties1->{$key};
      if (!defined $property1)
      {
        print "Merging property $key ...\n" if($debug);
        $property2->Dump();
        $properties1->{$key} = $property2;
      }
      # No overwrite if property exists
    }
  }
  return $rc;
}
1;
