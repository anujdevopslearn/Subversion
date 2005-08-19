###############################################################################
#
# Description :   Library code for inserting biosource/biosample records into 
# the database
#
###############################################################################
{
package SBEAMS::Biomarker::Biosample;

use SBEAMS::Connection;
use strict;

#### Set up new variables
use vars qw(@ISA @EXPORT);

require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
);

sub new {
  my $class = shift;
	my $this = {};
	bless $this, $class;
	return $this;
}

#+
# Routine for inserting 
#
#-
sub insert_biosamples {
  my $this = shift;
  my %args = @_;
  my $p = $args{'wb_parser'} || die "Missing required parameter wb_parser";
  $this->insert_biosources( wb_parser => $p );
  $this->insert_biosamples( wb_parser => $p );
}

sub getStr {
  my $this = shift;
  return "I am Biosample!\n";
}

} # End biosample

{
package SBEAMS::Biomarker::Biosource;

use SBEAMS::Connection;
use strict;

sub new {
  my $class = shift;
	my $this = {};
	bless $this, $class;
	return $this;
}

sub getStr {
  my $this = shift;
  return "I am Biosource!\n";
}
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
