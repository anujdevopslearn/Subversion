package SBEAMS::PeptideAtlas::Spectrum;

###############################################################################
# Class       : SBEAMS::PeptideAtlas::Spectrum
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
#
=head1 SBEAMS::PeptideAtlas::Spectrum

=head2 SYNOPSIS

  SBEAMS::PeptideAtlas::Spectrum

=head2 DESCRIPTION

This is part of the SBEAMS::PeptideAtlas module which handles
things related to PeptideAtlas spectra

=cut
#
###############################################################################

use strict;
use DB_File ;
use Data::Dumper;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
require Exporter;
@ISA = qw();
$VERSION = q[$Id$];
@EXPORT_OK = qw();

use SBEAMS::Connection qw( $log );
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::Settings;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::Proteomics::Tables;

###############################################################################
# Global variables
###############################################################################
use vars qw($VERBOSE $TESTONLY $sbeams);
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval);


###############################################################################
# Constructor
###############################################################################
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    $VERBOSE = 0;
    $TESTONLY = 0;
    return($self);
} # end new


###############################################################################
# setSBEAMS: Receive the main SBEAMS object
###############################################################################
sub setSBEAMS {
    my $self = shift;
    $sbeams = shift;
    return($sbeams);
} # end setSBEAMS



###############################################################################
# getSBEAMS: Provide the main SBEAMS object
###############################################################################
sub getSBEAMS {
    my $self = shift;
    return $sbeams || SBEAMS::Connection->new();
} # end getSBEAMS



###############################################################################
# setTESTONLY: Set the current test mode
###############################################################################
sub setTESTONLY {
    my $self = shift;
    $TESTONLY = shift;
    return($TESTONLY);
} # end setTESTONLY



###############################################################################
# setVERBOSE: Set the verbosity level
###############################################################################
sub setVERBOSE {
    my $self = shift;
    $VERBOSE = shift;
    return($TESTONLY);
} # end setVERBOSE



