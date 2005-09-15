package SBEAMS::Biomarker::Biosource;

##############################################################################
#
# Description :   Library code for maniulating biosample records within 
# the database
# $Id:   $
#
# Copywrite 2005   
#
##############################################################################

use strict;

use SBEAMS::Connection qw($log);
use SBEAMS::Biomarker::Tables;

#### Set up new variables
#use vars qw(@ISA @EXPORT);
#require Exporter;
#@ISA = qw (Exporter);
#@EXPORT = qw ();

sub new {
  my $class = shift;
	my $this = { @_ };
	bless $this, $class;
	return $this;
}

sub tissue_exists {
  my $this = shift;
  my $tissue = shift;
  return unless $tissue;

  my $sbeams = $this->getSBEAMS() || die "sbeams object not set";
  die "unsafe tissue detected: $tissue\n" if $sbeams->isTaintedSQL($tissue);

  my ($cnt) = $sbeams->selectrow_array( <<"  END_SQL" );
  SELECT COUNT(*) FROM $TBBM_BMRK_ATTRIBUTE
  WHERE tissue_name = '$tissue'
  END_SQL

  return $cnt;
}   
  
sub disease_exists {
  my $this = shift;
  my $disease = shift;
  return unless $disease;

  my $sbeams = $this->getSBEAMS() || die "sbeams object not set";
  die "unsafe disease detected: $disease\n" if $sbeams->isTaintedSQL($disease);

  my ($cnt) = $sbeams->selectrow_array( <<"  END_SQL" );
  SELECT COUNT(*) FROM $TBBM_BMRK_ATTRIBUTE
  WHERE disease_name = '$disease'
  END_SQL

  return $cnt;
}   
  
sub attr_exists {
  my $this = shift;
  my $attr = shift;
  return unless $attr;

  my $sbeams = $this->getSBEAMS() || die "sbeams object not set";
  die "unsafe attr detected: $attr\n" if $sbeams->isTaintedSQL($attr);

  my ($cnt) = $sbeams->selectrow_array( <<"  END_SQL" );
  SELECT COUNT(*) FROM $TBBM_BMRK_ATTRIBUTE
  WHERE attribute_name = '$attr'
  END_SQL

  return $cnt;
}   
  
sub setSBEAMS {
  my $this = shift;
  my $sbeams = shift || die "Must pass sbeams object";
  $this->{_sbeams} = $sbeams;
}

sub getSBEAMS {
  my $this = shift;
  return $this->{_sbeams};
}

  


#+
# Routine for inserting biosource(s)
#
#-
sub insert_biosources {
  my $this = shift;
  my %args = @_;
  my $p = $args{'wb_parser'} || die "Missing required parameter wb_parser";
  $this->insert_biosamples( wb_parser => $p );
}

#+
# Routine to create and cache biosource object if desired
#-
sub setBiosample {
  my $this = shift;
  $this->{_biosample} = shift || die 'Missing required biosource parameter'; 
}

#+
# Routine to fetch Biosample object
#-
sub getBiosample {
  my $this = shift;

  unless ( $this->{_biosample} ) {
    $log->warn('getBiosample called, none defined'); 
    return undef;
  }
  return $this->{_biosample};
}

1;
# End biosource

