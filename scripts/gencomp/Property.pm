#!/usr/bin/perl
package Property;

sub new
{
  my $class = shift;
  my ($name, $type, $default, $definition) = @_;

  chomp $definition;
  ($definition) = split /\/\//, $definition if ($definition =~ /\/\//); # Filter out comment
  ($definition) = split /,/, $definition if ($definition =~ /,\s*$/); # Filter out last ,
  ($definition) = split /;/, $definition;
  @tokens = split /\s+/, $definition;
  $definition = join ' ', @tokens;
  my $property = { Name		=> $name,
                   Type		=> $type,
                   Default		=> $default,
				Definition	=> $definition
  };
  bless($property);
  return $property;
}

sub GetName
{
  my $self = shift;
  return $self->{Name};
}

sub GetType
{
  my $self = shift;
  return $self->{Type};
}

sub GetDefault
{
  my $self = shift;
  return $self->{Default};
}

sub GetDefinition
{
  my $self = shift;
  return $self->{Definition};
}

sub Compare
{
  my $self = shift;
  my $property = shift;
  my $name1 = $self->{Name};
  my $type1 = $self->{Type};
  my $default1 = $self->{Default};
  my $name2 = $property->{Name};
  my $type2 = $property->{Type};
  my $default2 = $property->{Default};

  my $rc = 0;
  if ($name1 ne $name2)
  {
    $rc++;
    print "* Error: Different property names detected: ($name1) vs ($name2) *\n" if($debug);
    #$self->Dump();
    #print " " if($debug);
    #$property->Dump();
    #print "\n" if($debug);
  }
  if ($type1 ne $type2)
  {
    $rc++;
    print "* Error: Different types for property $name1 detected: ($type1) vs ($type2) *\n" if($debug);
  }
  if ($default1 ne $default2)
  {
    print "* Warning: Different default for property $name1 detected: ($default1) vs ($default2) *\n" if($debug);
  }
  return $rc;
}

sub Dump
{
  my $self = shift;
  my $keyCount = 0;

  print "Property : " if($debug);
  foreach $key (Name, Type, Default, Definition)
  {
    print " : " if (($keyCount++ > 0) && $debug);
    print "$key=$self->{$key}" if($debug);
  }
}

sub DumpToFile
{
  my $self = shift;
  my $FH = shift;
  my $keyCount = 0;

  print $FH "Property : " if($debug);
  foreach $key (Name, Type, Default, Definition)
  {
    print $FH ":  " if (($keyCount++ > 0) && ($debug));
    print $FH "$key=$self->{$key}" if($debug);
  }
}

sub DumpToString
{
  my $self = shift;
  my $record = "";
  my $keyCount = 0;

  $record .= "Property : ";
  foreach $key (Name, Type, Default, Definition)
  {
    $record .= " : " if $keyCount++ > 0;
    $record .= "$key=$self->{$key}";
  }
  return $record;
}

sub DumpToVhdlString
{
  my $self = shift;
  my $definition = $self->{Definition};
   
  return $definition;
}

sub DumpToVerilogString
{
  my $self = shift;
  my $definition = $self->{Definition};
   
  return $definition;
}

1;