###############################################################################
# loadBuildSpectra -- Loads all spectra for specified build
###############################################################################
sub loadBuildSpectra {
  my $METHOD = 'loadBuildSpectra';
  my $self = shift || die ("self not passed");
  my %args = @_;

  #### Process parameters
  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");

  my $atlas_build_directory = $args{atlas_build_directory}
    or die("ERROR[$METHOD]: Parameter atlas_build_directory not passed");

  my $organism_abbrev = $args{organism_abbrev}
    or die("ERROR[$METHOD]: Parameter organism_abbrev not passed");


  #### We now support two different file types
  #### First try to find the PAidentlist file
  my $filetype = 'PAidentlist';
  my $expected_n_columns = 14;
  my $peplist_file = "$atlas_build_directory/".
    "PeptideAtlasInput_concat.PAidentlist";

  #### Else try the older peplist file
  unless (-e $peplist_file) {
    print "WARNING: Unable to find PAidentlist file '$peplist_file'\n";

    $peplist_file = "$atlas_build_directory/".
      "APD_${organism_abbrev}_all.peplist";
    unless (-e $peplist_file) {
      print "ERROR: Unable to find peplist file '$peplist_file'\n";
      return;
    }
    #### Found it, so proceed but admonish user
    print "WARNING: Found older peplist file '$peplist_file'\n";
    print "         This file type is deprecated, but will load anyway\n";
    $filetype = 'peplist';
    $expected_n_columns = 17;
  }


  #### Find and open the input peplist file
  unless (open(INFILE,$peplist_file)) {
    print "ERROR: Unable to open for read file '$peplist_file'\n";
    return;
  }


  #### Read and verify header if a peplist file
  if ($filetype eq 'peplist') {
    my $header = <INFILE>;
    unless ($header && substr($header,0,10) eq 'search_bat' &&
	    length($header) == 155) {
      print "len = ".length($header)."\n";
      print "ERROR: Unrecognized header in peplist file '$peplist_file'\n";
      close(INFILE);
      return;
    }
  }


  #### Loop through all spectrum identifications and load
  my @columns;
  my ($start, $diff, $pre_search_batch_id, $n);
  $start = [gettimeofday];
  $n=0;
  while ( my $line = <INFILE>) {
    chomp $line;
    @columns = split(/\t/,$line);
    #print "cols = ".scalar(@columns)."\n";
    unless (scalar(@columns) == $expected_n_columns) {
      if ($expected_n_columns == 14 && scalar(@columns) == 11) {
				print "WARNING: Unexpected number of columns (".
				scalar(@columns)."!=$expected_n_columns) in\n$line\n".
					"This is likely missing ProteinProphet information, which is bad, but we will allow it until this bug is fixed.\n";
      } elsif (scalar(@columns) == 15) {
				#### This is okay for now: experimental SpectraST addition
      } else {
				die("ERROR: Unexpected number of columns (".
				scalar(@columns)."!=$expected_n_columns) in\n$line");
      }
    }

    my ($search_batch_id,$spectrum_name,$peptide_accession,$peptide_sequence,
        $preceding_residue,$modified_sequence,$following_residue,$charge,
        $probability,$massdiff,$protein_name,$proteinProphet_probability,
        $n_proteinProphet_observations,$n_sibling_peptides,
        $SpectraST_probability, $ptm_sequence);
    if ($filetype eq 'peplist') {
      ($search_batch_id,$peptide_sequence,$modified_sequence,$charge,
        $probability,$protein_name,$spectrum_name) = @columns;
    } elsif ($filetype eq 'PAidentlist') {
      ($search_batch_id,$spectrum_name,$peptide_accession,$peptide_sequence,
        $preceding_residue,$modified_sequence,$following_residue,$charge,
        $probability,$massdiff,$protein_name,$proteinProphet_probability,
        $n_proteinProphet_observations,$n_sibling_peptides,
        $SpectraST_probability) = @columns;
      #### Correction for occasional value '+-0.000000'
      $massdiff =~ s/\+\-//;
    } else {
      die("ERROR: Unexpected filetype '$filetype'");
    }
    
    $ptm_sequence = '';
    if ($modified_sequence =~ /\(/){
      $ptm_sequence = $modified_sequence;
      $modified_sequence =~ s/\([\d\.]+\)//g;
      $ptm_sequence =~ s/\[[\d\.]+\]//g;
    }

    $self->insertSpectrumIdentification(
       atlas_build_id => $atlas_build_id,
       search_batch_id => $search_batch_id,
       modified_sequence => $modified_sequence,
       ptm_sequence => $ptm_sequence,
       charge => $charge,
       probability => $probability,
       protein_name => $protein_name,
       spectrum_name => $spectrum_name,
       massdiff => $massdiff,);

    $n++;
    if($pre_search_batch_id ne $search_batch_id){
      $diff = tv_interval ( $start, [gettimeofday]);
      print "\nsearch_batch_id: $pre_search_batch_id, time per entry: " . $diff/$n ;
			print "s\n";
			$start = [gettimeofday];
      $n=0;
    }
    $pre_search_batch_id = $search_batch_id;
  }

} # end loadBuildSpectra



###############################################################################
# insertSpectrumIdentification --
###############################################################################
sub insertSpectrumIdentification {
  my $METHOD = 'insertSpectrumIdentification';
  my $self = shift || die ("self not passed");
  my %args = @_;

  #### Process parameters
  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");
  my $search_batch_id = $args{search_batch_id}
    or die("ERROR[$METHOD]: Parameter search_batch_id not passed");
  my $modified_sequence = $args{modified_sequence}
    or die("ERROR[$METHOD]: Parameter modified_sequence not passed");
  my $ptm_sequence = $args{ptm_sequence} || ''; 
  my $charge = $args{charge}
    or die("ERROR[$METHOD]: Parameter charge not passed");
  my $protein_name = $args{protein_name}
    or die("ERROR[$METHOD]: Parameter protein_name not passed");
  my $spectrum_name = $args{spectrum_name}
    or die("ERROR[$METHOD]: Parameter spectrum_name not passed");
  my $massdiff = $args{massdiff};
  
  my $probability = $args{probability};
  die("ERROR[$METHOD]: Parameter probability not passed") if($probability eq '');

  our $counter;

  #### Get the modified_peptide_instance_id for this peptide
  my $modified_peptide_instance_id = $self->get_modified_peptide_instance_id(
    atlas_build_id => $atlas_build_id,
    modified_sequence => $modified_sequence,
    charge => $charge,
  );

  #### Get the sample_id for this search_batch_id
  my $sample_id = $self->get_sample_id(
    proteomics_search_batch_id => $search_batch_id,
  );

  #### Get the atlas_search_batch_id for this search_batch_id
  my $atlas_search_batch_id = $self->get_atlas_search_batch_id(
    proteomics_search_batch_id => $search_batch_id,
  );

  #### Check to see if this spectrum is already in the database
  my $spectrum_id = $self->get_spectrum_id(
    sample_id => $sample_id,
    spectrum_name => $spectrum_name,
  );

  #### If not, INSERT it
  unless ($spectrum_id) {
    $spectrum_id = $self->insertSpectrumRecord(
      sample_id => $sample_id,
      spectrum_name => $spectrum_name,
      proteomics_search_batch_id => $search_batch_id,
    );
  }


  #### Check to see if this spectrum_identification is in the database
  my $spectrum_identification_id = $self->get_spectrum_identification_id(
    modified_peptide_instance_id => $modified_peptide_instance_id,
    spectrum_id => $spectrum_id,
    atlas_search_batch_id => $atlas_search_batch_id,
    atlas_build_id => $atlas_build_id,
  );

  $counter++;
  print "$counter..." if ($counter/100 == int($counter/100));
  #### If not, INSERT it
  unless ($spectrum_identification_id) {
    $spectrum_identification_id = $self->insertSpectrumIdentificationRecord(
      modified_peptide_instance_id => $modified_peptide_instance_id,
      spectrum_id => $spectrum_id,
      atlas_search_batch_id => $atlas_search_batch_id,
      probability => $probability,
      massdiff => $massdiff,
    );
    if ($ptm_sequence ne ''){
			my $spectrum_ptm_identification_id = $self->insertSpectrumPTMIdentificationRecord(
				spectrum_identification_id => $spectrum_identification_id,
				ptm_sequence => $ptm_sequence,
			);
    }
  }


} # end insertSpectrumIdentification



###############################################################################
# get_modified_peptide_instance_id --
###############################################################################
sub get_modified_peptide_instance_id {
  my $METHOD = 'get_modified_peptide_instance_id';
  my $self = shift || die ("self not passed");
  my %args = @_;

  #### Process parameters
  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");
  my $modified_sequence = $args{modified_sequence}
    or die("ERROR[$METHOD]: Parameter modified_sequence not passed");
  my $charge = $args{charge}
    or die("ERROR[$METHOD]: Parameter charge not passed");

  #### If we haven't loaded all modified_peptide_instance_ids into the
  #### cache yet, do so
  our %modified_peptide_instance_ids;
  unless (%modified_peptide_instance_ids) {
    print "[INFO] Loading all modified_peptide_instance_ids...\n";
    my $sql = qq~
      SELECT modified_peptide_instance_id,modified_peptide_sequence,
             peptide_charge
        FROM $TBAT_MODIFIED_PEPTIDE_INSTANCE MPI
        JOIN $TBAT_PEPTIDE_INSTANCE PI
             ON ( MPI.peptide_instance_id = PI.peptide_instance_id )
       WHERE PI.atlas_build_id = $atlas_build_id
    ~;

    my $sth = $sbeams->get_statement_handle( $sql );
    #### Loop through all rows and store in hash
    my $cnt = 0;
    while ( my $row = $sth->fetchrow_arrayref() ) {
      $cnt++;
      my $modified_peptide_instance_id = $row->[0];
      #my $key = $row->[1].'/'.$row->[2];
      #$modified_peptide_instance_ids{$key} = $modified_peptide_instance_id;
      $modified_peptide_instance_ids{$row->[2]}{$row->[1]} = $modified_peptide_instance_id;
    }
    print "       $cnt loaded...\n";
  }


  #### Lookup and return modified_peptide_instance_id
  #my $key = "$modified_sequence/$charge";
  #if ($modified_peptide_instance_ids{$key}) {
  #  return($modified_peptide_instance_ids{$key});
  #};
  if ($modified_peptide_instance_ids{$charge}{$modified_sequence}) {
    return($modified_peptide_instance_ids{$charge}{$modified_sequence});
  };

  die("ERROR: Unable to find '$modified_sequence/$charge' in modified_peptide_instance_ids hash. ".
      "This should never happen.");

} # end get_modified_peptide_instance_id



###############################################################################
# get_sample_id --
###############################################################################
sub get_sample_id {
  my $METHOD = 'get_sample_id';
  my $self = shift || die ("self not passed");
  my %args = @_;

  #### Process parameters
  my $proteomics_search_batch_id = $args{proteomics_search_batch_id}
    or die("ERROR[$METHOD]: Parameter proteomics_search_batch_id not passed");

  #### If we haven't loaded all sample_ids into the
  #### cache yet, do so
  our %sample_ids;
  unless (%sample_ids) {
    print "[INFO] Loading all sample_ids...\n";
    my $sql = qq~
      SELECT proteomics_search_batch_id,sample_id
        FROM $TBAT_ATLAS_SEARCH_BATCH
       WHERE record_status != 'D'
    ~;
    %sample_ids = $sbeams->selectTwoColumnHash($sql);

    print "       ".scalar(keys(%sample_ids))." loaded...\n";
  }


  #### Lookup and return sample_id
  if ($sample_ids{$proteomics_search_batch_id}) {
    return($sample_ids{$proteomics_search_batch_id});
  };

  die("ERROR: Unable to find '$proteomics_search_batch_id' in ".
      "sample_ids hash. This should never happen.");

} # end get_sample_id



###############################################################################
# get_atlas_search_batch_id --
###############################################################################
sub get_atlas_search_batch_id {
  my $METHOD = 'get_atlas_search_batch_id';
  my $self = shift || die ("self not passed");
  my %args = @_;

  #### Process parameters
  my $proteomics_search_batch_id = $args{proteomics_search_batch_id}
    or die("ERROR[$METHOD]: Parameter proteomics_search_batch_id not passed");

  #### If we haven't loaded all atlas_search_batch_ids into the
  #### cache yet, do so
  our %atlas_search_batch_ids;
  unless (%atlas_search_batch_ids) {
    print "[INFO] Loading all atlas_search_batch_ids...\n";

    my $sql = qq~
      SELECT proteomics_search_batch_id,atlas_search_batch_id
        FROM $TBAT_ATLAS_SEARCH_BATCH
       WHERE record_status != 'D'
    ~;
    %atlas_search_batch_ids = $sbeams->selectTwoColumnHash($sql);

    print "       ".scalar(keys(%atlas_search_batch_ids))." loaded...\n";
  }


  #### Lookup and return sample_id
  if ($atlas_search_batch_ids{$proteomics_search_batch_id}) {
    return($atlas_search_batch_ids{$proteomics_search_batch_id});
  };

  die("ERROR: Unable to find '$proteomics_search_batch_id' in ".
      "atlas_search_batch_ids hash. This should never happen.");

} # end get_atlas_search_batch_id



###############################################################################
# get_spectrum_id --
###############################################################################
sub get_spectrum_id {
  my $METHOD = 'get_spectrum_id';
  my $self = shift || die ("self not passed");
  my %args = @_;

  #### Process parameters
  my $sample_id = $args{sample_id}
    or die("ERROR[$METHOD]: Parameter sample_id not passed");
  my $spectrum_name = $args{spectrum_name}
    or die("ERROR[$METHOD]: Parameter spectrum_name not passed");

  #### If we haven't loaded all spectrum_ids into the
  #### cache yet, do so
  our %spectrum_ids;
  our %processed_sample_ids;
  unless ($processed_sample_ids{$sample_id}) {
    print "\n[INFO] Loading spectrum_ids for sample_id $sample_id...\n";
    %spectrum_ids = ();
    $processed_sample_ids{$sample_id} = 1;
    my $sql = qq~
      SELECT sample_id,spectrum_name,spectrum_id
        FROM $TBAT_SPECTRUM 
        WHERE sample_id=$sample_id
    ~;

    my $sth = $sbeams->get_statement_handle( $sql );
    my $num_ids =0;
    while ( my $row = $sth->fetchrow_arrayref() ) {
      #my $key = "$row->[0]-$row->[1]";
      $spectrum_ids{$row->[0]}{$row->[1]} = $row->[2];
      $num_ids++;
    }
    #my $num_ids = scalar(keys(%spectrum_ids));
    print "       $num_ids spectrum IDs loaded for sample_id $sample_id...\n";

    #### Put a dummy entry in the hash so load won't trigger twice if
    #### table is empty at this point
    $spectrum_ids{DUMMY} = -1 unless $num_ids;

    #### Print out a few entries
    #my $i=0;
    #while (my ($key,$value) = each(%spectrum_ids)) {
    #  print "  spectrum_ids: $key = $value\n";
    #  last if ($i > 5);
    #  $i++;
    #}

  }


  #### Lookup and return spectrum_id
  #my $key = "$sample_id-$spectrum_name";
  #print "key = $key  spectrum_ids{key} = $spectrum_ids{$key}\n";
  if ($spectrum_ids{$sample_id}{$spectrum_name}) {
    return($spectrum_ids{$sample_id}{$spectrum_name});
  };

  #### Else we don't have it yet
  return();

} # end get_spectrum_id



###############################################################################
# insertSpectrumRecord --
###############################################################################
sub insertSpectrumRecord {
  my $METHOD = 'insertSpectrumRecord';
  my $self = shift || die ("self not passed");
  my %args = @_;

  #### Process parameters
  my $sample_id = $args{sample_id}
    or die("ERROR[$METHOD]: Parameter sample_id not passed");
  my $spectrum_name = $args{spectrum_name}
    or die("ERROR[$METHOD]: Parameter spectrum_name not passed");
  my $proteomics_search_batch_id = $args{proteomics_search_batch_id}
    or die("ERROR[$METHOD]: Parameter proteomics_search_batch_id not passed");


  #### Parse the name into components
  my ($fraction_tag,$start_scan,$end_scan);
  if ($spectrum_name =~ /^(.+)\.(\d+)\.(\d+)\.\d$/) {
    $fraction_tag = $1;
    $start_scan = $2;
    $end_scan = $3;
  }
  elsif($spectrum_name  =~ /^(.+)\..*\s+(\d+).*\d\)$/) {
    $fraction_tag = $1;
    $start_scan = $2;
    $end_scan = $2;
  }
  else {
    die("ERROR: Unable to parse fraction name from '$spectrum_name'");
  }

  #### Define the attributes to insert
  my %rowdata = (
    sample_id => $sample_id,
    spectrum_name => $spectrum_name,
    start_scan => $start_scan,
    end_scan => $end_scan,
    scan_index => -1,
  );


  #### Insert spectrum record
  my $spectrum_id = $sbeams->updateOrInsertRow(
    insert=>1,
    table_name=>$TBAT_SPECTRUM,
    rowdata_ref=>\%rowdata,
    PK => 'spectrum_id',
    return_PK => 1,
    verbose=>$VERBOSE,
    testonly=>$TESTONLY,
  );


  #### Add it to the cache
  our %spectrum_ids;
  my $key = "$sample_id$spectrum_name";
  $spectrum_ids{$key} = $spectrum_id;


#  #### Get the spectrum peaks
#  my mz_intensitities = $self->getSpectrumPeaks(
#    proteomics_search_batch_id => $search_batch_id,
#    spectrum_name => $spectrum_name,
#    fraction_tag => $fraction_tag,
#  );


  return($spectrum_id);

} # end insertSpectrumRecord



