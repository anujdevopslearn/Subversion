package SBEAMS::Biomarker::ParseSampleWorkbook;

###############################################################################
#
# Description :   Library code for parsing sample workbook files
#
###############################################################################

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
# Based on file format as of 2005-08-01
#-
sub parse_file {
	my $this = shift;
	my %args = @_;

	die 'Missing required parameter wbook' unless $args{wbook};

  # Array of column headings
  my @headings;
  # column heading indicies
  my %idx;
  my %seen;

  open( WBOOK, "<$args{wbook}" ) || die "unable to open $args{wbook}";
  while( my $line = <WBOOK> ){
    chomp $line;
    next if $line =~ /^\s*$/;
    my @line = split( "\t", $line, -1 );
    unless( @headings ) {
      # Meaningful headings fingerprint?
      next unless ( $line[0] =~ /Sample Setup Order/  &&
                    $line[1] =~ /MS Sample Run Number/ );
      @headings = @line;
      my $i = 0;
      foreach (@headings) {
        $idx{$_} = $i++;
      }
      $this->{_headidx} = \%idx;
      next;
    }

    push @{$this->{_data}, \@line;
    next;

    # Vestigal
    my $i = 0;
    for my $item ( @line ) {
      if ( defined $item && $item !~ /^\s*$/ ){
        print "$headings[$i]\t$item\n";
        $seen{$i}++;
      }
      $i++;
    }
  }
  return;

  # Vestigal
  for my $k ( sort { $a <=> $b } keys(%seen) ) {
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
