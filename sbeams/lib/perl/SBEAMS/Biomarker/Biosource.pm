package SBEAMS::Biomarker::Biosource;

###############################################################################
#
# Description :   Library code for inserting biosample records into 
# the database
# $Id:   $
#
# Copywrite 2005   
#
###############################################################################

use SBEAMS::Connection qw($log);
use strict;

#### Set up new variables
use vars qw(@ISA @EXPORT);

require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
);

sub new {
  my $class = shift;
	my $this = { @_ };
	bless $this, $class;
	return $this;
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