###############################################################################
# get_data_location --
###############################################################################
sub get_data_location {
  my $METHOD = 'get_data_location';
  my $self = shift || die ("self not passed");
  my %args = @_;

  #### Process parameters
  my $proteomics_search_batch_id = $args{proteomics_search_batch_id}
    or die("ERROR[$METHOD]: Parameter proteomics_search_batch_id not passed");

  #### If we haven't loaded all atlas_search_batch_ids into the
  #### cache yet, do so
  our %data_locations;

  unless (%data_locations) {
    print "[INFO] Loading all data_locations...\n" if ($VERBOSE);

    my $sql = qq~
      SELECT proteomics_search_batch_id,data_location || '/' || search_batch_subdir
        FROM $TBAT_ATLAS_SEARCH_BATCH
       WHERE record_status != 'D'
    ~;
    %data_locations = $sbeams->selectTwoColumnHash($sql);

    print "       ".scalar(keys(%data_locations))." loaded...\n" if ($VERBOSE);
  }


  #### Lookup and return data_location
  if ($data_locations{$proteomics_search_batch_id}) {
    return($data_locations{$proteomics_search_batch_id});
  };

  die("ERROR: Unable to find '$proteomics_search_batch_id' in ".
      "data_locations hash. This should never happen.");

} # end get_data_location


