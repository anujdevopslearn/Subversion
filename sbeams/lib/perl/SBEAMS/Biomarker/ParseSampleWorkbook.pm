package SBEAMS::Biomarker::ParseSampleWorkbook;

###############################################################################
#
# Description :   Library code for parsing sample workbook files
# Copywrite 2005 
###############################################################################

use Spreadsheet::ParseExcel::Simple;
use Spreadsheet::ParseExcel;
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
#
#-
sub parse_file {
  my $this = shift;
  my %args = @_;
  
  # Check for required params
  for ( qw( type wbook ) ) {
	  die "Missing required parameter $_" unless $args{$_};
  }

  # Make sure workbook exists and is readable 
  unless( -e $args{wbook} && -r $args{wbook} ) {
	  die "Workbook file, $args{wbook}, unreadable or does not exist";
  }

  # Call appropriate parsing method 
  return ( $args{type} eq 'tsv' ) ? $this->_parse_tab_file( %args ) :  
                                    $this->_parse_excel_file( %args ); 
} # End parse_file

#+
# 
# -
sub process_data {
} # End process_data

#+
# Returns reference to hash of column index values keyed by column heading
# -
sub getHeadingsIndex {
  my $this = shift;
  return $this->{_headidx} || {};
}

#+
# Returns reference to array of arrayrefs which each represent worksheet row
# -
sub getDataRef {
  my $this = shift;
  return $this->{_data} || [];
}

### Private subroutines ###

#+
# Based on file format as of 2005-08-01
#-
sub _parse_tab_file {
	my $this = shift;
	my %args = @_;


  # Array of column headings
  my @headings;
  # column heading indicies
  my %idx;
  my %seen;

  open( WBOOK, "<$args{wbook}" ) || die "unable to open $args{wbook}";
  $this->{_wbook} = $args{wbook};
  
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

    push @{$this->{_data}}, \@line;
    next;
  }
  return;
}

#
#+
# Based on file format(s) as of 2005-08-25
#-
sub _parse_excel_file {
	my $this = shift;
	my %args = @_;

  # Messages to return to caller about the parse
  my @msg;

  my $xls =  Spreadsheet::ParseExcel::Simple->read( $args{wbook} ) ||
                                      die 'Unable to parse workbook';

  $this->{_wbook} = $args{wbook};

  # Array of column headings
  my @headings;
  # column heading indicies
  my %idx;
  my %seen;

  my $active_sheet;
  my $cnt = 1;

  foreach my $sheet ( $xls->sheets() ) { 
    $active_sheet ||= $sheet;
    $cnt++;
  }
  push @msg, 'workbook has multiple sheets, using only the first' if $cnt > 1;

  while ( $active_sheet->has_data() ) {
    my @line = $active_sheet->next_row();
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

    push @{$this->{_data}}, \@line;
    next;
  }
  push @msg, 'Unable to find heading signature' unless @headings;
  push @msg, 'No data found in first sheet' unless @{$this->{_data}};
  return \@msg;
}

1;

__DATA__
Biosource
Biosample
Attribute
Disease
Orphan
Treatment
Storage_location
Analysis_file

01      Sample Setup Order
02      MS Sample Run Number
03      Plate Layout
04      ISB sample ID
05      Patient_id
06      External Sample ID
07      Name of Institute
08      Name of Investigators
09      Sample type
10      species
11      age
12      gender
13      amount of sample received
14      Location of orginal sample
15      PARAM:time of sample collection
16      PARAM:meal
17      PARAM:alcohole
18      PARAM:smoke
19      PARAM:Date of Sample Collection
20      PARAM:Others
21      Disease:Breast cancer
22      Disease:Ovarian cancer
23      Disease:Prostate cancer
24      Disease:Blader Cancer
25      Disease:Skin cancer
26      Disease:Lung cancer
27      Disease: Huntington's Disease
28      Disease:other cancers
29      heart
30      blood
31      liver
32      diabetic
33      neuron
34      lung
35      bone
36      Disease Stage
37      others
38      Study Histology
39      Disease Info: Group
40      Prep Replicate id
41      Sample Prep Name
42      status of sample prep
43      date of finishing prep
44      amount of sample used in prep
45      Sample prep method
46      person prepared the samples
47      Volume of re-suspended sample
48      location of finished sample prep
49      MS Replicate Number
50      MS Run Name
51      status of MS
52      date finishing MS
53      Random Sample Run order
54      order of samples ran per day
55      MS run protocol
56      Volume Injected
57      location of data
58      status of Conversion
59      Date finishing conversion
60      name of raw files
61      location of raw files
62      name of mzXML
63      location of mzXML
64      person for MS analysis
65      date finishing alignment
66      location of alignment files
67      person for data analysis
68      peplist peptide peaks file location



# Attributes 
'Sample Setup Order'  # same
'MS Sample Run Number' # same
'Name of Investigators' # same
'PARAM:time of sample collection ' # param
'PARAM:meal' # param
'PARAM:alcohole' # param
'PARAM:smoke' # param
'PARAM:Date of Sample Collection' # param
'Study Histology' # anonymous

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



        # Odd bits, tries to unify column indices between worksheets
        if ( 0 ) {


          if ( $_ eq 'ISB sample ID' ){
            $i = 4;
          } elsif ( $_ eq 'PARAM:Others' ) {
            $i = 20;
          } elsif ( $_ eq 'Disease:Breast cancer' ) {
            $i = 21;
          } elsif ( $_ eq 'Disease:other cancers' ) {
            $i = 28;
          } elsif ( $_ eq 'heart' ) {
            $i = 29;
          } elsif ( $_ eq 'others' ) {
            $i = 37;
          } elsif ( $_ eq 'Study Histology' ) {
            $i = 38;
          } elsif ( $_ eq 'Prep Replicate id' ) {
            $i = 40;
          } elsif ( $_ eq 'date of finishing prep' ) {
            $i = 43;
          } elsif ( $_ eq 'amount of sample used in prep' ) {
            $i = 44;
          }
        }
        

