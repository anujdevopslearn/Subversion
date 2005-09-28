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
	my $this = { verbose => 0,
               @_
             };
	bless $this, $class;
	return $this;
}

#+
#
#-
sub parseFile {
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
  return ( $args{type} eq 'tsv' ) ? $this->_parseTabFile( %args ) :  
                                    $this->_parseExcelFile( %args ); 
} # End parseFile

#+
# 
# -
sub process_data {
  my $this = shift;

  my ( @sou_attr, @sam_attr, @dis );

  my $idx = $this->getHeadingsIndex();

  # Array to hold list of separated objects
  my @items;

  # Get headers for various sub-groups
  my @tags = qw( biosample biosample_attr prep_params ms_params analysis_params
                 biosource biosource_attr biosource_disease 
                 biosource_disease_stage tissue_type );

  # Get headers for all columns
  my %head;
  for my $tag ( @tags ) {
    $head{$tag} = $this->_getDb2ParserMap($tag);
  }
  
  # accumulator for processed lines
  my @all_items;

#  print "Saw a total of " . scalar @{$this->{_data}} . " lines\n";

  # Each row represents one sample
  foreach my $row ( @{$this->{_data}} ) {
    
    # hash representing item (line in file)
    my %item;

    # For each of the categories (tables)
    for my $tag ( @tags ) {

      my %subitem;
      
      # Confused yet?
      # The item hash is keyed by tags, i.e. biosource, biosample, etc. 
      # Each of these points at an anonymous hashref.
      # The referenced hash holds the actual spreadsheet values, keyed by db 
      # column name (keys of %{$head{$tag}} rather than by the spreadsheet
      # column header, which are the values of %{$head{$tag}}
      # @{$item{$tag}}{keys(%{$head{$tag}})} = @$row[@$idx{values(%{$head{$tag}})}];

      # Had to rewrite as a loop to avoid undefined cols getting $row[0].
      foreach my $key ( keys(%{$head{$tag}}) ) {
        $subitem{$key} = ( !defined( $idx->{${$head{$tag}}{$key}} ) ? undef :
                                     $row->[$idx->{${$head{$tag}}{$key}}] ); 
#        print "$key, $subitem{$key}\n" if $tag eq 'biosource';
      }
      $item{$tag} = \%subitem;
    }
    push @all_items, \%item;
  }

  # We have them all, cache and return.
  $this->{processed_items} = \@all_items;
  
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
sub getProcessedItems {
  my $this = shift;
  return $this->{processed_items} || undef;
}

#+
# cache sbeams object
#-
sub setSBEAMS {
  my $this = shift;
  my $sbeams = shift || die "Must pass sbeams object";
  $this->{_sbeams} = $sbeams;
}

#+
# Fetch cached sbeams object
#-
sub getSBEAMS {
  my $this = shift;
  return $this->{_sbeams};
}

#+
# Set the 'verbose' level for parser
# named argument  verbose (integer)
#-
sub setVerbosity {
  my $this = shift;
  my %args = @_;
  $this->{verbose} = $args{verbose} || 0;
}


 
 # # # ####################### # # #
  # #   ## Private methods ##   # #
   #     ###################     


#+
# Fetch the 'verbose' level for parser
#-
sub _verbose {
  my $this = shift;
  return $this->{verbose};
}

#+
# Rudimentry method to avoid dangerous SQL stmts
#-
sub _safeSQL {
  my $this = shift;
  my $value = shift;
  return ( $value =~ /DELETE|DROP|UPDATE|INSERT|ALTER/gi );
}


#+
# Based on file format as of 2005-08-01
#-
sub _parseTabFile {
	my $this = shift;
	my %args = @_;


  # Array of column headings
  my @headings;
  # column heading indicies
  my %idx;
  my %seen;

  open( WBOOK, "<$args{wbook}" ) || die "unable to open $args{wbook}";
  $this->{_wbook} = $args{wbook};
  
  die;
  while( my $line = <WBOOK> ){
    chomp $line;
    next if $line =~ /^\s*$/;
    my @line = split( "\t", $line, -1 );
    unless( @headings ) {
      # Meaningful headings fingerprint?
      next unless ( $line[0] =~ /Sample Setup Order/  &&
                    $line[1] =~ /MS Sample Run Number/ );
      for my $h ( @line ) {
        $h =~ s/\s+$//g;
        push @headings, $h;
      }

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
sub _parseExcelFile {
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

    # Sweet, the excel parser loves blank lines.  Doh!
    if ( !$line[0] &&  !$line[1] &&  !$line[2] &&  !$line[3] &&  !$line[4] &&
         !$line[5] &&  !$line[6] &&  !$line[7] &&  !$line[8] &&  !$line[9] ) { 
      next;
    }

    unless( @headings ) {
      # Meaningful headings fingerprint?
      next unless ( $line[0] =~ /Sample Setup Order/  &&
                    $line[1] =~ /MS Sample Run Number/ );
      for my $h ( @line ) {
#        $h =~ s/\s+$//g;
#        $h =~ s/^\s+//g;
        push @headings, $h;
      }

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

#+ 
# returns reversed hash; dangerous as always!
#-
sub _getDb2ParserMap {
  my $this = shift;
  my $mode = shift || 'all';
  my $map = $this->_getParser2DbMap( $mode );
  my %reverse = reverse( %$map );
  for( keys( %reverse ) ) {
    #print "$_ => $reverse{$_}\n";
  }
  return \%reverse;
}
sub _getParser2DbMap {
  my $this = shift;
  my $mode = shift || 'all';

  # Biosource
  my %biosource = (
    'ISB sample ID' => 'biosource_name',   # to be used as biosample_name also?
    'Patient_id' => 'patient_id',
    'External Sample ID' => 'external_id',
    'Name of Institute' => 'organization_id', #  Do ID lookup
    'Name of Investigators' => 'investigators', # need to add
    'Sample type ' => 'tissue_type_id', 
    'species' => 'organism_id', # Do ID lookup
    'age' => 'age',  # will have to split
    'gender' => 'gender', # need to add
  );
  return \%biosource if $mode eq 'biosource';
  

  # Biosource Attributes
  my %biosource_attr = (
    'PARAM:time of sample collection' => 'collection_time',  # type => PARAM, name => collection_time, value => value
    'PARAM:meal' => 'meal',   
#    'PARAM:alcohole' => 'alcohol',   
    'PARAM:alcohol' => 'alcohol',   
#    'PARAM:smoke' => 'smoke',   
    'PARAM:Date of Sample Collection' => 'collection_date',   
    'PARAM:Others' => 'other',   

    'others' => 'other',  # type => general, name => others, value => value
#    'Plate Layout' => 'plate_layout',      
    'Study Histology' => 'study_histology',
    'Disease Info: Group' => 'group_disease',
  );
  return \%biosource_attr if $mode eq 'biosource_attr';

  # biosource_disease.disease_stage
  my %biosource_disease_stage = (
    'Disease Stage' => 'disease_stage',
  );
  return \%biosource_disease_stage if $mode eq 'biosource_disease_stage';

    # Diseases
  my %biosource_disease = (
    'Disease:Breast cancer' => 'breast_cancer',   # disease_type => cancer, disease_name => breast_cancer, value => value
    'Disease:Ovarian cancer' => 'ovarian_cancer',   # source disease
    'Disease:Prostate cancer' => 'prostate_cancer',    # source disease
    'Disease:Blader Cancer' => 'bladder_cancer',     # source disease
    'Disease:Skin cancer' => 'skin_cancer',    # source disease
    'Disease:Lung cancer' => 'lung_cancer',    # source disease
    "Disease: Huntington's Disease" => 'huntingtons_disease',    # source disease
    'Disease:other cancers' => 'other_cancers',
  );
  return \%biosource_disease if $mode eq 'biosource_disease';

  # Biosample
  my %biosample = (
#    'ISB sample ID' => 'biosample_name',   # to be used as biosample_name also?
    'Location of orginal sample' => 'storage_location_id',
    'amount of sample received' => 'original_volume',
    'Plate Layout' => 'well_id'
  );
  return \%biosample if $mode eq 'biosample';

  # Biosample Attributes
  my %biosample_attr = (
    'Sample Setup Order' => 'sample_setup',#   biosample_attribute, type is sample_order name is sample_setup_order, value is value
    'MS Sample Run Number' => 'ms_run_number',
  );
  return \%biosample_attr if $mode eq 'biosample_attr';

  # Tissue types 
  my %tissue_type = (
    'heart' => 'heart',
    'blood' => 'blood',
    'liver' => 'liver',
    'diabetic' => 'diabetic',
    'neuron' => 'neuron',
    'lung' => 'lung',
    'bone' => 'bone'
  );
  return \%tissue_type if $mode eq 'tissue_type';

  # Prep stuff,    samples -> treatment
  my %prep_params = (
    'Prep Replicate id' => 'xxxx',   #   biosample_attribute, type is sample_order name is prep_replicate_id, value is value
    'Sample Prep Name' => 'xxxx',    # treatement_name  =>> deprecated, still a possibility???  # biogroup.bio_group_name, group type is sample_prep
    'status of sample prep' => 'xxxx',  # treatement.status
    'date of finishing prep' => 'xxxx', # treatment.date_completed
    'amount of sample used in prep' => 'xxxx', # input_volume
    'Sample prep method' => 'xxxx', # protocol
    'person prepared the samples' => 'xxxx',  # treatment.processed_by
    'Volume of re-suspended sample' => 'xxxx',  # New sample.original_volume
    'location of finished sample prep' => 'xxxx',   # New sample.storage_location 
  );
  return \%prep_params if $mode eq 'prep_params';

  # MS stuff, all downstream!
  my %ms_params = (
    'MS Replicate Number' => 'xxxx',
    'MS Run Name' => 'xxxx',
    'status of MS' => 'xxxx',
    'date finishing MS' => 'xxxx',
    'Random Sample Run order' => 'xxxx',
    'order of samples ran per day' => 'xxxx',
    'MS run protocol' => 'xxxx',
    'Volume Injected' => 'xxxx',
  );
  return \%ms_params if $mode eq 'ms_params';

    # analysis stuff, all downstream!
  my %analysis_params = (
    'location of data' => 'xxxx',
    'status of Conversion' => 'xxxx',
    'Date finishing conversion' => 'xxxx',
    'name of raw files' => 'xxxx',
    'location of raw files' => 'xxxx',
    'name of mzXML' => 'xxxx',
    'location of mzXML' => 'xxxx',
    'person for MS analysis' => 'xxxx',
    'date finishing alignment' => 'xxxx',
    'location of alignment files' => 'xxxx',
    'person for data analysis' => 'xxxx',
    'peplist peptide peaks file location' => 'xxxx'
  );
  return \%analysis_params if $mode eq 'analysis_params';

  my %map = ( %biosource,
              %biosource_attr,
              %biosource_disease,
              %biosource_disease_stage,
              %biosample,
              %biosample_attr, 
              %tissue_type,
              %prep_params,
              %ms_params,
              %analysis_params
            );

  return \%map if $mode eq 'all';
  die "Unknown mode $mode, try again";
  
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

    'Sample Setup Order' => xxxx
    'MS Sample Run Number' => xxxx
    'Plate Layout' => xxxx
    'ISB sample ID' => xxxx
    'Patient_id' => xxxx
    'External Sample ID' => xxxx
    'Name of Institute' => xxxx
    'Name of Investigators' => xxxx
    'Sample type' => xxxx
    'species' => xxxx
    'age' => xxxx
    'gender' => xxxx
    'amount of sample received' => xxxx
    'Location of orginal sample' => xxxx
    'PARAM:time of sample collection' => xxxx
    'PARAM:meal' => xxxx
    'PARAM:alcohole' => xxxx
    'PARAM:smoke' => xxxx
    'PARAM:Date of Sample Collection' => xxxx
    'PARAM:Others' => xxxx
    'Disease:Breast cancer' => xxxx
    'Disease:Ovarian cancer' => xxxx
    'Disease:Prostate cancer' => xxxx
    'Disease:Blader Cancer' => xxxx
    'Disease:Skin cancer' => xxxx
    'Disease:Lung cancer' => xxxx
    'Disease: Huntington's Disease' => xxxx
    'Disease:other cancers' => xxxx
    'heart' => xxxx
    'blood' => xxxx
    'liver' => xxxx
    'diabetic' => xxxx
    'neuron' => xxxx
    'lung' => xxxx
    'bone' => xxxx
    'Disease Stage' => xxxx
    'others' => xxxx
    'Study Histology' => xxxx
    'Disease Info: Group' => xxxx
    'Prep Replicate id' => xxxx
    'Sample Prep Name' => xxxx
    'status of sample prep' => xxxx
    'date of finishing prep' => xxxx
    'amount of sample used in prep' => xxxx
    'Sample prep method' => xxxx
    'person prepared the samples' => xxxx
    'Volume of re-suspended sample' => xxxx
    'location of finished sample prep' => xxxx
    'MS Replicate Number' => xxxx
    'MS Run Name' => xxxx
    'status of MS' => xxxx
    'date finishing MS' => xxxx
    'Random Sample Run order' => xxxx
    'order of samples ran per day' => xxxx
    'MS run protocol' => xxxx
    'Volume Injected' => xxxx
    'location of data' => xxxx
    'status of Conversion' => xxxx
    'Date finishing conversion' => xxxx
    'name of raw files' => xxxx
    'location of raw files' => xxxx
    'name of mzXML' => xxxx
    'location of mzXML' => xxxx
    'person for MS analysis' => xxxx
    'date finishing alignment' => xxxx
    'location of alignment files' => xxxx
    'person for data analysis' => xxxx
    'peplist peptide peaks file location' => xxxx

# Attributes 
'Sample Setup Order'  # 
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
        