###############################################################################
# getSpectrumPeaks_Lib --
###############################################################################
sub getSpectrumPeaks_Lib {
  my $METHOD = 'getSpectrumPeaks_Lib';
  my $self = shift || die ("self not passed");
  my %args = @_;

  #### Process parameters
  my $spectrum_name = $args{spectrum_name}
    or die("ERROR[$METHOD]: Parameter spectrum_name not passed");
  my $library_idx_file = $args{library_idx_file}
    or die("ERROR[$METHOD]: Parameter library_idx_file not passed");

  #### Infomational/problem message buffer, only printed if get fails
  my $buffer = '';
  #### Get the data_location of the spectrum

  $buffer .= "data_location = $library_idx_file\n";

  # If location does not begin with slash, prepend default dir.
  $buffer .= "library_location = $library_idx_file\n";

  use SBEAMS::PeptideAtlas::ConsensusSpectrum;
  my $consensus = new SBEAMS::PeptideAtlas::ConsensusSpectrum;
  $consensus->setSBEAMS($sbeams);
  my $peaks;

  my $comp_lib_idx_file = $library_idx_file;
  $comp_lib_idx_file =~ s/specidx/compspecidx/;
  my $off;
  if ( -e $comp_lib_idx_file ) {
    $log->debug( "Using compressed library $comp_lib_idx_file" );
    my $idx_line = `grep -m1 $args{spectrum_name} $comp_lib_idx_file`;
    chomp $idx_line;
    if ( !$idx_line ) {
      # spectra names are *not* supposed to have charges appended, but...
      my $trimmed_specname = $args{spectrum_name};
      $trimmed_specname =~ s/\.\d$//;
      $idx_line = `grep -m1 $trimmed_specname $comp_lib_idx_file`;
      chomp $idx_line;
      if ( $idx_line ) {
        $log->debug( "$trimmed_specname worked after removing .charge suffix" );
      } else {
        $log->error( "$trimmed_specname still doesn't work without .charge suffix" );
      }
    }

    if ( $idx_line ) {
      my @line = split( /\t/, $idx_line );
      $off = $line[4];
      my $len = $line[3];
      my $filename = $comp_lib_idx_file;
      $filename =~ s/.compspecidx/.sptxt.gz/;

      $peaks = $consensus->get_spectrum_peaks( file_path => $filename, 
                                               entry_idx => $off, 
                                                 rec_len => $len, 
                                                bgzipped => 1,
                                             denormalize => 0, 
                                              %args );

      $log->debug( "Compressed fetch failed" ) if !scalar( @{$peaks->{labels}} );
    } else {
      $log->debug( "unable to find $args{spectrum_name} in $comp_lib_idx_file" );
    }
  }

  if ( !$peaks  || !scalar( @{$peaks->{labels}} ) ) {
    $log->debug( "Using native library" );

    my $filename = $library_idx_file;

    if ( -e $comp_lib_idx_file && !-e $library_idx_file ) {
      print $sbeams->makeErrorText("Temporarily unable to open spectrum, this error has been logged.<BR>");
      my $libname = $comp_lib_idx_file;
      $libname =~ s/.compspecidx/.sptxt.gz/;
      $log->error( "unable to extract spectrum $off from $libname, and $filename does not exist" );
      return undef;
    } else {
      open (IDX, "<$filename") or die "cannot open $filename\n";
    }

    my $position;
    $spectrum_name =~ s/\.\d$//;
    while (my $line = <IDX>){
      chomp $line;
      if ($line =~ /$spectrum_name\t(\d+)/){
        $position = $1;
        last;
      }
    }
    close IDX; 

    if ($position eq ''){
      die ("ERROR: cannot find $spectrum_name in $filename");
    }
    $filename =~ s/.specidx/.sptxt/;
    if ( ! -e "$filename"){
      die ("ERROR: cannot find file $filename");
    }
    $filename =~ /.*\/(.*)/;

    # Dubious print statement!
    #  print "get spectrum from $1<BR>";

    $peaks = $consensus->get_spectrum_peaks( file_path => $filename, 
                                             entry_idx => $position, 
                                           denormalize => 0, 
                                            %args );
  }

  #### Read the spectrum data
  my @mz_intensities;
  for (my $i=0; $i< scalar @{$peaks->{masses}}; $i++) {
    push(@mz_intensities,[($peaks->{masses}[$i],$peaks->{intensities}[$i])]);
  }

  #### If there were no values, print diagnostics and return
  unless (@mz_intensities) {
    $buffer .= "ERROR: No peaks returned from extraction attempt<BR>\n";
    print $buffer;
    return;
  }
  #### Return result
  print "   ".scalar(@mz_intensities)." mass-inten pairs loaded\n"
    if ($VERBOSE);
  return(@mz_intensities);

} # end getSpectrumPeaks_Lib

