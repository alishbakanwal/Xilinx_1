#!/usr/bin/perl
package Filter;

sub new
{
  my $class = shift;
  my ($name, $property) = @_;

  my $properties;
  if (defined $property)
  {
    $propkey = $property->GetName();
    $properties = {$propkey, $property};
  }
  else
  {
    $property = new Property("Name", "Type", "Default");
    $propkey = $property->GetName();
    $properties = {$propkey, $property};
    delete $properties->{$propkey};
  }
  my $this = { Name		=> $name,
				Properties	=> $properties
  };
  bless($this);
  return $this;
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

sub AddProperty
{
  my $self = shift;
  my $property = shift;

  $properties = $self->{Properties};
  $key = $property->GetName();
  $prop = $properties->{$key};
  if (defined $prop)
  {
    print "Replacing existing property $key with new one.\n" if($debug);
    print "Old property:\n" if($debug);
    $prop->Dump();
    print "\nNew property:\n" if($debug);
    $property->Dump();
    print "\n" if($debug);
  }
  $properties->{$key} = $property;
}

sub Dump
{
  my $self = shift;
  print "Filter: $self->{Name}= \n" if($debug);
   
  my $propCount = 0;
  $properties = $self->{Properties};
  foreach $key (sort keys %$properties)
  {
    print ",\n" if (($propCount++ > 0) && ($debug));
    $property = $properties->{$key};
    $property->Dump();
  }
  print "\n" if (($propCount > 0) && ($debug));

  print ";\n" if ($debug);
}
1;
