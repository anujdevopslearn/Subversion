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
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
require Exporter;
@ISA = qw();
$VERSION = q[$Id$];
@EXPORT_OK = qw();

use SBEAMS::Connection;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::Settings;
use SBEAMS::PeptideAtlas::Tables;


###############################################################################
# Global variables
###############################################################################
use vars qw($VERBOSE $TESTONLY $sbeams);


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


  #### Find and open the input peplist file
  my $peplist_file = "$atlas_build_directory/".
    "APD_${organism_abbrev}_all.peplist";
  unless (-e $peplist_file) {
    print "ERROR: Unable to find peplist file '$peplist_file'\n";
    return;
  }
  unless (open(INFILE,$peplist_file)) {
    print "ERROR: Unable to open for read peplist file '$peplist_file'\n";
    return;
  }


  #### Read and verify header
  my $header = <INFILE>;
  unless ($header && substr($header,0,10) eq 'search_bat' &&
	  length($header) == 155) {
    print "len = ".length($header)."\n";
    print "ERROR: Unrecognized header in peplist file '$peplist_file'\n";
    close(INFILE);
    return;
  }


  #### Loop through all spectrum identifications and load
  while (my $line = <INFILE>) {
    my @columns = split(/\t/,$line);
    #print "cols = ".scalar(@columns)."\n";
    unless (scalar(@columns) == 17) {
      die("ERROR: Unexpected number of columns in\n$line");
    }
    my ($search_batch_id,$peptide_sequence,$modified_sequence,$charge,
        $probability,$protein_name,$spectrum_name) = @columns;

    $self->insertSpectrumIdentification(
       atlas_build_id => $atlas_build_id,
       search_batch_id => $search_batch_id,
       modified_sequence => $modified_sequence,
       charge => $charge,
       probability => $probability,
       protein_name => $protein_name,
       spectrum_name => $spectrum_name,
    );

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
  my $charge = $args{charge}
    or die("ERROR[$METHOD]: Parameter charge not passed");
  my $probability = $args{probability}
    or die("ERROR[$METHOD]: Parameter probability not passed");
  my $protein_name = $args{protein_name}
    or die("ERROR[$METHOD]: Parameter protein_name not passed");
  my $spectrum_name = $args{spectrum_name}
    or die("ERROR[$METHOD]: Parameter spectrum_name not passed");


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
  );


  #### If not, INSERT it
  unless ($spectrum_identification_id) {
    $spectrum_identification_id = $self->insertSpectrumIdentificationRecord(
      modified_peptide_instance_id => $modified_peptide_instance_id,
      spectrum_id => $spectrum_id,
      atlas_search_batch_id => $atlas_search_batch_id,
      probability => $probability,
    );
  }

  print ".";

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
    my @rows = $sbeams->selectSeveralColumns($sql);

    #### Loop through all rows and store in hash
    foreach my $row (@rows) {
      my $modified_peptide_instance_id = $row->[0];
      my $key = $row->[1].'/'.$row->[2];
      $modified_peptide_instance_ids{$key} = $modified_peptide_instance_id;
    }
    print "       ".scalar(@rows)." loaded...\n";
  }


  #### Lookup and return modified_peptide_instance_id
  my $key = "$modified_sequence/$charge";
  if ($modified_peptide_instance_ids{$key}) {
    return($modified_peptide_instance_ids{$key});
  };

  die("ERROR: Unable to find '$key' in modified_peptide_instance_ids hash. ".
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
  unless (%spectrum_ids) {
    print "[INFO] Loading all spectrum_ids...\n";
    my $sql = qq~
      SELECT sample_id,spectrum_name,spectrum_id
        FROM $TBAT_SPECTRUM
    ~;
    my @rows = $sbeams->selectSeveralColumns($sql);

    #### Create a hash out of it
    foreach my $row (@rows) {
      my $key = "$row->[0] - $row->[1]";
      $spectrum_ids{$key} = $row->[2];
    }

    print "       ".scalar(keys(%spectrum_ids))." loaded...\n";

    #### Put a dummy entry in the hash so load won't trigger twice if
    #### table is empty at this point
    $spectrum_ids{DUMMY} = -1;

    #### Print out a few entries
    #my $i=0;
    #while (my ($key,$value) = each(%spectrum_ids)) {
    #  print "  spectrum_ids: $key = $value\n";
    #  last if ($i > 5);
    #  $i++;
    #}

  }


  #### Lookup and return spectrum_id
  my $key = "$sample_id - $spectrum_name";
  #print "key = $key  spectrum_ids{key} = $spectrum_ids{$key}\n";
  if ($spectrum_ids{$key}) {
    return($spectrum_ids{$key});
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
  } else {
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


  #### Get the data_location of the spectrum
  my $data_location = $self->get_data_location(
    proteomics_search_batch_id => $proteomics_search_batch_id,
  );
  unless ($data_location =~ /^\//) {
    $data_location = $RAW_DATA_DIR{Proteomics}."/$data_location";
  }

  #### Sometimes a data_location will be a specific xml file
  if ($data_location =~ /^(.+)\/interac.+xml$/i) {
    $data_location = $1;
  }
  #print "data_location = $data_location\n";

  my $tgz_filename = "$data_location/$fraction_tag.tgz";
  my $filename = "/bin/tar -xzOf $tgz_filename ./$spectrum_name.dta|";
  #print "Pulling from tarfile: $tgz_filename<BR>\n";
  #print "Extracting: $filename<BR>\n";

  unless (open(DTAFILE,$filename)) {
    print "Cannot open file $filename!!<BR>\n";
  }

  #### Read in but ignore header line
  my $headerline = <DTAFILE>;

  my @mz_intensities;
  while (my $line = <DTAFILE>) {
    chomp($line);
    my @values = split(/\s+/,$line);
    push(@mz_intensities,\@values);
  }
  close(DTAFILE);
  print "   ".scalar(@mz_intensities)." mass-inten pairs loaded\n"
    if ($VERBOSE);

  return(@mz_intensities);

} # end getSpectrumPeaks



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

  #### If we haven't loaded all spectrum_identification_ids into the
  #### cache yet, do so
  our %spectrum_identification_ids;
  unless (%spectrum_identification_ids) {
    print "[INFO] Loading all spectrum_identification_ids...\n";
    my $sql = qq~
      SELECT modified_peptide_instance_id,spectrum_id,atlas_search_batch_id,spectrum_identification_id
        FROM $TBAT_SPECTRUM_IDENTIFICATION
    ~;
    my @rows = $sbeams->selectSeveralColumns($sql);

    #### Create a hash out of it
    foreach my $row (@rows) {
      my $key = "$row->[0] - $row->[1] - $row->[2]";
      $spectrum_identification_ids{$key} = $row->[3];
    }

    print "       ".scalar(keys(%spectrum_identification_ids))." loaded...\n";

    #### Put a dummy entry in the hash so load won't trigger twice if
    #### table is empty at this point
    $spectrum_identification_ids{DUMMY} = -1;
  }


  #### Lookup and return spectrum_id
  my $key = "$modified_peptide_instance_id - $spectrum_id - $atlas_search_batch_id";
  if ($spectrum_identification_ids{$key}) {
    return($spectrum_identification_ids{$key});
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
  my $probability = $args{probability}
    or die("ERROR[$METHOD]: Parameter probability not passed");


  #### Define the attributes to insert
  my %rowdata = (
    modified_peptide_instance_id => $modified_peptide_instance_id,
    spectrum_id => $spectrum_id,
    atlas_search_batch_id => $atlas_search_batch_id,
    probability => $probability,
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