###############################################################################
# getSpectrumPeaks --
###############################################################################
sub getSpectrumPeaks {
  my $METHOD = 'getSpectrumPeaks';
  my $self = shift || die ("self not passed");
  my %args = @_;

  #### Process parameters
  my $proteomics_search_batch_id = $args{proteomics_search_batch_id}
    or die("ERROR[$METHOD]: Parameter proteomics_search_batch_id not passed");
  my $spectrum_name = $args{spectrum_name}
    or die("ERROR[$METHOD]: Parameter spectrum_name not passed");
  my $fraction_tag = $args{fraction_tag}
    or die("ERROR[$METHOD]: Parameter fraction_tag not passed");


  #### Infomational/problem message buffer, only printed if get fails
  my $buffer = '';

  #### Get the data_location of the spectrum
  my $data_location = $self->get_data_location(
    proteomics_search_batch_id => $proteomics_search_batch_id,
  );
  $buffer .= "data_location = $data_location<br>\n";

  ($data_location, $buffer) = $self->groom_data_location(
    data_location => $data_location,
    history_buffer => $buffer,
  );
  $buffer .= "data_location = $data_location<br>\n";

  ### extracted into groom_data_location() -- can delete after 2/1/13
#--------------------------------------------------
#   # For absolute paths, leading slash is not being stored in
#   # data_location field of atlas_search_batch table. Until that is
#   # fixed, we have this nice kludge.
#   if ($data_location =~ /^regis/) {
#     $data_location = "/$data_location";
#   }
#   $buffer .= "data_location = $data_location<br>\n";
# 
#   # If location does not begin with slash, prepend default dir.
#   $buffer .= "data_location = $data_location\n";
#   unless ($data_location =~ /^\//) {
#     $data_location = $RAW_DATA_DIR{Proteomics}."/$data_location";
#   }
#   $buffer .= "data_location = $data_location<br>\n";
# 
#   #### Sometimes a data_location will be a specific xml file
#   if ($data_location =~ /^(.+)\/interac.+xml$/i) {
#     $data_location = $1;
#   }
# $buffer .= "data_location = $data_location<br>\n";
#-------------------------------------------------- 


  my $filename;


  #### First try to fetch the spectrum from an mzXML file
  my $mzXML_filename;
  
  if($fraction_tag =~ /.mzML/){
    $mzXML_filename = "$data_location/$fraction_tag";
    if ( ! -e $mzXML_filename ){
      $mzXML_filename = "$data_location/$fraction_tag.mzML";
    }
  }else{
    $mzXML_filename = "$data_location/$fraction_tag.mzML";
  }

  if ( ! -e $mzXML_filename){
    $mzXML_filename .= ".gz";
  }

  if( ! -e $mzXML_filename){
     $mzXML_filename = "$data_location/$fraction_tag.mzXML";
  }

  if ( ! -e $mzXML_filename){
    $mzXML_filename .= ".gz";
  } 
 
  $buffer .= "INFO: Looking for '$mzXML_filename'<BR>\n";
  if ( -e $mzXML_filename ) {
    $buffer .= "INFO: Found '$mzXML_filename'<BR>\n";
    my $spectrum_number;
    if ($spectrum_name =~ /(\d+)\.(\d+)\.\d$/) {
      $spectrum_number = $1;
      $buffer .= "INFO: Spectrum number is $spectrum_number<BR>\n";
    }

    #### If we have a spectrum number, try to get the spectrum data
    if ($spectrum_number) {
      #$filename = "$PHYSICAL_BASE_DIR/lib/c/Proteomics/getSpectrum/".
      #  "getSpectrum $spectrum_number $mzXML_filename |";
      $filename = "/proteomics/sw/tpp/bin/readmzXML -s ".
                  "$mzXML_filename $spectrum_number |"
    }

  }


  #### If there's no filename then try ISB SEQUEST style .tgz file
  unless ($filename) {
    my $tgz_filename = "$data_location/$fraction_tag.tgz";
    $buffer .= "INFO: Looking for '$data_location/$fraction_tag.tgz'<BR>\n";
    if ( -e $tgz_filename ) {
      $buffer .= "INFO: Found '$tgz_filename'<BR>\n";
      $spectrum_name = "./$spectrum_name";

      #### Since we didn't find that, try a Comet style access method
    } else {
      $tgz_filename = "$data_location/$fraction_tag.cmt.tar.gz";

      unless ( -e $tgz_filename ) {
	$buffer .= "WARNING: Unable to find Comet style .cmt.tar.gz<BR>\n";
	$buffer .= "ERROR: Unable to find spectrum archive to pull from<BR>\n";
	print $buffer;
	return;
      }
      $buffer .= "INFO: Found '$tgz_filename'\n";
    }


    $filename = "/bin/tar -xzOf $tgz_filename $spectrum_name.dta|";

    $buffer .= "Pulling from tarfile: $tgz_filename<BR>\n";
    $buffer .= "Extracting: $filename<BR>\n";
  }


  #### Try to open the spectrum for reading
  unless (open(DTAFILE,$filename)) {
    $buffer .= "ERROR Cannot open '$filename'!!<BR>\n";
    print $buffer;
    return;
  }

  #### Read in but ignore header line if a dta file
  if ($filename =~ m#/bin/tar#) {
    my $headerline = <DTAFILE>;
    unless ($headerline) {
      $buffer .= "ERROR: No result returned from extraction attempt<BR>\n";
      print $buffer;
      return;
    }
  }

  #### Read the spectrum data
  my @mz_intensities;
  while (my $line = <DTAFILE>) {
    chomp($line);
    next if($line !~ /mass.*inten/);
    #my @values = split(/\s+/,$line);
    $line =~ /mass\s+(\S+)\s+inten\s+(\S+)/;
    push(@mz_intensities,[($1,$2)]);
  }
  close(DTAFILE);

  #### If there were no values, print diagnostics and return
  unless (@mz_intensities) {
    $buffer .= "ERROR: No peaks returned from extraction attempt<BR>\n";
    print $buffer;
    return;
  }

  #### Return result
  print "   ".scalar(@mz_intensities)." mass-inten pairs loaded\n"
    if ($VERBOSE);
  return(@mz_intensities);

} # end getSpectrumPeaks


