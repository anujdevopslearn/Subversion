package SBEAMS::Biomarker::Biosample;

###############################################################################
#
# Description :   Library code for inserting biosource/biosample records into 
# the database
# $Id$
#
# Copywrite 2005   
#
###############################################################################

use strict;

use SBEAMS::Connection qw( $log );
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
# Routine for inserting biosample
#
#-
sub insert_biosamples {
  my $this = shift;
  my %args = @_;
  my $p = $args{'wb_parser'} || die "Missing required parameter wb_parser";
  $this->insert_biosamples( wb_parser => $p );
}

#+
# Routine to cache biosource object,
#-
sub setBiosource {
  my $this = shift;

  # Use passed biosource if available
  $this->{_biosource} = shift || die 'Missing required biosource parameter';
}

#+
# Routine to fetch Biosource object
#-
sub getBiosource {
  my $this = shift;

  unless ( $this->{_biosource} ) {
    log->warn('getBiosource called, none defined'); 
    return undef;
  }
  return $this->{_biosource};
}

1;







__DATA__

# Attributes 
'Sample Setup Order'
'MS Sample Run Number'
'Name of Investigators'
'PARAM:time of sample collection '
'PARAM:meal'
'PARAM:alcohole'
'PARAM:smoke'
'PARAM:Date of Sample Collection'
'Study Histology'

# Bioource 
'ISB sample ID'
'Patient_id'
'External Sample ID'
'Name of Institute'
'species'
'age'
'gender'

'Sample type'

# Biosample
'amount of sample received'
'Location of orginal sample'

# Disease
'Disease:Breast cancer'
'Disease:Ovarian cancer'
'Disease:Prostate cancer'
'Disease:Blader Cancer'
'Disease:Skin cancer'
'Disease:Lung cancer'
'Disease: Huntington\'s Disease'
'diabetic'

# tissue_type
'heart'
'blood'
'liver'
'neuron'
'lung'
'bone'

biosource_disease
'Disease Stage'

#orphan
'Disease Info: Group'
'Prep Replicate id'
'Sample Prep Name'
'status of sample prep'
'date of finishing prep'
'amount of sample used in prep'
'Sample prep method'
'person prepared the samples'
'Volume of re-suspended sample'
'location of finished sample prep'
'MS Replicate Number'
'MS Run Name'
'status of MS'
'date finishing MS'
'Random Sample Run order'
'order of samples ran per day'
'MS run protocol'
'Volume Injected'
'location of data'
'status of Conversion'
'Date finishing conversion'
'name of raw files'
'location of raw files'
'name of mzXML'
'location of mzXML'
'person for MS analysis'
'date finishing alignment'
'location of alignment files'
'person for data analysis'
'peplist peptide peaks file location'
