#!/usr/bin/perl
package Port;

sub new
{
  my $class = shift;
  my ($name, $type, $logic, $min, $max, $definition) = @_;

  chomp $definition;
  ($definition) = split /;/, $definition;
  my $verilogansiports = $ENV{GENCOMP_VERILOG_ANSI_PORT};
  #($definition) = split /,/, $definition if ($verilogansiports);
  ($definition) = split /,/, $definition if ($definition =~ /,\s*$/); # Filter out last ,
  @tokens = split /\s+/, $definition;
  $definition = join ' ', @tokens;
  my $port = {	Name => $name,
                Type => $type,
                Min => $min,
                Max => $max,
                Logic => $logic,
                Definition => $definition
  };
  bless($port);
  return $port;
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

sub GetMin
{
  my $self = shift;
  return $self->{Min};
}

sub GetMax
{
  my $self = shift;
  return $self->{Max};
}

sub GetLogic
{
  my $self = shift;
  return $self->{Logic};
}

sub GetDefinition
{
  my $self = shift;
  return $self->{Definition};
}

sub Compare
{
  my $self = shift;
  my $port = shift;
  my $name1 = $self->{Name};
  my $type1 = $self->{Type};
  my $definition1 = $self->{Definition};
  my $name2 = $port->{Name};
  my $type2 = $port->{Type};
  my $definition2 = $self->{Definition};

  my $rc = 0;
  if ($name1 ne $name2)
  {
    $rc++;
    print "* Error: Different port names detected: ($name1) vs ($name2) *\n" if($debug);
    #$self->Dump();
    #print " " if($debug);
    #$port->Dump();
    #print "\n" if($debug);
  }
  if ($type1 ne $type2)
  {
    $rc++;
    print "* Error: Different types for port $name1 detected: ($type1) vs ($type2) *\n" if($debug);
  }
  if ($definition1 ne $definition2)
  {
    print "* Warning: Different definition for port $name1 detected: ($definition1) vs ($definition2) *\n" if($debug);
  }
  return $rc;
}

sub Dump
{
  my $self = shift;
  my $keyCount = 0;

  print "Port : " if($debug);
  foreach $key (Name, Type, Min, Max, Logic, Definition)
  {
    print " : " if (($keyCount++ > 0) && ($debug));
    print "$key=$self->{$key}" if($debug);
  }
}

sub DumpToFile
{
  my $self = shift;
  my $FH = shift;
  my $keyCount = 0;

  print $FH "Port : " if($debug);
  foreach $key (Name, Type, Min, Max, Logic, Definition)
  {
    print $FH " : " if (($keyCount++ > 0) && ($debug));
    print $FH "$key=$self->{$key}" if($debug);
  }
}

sub DumpToString
{
  my $self = shift;
  my $record = "";
  my $keyCount = 0;

  $record .= "Port : ";
  foreach $key (Name, Type, Min, Max, Logic, Definition)
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