###############################################################################
# groom_data_location --
###############################################################################
sub groom_data_location {
  my $METHOD = 'groom_data_location';
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $data_location = $args{data_location};
  my $history_buffer = $args{history_buffer} || '';

  # For absolute paths, leading slash is not being stored in
  # data_location field of atlas_search_batch table. Until that is
  # fixed, we have this nice kludge.
  if ($data_location =~ /^regis/) {
    $data_location = "/$data_location";
  }
  $history_buffer .= "data_location = $data_location\n";

  # If location does not begin with slash, prepend default dir.
  $history_buffer .= "data_location = $data_location\n";
  unless ($data_location =~ /^\//) {
    $data_location = $RAW_DATA_DIR{Proteomics}."/$data_location";
  }
  $history_buffer .= "data_location = $data_location\n";

  #### Sometimes a data_location will be a specific xml file
  if ($data_location =~ /^(.+)\/interac.+xml$/i) {
    $data_location = $1;
  }

  $history_buffer .= "data_location = $data_location\n";

  return ($data_location, $history_buffer);
}


###############################################################################
# get_spectrum_identification_id --
###############################################################################
sub get_spectrum_identification_id {
  my $METHOD = 'get_spectrum_identification_id';
  my $self = shift || die ("self not passed");
  my %args = @_;

  #### Process parameters
  my $modified_peptide_instance_id = $args{modified_peptide_instance_id}
    or die("ERROR[$METHOD]:Parameter modified_peptide_instance_id not passed");
  my $spectrum_id = $args{spectrum_id}
    or die("ERROR[$METHOD]: Parameter spectrum_id not passed");
  my $atlas_search_batch_id = $args{atlas_search_batch_id}
    or die("ERROR[$METHOD]: Parameter atlas_search_batch_id not passed");
  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");

  #### If we haven't loaded all spectrum_identification_ids into the
  #### cache yet, do so
  our %spectrum_identification_ids;
  our %processed_atlas_search_batch_id;
  unless ($processed_atlas_search_batch_id{$atlas_search_batch_id}) {
    print "\n[INFO] Loading all spectrum_identification_ids for atlas_search_batch_id $atlas_search_batch_id...\n";
    $processed_atlas_search_batch_id{$atlas_search_batch_id} = 1;
    %spectrum_identification_ids = ();
 
    my $sql = qq~
      SELECT SI.modified_peptide_instance_id,SI.spectrum_id,
             SI.atlas_search_batch_id,SI.spectrum_identification_id
        FROM $TBAT_SPECTRUM_IDENTIFICATION SI
        JOIN $TBAT_MODIFIED_PEPTIDE_INSTANCE MPI
             ON ( SI.modified_peptide_instance_id = MPI.modified_peptide_instance_id )
        JOIN $TBAT_PEPTIDE_INSTANCE PEPI
             ON ( MPI.peptide_instance_id = PEPI.peptide_instance_id )
       WHERE PEPI.atlas_build_id = '$atlas_build_id'
             AND SI.atlas_search_batch_id = $atlas_search_batch_id
    ~;

    my $sth = $sbeams->get_statement_handle( $sql );
    my $n = 0;
    #### Create a hash out of it
    while ( my $row = $sth->fetchrow_arrayref() ) {
      #my $key = "$row->[0]-$row->[1]-$row->[2]";
      $spectrum_identification_ids{$row->[2]}{$row->[0]}{$row->[1]} = $row->[3];
      $n++;
    }

    print "       $n loaded...\n";

    #### Put a dummy entry in the hash so load won't trigger twice if
    #### table is empty at this point
    $spectrum_identification_ids{DUMMY} = -1;
  }

  #### Lookup and return spectrum_id
  #my $key = "$modified_peptide_instance_id-$spectrum_id-$atlas_search_batch_id";
  if ($spectrum_identification_ids{$atlas_search_batch_id}{$modified_peptide_instance_id}{$spectrum_id}) {
    return($spectrum_identification_ids{$atlas_search_batch_id}{$modified_peptide_instance_id}{$spectrum_id});
  };

  #### Else we don't have it yet
  return();

} # end get_spectrum_identification_id

###############################################################################
# insertSpectrumIdentificationRecord --
###############################################################################
sub insertSpectrumIdentificationRecord {
  my $METHOD = 'insertSpectrumIdentificationRecord';
  my $self = shift || die ("self not passed");
  my %args = @_;

  #### Process parameters
  my $modified_peptide_instance_id = $args{modified_peptide_instance_id}
    or die("ERROR[$METHOD]:Parameter modified_peptide_instance_id not passed");
  my $spectrum_id = $args{spectrum_id}
    or die("ERROR[$METHOD]: Parameter spectrum_id not passed");
  my $atlas_search_batch_id = $args{atlas_search_batch_id}
    or die("ERROR[$METHOD]: Parameter atlas_search_batch_id not passed");
  my $massdiff = $args{massdiff};

  my $probability = $args{probability};
  die("ERROR[$METHOD]: Parameter probability not passed") if($probability eq '');


  #### Define the attributes to insert
  my %rowdata = (
    modified_peptide_instance_id => $modified_peptide_instance_id,
    spectrum_id => $spectrum_id,
    atlas_search_batch_id => $atlas_search_batch_id,
    probability => $probability,
    massdiff => $massdiff,
  );

  
  #### Insert spectrum identification record
  my $spectrum_identification_id = $sbeams->updateOrInsertRow(
    insert=>1,
    table_name=>$TBAT_SPECTRUM_IDENTIFICATION,
    rowdata_ref=>\%rowdata,
    PK => 'spectrum_identification_id',
    return_PK => 1,
    verbose=>$VERBOSE,
    testonly=>$TESTONLY,
  );


  #### Add it to the cache
  our %spectrum_identification_ids;
  my $key = "$modified_peptide_instance_id - $spectrum_id - $atlas_search_batch_id";
  $spectrum_identification_ids{$key} = $spectrum_identification_id;

  return($spectrum_identification_id);

} # end insertSpectrumIdentificationRecord


###############################################################################
# insertSpectrumPTMIdentificationRecord --
###############################################################################
sub insertSpectrumPTMIdentificationRecord {
  my $METHOD = 'insertSpectrumPTMIdentificationRecord';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $spectrum_identification_id = $args{spectrum_identification_id}
    or die("ERROR[$METHOD]: Parameter spectrum_identification_id not passed");
  my $ptm_sequence = $args{ptm_sequence}
    or die("ERROR[$METHOD]: Parameter ptm_sequence not passed");

  #### Define the attributes to insert
  my %rowdata = (
    ptm_sequence => $ptm_sequence,
    spectrum_identification_id => $spectrum_identification_id,
  );

  #### Insert spectrum PTM identification record
  my $spectrum_ptm_identification_id = $sbeams->updateOrInsertRow(
    insert=>1,
    table_name=>$TBAT_SPECTRUM_PTM_IDENTIFICATION,
    rowdata_ref=>\%rowdata,
    PK => 'spectrum_ptm_identification_id',
    return_PK => 1,
    verbose=>$VERBOSE,
    testonly=>$TESTONLY,
  );

  return($spectrum_ptm_identification_id);

} # end insertSpectrumPTMIdentificationRecord



###############################################################################
# loadSpectrum_Fragmentation_Type -- Loads all Spectrum_Fragmentation_Type for specified build
###############################################################################
sub loadSpectrum_Fragmentation_Type {
  my $METHOD = 'loadBuildSpectra';
  my $self = shift || die ("self not passed");
  my %args = @_;

  #### Process parameters
  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");

  my $sql = qq~
		SELECT SP.SPECTRUM_ID,
           SP.SPECTRUM_NAME, 
           ASB.DATA_LOCATION, 
           ASB.SEARCH_BATCH_SUBDIR, 
           IT.INSTRUMENT_TYPE_NAME
		FROM $TBAT_SPECTRUM SP
		JOIN $TBAT_ATLAS_SEARCH_BATCH ASB ON (SP.SAMPLE_ID = ASB.SAMPLE_ID)
		JOIN $TBAT_ATLAS_BUILD_SEARCH_BATCH ABSB ON (ABSB.ATLAS_SEARCH_BATCH_ID  = ASB.ATLAS_SEARCH_BATCH_ID )
		JOIN $TBAT_SAMPLE  S ON (ABSB.SAMPLE_ID = S.SAMPLE_ID)
		JOIN $TBPR_INSTRUMENT I ON (I.INSTRUMENT_ID = S.INSTRUMENT_MODEL_ID)
		JOIN $TBPR_INSTRUMENT_TYPE IT ON (I.INSTRUMENT_TYPE_ID = IT.INSTRUMENT_TYPE_ID)
		WHERE ABSB.ATLAS_BUILD_ID = $atlas_build_id 
		AND SP.FRAGMENTATION_TYPE_ID IS NULL 
		ORDER BY SP.SPECTRUM_NAME, DATA_LOCATION
  ~;

  print "Loading SPECTRUM_ID ";
  my @rows = $sbeams->selectSeveralColumns($sql);
  print scalar @rows ." loaded\n";
  my %spectrum=();
  my %fragmentation_type=();
  my $pre_file='';
  my $cnt = 0;
  my $cnt_update = 0;

  foreach my $row (@rows){
    my ($spectrum_id, $spectrum_name,$data_location,$subdir, $instrument_type_name)= @$row;
    $spectrum_name=~ /^(.*)\.(\d+)\.(\d+)\.\d+$/;
    my $filename = $1;
    my $scan = $2;
    $scan =~ s/^0+//g;

    my $file ="/regis/sbeams/archive/$data_location/$subdir/$filename.mzML";
    chomp $file;
    if(! -e $file){
      $file ="/regis/sbeams/archive/$data_location/$subdir/$filename.mzXML";
      if(! -e $file){
        $file ="/regis/sbeams/archive/$data_location/$subdir/$filename.mzML.gz";
        if(! -e $file){
           $file ="/regis/sbeams/archive/$data_location/$subdir/$filename.mzXML.gz";
        }else{
          die "cannot found mzXML/mzML file: /regis/sbeams/archive/$data_location/$subdir/$filename\n";
        }
      }
    }

    my $type = 0;
    ## decide type 4 
    if ($instrument_type_name  =~ /tof/i){$type= 4;};
    ## if not type 4, read file
    if ($pre_file ne $file && ! $type ){ 
      %fragmentation_type = ();
      print "$file\n";
      get_fragmentation_type( file => $file,
                            fragmentation_type => \%fragmentation_type);
      print scalar keys %fragmentation_type , "\n";
      if(scalar keys %fragmentation_type == 0){
        print "no update: $file\n";
      }
    }
    $pre_file = $file;
    if( $type == 4 || defined $fragmentation_type{$scan}){ 
      if(defined $fragmentation_type{$scan}){
        $type = $fragmentation_type{$scan};
      }
			my %rowdata = (
				 fragmentation_type_id => $type,
			);
			my $response = $sbeams->updateOrInsertRow(
				 update=>1,
				 table_name=>$TBAT_SPECTRUM,
				 rowdata_ref=>\%rowdata,
				 PK => 'spectrum_id',
				 PK_value=> $spectrum_id,
				 return_PK => 1,
				 verbose=>$VERBOSE,
				 testonly=> $TESTONLY
			);
			if($cnt_update % 1000 == 0){
				print "$cnt_update...";
			}
			$cnt_update++;
    }
    $cnt++;
  }  
  print "\n$cnt_update of $cnt updated\n";
}

sub get_fragmentation_type {
  my %args = @_;
  my $file = $args{file};
  my $fragmentation_type = $args{fragmentation_type};
  my $fh;
  if($file =~ /.gz$/){
   	open ($fh, "zcat $file|") or die "cannot open $file\n";
  }else{
    open ($fh, "<$file");
  }
	my %filterstr = ();
  my %instrumentConfiguration =();
	##  1 HR IT CID  (FTICR or Orbitrap)
	##  2 HR IT ETD (FTICR or Orbitrap)
	##  3 HR IT HCD (FTICR or Orbitrap)
	##  4 HR Q-TOF  (Agilent Q-TOF or AB SCIEX 5600 or QSTAR)
	##  5 LR IT CID (QTRAP 4000, 5500, LTQ, LCQ, Equire, etc.)
	##  6 LR IT ETD (LTQ)
  my ($insconf,$insconfid);
	while (my $line = <$fh>){
    ## below parsing needs to be refined, cause I am not sure if some tags will be missing or have differt names.
		if($line =~ /<instrumentConfigurationList/){  # mzML
			while ($line !~ /<\/instrumentConfigurationList/){
				$line = <$fh>;
				if($line =~ /instrumentConfiguration id="([^"]+)"/){
					$insconf = $1;
				}elsif($line =~ /<analyzer/){
					$line = <$fh>;
					if ($line =~ /.*name="([^"]+)"/){
						$instrumentConfiguration{$insconf} = $1;
						$insconf = '';
					}
				}
			}
      next;
    }
    if($line =~ /<msInstrument id="([^"]+)/){ #mzXML
      $insconfid = $1;
      while ($line !~ /<scan/){
        $line = <$fh>;
        if($line =~ /.*category="msMassAnalyzer" value="([^"]+)"/){
          $instrumentConfiguration{$insconfid} = $1;
        }
        $insconf = '';
      }
      next;
    }elsif($line =~ /<msInstrument>/){
       $insconfid = 'all';
       while ($line !~ /<\/msInstrument/){
        $line = <$fh>;
        if($line =~ /.*category="msMassAnalyzer" value="([^"]+)"/){
          $instrumentConfiguration{$insconfid} = $1;
        }
        $insconf = '';
      }
      next;
    }

		if($line =~ /<spectrum index="(\d+)".*/){ ## mzML 
	    my ($ms1,$scan, $insconf, $insid,$analyzer, $activation);
			$scan = $1 + 1;
      while ($line !~/<\/spectrum/){
        $line = <$fh>;
        if($line =~ /ms level" value="1"/){
          last;
        }
				if($line =~ /name="filter string" value="(.*)"/){
					my $str = $1;
					my $type = '';
					if($str =~ /FTMS.*\@cid/){
						$type = 1;
					}elsif($str =~ /FTMS.*\@etd/){
						$type = 2;
					}elsif($str =~ /ITMS.*\@etd/){
						$type = 6;
					}elsif($str =~ /ITMS.*\@cid/){
						$type = 5;
					}elsif($str =~ /FTMS.*\@hcd/){
						$type = 3;
					}
					$fragmentation_type->{$scan} = $type;
				}elsif($line =~ /scan instrumentConfigurationRef="([^"]+)"/){
					$insid = $1;
				}elsif($line =~ /<activation>/ && not defined $fragmentation_type ->{$scan} ){
           if( $insid eq ''){
             if (scalar keys %instrumentConfiguration == 1){
               my @insids = keys %instrumentConfiguration;
               $insid = $insids[0];
             }
           }
 					 while ($line !~ /dissociation/ && $line !~ /binaryDataArrayList/){
						 $line = <$fh>;
					 }
					 $line =~ /name="([^"]+)"/;
           $activation = $1;
           if ($insid && $activation){
             $analyzer = $instrumentConfiguration{$insid};
             $fragmentation_type->{$scan} = get_type_id($analyzer, $activation);
             #print "$analyzer,$activation, ". $fragmentation_type ->{$scan} ."\n";
           }
        }
      }
    }elsif($line =~ /<scan num="(\d+)"/){## mzXML
	    my ($ms1,$scan, $insconf, $insid,$analyzer, $activation);
      $scan = $1;
      while ($line !~/<\/scan/){
        $line = <$fh>;
        if($line =~ /msLevel="1"/){
          last;
        }
          
        if($line =~ /filterLine="(.*)"/){
          my $str = $1;
          my $type = '';
          if($str =~ /FTMS.*\@cid/){
            $type = 1;
          }elsif($str =~ /FTMS.*\@etd/){
            $type = 2;
          }elsif($str =~ /ITMS.*\@etd/){
            $type = 6;
          }elsif($str =~ /ITMS.*\@cid/){
            $type = 5;
          }elsif($str =~ /FTMS.*\@hcd/){
            $type = 3;
          }
          $fragmentation_type->{$scan} = $type;
        }elsif($line =~ /msInstrumentID="([^"]+)"/){
           $insid = $1;
        }elsif($line =~ /activationMethod="(\w+)"/){
           $activation = $1;
        }elsif($line =~ /<peak/ && not defined $fragmentation_type ->{$scan}){
          if($insid eq ''){
            $insid = 'all';
          }
          if(! $activation){
            $activation = 'CID';
          }
          #print "$insid, $instrumentConfiguration{$insid} , $activation\n";
          if(defined $instrumentConfiguration{$insid}){
						$analyzer = $instrumentConfiguration{$insid};
						$fragmentation_type->{$scan} = get_type_id($analyzer, $activation);
          }
        }
      }
    }
  }
  close $fh;

}

sub get_type_id{
  my $analyzer = shift;
  my $activation = shift;
  my $type = '';

 if($activation =~ /(electron transfer|ETD)/i){
	 if ($analyzer !~ /(orbi|FT|fourier)/i && $analyzer !~ /tof/i ){
		 $type = 6;
	 }elsif($analyzer =~ /tof/i){
			$type = 4; 
	 }else{
		 $type = 2;
	 }
 }elsif ($activation =~ /(collision.induced|CID)/i){
	 if ($analyzer !~ /(orbi|FT|fourier)/i ){
		 $type = 5;
	 }elsif($analyzer =~ /tof/i){
			$type = 4;
	 }else{
		 $type = 1;
	 }
 }elsif($activation =~ /(high.energy collision.induced|HCD)/i){
	 $type = 3;
 }
  return $type;
}
###############################################################################
=head1 BUGS

Please send bug reports to SBEAMS-devel@lists.sourceforge.net

=head1 AUTHOR

Eric W. Deutsch (edeutsch@systemsbiology.org)

=head1 SEE ALSO

perl(1).

=cut
###############################################################################
1;

__END__
###############################################################################
###############################################################################
###############################################################################
