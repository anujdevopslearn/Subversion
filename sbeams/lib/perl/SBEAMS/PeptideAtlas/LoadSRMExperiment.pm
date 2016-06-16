package SBEAMS::PeptideAtlas::LoadSRMExperiment;

###############################################################################
# Class       : SBEAMS::PeptideAtlas::LoadSRMExperiment
# Author      : Terry Farrah # <tfarrah@systemsbiology.org>
#
=head1 SBEAMS::PeptideAtlas::LoadSRMExperiment

=head2 SYNOPSIS

  SBEAMS::PeptideAtlas::LoadSRMExperiment

=head2 DESCRIPTION

This is part of SBEAMS::PeptideAtlas which handles the loading of SRM
experiment data.

=cut
#
###############################################################################

use strict;
$|++;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
require Exporter;
@ISA = qw();
$VERSION = q[$Id$];
@EXPORT_OK = qw();

use POSIX;
use List::Util qw[min max];

use SBEAMS::Connection qw($log);
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::Settings;
use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::PeptideAtlas::Annotations;
use SBEAMS::PeptideAtlas::ProtInfo;
use SBEAMS::Proteomics::PeptideMassCalculator;

my $sbeams = SBEAMS::Connection->new();
my $sbeamsMOD = SBEAMS::PeptideAtlas->new();

###############################################################################
# Constructor -- copied from AtlasBuild.pm
###############################################################################
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    $sbeams = $self->getSBEAMS();
    return($self);
} # end new


###############################################################################
# getSBEAMS: Provide the main SBEAMS object
#   Copied from AtlasBuild.pm
###############################################################################
sub getSBEAMS {
    my $self = shift;
    return $sbeams || SBEAMS::Connection->new();
} # end getSBEAMS



###############################################################################
# collect_tx_from_spectrum_file
#   Get all precusor/fragment m/z pairs from a spectrum file.
#   These are all the possible transitions that were measured.
#   These m/z values are typically rounded.
#  04/25/12: Olga points out a bug here; see below.
###############################################################################

sub collect_tx_from_spectrum_file {
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $spectrum_filepath = $args{spectrum_filepath};
  my %tx_measured;
  my $VERBOSE = $args{'verbose'} || 0;
  my $QUIET = $args{'quiet'} || 0;
  my $TESTONLY = $args{'testonly'} || 0;
  my $DEBUG = $args{'debug'} || 0;

  open (SPECFILE, $spectrum_filepath) || die "Can't open $spectrum_filepath";

  my $precursor = '';
  my $product = '';
  my @products;
  if ($spectrum_filepath =~ /\.mzML$/i) {
    my $in_precursor = 0;
    my $in_product = 0;
    while (my $line = <SPECFILE>) {
      chomp $line;
      $in_precursor = 1 if ($line =~ /<precursor>/);
      if ( $in_precursor && 
	   ( $line =~ /<cvParam .* name="isolation window target m.z"\s+value="(\S+?)"/)) {
	$precursor = $1;
      }
      $in_precursor = 0 if ($line =~ /<\/precursor>/);
      $in_product = 1 if ($line =~ /<product>/);
      if ( $in_product && 
	   ( $line =~ /<cvParam .* name="isolation window target m.z"\s+value="(\S+?)"/)) {
        $product = $1;
	$tx_measured{$precursor}->{$product} = 1;
      }
      $in_precursor = 0 if ($line =~ /<\/precursor>/);
    }
  } elsif ($spectrum_filepath =~ /\.mzXML$/i) {
    while (my $line = <SPECFILE>) {
      ### 04/24/12: According to Olga's bioinformaticist,
      ###   basePeakMz gives the most intense ion at this point.
      ### Perhaps all product ions are measured in each <scan>
      ###   and I should get them from between the brackets in this line:
      #   filterLine="+ c NSI SRM ms2 574.819 [373.218-373.220, 502.261-502.263, 665.324-665.326, 778.408-778.410, 835.430-835.432, 922.462-922.464]"
      ### 04/26/12: ... but Simon's data doesn't have that, so I
      ###  will keep the old method around for his data, even though
      ###  I'm not certain it's correct!

      if ($line =~ /filterLine=.+\[(.*)\]/) {
        my $product_string = $1;
	my @mz_windows = split(", " , $product_string);
	for my $mz_window (@mz_windows) {
	  my ($low, $high) = split("-", $mz_window);
	  my $mz = ($low + $high) / 2;
	  push (@products, $mz);
	}
      }
      if ($line =~ /basePeakMz=\"(\S+)\"/) {
	my $mz = $1;
	push (@products, $mz);
      }
      if ($line =~ /<precursorMz.*>(\S+)<.precursorMz>/) {
	$precursor = $1;
      }
      if ($line =~ /<\/scan>/) {
	for my $product (@products) {
	  $tx_measured{$precursor}->{$product} = 1;
	}
	@products = ();  #clear/reset
      }
    }
    print "Measured Q1 (found in spectrum file):\n" if $VERBOSE > 2;
  } else {
     die "collect_tx_from_spectrum_file: $spectrum_filepath neither .mzXML nor .mzML";
  }

  if ($VERBOSE > 2) {
    print "Transitions measured:\n";
    my @q1s = sort {$a <=> $b} keys %tx_measured;
    for my $q1 (@q1s) {
      my @q3s = sort {$a <=> $b} keys %{$tx_measured{$q1}};
      for my $q3 (@q3s) {
	printf "  %s  %s\n", $q1, $q3;
      }
    }
  }

  return \%tx_measured;
}


###############################################################################
# collect_q1s_from_spectrum_file (deprecated)
#   Get all precusor m/z values from a spectrum file.
#   These are all the possible Q1 values that were measured.
###############################################################################

sub collect_q1s_from_spectrum_file {
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $spectrum_filepath = $args{spectrum_filepath};
  my %q1_measured;
  my $VERBOSE = $args{'verbose'} || 0;
  my $QUIET = $args{'quiet'} || 0;
  my $TESTONLY = $args{'testonly'} || 0;
  my $DEBUG = $args{'debug'} || 0;

  open (SPECFILE, $spectrum_filepath) || die "Can't open $spectrum_filepath";

  if ($spectrum_filepath =~ /\.mzML$/i) {
    my $in_precursor = 0;
    while (my $line = <SPECFILE>) {
      chomp $line;
      $in_precursor = 1 if ($line =~ /<precursor>/);
      if ( $in_precursor && 
	   ( $line =~ /<cvParam .* name="isolation window target m.z"\s+value="(\S+?)"/)) {
	$q1_measured{$1} = 1;
      }
      $in_precursor = 0 if ($line =~ /<\/precursor>/);
    }
  } elsif ($spectrum_filepath =~ /\.mzXML$/i) {
    while (my $line = <SPECFILE>) {
      if ($line =~ /<precursorMz.*>(\S+)<.precursorMz>/) {
	$q1_measured{$1} = 1;
      }
    }
    print "Measured Q1 (found in spectrum file):\n" if $VERBOSE > 2;
  } else {
     die "collect_q1s_from_spectrum_file: $spectrum_filepath neither .mzXML nor .mzML";
  }
  my @q1_measured = sort keys %q1_measured;
  for my $q1 (@q1_measured) {
    print "  $q1\n" if $VERBOSE > 2;
  }
  return \@q1_measured;
}


###############################################################################
# get_spec_file_basename_and_extension
###############################################################################

sub get_spec_file_basename_and_extension {
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $SEL_run_id = $args{'SEL_run_id'};

  my $sql = qq~
    SELECT spectrum_filename FROM $TBAT_SEL_RUN SELR
    WHERE SELR.SEL_run_id = $SEL_run_id
    AND SELR.record_status != 'D';
  ~;
  my ($specfile) = $sbeams->selectOneColumn($sql);
  if (! $specfile ) {
    return 0;
  }

  $specfile =~ /^(.*)\.(mzX?ML)$/;
  my $spec_file_basename = $1;
  my $extension = $2;
  if (! $spec_file_basename) {
    die "get_spec_file_basename_and_extension: $specfile: must be .mzML or .mzXML";
  }
  return $spec_file_basename, $extension;
}

###############################################################################
# get_SEL_run_id
###############################################################################

sub get_SEL_run_id {
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $spec_file_basename = $args{spec_file_basename};

  $spec_file_basename =~ s/_/[_]/g;

  my $sql = qq~
    SELECT SEL_run_id FROM $TBAT_SEL_RUN SELR
   WHERE SELR.spectrum_filename LIKE '$spec_file_basename.%'
   AND SELR.record_status != 'D' 
  ~;
  my @run_ids = $sbeams->selectOneColumn($sql);
  my $n_run_ids = scalar @run_ids;
  if (! $n_run_ids) {
    die "No entry in SEL_run matches spectrum file basename ${spec_file_basename}";
  } elsif ($n_run_ids > 1) {
    die "More than one SEL_run record matches ${spec_file_basename}";
  }

  my $SEL_run_id = shift @run_ids;
  return $SEL_run_id;
}

###############################################################################
# get_SEL_experiment_id
###############################################################################

sub get_SEL_experiment_id {
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $SEL_run_id = $args{SEL_run_id};

  my $sql = qq~
    SELECT SEL_experiment_id FROM $TBAT_SEL_RUN SELR
   WHERE SELR.SEL_run_id = $SEL_run_id;
  ~;
  my @experiment_ids = $sbeams->selectOneColumn($sql);
  my $n_experiment_ids = scalar @experiment_ids;
  if (! $n_experiment_ids) {
    die "PASSEL run # $SEL_run_id has no SEL_experiment_id.";
  }

  my $SEL_experiment_id = shift @experiment_ids;
  return $SEL_experiment_id;
}

###############################################################################
# read_mquest_peakgroup_file
###############################################################################

sub read_mquest_peakgroup_file {
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $mquest_file  = $args{mquest_file};
  my $mpro_href  = $args{mpro_href};
  my $spec_file_basename = $args{spec_file_basename};
  my $special_expt = $args{special_expt};
  my $VERBOSE = $args{'verbose'} || 0;
  my $QUIET = $args{'quiet'} || 0;
  my $TESTONLY = $args{'testonly'} || 0;
  my $DEBUG = $args{'debug'} || 0;

  # First, set up a universal lookup table of possible header strings
  # We store it this way because it's easy to read and maintain.
  my %possible_headers = (
                      file_name => [ qw( file_name ) ],
                target_group_id => [ qw( target_group_id ) ],
        transition_group_pepseq => [ qw( transition_group_pepseq ) ],
        transition_group_charge => [ qw( transition_group_charge ) ],
                          decoy => [ qw( decoy is_decoy) ],
		     pg_prerank => [ qw( pg_prerank ) ],
             max_apex_intensity => [ qw( max_apex_intensity ) ],
      light_heavy_ratio_maxapex => [ qw( light_heavy_ratio_maxapex light_heavy_ratio ) ],
	       collision_energy => [ qw( collision_energy ) ],
	        number_of_peaks => [ qw( number_of_peaks ) ],
	  relative_pg_intensity => [ qw( relative_pg_intensity ) ],
     weighted_xcoor_shape_score => [ qw( weighted_xcoor_shape_score ) ],
       pre_discrimination_score => [ qw( pre_discrimination_score ) ],
	        target_prescore => [ qw( target_prescore ) ],
	     reference_prescore => [ qw( reference_prescore ) ],
	        log10_total_xic => [ qw( log10_total_xic ) ],
	         	    S_N => [ qw( s_n ) ],
	         	     Tr => [ qw( tr ) ],
  );

  # Now reverse the direction of the hash to make it easier to use.
  my %header_lookup;
  for my $header (keys %possible_headers) {
    for my $s (@{$possible_headers{$header}}) {
      $header_lookup{$s} = $header;
      print "header_lookup for $s is $header\n" if ($DEBUG);
    }
  }

  # Finally, associate each header string with its position in this particular
  # transition file.
  open (MQUEST_FILE, $mquest_file) || die "Can't open $mquest_file for reading.";
  my $line = <MQUEST_FILE>;
  chomp $line;
  my @fields = split('\t', $line);
  my %idx;

  my $i = 0;
  for my $field (@fields) {
    my $header;

    # if this header is recognized ...
    if ($header = $header_lookup{ lc $field }) {
      $idx{$header} = $i;
      print "idx for $header is $i\n" if ($DEBUG);
    }
    $i++;
  }

  ### Read and store each line of mQuest file, except for dummy peakgroups.
  print "Processing mQuest file $mquest_file!\n" if ($VERBOSE);

  my $spectrum_file;
  while ($line = <MQUEST_FILE>) {
    chomp $line;
    @fields = split('\t', $line);

    # Get info that will allow us to identify the transition group.
    my $is_dummy = ($fields[$idx{target_group_id}] =~ /dummy/) || 0;
    next if ($is_dummy);
    my $spectrum_file_basename = $fields[$idx{file_name}];
    my $pepseq = $fields[$idx{transition_group_pepseq}];
    my $charge = $fields[$idx{transition_group_charge}];
    my $decoy = $fields[$idx{decoy}] || 0;
    # Hack to see if this is a heavy-labelled TG
    # 11/17/11: learned today that light & heavy combine in same TG
    #   Store info under 'light' always.
    # 04/26/12: sometimes we only have heavy. Let's store under both.
    #my $isotype =  $line =~ /heavy/i ? 'heavy' : 'light';
    #my $isotype = 'light';
    my $isotype;

    # If somehow no peak_group ranking is specified, set to 1.
    # This means that the last peak_group in the file will clobber all the
    # others. But if there is no ranking, we are working with some kind
    # of older, handcrafted, or broken file, anyway.
    my $peak_group = $fields[$idx{pg_prerank}] || 1;

    # Get the info that we want to store for this transition group
    my $max_apex_intensity = $fields[$idx{ max_apex_intensity }];
    my $log10_max_apex_intensity = $max_apex_intensity ?
         log10($max_apex_intensity) : 0;
    my $light_heavy_ratio_maxapex = $fields[$idx{ light_heavy_ratio_maxapex }];
    my $collision_energy = $fields[$idx{ collision_energy }];
    my $number_of_peaks = $fields[$idx{ number_of_peaks }];
    my $relative_pg_intensity = $fields[$idx{ relative_pg_intensity }];
    my $weighted_xcoor_shape_score = $fields[$idx{ weighted_xcoor_shape_score }];
    my $pre_discrimination_score = $fields[$idx{ pre_discrimination_score }];
    my $target_prescore = $fields[$idx{ target_prescore }];
    my $reference_prescore = $fields[$idx{ reference_prescore }];
    my $log10_total_xic = $fields[$idx{ log10_total_xic }];
    my $S_N = $fields[$idx{ S_N }];
    my $Tr = $fields[$idx{ Tr }];

    # Store info in hash according to transition group.
    if ($spectrum_file_basename && $pepseq ) {
      my @chargelist;
      if ($charge) {
	@chargelist = ($charge);
      } else {
        @chargelist = (1, 2, 3);
      }

      my @isotypes;
      if ($isotype) {               #this is always false; $isotype has no value yet.
	@isotypes = ($isotype);
      } else {
        @isotypes = ( 'light', 'heavy' );
      }

      for my $charge (@chargelist) {
	for my $isotype (@isotypes) {
	  my $mpro_pg_href =
	  $mpro_href->{$spectrum_file_basename}->{$pepseq}->{$charge}->{$isotype}->{$decoy}->{$peak_group};
	  $mpro_href->{$spectrum_file_basename}->{$pepseq}->{$charge}->{$isotype}->{$decoy}->{$peak_group}->{log10_max_apex_intensity} = $log10_max_apex_intensity;
	  $mpro_href->{$spectrum_file_basename}->{$pepseq}->{$charge}->{$isotype}->{$decoy}->{$peak_group}->{light_heavy_ratio_maxapex} = $light_heavy_ratio_maxapex;
	  $mpro_href->{$spectrum_file_basename}->{$pepseq}->{$charge}->{$isotype}->{$decoy}->{$peak_group}->{collision_energy} = $collision_energy;
	  $mpro_href->{$spectrum_file_basename}->{$pepseq}->{$charge}->{$isotype}->{$decoy}->{$peak_group}->{number_of_peaks} = $number_of_peaks;
	  $mpro_href->{$spectrum_file_basename}->{$pepseq}->{$charge}->{$isotype}->{$decoy}->{$peak_group}->{relative_pg_intensity} = $relative_pg_intensity;
	  $mpro_href->{$spectrum_file_basename}->{$pepseq}->{$charge}->{$isotype}->{$decoy}->{$peak_group}->{weighted_xcoor_shape_score} = $weighted_xcoor_shape_score;
	  $mpro_href->{$spectrum_file_basename}->{$pepseq}->{$charge}->{$isotype}->{$decoy}->{$peak_group}->{pre_discrimination_score} = $pre_discrimination_score;
	  $mpro_href->{$spectrum_file_basename}->{$pepseq}->{$charge}->{$isotype}->{$decoy}->{$peak_group}->{target_prescore} = $target_prescore;
	  $mpro_href->{$spectrum_file_basename}->{$pepseq}->{$charge}->{$isotype}->{$decoy}->{$peak_group}->{reference_prescore} = $reference_prescore;
	  $mpro_href->{$spectrum_file_basename}->{$pepseq}->{$charge}->{$isotype}->{$decoy}->{$peak_group}->{log10_total_xic} = $log10_total_xic;
	  $mpro_href->{$spectrum_file_basename}->{$pepseq}->{$charge}->{$isotype}->{$decoy}->{$peak_group}->{S_N} = $S_N;
	  $mpro_href->{$spectrum_file_basename}->{$pepseq}->{$charge}->{$isotype}->{$decoy}->{$peak_group}->{Tr} = $Tr;

	  print 'Storing $mpro_href->{',$spectrum_file_basename,'}->{',$pepseq,'}->{',$charge,'}->{',$isotype,'}->{',$decoy,'}->{',$peak_group,'}->{S_N} = ', $mpro_href->{$spectrum_file_basename}->{$pepseq}->{$charge}->{$isotype}->{$decoy}->{$peak_group}->{S_N}, "\n" if ($VERBOSE > 1);
	  print 'Storing $mpro_href->{',$spectrum_file_basename,'}->{',$pepseq,'}->{',$charge,'}->{',$isotype,'}->{',$decoy,'}->{',$peak_group,'}->{number_of_peaks} = ', $mpro_href->{$spectrum_file_basename}->{$pepseq}->{$charge}->{$isotype}->{$decoy}->{$peak_group}->{number_of_peaks}, "\n" if ($VERBOSE > 1);
	  print 'Storing $mpro_href->{',$spectrum_file_basename,'}->{',$pepseq,'}->{',$charge,'}->{',$isotype,'}->{',$decoy,'}->{',$peak_group,'}->{log10_max_apex_intensity} = ', $mpro_href->{$spectrum_file_basename}->{$pepseq}->{$charge}->{$isotype}->{$decoy}->{$peak_group}->{log10_max_apex_intensity}, "\n" if ($VERBOSE > 1);
	  print 'Storing $mpro_href->{',$spectrum_file_basename,'}->{',$pepseq,'}->{',$charge,'}->{',$isotype,'}->{',$decoy,'}->{',$peak_group,'}->{light_heavy_ratio_maxapex} = ', $mpro_href->{$spectrum_file_basename}->{$pepseq}->{$charge}->{$isotype}->{$decoy}->{$peak_group}->{light_heavy_ratio_maxapex}, "\n" if ($VERBOSE > 1);
	  print 'Storing $mpro_href->{',$spectrum_file_basename,'}->{',$pepseq,'}->{',$charge,'}->{',$isotype,'}->{',$decoy,'}->{',$peak_group,'}->{Tr} = ', $mpro_href->{$spectrum_file_basename}->{$pepseq}->{$charge}->{$isotype}->{$decoy}->{$peak_group}->{Tr}, "\n" if ($VERBOSE > 1);
	}
      }
    } else {
      print "Not storing mQuest scores. file_basename = $spectrum_file_basename pepseq = $pepseq decoy = $decoy peak_group = $peak_group\n" if ($VERBOSE > 1);
    }
  }
}

###############################################################################
# read_mprophet_peakgroup_file
###############################################################################

sub read_mprophet_peakgroup_file {
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $mpro_file  = $args{mpro_file};
  my $mpro_href  = $args{mpro_href};
  my $spec_file_basename = $args{spec_file_basename};
  my $special_expt = $args{special_expt};
  my $VERBOSE = $args{'verbose'} || 0;
  my $QUIET = $args{'quiet'} || 0;
  my $TESTONLY = $args{'testonly'} || 0;
  my $DEBUG = $args{'debug'} || 0;


  # First, set up a universal lookup table of possible header strings
  # We store it this way because it's easy to read and maintain.
  my %possible_headers = (
       log10_max_apex_intensity => [ qw( log10_max_apex_intensity ) ],
             max_apex_intensity => [ qw( max_apex_intensity, var_max_apex_intensity ) ],
      light_heavy_ratio_maxapex => [ qw( light_heavy_ratio_maxapex light_heavy_ratio) ],
                          decoy => [ qw( decoy is_decoy) ],
                         charge => [ qw( transition_group_charge ) ],
                        protein => [ qw( protein ) ],
                  peak_group_id => [ qw( peak_group_id ) ],
                   peakgroup_id => [ qw( peakgroup_id ) ],
	        peak_group_rank => [ qw( peak_group_rank ) ],
                        m_score => [ qw( m_score ) ],
			#mrm_prophet_score is from M-Y's file for Ulli's data
                        d_score => [ qw( d_score mrm_prophet_score ) ],
                      file_name => [ qw( file_name ) ],  # Ruth 2011, Filimonov only
	transition_group_pepseq => [ qw( transition_group_pepseq ) ], #Ruth 2011
        # I think the record below is simply a result of M-Y creating custom file
	# 05/02/12: no. It's also in Ruth's ovarian cancer plasma mPro file.
        transition_group_record => [ qw( transition_group_record ) ], #Ulli
		             Tr => [ qw( tr ) ],  # Ruth 2011 only?
		         run_id => [ qw( run_id ) ],
		            S_N => [ qw( s_n , var_s_n) ],
  );

  # Now reverse the direction of the hash to make it easier to use.
  my %header_lookup;
  for my $header (keys %possible_headers) {
    for my $s (@{$possible_headers{$header}}) {
      $header_lookup{$s} = $header;
      print "header_lookup for $s is $header\n" if ($DEBUG);
    }
  }

  # Finally, associate each header string with its position in this particular
  # transition file.
  open (MPRO_FILE, $mpro_file) || die "Can't open $mpro_file for reading.";
  my $line = <MPRO_FILE>;
  chomp $line;
  my @fields = split('\t', $line);
  my %idx;

  my $i = 0;
  for my $field (@fields) {
    my $header;

    print "$field... " if ($DEBUG);
    # if this header is recognized ...
    if ($header = $header_lookup{ lc $field }) {
      $idx{$header} = $i;
      print "header is $header; idx is $i" if ($DEBUG);
    }
    print "\n" if ($DEBUG);
    $i++;
  }

  ### Read and store each line of mProphet file
  ### NOTE!
  ### The mProphet file for Ruth_prelim contains one line per peakgroup.
  ### The one for Ruth's 2011 data contains only one line per pep, for the top
  ### peakgroup! This code seems to stumble along for both.
  print "Processing mProphet file $mpro_file!\n" if ($VERBOSE);
  my ($decoy, $log10_max_apex_intensity, $light_heavy_ratio_maxapex,
    $protein,  $stripped_pepseq, $modified_pepseq,
    $charge, $peak_group,  $m_score, $d_score, $Tr, $S_N, $isotype);

  $decoy = 0;
  my $mpro_specfile;  #used to get specfile basename
  my $counter = 0;
  while ($line = <MPRO_FILE>) {
    chomp $line;
    @fields = split('\t', $line);
    $log10_max_apex_intensity = (defined $idx{log10_max_apex_intensity}) ?
         $fields[$idx{log10_max_apex_intensity}] :
         defined $idx{max_apex_intensity} ?
	   log10 $fields[$idx{max_apex_intensity}] : 0;
    $light_heavy_ratio_maxapex = (defined $idx{light_heavy_ratio_maxapex}) ?
         $fields[$idx{light_heavy_ratio_maxapex}] : 0 ;
    $protein = (defined $idx{protein}) ? $fields[$idx{protein}] : '' ;
    $Tr = (defined $idx{Tr}) ? $fields[$idx{Tr}] : 0 ;  #retention time for best peak group

    # Hack to see if this is a heavy-labelled TG
    $isotype =  $line =~ /heavy/i ? 'heavy' : 'light';

    if ( ( defined $idx{peak_group_id} ) ||   # ruth_prelim
         ( defined $idx{peakgroup_id} ) ) {    # ruth_2011; Filimonov
      if ( defined $idx{peak_group_id} ) {
	$_ = $fields[$idx{peak_group_id}];
	($mpro_specfile, $modified_pepseq, $charge, $decoy, $peak_group) =
	/(\S+) (\S+?)\.(\S+) (\d) (\d+)/;
      } 
      if ( defined $idx{peakgroup_id} ) {
	$_ = $fields[$idx{peakgroup_id}];
	my $dummy;
	# stripped_pepseq gotten here may include extraneous
	# dot-separated prefix (Jovanovic/Lukas data).
	# For Filimonov Dec2012 data, format has several differences.
	# pg_Q32NC0C5DC.decoy_1_target_dummy0
	($stripped_pepseq, $charge, $decoy, $dummy, $peak_group) =
	 /pg_(\S+?)\.(\d)_(\d)_target_(dummy)?(\d)/;
	$peak_group += 1; #stored with zero indexing
      }
      $decoy = 0 if !$decoy;   #without this, zero value somehow prints as ''
      $modified_pepseq = $fields[$idx{transition_group_pepseq}]
         if (defined $idx{transition_group_pepseq}); #is it really modified?
      # change mods of format [C160] to C[160]
      while ( $modified_pepseq =~ /\[([A-Z])(\d{3})\]/) {
	$modified_pepseq =~ s/\[([A-Z])(\d{3})\]/$1\[$2\]/;
      }
      # best to get stripped pepseq from modseq if it's available
      $stripped_pepseq = 
        SBEAMS::PeptideAtlas::Annotations::strip_mods($modified_pepseq)
	   if (defined $modified_pepseq);
      # best to get mpro_specfile from run_id if available
      my $run_id = (defined $idx{run_id}) ? $fields[$idx{run_id}] : undef ;
      $mpro_specfile = $run_id if ($run_id);
      $S_N = (defined $idx{S_N}) ? $fields[$idx{S_N}] : 0 ; 

    } elsif ( defined $idx{transition_group_record} ) {   #Ulli's data
      $mpro_specfile = "${spec_file_basename}.mzXML";

      # Get the dilution & replicate from the filename. Really only need to do
      # once per subroutine call, but it's easiest to put this here.
      $spec_file_basename =~ /4Q2010030[34]uk_set[12][ab]_ATAQS_(\d+)f_(\d)-s1.mzXML/;
      $spec_file_basename =~ /ATAQS_(\d+)f_(\d)-s1/;
      my ($dilution, $replicate) = ($1, $2);
      #print "$spec_file_basename\n";
      #print "dilution $dilution replicate $replicate\n";

      # See if the suffix of the transition _group_record matches.
      # If not, skip this mProphet record; it's for another spectrum file.
      my $calculated_suffix = $replicate;
      $calculated_suffix += 3 if ($dilution == 40);
      $calculated_suffix += 6 if ($dilution == 8);
      #print "$calculated_suffix\n";
      my $suffix;  # 1-9, maps to 8f/40f/200f and replicates 1/2/3
      $_ = $fields[$idx{transition_group_record}]; 
      ($stripped_pepseq, $suffix) = /^(\S+?)_(\d)$/;
      next if (!$stripped_pepseq);  #empty line
      if ($suffix != $calculated_suffix) {
	print "suffix mismatch $stripped_pepseq $suffix != $calculated_suffix\n" 
	if ($VERBOSE > 2);
	next;
      }
      #print "$stripped_pepseq $suffix\n";
      $modified_pepseq = $stripped_pepseq;
      #print "$modified_pepseq $suffix\n";
    }

    # Get stripped seq from transition_group_pepseq field. For Olga's data, the
    # seq stored here is indeed stripped, but I'm not sure this is generally true.
    if (! defined $stripped_pepseq) {
      $stripped_pepseq = (defined $idx{transition_group_pepseq}) ?
	  $fields[$idx{transition_group_pepseq}] : $modified_pepseq;
    }

    # 05/02/12 Olga's second version of ovarian cancer plasma data uses
    #  'B' for modified cysteines in peakgroup_id and transition_group_record.
    # Since we get our seqs from one of those, fix them here.
    $modified_pepseq =~ s/B/C[160]/g;
    $stripped_pepseq =~ s/B/C/g;

    # These values may already have been gleaned from peakgroup_id,
    # but we will prefer those stored in dedicated columns.
    $charge = (defined $idx{charge}) ? $fields[$idx{charge}] : $charge ;
    # added 11/2012 for Zgoda/Filimonov data. They've modified mPro.
    $mpro_specfile = (defined $idx{file_name}) ?
        $fields[$idx{file_name}] :
	$mpro_specfile ;
    $peak_group = (defined $idx{peak_group_rank}) ?
        $fields[$idx{peak_group_rank}] :
        $peak_group ;
    $peak_group = 1 if (! $peak_group); 
    $decoy = ( defined $idx{decoy} &&
               (( $fields[$idx{decoy}] =~ /(Y|TRUE)/i ) ||
	        ( $fields[$idx{decoy}] == 1)) )
	      ? 1 : $decoy ;

    if ($charge =~ /decoy/) {
      $charge =~ /(\S+)\.decoy/;
      $charge = $1;
    };

    $mpro_specfile =~ /(\S+)\.\S+/;
    my $this_file_basename = defined $1 ? $1 : $mpro_specfile;

    print "$this_file_basename, $stripped_pepseq, $charge, $decoy, $peak_group\n" if ($VERBOSE)>1;
    my ($m_score, $d_score);
    $m_score =  $fields[$idx{m_score}] if (defined $idx{m_score});
    $d_score =  $fields[$idx{d_score}] if (defined $idx{d_score});
    print "  -- m_score = $m_score; d_score = $d_score\n" if ($DEBUG);

    # 06/15/11: removed check for !$decoy from below -- why did I have it?
    if ($this_file_basename && $modified_pepseq && (defined $peak_group)) {
      my @chargelist;
      if ($charge) {
	@chargelist = ($charge);
      } else {
        @chargelist = (1, 2, 3);
      }
      for my $charge (@chargelist) {
	# Don't clobber values that may have been
	# found in mQuest file.
	$mpro_href->{$this_file_basename}->{$modified_pepseq}->{$charge}->{$isotype}->{$decoy}->{$peak_group}->{log10_max_apex_intensity}
	= $log10_max_apex_intensity if $log10_max_apex_intensity;
	$mpro_href->{$this_file_basename}->{$modified_pepseq}->{$charge}->{$isotype}->{$decoy}->{$peak_group}->{light_heavy_ratio_maxapex}
	= $light_heavy_ratio_maxapex if $light_heavy_ratio_maxapex;
	$mpro_href->{$this_file_basename}->{$modified_pepseq}->{$charge}->{$isotype}->{$decoy}->{$peak_group}->{S_N} = $S_N if $S_N;
	$mpro_href->{$this_file_basename}->{$modified_pepseq}->{$charge}->{$isotype}->{$decoy}->{$peak_group}->{Tr} = $Tr if $Tr;

	$mpro_href->{$this_file_basename}->{$modified_pepseq}->{$charge}->{$isotype}->{$decoy}->{$peak_group}->{protein} = $protein; #probably unnecessary
	$mpro_href->{$this_file_basename}->{$modified_pepseq}->{$charge}->{$isotype}->{$decoy}->{$peak_group}->{m_score} = $m_score;
	$mpro_href->{$this_file_basename}->{$modified_pepseq}->{$charge}->{$isotype}->{$decoy}->{$peak_group}->{d_score} = $d_score;
	print
	'$mpro_href->{',$this_file_basename,'}->{',$modified_pepseq,'}->{',$charge,'}->{',$isotype,'}->{',$decoy,'}->{',$peak_group,'}->{m_score} = ',
	$mpro_href->{$this_file_basename}->{$modified_pepseq}->{$charge}->{$isotype}->{$decoy}->{$peak_group}->{m_score}, "\n" if ($VERBOSE > 1);
	print
	'$mpro_href->{',$this_file_basename,'}->{',$modified_pepseq,'}->{',$charge,'}->{',$isotype,'}->{',$decoy,'}->{',$peak_group,'}->{d_score} = ',
	$mpro_href->{$this_file_basename}->{$modified_pepseq}->{$charge}->{$isotype}->{$decoy}->{$peak_group}->{d_score}, "\n" if ($VERBOSE > 1);
	print
	'$mpro_href->{',$this_file_basename,'}->{',$modified_pepseq,'}->{',$charge,'}->{',$isotype,'}->{',$decoy,'}->{',$peak_group,'}->{Tr} = ',
	$mpro_href->{$this_file_basename}->{$modified_pepseq}->{$charge}->{$isotype}->{$decoy}->{$peak_group}->{Tr}, "\n" if ($VERBOSE > 1);
	print
	'$mpro_href->{',$this_file_basename,'}->{',$modified_pepseq,'}->{',$charge,'}->{',$isotype,'}->{',$decoy,'}->{',$peak_group,'}->{S_N} = ',
	$mpro_href->{$this_file_basename}->{$modified_pepseq}->{$charge}->{$isotype}->{$decoy}->{$peak_group}->{S_N}, "\n" if ($VERBOSE > 1);
	print
	'$mpro_href->{',$this_file_basename,'}->{',$modified_pepseq,'}->{',$charge,'}->{',$isotype,'}->{',$decoy,'}->{',$peak_group,'}->{log10_max_apex_intensity} = ',
	$mpro_href->{$this_file_basename}->{$modified_pepseq}->{$charge}->{$isotype}->{$decoy}->{$peak_group}->{log10_max_apex_intensity}, "\n" if ($VERBOSE > 1);
	print
	'$mpro_href->{',$this_file_basename,'}->{',$modified_pepseq,'}->{',$charge,'}->{',$isotype,'}->{',$decoy,'}->{',$peak_group,'}->{light_heavy_ratio_maxapex} = ',
	$mpro_href->{$this_file_basename}->{$modified_pepseq}->{$charge}->{$isotype}->{$decoy}->{$peak_group}->{light_heavy_ratio_maxapex}, "\n" if ($VERBOSE > 1);
      }
    } else {
      print "Not storing mProphet scores. file_basename = $this_file_basename modified_pepseq = $modified_pepseq decoy = $decoy peak_group = $peak_group\n" if ($VERBOSE > 1);
    }

    $counter++;
    print "$counter..." if ($counter/100 == int($counter/100) && $VERBOSE);
  }

  print "\n";

}

###############################################################################
# read_transition_list -- return infos about transitions in a hash
###############################################################################
sub read_transition_list {
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $transition_file  = $args{transition_file};
  my $tr_format = $args{tr_format};
  # 11/18/11: may not need the below anymore. mPro is our
  # standard input format & we should convert any ATAQS contributions.
  my $ataqs = $args{ataqs} || 0;
  my $special_expt = $args{special_expt};
  my $VERBOSE = $args{'verbose'} || 0;
  my $QUIET = $args{'quiet'} || 0;
  my $TESTONLY = $args{'testonly'} || 0;
  my $DEBUG = $args{'debug'} || 0;

  my $sep = "\t";
  $sep = "," if ($tr_format eq 'csv');

  # TODO: beefier error handling
  open (TRAN_FILE, $transition_file) || die "Can't open $transition_file for reading.";

  ### Read header and store indices for key elements
  my %idx;
  # 11/18/11: may not need the below anymore. mPro is our
  # standard input format & we should convert any ATAQS contributions.
  if ( $ataqs ) {
    # ATAQS transition lists do not have header lines.
    # The fields are always in this order:
    %idx = ('protein_name' => 0,
            'stripped_sequence'=> 1,
            'prec_z'=> 2,
            'q1_mz'=> 3,
            'frg_z'=> 4,
            'q3_mz'=> 5,
            'frg_type'=> 6,
            'frg_nr'=> 7,
            'ce'=> 8,
            'rt'=> 9,
            'ataqs_modstring' => 10,
            );

  } else {
    print "Reading transition file header!\n" if ($VERBOSE);

    # First, set up a universal lookup table of possible header strings
    # for various types of data.
    # We store it this way because it's easy to read and maintain.
    # Formats: MaRiMba, Ruth's table, Simon's table

    my %possible_headers = (
			   q1_mz => [ qw( q1 q1_mz ), ],
			   q3_mz => [ qw( q3 q3_mz ), ],
			      ce => [ qw( ce ), ],
			      rt => [ qw( rt ), ],  #04/27/12: not used for anything
		    protein_name => [ qw( protein_name protein ), 'protein ipi' ],
	       stripped_sequence => [ qw( stripped_sequence strippedSequence peptide_seq peptide ) ],
			 isotype => [ qw( isotype heavy/light modified ) ],
			  prec_z => [ qw( prec_z q1_z ), 'q1 z',  ],
			frg_type => [ qw( frg_type ), 'fragment type', 'ion type' ],
			  frg_nr => [ qw( frg_nr ), 'ion number',  ],
			   frg_z => [ qw( frg_z ), 'q3 z',  ],
			frg_loss => [ qw( frg_loss ),  ],
         q1_delta_mz => [ qw(q1_delta_mz ), ],
         q3_mz_diff => [ qw( q3_mz_diff ), ],
      trfile_transition_group_id => [ qw( transition_group_id ) ],
		    modification => [ qw( modification modified_sequence sequence) ],
	      relative_intensity => [ qw( relative_intensity intensity ) ],
		  intensity_rank => [ qw( ), 'intensity rank',  ],
		        is_decoy => [ qw( is_decoy decoy ), ],
    );

    # Now reverse the direction of the hash to make it easier to use.
    my %header_lookup;
    for my $header (keys %possible_headers) {
      for my $s (@{$possible_headers{$header}}) {
				$header_lookup{$s} = $header;
      }
    }

    # Associate each header string with its position in this particular
    # transition file.
    my $line = <TRAN_FILE>;
    chomp $line;
    $line =~ s/[\r\n]//g;
    my @fields = split($sep, $line);
    my $i = 0;
    for my $field (@fields) {
      my $header;
      # if this header is recognized ...
      if ($header = $header_lookup{lc $field}) {
				$idx{$header} = $i;
				print "$header $i\n" if $DEBUG;
      }
      $i++;
    }

    # Check that essential headers are present
    if ( ! ( defined $idx{'q1_mz'} &&  defined $idx{'q3_mz'})) {
	die "Q1 and Q3 must be specified in ${transition_file}.";
    }
    if ( ! ( defined $idx{'frg_type'} &&  defined $idx{'frg_nr'} &&  defined $idx{'frg_z'})) {
	print "WARNING: one or more of frg_nr, frg_type, frg_z missing from ${transition_file}.\n";
    }

  } # end read transition file header

  
  ### Read and store each line of transition file
  my $transdata_href;
  my $modified_peptide_sequence;

  print "Processing transition file!\n" if ($VERBOSE);
  while (my $line = <TRAN_FILE>) {
    # Store select fields into transdata_href hash
    # and load into SEL_transitions and SEL_transition_groups, if requested.
    chomp $line;
    my @fields = split($sep, $line);
    my $q1_mz = $fields[$idx{q1_mz}];
    my $q3_mz = $fields[$idx{q3_mz}];
    # Skip these; retention time peptides that are sold by Biognosys
    # 01/23/12: Olga would like to see these. Hmmm.
    # Can store as a new field of SEL_peptide_ion and make it a display option
    #  to display or not. (To display ONLY RT peps, add a query to the form.).
#--------------------------------------------------
#     next if ( ($special_expt =~ /ruth/) &&
#               ($transdata_href->{$q1_mz}->{protein_name} =~ /Tr_peps_set/) );
#-------------------------------------------------- 


    my $stripped_sequence = '';
    $stripped_sequence = $fields[$idx{stripped_sequence}]
        if defined $idx{stripped_sequence};

    # Get modified peptide sequence, needed for reading mProphet file.
    # For Ruth's preliminary data, extract from transition group id
    my $modified_peptide_sequence;
    if ($special_expt eq 'ruth_prelim') {
      my $trfile_transition_group_id = $fields[$idx{trfile_transition_group_id}];
      print $trfile_transition_group_id, "\n" if ($VERBOSE > 2);
      $trfile_transition_group_id =~ /^(\S+)\./;
      $modified_peptide_sequence = $1;
      $modified_peptide_sequence =~ s/B/C\[160\]/g;
    # Else, check for modified sequence in its own field
    } elsif (defined $idx{modification}) {
      $modified_peptide_sequence = $fields[$idx{modification}];
      if ($special_expt eq 'ruth_2011') {
	$modified_peptide_sequence =~ s/\[C160\]/C\[160\]/g;
      }
    # Else, take the stripped sequence (even if null).
    } else {
      $modified_peptide_sequence = $stripped_sequence;
    }

    # If there is a modified pepseq but no stripped, strip.
    if ( $modified_peptide_sequence && ( ! $stripped_sequence )) {
      $stripped_sequence = 
	SBEAMS::PeptideAtlas::Annotations::strip_mods($modified_peptide_sequence);
    }

    # Create a data structure for this modified pepseq
    # that we can hash to using Q1 and Q3.
    # Allow for multiple pepseqs per Q1/Q3 pair.
    # CAUTION: we are storing multiple identical copies of this info,
    #   one for each Q3. This is not so much of a memory issue, but it
    #   could cause problems later if we modify one and not all.
    my $tx_href;
    $tx_href->{stripped_peptide_sequence} = $stripped_sequence;
    $tx_href->{collision_energy} = $fields[$idx{ce}] if defined $idx{ce};
    $tx_href->{protein_name} = $fields[$idx{protein_name}]
        if defined $idx{protein_name};

    # Set isotype
    $tx_href->{isotype} = 'light'; #default
    $tx_href->{isotype} = $fields[$idx{isotype}] if defined $idx{isotype};
    # Simon's data: translate H to heavy, L to light
    $tx_href->{isotype} = 'heavy' if $tx_href->{isotype} eq 'H';
    $tx_href->{isotype} = 'light' if $tx_href->{isotype} eq 'L';
    # 11/18/11: may not need the below anymore. mPro is our
    # standard input format & we should convert any ATAQS contributions.
    if ($ataqs && ( defined $idx{ataqs_modstring} ) ) {
      if ($fields[$idx{ataqs_modstring}] =~ /AQUA/) {
	$tx_href->{isotype} = 'heavy'
      } else {
	$tx_href->{isotype} = 'light'
      }
    }
    # Hack in additional masses of isotopically labelled peptides.
    # Actually, these can vary, and they need to be input by the
    # user somehow.
    if ($tx_href->{isotype} eq 'heavy') {
      if ($stripped_sequence =~ /K$/) {
				$tx_href->{isotype_delta_mass} = '8.0142';
      } elsif ($stripped_sequence =~ /R$/) {
				$tx_href->{isotype_delta_mass} = '10.0083';
      } #elsif($stripped_sequence =~ /L/){
        #  my @n = $stripped_sequence =~ /L/g;
        #  $tx_href->{isotype_delta_mass} = 7.017164 * scalar @n;
      #}
    }
    $tx_href->{peptide_charge} = $fields[$idx{prec_z}] if defined $idx{prec_z};
    $tx_href->{frg_type} = $fields[$idx{frg_type}] if defined $idx{frg_type};
    $tx_href->{frg_nr} = int($fields[$idx{frg_nr}]) if defined $idx{frg_nr};
    $tx_href->{frg_z} = int($fields[$idx{frg_z}]) if defined $idx{frg_z};
    $tx_href->{frg_loss} = 0;
    $tx_href->{frg_loss} = $fields[$idx{frg_loss}] if defined $idx{frg_loss};
    $tx_href->{q1_delta_mz} = $fields[$idx{q1_delta_mz}];
    $tx_href->{q3_mz_diff} = $fields[$idx{q3_mz_diff}];
    $tx_href->{is_decoy} =
        ( ((defined $idx{is_decoy}) &&
	   (($fields[$idx{is_decoy}] == 1) ||
	    ($fields[$idx{is_decoy}] =~ /true/i) ||
	    ($fields[$idx{is_decoy}] =~ /yes/i)) ) ||
	  ( ( uc($stripped_sequence) =~ /^[KR]/) && $ataqs ))  # reverse pepseq.
	  || 0;
    if (($idx{relative_intensity}) && $fields[$idx{relative_intensity}]) {
      $tx_href->{relative_intensity} = $fields[$idx{relative_intensity}];
    # transform intensity rank to relative intensity by taking inverse
    } elsif (($idx{intensity_rank}) && $fields[$idx{intensity_rank}]) {
      my $relative_intensity;
      if ($fields[$idx{intensity_rank}]) {
	$tx_href->{relative_intensity} = 1/$fields[$idx{intensity_rank}];
      } else {
	$tx_href->{relative_intensity} = 0;
      }
    }

    print "$modified_peptide_sequence ".
          "$tx_href->{stripped_peptide_sequence} ".
          "+$tx_href->{peptide_charge} ".
          "$tx_href->{isotype} ".
          "q1=$q1_mz q3=$q3_mz is_decoy=$tx_href->{is_decoy}\n"
       if ($VERBOSE > 1);

    $transdata_href->{$q1_mz}->{transitions}->{$q3_mz}->{mod_pepseq}->
          {$modified_peptide_sequence} = $tx_href;


  }
  return $transdata_href;
}

###############################################################################
# store_mprophet_scores_in_transition_hash
###############################################################################

sub store_mprophet_scores_in_transition_hash {
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $mpro_href = $args{mpro_href};
  my $transdata_href = $args{transdata_href};
  my $tx_map_href = $args{tx_map_href};
  my $spec_file_basename = $args{spec_file_basename};
  my $VERBOSE = $args{'verbose'} || 0;
  my $QUIET = $args{'quiet'} || 0;
  my $TESTONLY = $args{'testonly'} || 0;
  my $DEBUG = $args{'debug'} || 0;

  print "Getting the mQuest and/or mProphet scores for each transition group!\n" if ($VERBOSE);
  my $n_q1 = keys %$tx_map_href;
  print "$n_q1 measured Q1 in tx_map\n" if $VERBOSE > 2;
  # For each targeted Q1
  for my $target_q1 (keys %{$transdata_href}) {
    print "For target Q1 $target_q1...\n" if $VERBOSE>2;

    # Get the pepseq(s) and Q3s that were measured in this spectrum file
    # (usually only one, but sometimes multiple, as in phospho data)
    my $found_matching_measured_q1 = 0;

    my ($modified_pepseq, $matching_target_q3s_aref);
    for my $measured_q1 (keys %{$tx_map_href}) {
      print "Checking measured Q1 $measured_q1\n" if $VERBOSE > 2;
      my $matching_modpeps_href = $tx_map_href->{$measured_q1};
      for my $mod_pepseq (keys %{$matching_modpeps_href}) {
				if ($matching_modpeps_href->{$mod_pepseq}->{'target_q1'} == $target_q1) {
					print "DOES match Q1 for $mod_pepseq!\n" if $VERBOSE > 2;
					$found_matching_measured_q1 = 1;
					$modified_pepseq = $mod_pepseq;
					$matching_target_q3s_aref =
					$matching_modpeps_href->{$mod_pepseq}->{'matching_target_q3s_aref'};
					my @matching_target_q3s = @{$matching_target_q3s_aref};

					# Create stripped sequence, because this is sometimes (always?) what is used
					# to index into mProphet score hash
					# 02/07/12: TODO can't index by stripped seq with phospho data and
					# --mult_tg_per_q1.
					my $stripped_pepseq = 
					SBEAMS::PeptideAtlas::Annotations::strip_mods($modified_pepseq);
					print "Stripped = $stripped_pepseq Modseq = $modified_pepseq\n" if $VERBOSE > 1;

					my $sample_target_q3 = $matching_target_q3s[0];
					my $sample_tx_href = $transdata_href->{$target_q1}->{transitions}->
					{$sample_target_q3}->{mod_pepseq}->{$modified_pepseq};


					# Grab the mProphet score(s) for this Q1's transition group.
					my $charge = $sample_tx_href->{peptide_charge};
					my $isotype = $sample_tx_href->{isotype} || 'light';
					# Call this Q1 a decoy if all its Q3's are decoy
					my $decoy = 1;
					for my $q3_mz (@matching_target_q3s) {
						my $tx_href = $transdata_href->{$target_q1}->{transitions}->
						{$q3_mz}->{mod_pepseq}->{$modified_pepseq};
						$decoy = 0 if !$tx_href->{is_decoy};
					}
					print "Getting mQuest/mProphet scores for $spec_file_basename, $modified_pepseq, +$charge, $isotype, decoy=$decoy\n"
					if ($VERBOSE > 1);
					# For Ruth 2011 expt., mProphet file gives scores for only top peakgroup,
					# but for ruth_prelim it gives scores for all peakgroups.
					# Store them all.
					my $best_m_score = 0;
					my $best_d_score = 0;
					my $Tr = 0;
					my $log10_max_apex_intensity = 0;
					my $light_heavy_ratio_maxapex = 0;
					my $S_N = 0;

					# See if modified or stripped sequence is used in mpro_href hash.
					my $mpro_pepseq = '';
					if (defined $mpro_href->{$spec_file_basename}->{$modified_pepseq}) {
						$mpro_pepseq = $modified_pepseq;
				# 11/30/12: this is getting us into trouble. We now store only under modseq.
				#--------------------------------------------------
				#   } elsif (defined $mpro_href->{$spec_file_basename}->{$stripped_pepseq}) {
				#     $mpro_pepseq = $stripped_pepseq;
				#-------------------------------------------------- 
					} elsif (! defined $mpro_href->{$spec_file_basename}) {
						print "\$mpro_href->{$spec_file_basename} not defined!\n" if $VERBOSE;
					} else {
						#print "\$mpro_href->{$spec_file_basename}->{pepseq} not defined for either modified pepseq |$modified_pepseq| or stripped pepseq |$stripped_pepseq|!\n" if $VERBOSE;
						print "\$mpro_href->{$spec_file_basename}->{pepseq} not defined for modified pepseq |$modified_pepseq|!\n" if $VERBOSE;
					}
					print "Hashing sequence |$mpro_pepseq|\n" if $DEBUG;

					if ($VERBOSE > 2) {
						print "$spec_file_basename is in mpro_href\n"
						if defined  $mpro_href->{$spec_file_basename};
						print "$mpro_pepseq is in mpro_href\n"
						if defined $mpro_href->{$spec_file_basename}->{$mpro_pepseq};
						print "+$charge is in mpro_href\n"
						if defined $mpro_href->{$spec_file_basename}->{$mpro_pepseq}->{$charge};
						print "$isotype is in mpro_href\n"
						if defined $mpro_href->{$spec_file_basename}->{$mpro_pepseq}->{$charge}->
						{$isotype};
						print "is_decoy=$decoy is in mpro_href\n"
						if defined $mpro_href->{$spec_file_basename}->{$mpro_pepseq}->{$charge}->
						{$isotype}->{$decoy};
						print "peak_group 1 is in mpro_href\n"
						if defined $mpro_href->{$spec_file_basename}->{$mpro_pepseq}->{$charge}->
						{$isotype}->{$decoy}->{1};
					}

					# For each peak_group we have info on, get the scores.
					# First, create descending list of peak_group numbers.
					# Lower numbers are for better peak groups.
					# (before 02/28/12, we weren't sorting - aack!)
					my @pgs = sort {$b <=> $a}
						keys %{ $mpro_href->{$spec_file_basename}->{$mpro_pepseq}->
							{$charge}->{$isotype}->{$decoy}};
					for my $pg (@pgs) {
						print "Checking peakgroup $pg\n" if $VERBOSE > 2;
						my $mpro_pg_href =
						$mpro_href->{$spec_file_basename}->{$mpro_pepseq}->{$charge}->{$isotype}->{$decoy}->{$pg};
						my $m_score = $mpro_pg_href ->{m_score};
						my $d_score = $mpro_pg_href ->{d_score};
						print "Found m_score=$m_score\n" if ($VERBOSE > 2);
						my $max = $mpro_pg_href ->{max_apex_intensity};
						$light_heavy_ratio_maxapex =
							$mpro_pg_href->{light_heavy_ratio_maxapex};
						my $log_max = $max ? log10($max) : 0;  #avoid log(0).
						$log10_max_apex_intensity =
							$mpro_pg_href->{log10_max_apex_intensity} || $log_max;
						$Tr = $mpro_pg_href ->{Tr};
						$S_N = $mpro_pg_href ->{S_N};
						print "Found S_N=$S_N\n" if ($VERBOSE > 2);

						# 01/24/12: this is never used.
						$transdata_href->{$target_q1}->{peak_groups}->{$pg}->{m_score} = $m_score;

						# Keep the m_score and d_score for the highest scoring peakgroup (should be #1)
						if ($m_score) {
							if (!$best_m_score || ($m_score < $best_m_score)) { $best_m_score = $m_score; }
							print '$mpro_href->{',$spec_file_basename,'}->{',$mpro_pepseq,'}->{',$charge,'}->{',$decoy,'}->{',$pg,'}->{m_score} = ', $m_score, "\n" if ($VERBOSE > 1);
						} else {
							print 'No m_score for $mpro_href->{',$spec_file_basename,'}->{',$mpro_pepseq,'}->{',$charge,'}->{',$decoy,'}->{',$pg,'}->{m_score}', "\n"  if ($VERBOSE > 1);
						}
						if ($d_score) {
							if (!$best_d_score || ($d_score > $best_d_score)) { $best_d_score = $d_score; }
							print '$mpro_href->{',$spec_file_basename,'}->{',$mpro_pepseq,'}->{',$charge,'}->{',$decoy,'}->{',$pg,'}->{d_score} = ', $d_score, "\n" if ($VERBOSE > 1);
						} else {
							print 'No d_score for $mpro_href->{',$spec_file_basename,'}->{',$mpro_pepseq,'}->{',$charge,'}->{',$decoy,'}->{',$pg,'}->{d_score}', "\n"  if ($VERBOSE > 1);
						}
					}
					# Store the max m_score. Store the most recent Tr, intensity 
					# (will be for the lowest numbered peak group, #1 except
					# in weird cases)
					$transdata_href->{$target_q1}->{$modified_pepseq}->{scores}->{$decoy}->{best_m_score} = $best_m_score;
					$transdata_href->{$target_q1}->{$modified_pepseq}->{scores}->{$decoy}->{best_d_score} = $best_d_score;
					#print "Storing best_m_score $best_m_score\n" if ($VERBOSE > 2);
					$transdata_href->{$target_q1}->{$modified_pepseq}->{scores}->{$decoy}->{Tr} = $Tr;
								$transdata_href->{$target_q1}->{$modified_pepseq}->{scores}->{$decoy}->{S_N} = $S_N;
								$transdata_href->{$target_q1}->{$modified_pepseq}->{scores}->{$decoy}->{log10_max_apex_intensity} = $log10_max_apex_intensity;
								$transdata_href->{$target_q1}->{$modified_pepseq}->{scores}->{$decoy}->{light_heavy_ratio_maxapex} = $light_heavy_ratio_maxapex;

	} else {
	  print "Doesn't match Q1 for $mod_pepseq.\n" if $VERBOSE > 2;
	} # end if matches target Q1
      } # end for each modpep
    } # end for each measured Q1

    if (!$found_matching_measured_q1) {
      print "Target Q1 $target_q1 not measured in this spec file; skipping\n"
				if ! defined $modified_pepseq && $VERBOSE > 1;
    }

  } # end for each target Q1
}

#--------------------------------------------------
#       if ($tx_map_href->{$measured_q1}->{'target_q1'} == $target_q1) {
# 	my @mod_pepseqs = keys %{$tx_map_href->{$measured_q1}};
# 	# 02/06/12: for now, assume just one matching pepseq
# 	$modified_pepseq = $mod_pepseqs[0];
# 	$matching_target_q3s_aref = $tx_map_href->{$measured_q1}->
# 	   {$modified_pepseq}->{'matching_target_q3s'};
# 	#--------------------------------------------------
# 	# $modified_pepseq = $tx_map_href->{$measured_q1}->{'mod_pepseq'};
# 	# $matching_target_q3s_aref =
# 	#       $tx_map_href->{$measured_q1}->{'matching_target_q3s'};
# 	#-------------------------------------------------- 
# 	last;
#       }
#     }
#     next if ! defined $modified_pepseq;
#-------------------------------------------------- 

###############################################################################
# map_peps_to_prots
###############################################################################
 
sub map_peps_to_prots {
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $SEL_experiment_id = $args{'SEL_experiment_id'};
  my $glyco = $args{'glyco'};
  my $VERBOSE = $args{'verbose'} || 0;
  my $QUIET = $args{'quiet'} || 0;
  my $TESTONLY = $args{'testonly'} || 0;
  my $DEBUG = $args{'debug'} || 0;

  print "Mapping peptides to protein sequences in biosequence set!\n" if ($VERBOSE);

  # Get organism ID for this experiment
  my $sql = qq~
  SELECT S.organism_id FROM $TBAT_SEL_EXPERIMENT SELE
  JOIN $TBAT_SAMPLE S
  ON S.sample_id = SELE.sample_id
  WHERE SELE.SEL_experiment_id = '$SEL_experiment_id'
  ~;
  my ($organism_id) = $sbeams->selectOneColumn($sql);
  if (! defined $organism_id ) {
    print "map_peps_to_prots: No organism ID for sample linked to experiment ${SEL_experiment_id}.\n";
    return;
  }

  # Get ID for latest BSS for this organism
  my $sql = '';
  if ($organism_id  == 2){
    $sql = qq~
			SELECT BS.BIOSEQUENCE_SET_ID
			FROM $TBAT_DEFAULT_ATLAS_BUILD DAP
			JOIN $TBAT_ATLAS_BUILD AB ON (DAP.ATLAS_BUILD_ID = AB.ATLAS_BUILD_ID)
			JOIN $TBAT_BIOSEQUENCE_SET BS ON (BS.BIOSEQUENCE_SET_ID = AB.BIOSEQUENCE_SET_ID)
			WHERE DAP.ORGANISM_ID IS NULL
    ~;
   }else{
    $sql = qq~
      SELECT BSS.biosequence_set_id 
      FROM $TBAT_BIOSEQUENCE_SET BSS
      WHERE BSS.organism_id = '$organism_id'
      AND BSS.record_status != 'D';
      ~;
   }
  my @bss_ids = $sbeams->selectOneColumn($sql);
  if (! scalar @bss_ids) {
    print "Can't map peptides to proteins for organism ${organism_id}; no biosequence set.\n";
    return;
  }
  my $bss_id = max (@bss_ids);

  # Get filename for this BSS
  my $sql = qq~
  SELECT BSS.set_path FROM $TBAT_BIOSEQUENCE_SET BSS
  WHERE BSS.biosequence_set_id = '$bss_id'
  ~;
  my ($set_path) = $sbeams->selectOneColumn($sql);

  # Read all entries in this organism's latest biosequence set
  # into a hash according to protein sequence. Store accession(s) and,
  # optionally, biosequence_id for each seq in the hash.
  my $prots_href = read_prots_into_hash (
    prot_file => $set_path,
    store_biosequence_id => 0,
    swissprot_only => 0,
    organism_id => $organism_id,
    verbose => $VERBOSE,
    quiet => $QUIET,
    testonly => $TESTONLY,
    debug => $DEBUG,
  );
  my @biosequences = keys %{$prots_href};
  my $n_bss = scalar @biosequences;

  # Read regexes for preferred protein identifiers
  my $preferred_patterns_aref =
  SBEAMS::PeptideAtlas::ProtInfo::read_protid_preferences(
    organism_id=>$organism_id,
  );
  my $n_patterns = scalar @{$preferred_patterns_aref};
  if ( $n_patterns == 0 ) {
    print "WARNING: No preferred protein identifier patterns found ".
    "for organism $organism_id! ".
    "Arbitrary identifiers will be used.\n";
  }

  # Create a hash of all peptide ions in this experiment,
  # mapping peptide sequence to SEL_peptide_ion_id
  my $sql = qq~
  SELECT DISTINCT SELPI.stripped_peptide_sequence, SELPI.SEL_peptide_ion_id 
  FROM $TBAT_SEL_PEPTIDE_ION SELPI
  JOIN $TBAT_SEL_TRANSITION_GROUP SELTG
  ON SELTG.SEL_peptide_ion_id = SELPI.SEL_peptide_ion_id
  JOIN $TBAT_SEL_RUN SELR
  ON SELR.SEL_run_id = SELTG.SEL_run_id
  WHERE SELR.SEL_experiment_id = '$SEL_experiment_id'
  ~;
  my @rows = $sbeams->selectSeveralColumns($sql);
  my $n_peps = scalar @rows;
  print "$n_peps peptide_ion records retrieved for experiment $SEL_experiment_id\n"
     if $VERBOSE;
  my $peps_href;
  for my $row (@rows) {
    my $pepseq = $row->[0];
    my $ion_id = $row->[1];
    if ( ! $peps_href->{$pepseq}->{SEL_peptide_ion_ids_string}) {
      $peps_href->{$pepseq}->{SEL_peptide_ion_ids_string} = "$ion_id";
    } else {
      $peps_href->{$pepseq}->{SEL_peptide_ion_ids_string} .= ",$ion_id";
    }
  }
  my @pepseqs = keys %{$peps_href};
  my $n_peps = scalar @pepseqs;
  print "Found $n_peps distinct peptide sequences.\n" if $VERBOSE;


  # For each pepseq, if there is protein_name in transition list file, use that mapping, 
  # otherwise use grep to map to prots.
  # Store mapping in $peps_href.

	print "Using grep to map each pep to its prots.\n" if $VERBOSE;
	for my $pepseq (@pepseqs) {
		print "Mapping $pepseq\n" if $VERBOSE;
		map_single_pep_to_prots(
			pepseq => $pepseq,
			prots_href => $prots_href,
			peps_href => $peps_href,
			preferred_patterns_aref => $preferred_patterns_aref,
			glyco => $glyco,
			verbose => $VERBOSE,
			quiet => $QUIET,
			testonly => $TESTONLY,
			debug => $DEBUG,
		);
	}


  # Load mapping!
  # For each peptide in hash
  print "Loading the mapping!\n" if $VERBOSE;
  for my $pepseq (keys %{$peps_href}) {
    print "pep $pepseq\n" if $VERBOSE;
    # For each peptide_ion record (when multiple charge states)
    for my $SEL_peptide_ion_id (split (/,/, $peps_href->{$pepseq}->{SEL_peptide_ion_ids_string} )) {
	    print " SEL_peptide_ion_id $SEL_peptide_ion_id\n" if $VERBOSE;
      # For each protein the peptide maps to
      # Cima/Schiess data -- we are not getting any acc's here!
      print "   acc string: $peps_href->{$pepseq}->{accessions_string}\n" if ($VERBOSE > 2);
      for my $acc (split ( /,/, $peps_href->{$pepseq}->{accessions_string} ) ) {
				print "  accession $acc\n" if $VERBOSE;
				my $rowdata_ref;
				$rowdata_ref->{protein_accession} = $acc;
				$rowdata_ref->{SEL_peptide_ion_id} = $SEL_peptide_ion_id;

				# See if this mapping is already loaded
				my $sql = qq~
				SELECT * FROM $TBAT_SEL_PEPTIDE_ION_PROTEIN
				WHERE protein_accession = '$acc'
				AND SEL_peptide_ion_id = '$SEL_peptide_ion_id'
				~;
				my ($SEL_peptide_ion_protein_id) = $sbeams->selectOneColumn($sql);

				# If we haven't already loaded a mapping between this ion 
				# and this prot ...
				if (! $SEL_peptide_ion_protein_id) {
					print "    loading SEL_peptide_ion_id $rowdata_ref->{SEL_peptide_ion_id}\n" if $VERBOSE;
					# if there are bioseq id's stored for this pepseq ...
					if ($peps_href->{$pepseq}->{bs_ids_string}) {
						my @bs_ids =  (split /,/, $peps_href->{$pepseq}->{bs_ids_string});
						# In table SEL_PEPTIDE_ION_PROTEIN,
						# store SEL_peptide_ion_id, biosequence_id (optional),
						# protein_accession
						for my $bs_id (@bs_ids) { # usually just one, but possibly more
							print "      bs_id $bs_id\n" if $VERBOSE;
							$rowdata_ref->{biosequence_id} = $bs_id;
							$SEL_peptide_ion_protein_id = $sbeams->updateOrInsertRow(
									insert=>1,
									table_name=>$TBAT_SEL_PEPTIDE_ION_PROTEIN,
									rowdata_ref=>$rowdata_ref,
									PK => 'SEL_peptide_ion_protein_id',
									return_PK => 1,
									verbose=>$VERBOSE,
									testonly=>$TESTONLY,
											);
						}
					} else {   # insert record without bs_id
						print "      NO bs_id\n" if $VERBOSE;
						$SEL_peptide_ion_protein_id = $sbeams->updateOrInsertRow(
							insert=>1,
							table_name=>$TBAT_SEL_PEPTIDE_ION_PROTEIN,
							rowdata_ref=>$rowdata_ref,
							PK => 'SEL_peptide_ion_protein_id',
							return_PK => 1,
							verbose=>$VERBOSE,
							testonly=>$TESTONLY,
						);
					}
				} else {
					print "    SEL_peptide_ion_id $SEL_peptide_ion_protein_id already loaded\n"
						 if $VERBOSE;
				}
      }
    }
  }
}

###############################################################################
# purge_protein_mapping
###############################################################################
 
sub purge_protein_mapping {
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $SEL_experiment_id = $args{'SEL_experiment_id'} ||
    die "purge_protein_mapping: need SEL_experiment_id";
  my $VERBOSE = $args{'verbose'} || 0;
  my $QUIET = $args{'quiet'} || 0;
  my $TESTONLY = $args{'testonly'} || 0;
  my $DEBUG = $args{'debug'} || 0;

  print "Purging SEL_peptide_ion_protein for experiment $SEL_experiment_id!\n" 
    if ($VERBOSE);

  # Get primary keys for all records we want to delete
  my $sql = qq~
    SELECT SELPIP.SEL_peptide_ion_protein_id
    FROM $TBAT_SEL_PEPTIDE_ION_PROTEIN SELPIP
    INNER JOIN $TBAT_SEL_TRANSITION_GROUP SELTG
    ON SELTG.SEL_peptide_ion_id = SELPIP.SEL_peptide_ion_id
    INNER JOIN $TBAT_SEL_RUN SELR
    ON SELR.SEL_run_id = SELTG.SEL_run_id
    WHERE SELR.SEL_experiment_id = $SEL_experiment_id;
  ~;
  print $sql if ($VERBOSE > 1);
  my @SEL_peptide_ion_protein_ids = $sbeams->selectOneColumn($sql);
  my $nrecords = scalar @SEL_peptide_ion_protein_ids;
  print "About to delete $nrecords records from SEL_peptide_ion_protein\n"
      if ($VERBOSE);
  print "(Test only, not really deleting.)\n" if ($VERBOSE && $TESTONLY);

  # delete
  my $result = $sbeams->deleteRecordsAndChildren(
    table_name => 'SEL_peptide_ion_protein',
    table_child_relationship => {},
    delete_PKs => \@SEL_peptide_ion_protein_ids,
    delete_batch => 1000,
    database => $DBPREFIX{PeptideAtlas},
    verbose => $VERBOSE,
    testonly => $TESTONLY,
    keep_parent_record => 0,
  );
  print "deleteRecordsAndChildren return value = $result\n" if $VERBOSE > 1;
}

###############################################################################
# glycoswap --  For any DX[ST] or D.$, replace D with [ND].
###############################################################################
sub glycoswap {
  my $pep = shift;
  my $generalized_pep = $pep;
  if ($pep =~ m/D.[ST]/) {
    $generalized_pep =~ s/D(.[ST])/\[ND\]$1/gi;
  }
  if ($pep =~ m/D.$/) {
    $generalized_pep =~ s/D(.)$/\[ND\]$1/i;
  }
  return $generalized_pep;
}


#--------------------------------------------------
# ###############################################################################
# # get_matching_q3_for_q1 -- Given a Q1 from a spectrum file and a targeted pepseq,
# #   return a list of Q3s that (a) are listed for that Q1/pepseq in the transition
# #   file, and (b) are measured in the spectrum file.
# ###############################################################################
# 
# sub get_matching_q3_for_q1 {
#   my %args = @_;
#   my $measured_q1_mz=$args{'measured_q1_mz'};
#   my $measured_q3_aref = $args{'measured_q3_aref'};
#   my $transdata_href = $args{'transdata_href'};
#   my $q1_tol = $args{'q1_tol'};
#   my $q3_tol = $args{'q3_tol'};
#   my $VERBOSE = $args{'verbose'} || 0;
#   my $QUIET = $args{'quiet'} || 0;
#   my $TESTONLY = $args{'testonly'} || 0;
#   my $DEBUG = $args{'debug'} || 0;
# 
#   my @matched_q3_list;
#   # For each measured Q3, see if the Q1/Q3 pair is seen in the
#   # transition file for the given pepseq.
#   for my $q3 (@{$measured_q3_aref}) {
#     if (
#       $transdata_href->{$q1_mz}->{transitions}->{$first_q3_mz}->{mod_pepseq};
# 
#     # If it is, add it to the output list.
#   }
# 
#   for my $measured_q1 (keys %{$href}) {
#      if (($measured_q1 > $target_q1-$q1_tol) &&
# 	 ($measured_q1 < $target_q1+$q1_tol)) {
#        for my $measured_q3 (keys %{$href->{$measured_q1}}) {
#          for my $target_q3 (@{$q3_aref}) {
# 	   if (($measured_q3 > $target_q3-$q3_tol) &&
# 	       ($measured_q3 < $target_q3+$q3_tol)) {
# 	    return 1;
# 	  }
# 	}
#       }
#     }
#   }
#   return 0;
# }
#-------------------------------------------------- 



###############################################################################
# find_tx_in_hash -- true if q1/q3 is found in hash, within a tolerance window
###############################################################################

sub find_tx_in_hash {
  my %args = @_;
  my $target_q1=$args{'q1_mz'};
  my $target_q3=$args{'q3_mz'};
  my $href = $args{'href'};
  my $q1_tol = $args{'q1_tol'};
  my $q3_tol = $args{'q3_tol'};
  my $VERBOSE = $args{'verbose'} || 0;
  my $QUIET = $args{'quiet'} || 0;
  my $TESTONLY = $args{'testonly'} || 0;
  my $DEBUG = $args{'debug'} || 0;

  for my $measured_q1 (keys %{$href}) {
     if (($measured_q1 > $target_q1-$q1_tol) &&
	 ($measured_q1 < $target_q1+$q1_tol)) {
       for my $measured_q3 (keys %{$href->{$measured_q1}}) {
	 if (($measured_q3 > $target_q3-$q3_tol) &&
	     ($measured_q3 < $target_q3+$q3_tol)) {
	  return 1;
	}
      }
    }
  }
  return 0;
}



###############################################################################
# find_q1_in_list -- true if q1 is found in list, within a tolerance window
#   deprecated
###############################################################################

sub find_q1_in_list {
  my %args = @_;
  my $target_q1=$args{'q1_mz'};
  my $list_aref = $args{'list_aref'};
  my $tol = $args{'tol'};
  my $VERBOSE = $args{'verbose'} || 0;
  my $QUIET = $args{'quiet'} || 0;
  my $TESTONLY = $args{'testonly'} || 0;
  my $DEBUG = $args{'debug'} || 0;

  for my $measured_q1 (@{$list_aref}) {
    return 1 if (($measured_q1 > $target_q1-$tol) &&
		 ($measured_q1 < $target_q1+$tol));
  }
  return 0;
}



###############################################################################
# map_transition_data_to_spectrum_file_data
###############################################################################
sub map_transition_data_to_spectrum_file_data {
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $transdata_href = $args{transdata_href};
  my $tx_measured_href = $args{tx_measured_href};
  my $q1_tol = $args{q1_tolerance} || 0.07;
  my $q3_tol = $args{q3_tolerance} || $q1_tol;
  my $mult_tg_per_q1 = $args{mult_tg_per_q1};
  my $VERBOSE = $args{'verbose'} || 0;
  my $QUIET = $args{'quiet'} || 0;
  my $TESTONLY = $args{'testonly'} || 0;
  my $DEBUG = $args{'debug'} || 0;

  my $tx_map_href;
  my $calculator = new SBEAMS::Proteomics::PeptideMassCalculator;

  print "Mapping transition file data to spectrum file data!\n" if ($VERBOSE);

  # For each Q1 measured in the current spectrum file, map
  for my $measured_q1 (keys %{$tx_measured_href}) {
    my @measured_q3s = keys %{$tx_measured_href->{$measured_q1}};
    print "Measured Q1 $measured_q1\n" if $VERBOSE;

    # Retrieve from the transition list the transition group that best matches
    # this measured Q1 and all the Q3s it was measured with.
    # (If multiple, and $mult_tg_per_q1 set, return all, not just best.)

    my $matching_modpeps_href = 
      get_target_transitions_for_measured_Q1(
				measured_q1=>$measured_q1,
				measured_q3_aref=>\@measured_q3s,
				transdata_href=>$transdata_href,
				q1_tol=>$q1_tol,
				q3_tol=>$q3_tol,
				mult_tg_per_q1 => $mult_tg_per_q1,
				verbose => $VERBOSE,
				quiet => $QUIET,
				testonly => $TESTONLY,
				debug => $DEBUG,
      );
    if ( ! (scalar keys %{$matching_modpeps_href}) ) {
      print "None of the measured transitions for Q1 $measured_q1 appears in the transition file.\n" if $VERBOSE;
      next;
    }
     $tx_map_href->{$measured_q1} = $matching_modpeps_href;
  }
  return $tx_map_href;
}

###############################################################################
# load_transition_data -- load data for this run into SBEAMS database
###############################################################################
sub load_transition_data {
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $SEL_run_id = $args{SEL_run_id};
  my $transdata_href = $args{transdata_href};
  my $tx_measured_href = $args{tx_measured_href};
  my $tx_map_href = $args{tx_map_href};
  my $q1_tol = $args{q1_tolerance} || 0.07;
  my $q3_tol = $args{q3_tolerance} || $q1_tol;
  my $load_chromatograms = $args{load_chromatograms};
  my $load_transitions = $args{load_transitions};
  my $load_peptide_ions = $args{load_peptide_ions};
  my $load_transition_groups = $args{load_transition_groups};
  my $load_scores_only = $args{load_scores_only} || 0;
  my $VERBOSE = $args{'verbose'} || 0;
  my $QUIET = $args{'quiet'} || 0;
  my $TESTONLY = $args{'testonly'} || 0;
  my $DEBUG = $args{'debug'} || 0;

  my $rowdata_ref;
  my $calculator = new SBEAMS::Proteomics::PeptideMassCalculator;

  print "Loading data into SBEAMS!\n" if ($VERBOSE);

  # For each Q1 measured in the current spectrum file, process and load.
  for my $measured_q1 (keys %{$tx_measured_href}) {

    print "Measured Q1 $measured_q1\n" if $DEBUG;

    if (! defined $tx_map_href->{$measured_q1}) {
      print "None of the measured transitions for Q1 $measured_q1 appears in the transition file.\n" if $VERBOSE;
      next;
    }

    # For the modified peptides that go with this Q1 (either just the
    # one with the transition group that best matches this measured
    # Q1 and all the Q3s it was measured with, or all those that
    # match within tolerance, depending on param --mult_tg_per_q1)
    my @mod_pepseqs = keys %{$tx_map_href->{$measured_q1}};
    for my $modified_peptide_sequence (@mod_pepseqs) {
      # 02/06/12: for now, assume just one
      #my $modified_peptide_sequence = $mod_pepseqs[0];
      my $matching_target_q3s_aref = $tx_map_href->{$measured_q1}->
      {$modified_peptide_sequence}->{'matching_target_q3s_aref'};
      my $target_q1 = $tx_map_href->{$measured_q1}->
      {$modified_peptide_sequence}->{'target_q1'};

      my @matching_target_q3s = @{$matching_target_q3s_aref};

			if (scalar @matching_target_q3s == 0) {
				print "None of the measured transitions for Q1 $measured_q1 appears in the transition file.\n" if $VERBOSE;
				next;
			}

			# See if this peptide ion was measured as a decoy and/or as a real pep.
			my $q3_decoy_aref = [];
			my $q3_real_aref = [];
			my $measured_as_decoy = 0;
			my $measured_as_real = 0;

      # For all the matching target Q3s, see if decoy or real.
      for my $q3_mz (@matching_target_q3s) {
				my $tx_href = $transdata_href->{$target_q1}->{transitions}->{$q3_mz}->
				{mod_pepseq}->{$modified_peptide_sequence};
				if ($tx_href->{is_decoy}) {
					$measured_as_decoy = 1;
					push (@{$q3_decoy_aref}, $q3_mz);
				} else {
					$measured_as_real = 1;
					push (@{$q3_real_aref}, $q3_mz);
				}
      }

      for my $is_decoy ( 1 , 0 ) {    # for each possible decoy state

				my $is_decoy_char = $is_decoy ? 'Y' : 'N' ;

				# If this Q1 was measured for this decoy state, load stuff.
				if ( ( $is_decoy_char eq 'Y' && $measured_as_decoy) ||
					( $is_decoy_char eq 'N' && $measured_as_real) )    {

					# Get a sample Q3 depending on decoy state, to get hash records
					my $q3_mz = ($is_decoy_char eq 'Y') ? $q3_decoy_aref->[0] :
					$q3_real_aref->[0] ;

					# I don't know how this line got here, but I think it was a
					# mistake. TMF 01/12
					#for my $q3_mz (@matching_target_q3s) {

					# Load peptide ion, if not already loaded. One peptide ion per
					#  modified_peptide_sequence + peptide_charge + is_decoy.
					# Also store stripped_peptide_sequence, monoisotopic_peptide_mass
					# (calc'd), and Q1_mz (calculated)
					$rowdata_ref = {};  #reset
					my $tx_href = $transdata_href->{$target_q1}->{transitions}->{$q3_mz}->
					{mod_pepseq}->{$modified_peptide_sequence};
					$rowdata_ref->{modified_peptide_sequence} = $modified_peptide_sequence;
					$rowdata_ref->{stripped_peptide_sequence} = $tx_href->{stripped_peptide_sequence};
					$rowdata_ref->{peptide_charge} = $tx_href->{peptide_charge};
					# In peptide_ion, store calculated m/z, not the one used in the
					# transition list, because this ion might be used by several experiments
					# and we want the value to be identical, with identical precision.
					$rowdata_ref->{q1_mz} = $calculator->getPeptideMass(
						sequence => $rowdata_ref->{modified_peptide_sequence},
						mass_type => 'monoisotopic',
						charge => $rowdata_ref->{peptide_charge},
					);
          $rowdata_ref->{q1_delta_mz} = $tx_href->{q1_delta_mz};
					$rowdata_ref->{monoisotopic_peptide_mass} = $calculator->getPeptideMass(
						sequence => $rowdata_ref->{modified_peptide_sequence},
						mass_type => 'monoisotopic',
					);

					$rowdata_ref->{is_decoy} = $is_decoy_char;

					my $sql =qq~
					SELECT SEL_peptide_ion_id
					FROM $TBAT_SEL_PEPTIDE_ION
					WHERE stripped_peptide_sequence = '$rowdata_ref->{stripped_peptide_sequence}'
					AND modified_peptide_sequence = '$rowdata_ref->{modified_peptide_sequence}'
					AND q1_mz = $rowdata_ref->{q1_mz}
          AND q1_delta_mz = $rowdata_ref->{q1_delta_mz}
					AND is_decoy = '$rowdata_ref->{is_decoy}'
					~;

					my @existing_peptide_ions = $sbeams->selectOneColumn($sql);
					my $n_existing_pi = scalar @existing_peptide_ions;

					my $peptide_ion_id;
					if ( $load_peptide_ions && ! $n_existing_pi && ! $load_scores_only) {
						$peptide_ion_id = $sbeams->updateOrInsertRow(
							insert=>1,
							table_name=>$TBAT_SEL_PEPTIDE_ION,
							rowdata_ref=>$rowdata_ref,
							PK => 'SEL_peptide_ion_id',
							return_PK => 1,
							verbose=>$VERBOSE,
							testonly=>$TESTONLY,
						);
					} else {
	    if ($n_existing_pi > 1) {
	      print "WARNING: $n_existing_pi peptide ions found for q1 $rowdata_ref->{q1_mz}, $rowdata_ref->{modified_peptide_sequence}, is_decoy = $is_decoy_char; using last\n" unless ($QUIET);
	      $peptide_ion_id = $existing_peptide_ions[$n_existing_pi-1];
	    } elsif ($n_existing_pi == 0) {
	      print "ERROR: no peptide ion found for q1 $rowdata_ref->{q1_mz}, $rowdata_ref->{modified_peptide_sequence}, is_decoy=$is_decoy_char\n";
	    } else {
	      $peptide_ion_id = $existing_peptide_ions[0];
	      print "Peptide ion $peptide_ion_id (pepseq $rowdata_ref->{modified_peptide_sequence}, Q1 $rowdata_ref->{q1_mz}), is_decoy=$is_decoy_char already loaded\n" if ($VERBOSE > 2 && !$load_scores_only);
	    }
	  }

	  # Now, load transition group.
	  $rowdata_ref = {};  #reset

	  # Basic data
	  if (! $load_scores_only) {
	    $rowdata_ref->{q1_mz} = $target_q1;
	    $rowdata_ref->{SEL_peptide_ion_id} = $peptide_ion_id;
	    $rowdata_ref->{SEL_run_id} = $SEL_run_id;
	    $rowdata_ref->{collision_energy} = $tx_href->{collision_energy};
	    $rowdata_ref->{isotype} = $tx_href->{isotype};
	    $rowdata_ref->{isotype_delta_mass} = $tx_href->{isotype_delta_mass};
	    $rowdata_ref->{experiment_protein_name} = $tx_href->{protein_name};
	  }

	  # Score data
	  my $scores_href = $transdata_href->{$target_q1}->{$modified_peptide_sequence}->{scores}->{$is_decoy};
	  $rowdata_ref->{m_score} = $scores_href->{best_m_score};
	  $rowdata_ref->{d_score} = $scores_href->{best_d_score};
	  $rowdata_ref->{S_N} = $scores_href->{S_N};
	  $rowdata_ref->{max_apex_intensity} =
	    $scores_href->{log10_max_apex_intensity};
	  $rowdata_ref->{light_heavy_ratio_maxapex} =
	    $scores_href->{light_heavy_ratio_maxapex};

	  # Set these score fields to NULL if there is no value for them.
	  if (! $rowdata_ref->{m_score} || ($rowdata_ref->{m_score} eq 'NA') )
	  { $rowdata_ref->{m_score} = 'NULL' };
	  if (! $rowdata_ref->{d_score} || ($rowdata_ref->{d_score} eq 'NA'))
	  { $rowdata_ref->{d_score} = 'NULL' };
	  if (! $rowdata_ref->{S_N}|| ($rowdata_ref->{S_N} eq 'NA') )
	  { $rowdata_ref->{S_N} = 'NULL' };
	  if (! $rowdata_ref->{max_apex_intensity}||
	    ($rowdata_ref->{max_apex_intensity} eq 'NA') )
	  { $rowdata_ref->{max_apex_intensity} = 'NULL' };
	  if (! $rowdata_ref->{light_heavy_ratio_maxapex}||
	    ($rowdata_ref->{light_heavy_ratio_maxapex} eq 'NA') )
	  { $rowdata_ref->{light_heavy_ratio_maxapex} = 'NULL' };


	  # Compute fragment_ions string and store in field of same name.
	  my @ion_list;
    my %mz_diff_list;
	  my @q3_list = $is_decoy ? @{$q3_decoy_aref} : @{$q3_real_aref} ;
	  for my $q3_mz (@q3_list) {

	    # Skip if not actually measured in run currently being loaded.
	    # Should never happen! 
	    # Remove this code July '12 after 6 mos. testing.
	    my $was_scanned = find_tx_in_hash (
	      q1_mz=>$target_q1,
	      q3_mz=>$q3_mz,
	      href=>$tx_measured_href,
	      q1_tol=>$q1_tol,
	      q3_tol=>$q3_tol,
	    );
	    if ( ! $was_scanned) {
	      die "BUG in load_transition_data: ".
	      "Q1 $target_q1 Q3 $q3_mz does not appear in this spectrum file.\n"
	      if ($DEBUG);
	    }

	    my $tx_href = $transdata_href->{$target_q1}->{transitions}->{$q3_mz}->
	    {mod_pepseq}->{$modified_peptide_sequence};
	    my $frg_href;
	    $frg_href->{frg_type} = $tx_href->{frg_type};
	    $frg_href->{frg_nr} = $tx_href->{frg_nr};
	    $frg_href->{frg_z} = $tx_href->{frg_z};
	    $frg_href->{frg_loss} = $tx_href->{frg_loss};
	    push (@ion_list, $frg_href);

      my $label = '';
      if (defined $tx_href->{isotype}){
        if ($tx_href->{isotype} =~ /^h/i){
           $label = 'H';
        }else{
           $label = 'L';
        }
      }
      my $encoded_tg = '';
      my $sep = '';
      $encoded_tg .= $frg_href->{'frg_type'} . $frg_href->{'frg_nr'};
      $encoded_tg .= "^$frg_href->{'frg_z'}" if ($frg_href->{'frg_z'} > 1);
      $encoded_tg .= sprintf("%.0f", $frg_href->{'frg_loss'})  if ($frg_href->{'frg_loss'} != 0);
      if (abs($tx_href->{q1_delta_mz}) > $q1_tol){
        $mz_diff_list{$encoded_tg} = "Q1$label=". $tx_href->{q1_delta_mz};
         $sep = ",";
      }
      if (abs($tx_href->{q3_mz_diff}) > $q3_tol){
        $mz_diff_list{$encoded_tg} .= $sep ."T" . "Q3$label=" . $tx_href->{q3_mz_diff};
      }
	  }
   
	  my $fragment_ions = $self->encode_transition_group_list (tg_aref=>\@ion_list);
	  $rowdata_ref->{fragment_ions} = $fragment_ions if (! $load_scores_only);
    my %mz_diffs = ();
    my $cnt = 1;
    foreach my $i (split(/,/, $fragment_ions)){
      if (defined $mz_diff_list{$i}){
         if ($mz_diff_list{$i} =~ /TQ3/){
           $mz_diff_list{$i} =~ s/TQ3/T${cnt}Q3/g;
         }
         $mz_diffs{$mz_diff_list{$i}} =1;
      }
      $cnt++;
    }
    my $mz_diffs = join(",", sort {$a cmp $b } keys %mz_diffs);
    $rowdata_ref->{mz_diffs} = $mz_diffs if (! $load_scores_only); 

	  # See if a record for this transition group is already
	  # loaded
	  my $sql =qq~
	    SELECT SEL_transition_group_id
	    FROM $TBAT_SEL_TRANSITION_GROUP
	    WHERE SEL_peptide_ion_id =
	      '$peptide_ion_id'
	    AND SEL_run_id = '$SEL_run_id'
	    AND q1_mz = '$target_q1'
	    AND isotype = '$tx_href->{isotype}'
	  ~;

	  my @existing_tgs = $sbeams->selectOneColumn($sql);
	  my $n_existing_tg = scalar @existing_tgs;

	  # Load a SEL_transition_group record, or, if already loaded,
	  # get its SEL_transition_group_id number.
	  my $transition_group_id = 0;
	  if ( $load_transition_groups &&
	       ! $n_existing_tg &&
	       ! $load_scores_only ) {
	    $transition_group_id = $sbeams->updateOrInsertRow(
	      insert=>1,
	      table_name=>$TBAT_SEL_TRANSITION_GROUP,
	      rowdata_ref=>$rowdata_ref,
	      PK => 'SEL_transition_group_id',
	      return_PK => 1,
	      verbose=>$VERBOSE,
	      testonly=>$TESTONLY,
	    );
	  } else {
	    if ($n_existing_tg > 1) {
	      print "WARNING: $n_existing_tg transition_groups found for SEL_peptide_ion_id $peptide_ion_id, SEL_run_id $SEL_run_id, q1 $target_q1, isotype $tx_href->{isotype}; using last\n" unless ($QUIET);
	      $transition_group_id = $existing_tgs[$n_existing_tg-1];
	    } elsif ($n_existing_tg == 0 ) {
	      print "ERROR: no transition group found for SEL_peptide_ion_id $peptide_ion_id, SEL_run_id $SEL_run_id, q1 $target_q1, isotype $tx_href->{isotype}.\n" unless ($QUIET);
	    } elsif ($n_existing_tg == 1 && ! $load_scores_only)  {
	      $transition_group_id = $existing_tgs[0];
	      print "Transition group $transition_group_id (SEL_peptide_ion_id $peptide_ion_id, SEL_run_id $SEL_run_id, q1 $target_q1, isotype $tx_href->{isotype}) already loaded\n" if $VERBOSE > 2;
	    }
	    if ( $load_scores_only && $n_existing_tg ) {
	      $transition_group_id = $existing_tgs[0];
	      print "Updating scores for transition group $transition_group_id, peptide $modified_peptide_sequence!\n"
	          if $VERBOSE > 2;
	      my $result = $sbeams->updateOrInsertRow(
					update=>1,
					table_name=>$TBAT_SEL_TRANSITION_GROUP,
					rowdata_ref=>$rowdata_ref,
					PK => 'SEL_transition_group_id',
					return_PK => 1,
					PK_value => $transition_group_id,
					verbose=>$VERBOSE,
					testonly=>$TESTONLY,
	      );
	    }
	  }


	  # Load a chromatogram record for this transition group
          # First, see if there is an existing record.
	  my $chromatogram_id = 0;
	  my $sql =qq~
	  SELECT SEL_chromatogram_id
	  FROM $TBAT_SEL_CHROMATOGRAM
	  WHERE SEL_transition_group_id =
	    $transition_group_id
	  ~;

	  my @existing_ch = $sbeams->selectOneColumn($sql);
	  my $n_existing_ch = scalar @existing_ch;
          $chromatogram_id = $existing_ch[0] if $n_existing_ch;
	  
	  if ($load_chromatograms &&
	      ! $load_scores_only &&
	      ! $chromatogram_id   ) {
	    $rowdata_ref = {};  #reset
	    $rowdata_ref->{SEL_transition_group_id} = $transition_group_id;
	    $chromatogram_id = $sbeams->updateOrInsertRow(
	      insert=>1,
	      table_name=>$TBAT_SEL_CHROMATOGRAM,
	      rowdata_ref=>$rowdata_ref,
	      PK => 'SEL_chromatogram_id',
	      return_PK => 1,
	      verbose => $VERBOSE,
	      testonly=> $TESTONLY,
	    );
	  } elsif ($load_scores_only && ! $chromatogram_id ) {
	      print "ERROR: no chromatogram found for SEL_transition_group_id $transition_group_id.\n" unless ($QUIET);
	  }

	  # Load a peak group record for this chromatogram,
	  # if we have peak group infos.
	  my $scores_href = $transdata_href->{$target_q1}->{$modified_peptide_sequence}->{scores}->{$is_decoy};
	  if ($load_chromatograms &&
	    ( $load_scores_only || $scores_href->{Tr} ||
	      $scores_href->{log10_max_apex_intensity} )) {
	    $rowdata_ref = {};  #reset
	    $rowdata_ref->{SEL_chromatogram_id} = $chromatogram_id;
	    $rowdata_ref->{Tr} = $scores_href->{Tr};
	    $rowdata_ref->{max_apex_intensity} =
	    $scores_href->{log10_max_apex_intensity};
	    $rowdata_ref->{rank} = 1;  # will change when we load multiple peak groups
	    if (! $rowdata_ref->{Tr} ) { $rowdata_ref->{Tr} = 'NULL' };
	    if (! $rowdata_ref->{max_apex_intensity} ) { $rowdata_ref->{max_apex_intensity} = 'NULL' };

	    # Is there already a peak group record loaded?
	    my $peak_group_id = 0;
	    my $sql =qq~
	      SELECT SEL_peak_group_id
	      FROM $TBAT_SEL_PEAK_GROUP
	      WHERE SEL_chromatogram_id = $chromatogram_id
	    ~;

	    my @existing_pg = $sbeams->selectOneColumn($sql);
	    my $n_existing_pg = scalar @existing_pg;
	    $peak_group_id = $existing_pg[0] if $n_existing_pg;

	    if ($load_scores_only && $n_existing_pg) {
		# update
		$peak_group_id = $sbeams->updateOrInsertRow(
		  update=>1,
		  table_name=>$TBAT_SEL_PEAK_GROUP,
		  rowdata_ref=>$rowdata_ref,
		  PK => 'SEL_peak_group_id',
		  return_PK => 1,
		  PK_value => $peak_group_id,
		  verbose => $VERBOSE,
		  testonly=> $TESTONLY,
		);
	    } elsif (! $n_existing_pg && $chromatogram_id ) {
#	          && ! $load_scores_only) {
	      $peak_group_id = $sbeams->updateOrInsertRow(
				insert=>1,
				table_name=>$TBAT_SEL_PEAK_GROUP,
				rowdata_ref=>$rowdata_ref,
				PK => 'SEL_peak_group_id',
				return_PK => 1,
				verbose => $VERBOSE,
				testonly=> $TESTONLY,
	      );
	    } else {
	      print "No peak group loaded or updated for chromatogram $chromatogram_id.\n" if $VERBOSE > 2;
	    }
	  } else {
	      print "No peak group loaded for chromatogram $chromatogram_id; either no scores (& not loading scores only), or request not to load chromatograms.\n" if $VERBOSE > 2;
	  }


	  # Now, finally, load a record for each transition for current decoy state
	  # (q3_list contains only those transitions for this decoy state.)
	  for my $q3_mz (@q3_list) {
	    $rowdata_ref = {};  #reset
	    my $tx_href = $transdata_href->{$target_q1}->{transitions}->{$q3_mz}->
	    {mod_pepseq}->{$modified_peptide_sequence};
	    $rowdata_ref->{SEL_transition_group_id} = $transition_group_id;
	    $rowdata_ref->{q3_mz} = $q3_mz;
      $rowdata_ref->{q3_mz_diff} = $tx_href->{q3_mz_diff};
	    $rowdata_ref->{frg_type} = $tx_href->{frg_type};
	    $rowdata_ref->{frg_nr} = $tx_href->{frg_nr};
	    $rowdata_ref->{frg_z} = $tx_href->{frg_z};
	    $rowdata_ref->{frg_loss} = $tx_href->{frg_loss};
	    $rowdata_ref->{relative_intensity} = $tx_href->{relative_intensity};

	    my $transition_id = 0;
	    # Has this transition already been loaded?
	    my $sql =qq~
	    SELECT SEL_transition_id
	    FROM $TBAT_SEL_TRANSITION
	    WHERE SEL_transition_group_id = '$transition_group_id'
	    AND q3_mz = '$q3_mz'
	    ~;
	    my @existing_transitions = $sbeams->selectOneColumn($sql);
	    my $n_existing_tr = scalar @existing_transitions;

	    if ($n_existing_tr && ! $load_scores_only) {
	      $transition_id = $existing_transitions[0];
	      print "Transition $transition_id (TG_id $transition_group_id, Q3 $q3_mz) already loaded\n" if $VERBOSE > 2;
	    }
	    if ($load_transitions && ! $n_existing_tr) {
	      if (! $load_scores_only) {
					$transition_id = $sbeams->updateOrInsertRow(
						insert=>1,
						table_name=>$TBAT_SEL_TRANSITION,
						rowdata_ref=>$rowdata_ref,
						PK => 'SEL_transition_id',
						return_PK => 1,
						verbose => $VERBOSE,
						testonly=> $TESTONLY,
					);
							} else {
					print "ERROR: no transition loaded for TG_id $transition_group_id, Q3 $q3_mz\n" if $VERBOSE > 2;
	      }
	    }
	  } # end load Tx record for each Q3 measured for this Q1 & decoy state
	  #} # end for each matching target Q3
	} # end if this Q1 was measured for this decoy state
      } # end for each possible decoy state
    } # end for each targeted modpep
  } # end for each measured Q1
}

###############################################################################
# get_target_transitions_for_measured_Q1 --
#   Given a measured Q1 and the list of measured Q3s for that Q1,
#   compile a list of matching Q3s that are listed for a matching Q1
#   in the transition file under a single modified_pepseq.
#   Choose the Q1/pepseq that yields the most matching Q3s.
###############################################################################
sub get_target_transitions_for_measured_Q1 {

  my %args = @_;
  my $measured_q1=$args{'measured_q1'};
  my @measured_q3s=@{$args{'measured_q3_aref'}};
  my $transdata_href=$args{'transdata_href'};
  my $q1_tol=$args{'q1_tol'};
  my $q3_tol=$args{'q3_tol'};
  my $mult_tg_per_q1 = $args{'mult_tg_per_q1'};
  my $VERBOSE =$args{'verbose'};
  my $QUIET =$args{'quiet'};
  my $TESTONLY =$args{'testonly'};
  my $DEBUG =$args{'debug'};

  # Get all the targeted Q1s matching the measured Q1 within tolerance
  # (usually one, or sometimes a very few)
  my @target_q1s = ();
  for my $target_q1 (keys %{$transdata_href}) {
    if (($measured_q1 > $target_q1-$q1_tol) &&
      ($measured_q1 < $target_q1+$q1_tol)) {
      push (@target_q1s, $target_q1);
    }
  }
  my $n_target_q1s = scalar @target_q1s;
  if ($DEBUG) {
    print "$n_target_q1s matching target Q1s ";
    for my $q1 (@target_q1s) { print "$q1 "; }
    print "\n";
  }

  my $max_q3_per_modpep_count = 0;
  my $best_modpep = '';
  my $best_target_q1 = '';
  my @max_matching_q3s = ();

  my $matching_modpeps_href;

  # For each matching target Q1 (probably only one or a very few)
  for my $target_q1 (@target_q1s) {
    print "Looking at target Q1 $target_q1\n" if $DEBUG;
    # For all the corresponding target Q3s,
    # get all the matching target modpeps
    my $target_modpeps_href = get_matching_target_modpeps(
				target_q1=>$target_q1,
				measured_q3_aref=>\@measured_q3s,
				transdata_href=>$transdata_href,
				q3_tol=>$q3_tol,
				verbose => $VERBOSE,
				quiet => $QUIET,
				debug => $DEBUG,
    );

    if ($mult_tg_per_q1) {
      # Store all of these transition groups
      for my $modpep (keys %{$target_modpeps_href}) {
				$matching_modpeps_href->{$modpep}->{'target_q1'} =
					$target_q1;
				my @matching_q3s = keys %{$target_modpeps_href->{$modpep}};
				$matching_modpeps_href->{$modpep}->{'matching_target_q3s_aref'} =
					\@matching_q3s;
      }
    } else {
      # Find best target modpep:
      # For each target modpep in hash just created
      for my $target_modpep (keys %{$target_modpeps_href}) {
				print "Looking at target modpep $target_modpep\n" if $DEBUG;
				# If it has more Q3s than any previous, save as best
				my @matching_q3s = keys %{$target_modpeps_href->{$target_modpep}};
				my $n_q3s = scalar @matching_q3s;
				print "  Has $n_q3s matching Q3s.\n" if $DEBUG;
				if ($n_q3s > $max_q3_per_modpep_count) {
					print "  Better than previous max of $max_q3_per_modpep_count!\n" if $DEBUG;
					$max_q3_per_modpep_count = $n_q3s;
					$best_modpep = $target_modpep;
					@max_matching_q3s = @matching_q3s;
					$best_target_q1 = $target_q1;
				}
      }
    }
  }

  if ( $mult_tg_per_q1) {
    my $n_modpeps = scalar keys %{$matching_modpeps_href};
    my $n_q1s = scalar @target_q1s;
    print "Storing $n_q1s target Q1s, $n_modpeps modified peptides for measured Q1 $measured_q1\n" if $DEBUG;
  } else {
			print "Best target Q1 $best_target_q1 Q3s $max_q3_per_modpep_count modpep $best_modpep for measured Q1 $measured_q1\n" if $DEBUG;
			$matching_modpeps_href->{$best_modpep}->{'target_q1'} = $best_target_q1;
			$matching_modpeps_href->{$best_modpep}->{'matching_target_q3s_aref'} = \@max_matching_q3s;
   }

  return $matching_modpeps_href;

  sub get_matching_target_modpeps {
    my %args = @_;
    my $transdata_href = $args{transdata_href};
    my $target_q1 = $args{target_q1};
    my @measured_q3s=@{$args{'measured_q3_aref'}};
    my $q3_tol=$args{'q3_tol'};
    my $VERBOSE =$args{'verbose'};
    my $QUIET =$args{'quiet'};
    my $DEBUG =$args{'debug'};
    my $target_modpeps_href;

    for my $target_q3
	 (keys %{$transdata_href->{$target_q1}->{'transitions'}}) {
      print "  Looking at target Q3 $target_q3\n" if $DEBUG;
      # For each measured Q3 matching within tolerance
      for my $measured_q3 (@measured_q3s) {
				print "    Looking at measured Q3 $measured_q3\n" if $DEBUG;
				if (($measured_q3 > $target_q3-$q3_tol) &&
					($measured_q3 < $target_q3+$q3_tol)) {
					print "      MATCH!\n" if $DEBUG;
					# For each target modpep for this target Q1/Q3 (one or a very few)
					for my $target_modpep (keys %{$transdata_href->{$target_q1}->
							{'transitions'}->{$target_q3}->{'mod_pepseq'}}) {
						print "      Hashing target modpep $target_modpep\n" if $DEBUG;
						# Add target Q3 to a hash for that target modpep
						$target_modpeps_href->{$target_modpep}->{$target_q3} = 1;
					}
				}
      }
    }
    return $target_modpeps_href;
  }

}


###############################################################################
# removePeptideIon -- removes records for an single peptide ion in a specific
#    PASSEL run
###############################################################################
sub removePeptideIon {
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $SEL_run_id = $args{'SEL_run_id'} || die "removePeptideIon: need run_id";
  my $modified_peptide_sequence = $args{'modified_peptide_sequence'} ||
      die "removePeptideIon: need modified pepseq";
  my $charge = $args{'charge'} || die "removePeptideIon: need peptide charge";
  my $VERBOSE = $args{'verbose'} || 0;
  my $QUIET = $args{'quiet'} || 0;
  my $TESTONLY = $args{'testonly'} || 0;
  my $DEBUG = $args{'debug'} || 0;

  my $database_name = $DBPREFIX{PeptideAtlas};

  # Get SEL_peptide_ion records with specified seq/charge
  # that belong to specfied run. There should be only one.
  my $sql = qq~
  SELECT SELPI.SEL_peptide_ion_id
  FROM $TBAT_SEL_PEPTIDE_ION SELPI
  JOIN $TBAT_SEL_TRANSITION_GROUP SELTG
  ON SELTG.SEL_peptide_ion_id = SELPI.SEL_peptide_ion_id
  WHERE SELTG.SEL_run_id = $SEL_run_id
  AND SELPI.modified_peptide_sequence = '$modified_peptide_sequence'
  AND SELPI.peptide_charge = $charge
  ~;
  print $sql if $DEBUG;
  my @peptide_ion_ids = $sbeams->selectOneColumn($sql);
  my $n_peptide_ions = scalar @peptide_ion_ids;
  if ($n_peptide_ions > 1) {
    print "ERROR (removePeptideIon): multiple records for seq '$modified_peptide_sequence', charge $charge, SEL_run_id $SEL_run_id. None deleted.\n";
    return();
  } elsif ($n_peptide_ions < 1) {
    print "ERROR (removePeptideIon): no records found for seq '$modified_peptide_sequence', charge $charge, SEL_run_id $SEL_run_id. None deleted.\n";
    return();
  }

  print "\nDeleting SEL_peptide_ion record $peptide_ion_ids[0] and children.\n\n"
     if $VERBOSE;

  my %table_child_relationship = (
    SEL_peptide_ion => 'SEL_peptide_ion_protein(C),SEL_transition_group(C)',
    SEL_transition_group => 'SEL_transition(C),SEL_chromatogram(C)',
    SEL_chromatogram => 'SEL_peak_group(C)',
  );

  $sbeams->deleteRecordsAndChildren(
    table_name => 'SEL_peptide_ion',
    table_child_relationship => \%table_child_relationship,
    delete_PKs => \@peptide_ion_ids,
    delete_batch => 100,
    database => $database_name,
    verbose => $VERBOSE,
    testonly => $TESTONLY,
    keep_parent_record => 0,
  );

  print "\n" unless $QUIET;

} # end removeSRMExperiment

###############################################################################
# removeSRMExperiment -- removes records for an SRM experiment or
# single run
###############################################################################
sub removeSRMExperiment {
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $SEL_experiment_id = $args{'SEL_experiment_id'};
  my $SEL_run_id = $args{'SEL_run_id'};
  my $keep_experiments_and_runs = $args{'keep_experiments_and_runs'} || 0;
  my $VERBOSE = $args{'verbose'} || 0;
  my $QUIET = $args{'quiet'} || 0;
  my $TESTONLY = $args{'testonly'} || 0;
  my $DEBUG = $args{'debug'} || 0;

  my $database_name = $DBPREFIX{PeptideAtlas};

  # Figure out which runs to purge. If a run_id was given, just
  # purge that.
  my (@run_ids, $run_id_string, $msg_string);
  if ($SEL_run_id) {
    @run_ids = ($SEL_run_id);
    $run_id_string = $SEL_run_id;
    $msg_string = "run $SEL_run_id";
  } elsif ($SEL_experiment_id) {
    my $sql = qq~
    SELECT SEL_run_id
    FROM $TBAT_SEL_RUN 
    WHERE SEL_experiment_id = $SEL_experiment_id
    ~;
    @run_ids = $sbeams->selectOneColumn($sql);
    $run_id_string = join (",", @run_ids);
    $msg_string = "experiment $SEL_experiment_id";
  } else {
    die "removeSRMExperiment: must specify either run_id or experiment_id";
  }

   # Next, get SEL_peptide_ion records that belong
   # to these runs, and turn the list into a SQL format string.
   my $sql = qq~
     SELECT SELPI.SEL_peptide_ion_id
       FROM $TBAT_SEL_PEPTIDE_ION SELPI
       JOIN $TBAT_SEL_TRANSITION_GROUP SELTG
         ON SELTG.SEL_peptide_ion_id = SELPI.SEL_peptide_ion_id
      WHERE SELTG.SEL_run_id in ($run_id_string)
   ~;
   my @peptide_ion_ids = $sbeams->selectOneColumn($sql);
   if (! scalar @peptide_ion_ids) {
     return (0);
   }
   my $peptide_ion_ids_sql_string = sprintf "( %s", shift @peptide_ion_ids;
   for my $peptide_ion_id (@peptide_ion_ids) {
     $peptide_ion_ids_sql_string .= ", $peptide_ion_id";
   }
   $peptide_ion_ids_sql_string .= ")";
   print $peptide_ion_ids_sql_string, "\n" if $DEBUG;
   my $n_peptide_ions = scalar @peptide_ion_ids;

   # Purge transition_group records, and possibly also experiment & run records.
   my %table_child_relationship = (
      SEL_experiment => 'SEL_run(C)',
      SEL_run => 'SEL_transition_group(C)',
      SEL_transition_group => 'SEL_transition(C),SEL_chromatogram(C)',
      SEL_chromatogram => 'SEL_peak_group(C)',
   );

   if ($keep_experiments_and_runs) {
     print "Purging $msg_string; keeping expt & run records.\n" if $VERBOSE;
     print "(not really purging because of --testonly)\n" if ($VERBOSE && $TESTONLY);

     #don't delete experiment OR run records
     delete $table_child_relationship{SEL_EXPERIMENT};
     $sbeams->deleteRecordsAndChildren(
       table_name => 'SEL_run',
       table_child_relationship => \%table_child_relationship,
       delete_PKs => \@run_ids,
       delete_batch => 100,
       database => $database_name,
       verbose => $VERBOSE,
       testonly => $TESTONLY,
       keep_parent_record => 1,
    );
  } else {
     print "Purging $msg_string; removing parent record.\n" if $VERBOSE;
     print "(not really purging because of --testonly)\n" if ($VERBOSE && $TESTONLY);
     my ($table_name, @PKs);
    if ($SEL_run_id) {
      $table_name = 'SEL_run';
      @PKs = @run_ids
    } else {
      $table_name = 'SEL_experiment';
      @PKs = ( $SEL_experiment_id );
    }
      $sbeams->deleteRecordsAndChildren(
         table_name => $table_name,
         table_child_relationship => \%table_child_relationship,
         delete_PKs => \@PKs,
         delete_batch => 100,
         database => $database_name,
         verbose => $VERBOSE,
         testonly => $TESTONLY,
	 keep_parent_record => 0,
      );
  }

  if ($n_peptide_ions) {
    # Which of this experiment's peptide_ion records are now orphaned?
    # Any of these three queries will work; perhaps one is faster than others.

  #--------------------------------------------------
  #   select SELPI.SEL_peptide_ion_id from $TBAT_SEL_PEPTIDE_ION SELPI
  #   where SELPI.SEL_peptide_ion_id not in (select SELTG.SEL_peptide_ion_id from
  #     $TBAT_SEL_TRANSITION_GROUP SELTG)
  #     and SELPI.SEL_peptide_ion_id in $peptide_ion_ids_sql_string;
  # 
  #   select SELPI.SEL_peptide_ion_id from $TBAT_SEL_PEPTIDE_ION SELPI
  #   where not exists (select * from $TBAT_SEL_TRANSITION_GROUP SELTG where
  #     SELTG.SEL_peptide_ion_id = SELPI.SEL_peptide_ion_id)
  #     and SELPI.SEL_peptide_ion_id in $peptide_ion_ids_sql_string;
  # 
  #   select SELPI.SEL_peptide_ion_id from $TBAT_SEL_TRANSITION_GROUP SELTG
  #     RIGHT OUTER JOIN $TBAT_SEL_PEPTIDE_ION SELPI
  #             ON SELTG.SEL_peptide_ion_id = SELPI.SEL_peptide_ion_id
  #   WHERE SELTG.SEL_peptide_ion_id IS NULL
  #     and SELPI.SEL_peptide_ion_id in $peptide_ion_ids_sql_string;
  #-------------------------------------------------- 

     $sql = qq~
    select SELPI.SEL_peptide_ion_id from $TBAT_SEL_TRANSITION_GROUP SELTG
      RIGHT OUTER JOIN $TBAT_SEL_PEPTIDE_ION SELPI
	      ON SELTG.SEL_peptide_ion_id = SELPI.SEL_peptide_ion_id
    WHERE SELTG.SEL_peptide_ion_id IS NULL
      and SELPI.SEL_peptide_ion_id in $peptide_ion_ids_sql_string;
     ~;
     my @orphaned_peptide_ion_ids = $sbeams->selectOneColumn($sql);


    %table_child_relationship = (
       SEL_peptide_ion => 'SEL_peptide_ion_protein(C)',
    );

    # Delete orphaned peptide_ion records along with their children.
   my $result = $sbeams->deleteRecordsAndChildren(
      table_name => 'SEL_peptide_ion',
      table_child_relationship => \%table_child_relationship,
      delete_PKs => \@orphaned_peptide_ion_ids,
      delete_batch => 1000,
      database => $database_name,
      verbose => $VERBOSE,
      testonly => $TESTONLY,
      keep_parent_record => 0,
   );

  }
  return (1);

} # end removeSRMExperiment

###############################################################################
# encode_transition_group -- transform a series of ions into a string
###############################################################################
sub encode_transition_group {
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $SEL_transition_group_id = $args{'SEL_transition_group_id'};
  my $VERBOSE = $args{'verbose'} || 0;
  my $QUIET = $args{'quiet'} || 0;
  my $TESTONLY = $args{'testonly'} || 0;
  my $DEBUG = $args{'debug'} || 0;

  my $encoded_tg = '';

  return $encoded_tg;
}

# Input: an unsorted list of hrefs (frg_type frg_nr frg_z frg_loss)
# Sort by charge, type, number, neutral_loss.
sub encode_transition_group_list {
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $tg_aref = $args{'tg_aref'};

  my @ion_list = @{$tg_aref};
  my $encoded_tg = '';

  my @sorted_ion_list = sort lower_fragment_ion @ion_list;

  sub lower_fragment_ion {
    return -1 if ($a->{'frg_z'} < $b->{'frg_z'});
    return  1 if ($a->{'frg_z'} > $b->{'frg_z'});
    return -1 if (lower_frg_type ($a->{'frg_type'}, $b->{'frg_type'} ));
    return  1 if (lower_frg_type ($b->{'frg_type'}, $a->{'frg_type'} ));
    return -1 if ($a->{'frg_nr'} < $b->{'frg_nr'});
    return  1 if ($a->{'frg_nr'} > $b->{'frg_nr'});
    return -1 if ($a->{'frg_loss'} < $b->{'frg_loss'});
    return  1 if ($a->{'frg_loss'} > $b->{'frg_loss'});
    return 0;

    sub lower_frg_type {
      my $a = shift; my $b = shift;
      return 0 if (lc($a) eq lc($b));
      return 1 if (lc($a) eq 'y');
      return 0 if (lc($b) eq 'y');
      return 1 if (lc($a) eq 'b');
      return 0 if (lc($b) eq 'b');
      return 1 if (lc($a) eq 'p');  # precursor
      return 0 if (lc($b) eq 'p');
      return 1 if (lc($a) eq 'x');
      return 0 if (lc($b) eq 'x');
      return 1 if (lc($a) eq 'a');
      return 0 if (lc($b) eq 'a');
      return 1 if (lc($a) eq 'z');
      return 0 if (lc($b) eq 'z');
      return 1 if (lc($a) eq 'c');
      return 0 if (lc($b) eq 'c');
      print STDERR "WARNING: unidentified ion types $a and $b\n";
      return 0;
    }
    
  }

  my $n_ions = scalar @sorted_ion_list;
  my $i = 0;
  for my $ion (@sorted_ion_list) {
    $encoded_tg .= $ion->{'frg_type'} . $ion->{'frg_nr'};
    $encoded_tg .= "^$ion->{'frg_z'}" if ($ion->{'frg_z'} > 1);
    $encoded_tg .= sprintf("%.0f", $ion->{'frg_loss'})  if ($ion->{'frg_loss'} != 0);
    $i++;
    $encoded_tg .= ',' if ($i < $n_ions);
  }
  return $encoded_tg;
  
}


###############################################################################
# read_prots_into_hash
###############################################################################
sub read_prots_into_hash {
  my %args = @_;
  my $prot_file = $args{'prot_file'};
  my $store_biosequence_id = $args{'store_biosequence_id'} || 0;
  my $swissprot_only = $args{'swissprot_only'} || 0;
  my $organism_id = $args{'organism_id'};
  my $VERBOSE = $args{'verbose'} || 0;
  my $QUIET = $args{'quiet'} || 0;
  my $TESTONLY = $args{'testonly'} || 0;
  my $DEBUG = $args{'debug'} || 0;

  my $prots_href;
  my $line;
  my $acc;
  my $desc;
  my $n_seq = 0;
  my $current_seq = '';

  my @biosequences;

  print " Reading protein FASTA file ${prot_file}...\n" if $VERBOSE;
  open (PROTFILE, $prot_file) || die "Can't open $prot_file for reading.";

  #### Loop through file
  my $done = 0;

  while (! $done) {
    $line = <PROTFILE>;
    chomp $line;
    unless ($line) {
      $line = '>dummy';
      $done = 1;
    }
    $line =~ s/[\r\n]//g;
    if ($line =~ /\>/) {
      if ($line =~ /^>(\S+)\s+(.*)$/) {
				my $next_acc = $1;
        my $next_desc = $2;
				if ($current_seq &&     # check for Swiss-Prot accession
					  (( ! $swissprot_only )||($acc =~ /^[ABOPQ]\w{5}$/ )||($acc =~ /^[ABCOPQ]\w{5}-\d{1,2}$/))){
          if ($organism_id == 2){ ## use only nP20K and SPnotNP 
             if ($desc =~ /(nP20K|SPnotNP)\s/i){
              if ($prots_href->{$current_seq}) {
								$prots_href->{$current_seq}->{accessions_string} .= ",$acc";
							} else {
								$prots_href->{$current_seq}->{accessions_string} = $acc;
							}
            }
          }else{
						if ($prots_href->{$current_seq}) {
							$prots_href->{$current_seq}->{accessions_string} .= ",$acc";
						} else {
							$prots_href->{$current_seq}->{accessions_string} = $acc;
						}
          }
				}
				$current_seq = '';
				$acc = $next_acc;
        $desc = $next_desc;
				$n_seq++;
      } else {
				print "ERROR in header of $acc!!!\n";
      }
    } else {
      $current_seq .= $line;
    }
  }

  @biosequences =  keys( %{$prots_href} );
  # This is slow (30 seconds for 35,000 Swiss-Prot IDs)
  if ($store_biosequence_id) {
    print " Getting biosequence ID for each prot ...\n" if $VERBOSE;
    for my $biosequence (@biosequences) {
      my $sql = qq~
				SELECT BS.biosequence_id 
					FROM $TBAT_BIOSEQUENCE BS
					WHERE BS.biosequence_name =
					'$prots_href->{$biosequence}->{accessions_string}';
      ~;
      my @bs_ids = $sbeams->selectOneColumn($sql);
      my $bss_id_string = join (",", @bs_ids);
      $prots_href->{$biosequence}->{bs_ids_string} = $bss_id_string;
    }
  }

  print "Read " . scalar( @biosequences ) . " Swiss-Prot proteins\n" if $VERBOSE;
  return $prots_href;
}

###############################################################################
# map_single_pep_to_prots
###############################################################################
sub map_single_pep_to_prots {
  my %args = @_;
  my $pepseq = $args{'pepseq'};
  my $prots_href = $args{'prots_href'};
  my $peps_href = $args{'peps_href'};
  my $preferred_patterns_aref =$args{'preferred_patterns_aref'};
  my $glyco = $args{'glyco'};
  my $VERBOSE = $args{'verbose'} || 0;
  my $QUIET = $args{'quiet'} || 0;
  my $TESTONLY = $args{'testonly'} || 0;
  my $DEBUG = $args{'debug'} || 0;

  my @biosequences = keys %{$prots_href};
  my $n_bss = scalar @biosequences;

  # If the glyco flag is set, swap D back to N in glycosites
  my $pepseq_to_lookup = $pepseq;
  if ($glyco) {
    $pepseq_to_lookup = glycoswap($pepseq);
    if ($pepseq ne $pepseq_to_lookup && ($VERBOSE > 2)) {
      print "Glycoswap $pepseq => $pepseq_to_lookup\n";
    }
  }

  # Get all protein sequences to which this peptide matches
  my @matches = grep(/${pepseq_to_lookup}/, @biosequences);
  my $n_matches = scalar @matches;
  print "Matched $pepseq_to_lookup to $n_matches out of $n_bss bioseqs\n"
     if $VERBOSE > 2;


  # Collect the accessions of these as a list
  my @all_accessions = ();
  for my $match (@matches) {
    my @bs_ids = split (/,/, $prots_href->{$match}->{bs_ids_string});
    my @accessions = split (/,/, $prots_href->{$match}->{accessions_string});
    print "   acc string: $prots_href->{$match}->{accessions_string}\n"
        if ($VERBOSE > 2);
    @all_accessions = (@all_accessions, @accessions);
  }

  # If preferred protein accesion patterns are passed,
  # get and store only the most preferred accession.
  if (defined  $preferred_patterns_aref ) {
        my $preferred_protein_name =
          SBEAMS::PeptideAtlas::ProtInfo::get_preferred_protid_from_list(
            protid_list_ref=>\@all_accessions,
            preferred_patterns_aref => $preferred_patterns_aref,
        );
    @all_accessions = ($preferred_protein_name);
    print " Preferred is $preferred_protein_name\n" if ($VERBOSE > 2);
  }

  # Store the accession(s) as a csv list, in string format,
  # in the peptide hash
  $peps_href->{$pepseq}->{accessions_string} = join (",", @all_accessions);
#--------------------------------------------------
#     foreach my $acc (@accessions) {
#       if ( defined $peps_href->{$pepseq}->{accessions_string} ) {
# 	 $peps_href->{$pepseq}->{accessions_string} .= ",$acc";
#       } else {
# 	 $peps_href->{$pepseq}->{accessions_string} = "$acc";
#       }
#-------------------------------------------------- 
#--------------------------------------------------
#     }
#-------------------------------------------------- 
}

###############################################################################
# load_srm_run
###############################################################################
sub load_srm_run {
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $SEL_run_id = $args{'SEL_run_id'};
  my $spectrum_file = $args{'spectrum_file'};
  my $data_path = $args{'data_path'};
  my $mquest_file = $args{'mquest_file'};
  my $mpro_file = $args{'mpro_file'};
  my $transition_file = $args{'transition_file'};
  my $tr_format = $args{'tr_format'};
  my $ataqs = $args{'ataqs'} || 0;
  my $special_expt = $args{'special_expt'};
  my $q1_tolerance = $args{'q1_tolerance'} || 0.007;
  my $q3_tolerance = $args{'q3_tolerance'} || $q1_tolerance;
  my $mult_tg_per_q1 = $args{'mult_tg_per_q1'};
  my $load_peptide_ions = $args{'load_peptide_ions'} || 1;
  my $load_transition_groups = $args{'load_transition_groups'} || 1;
  my $load_transitions = $args{'load_transitions'} || 1;
  my $load_chromatograms = $args{'load_chromatograms'} || 1;
  my $load_scores_only = $args{'load_scores_only'} || 0;
  my $purge = $args{'purge'} || 0;
  my $VERBOSE = $args{'verbose'};
  my $QUIET = $args{'quiet'};
  my $TESTONLY = $args{'testonly'};
  my $DEBUG = $args{'debug'};

  if ( (! defined $SEL_run_id) &&
       (! defined $spectrum_file) &&
       (! defined $transition_file)) {
    die "load_srm_run: need either SEL_run_id, spec_file_basename, or transition_file."
  }

  if ( ($load_scores_only) &&
       (! defined $mquest_file ) &&
       (! defined $mpro_file )) {
    die "load_srm_run: load_scores_only specified, but no mProphet or mQuest file given."
  }

  my ($data_dir, $tran_file_basename);
  my $spec_file_basename;
  my $spectrum_filepath;
  my $extension;
  
  # The code just below, which attempts to get file paths for the spectrum
  # and transition files, is hokey and not totally logical. Should be cleaned
  # up.

  # if a transition_file was given, get the data_dir from it.
  if ( defined $transition_file ) {
    my $data_dir = `dirname $transition_file`;
    chomp $data_dir;
    $_ = `basename $transition_file`;
    my ($tran_file_basename) = /^(\S+)\.\S+$/;  #strip extension
  }

  # if a spectrum_file was given, assume it's a path
  if (! $SEL_run_id && $spectrum_file) {
    $_ = `basename $spectrum_file`;
    ($spec_file_basename, $extension) = /^(\S+)\.(\S+)$/;  #strip extension
    $spectrum_filepath = $spectrum_file;
    $SEL_run_id = $self->get_SEL_run_id(
      spec_file_basename => $spec_file_basename,
    );

  # if no spectrum_file, but SEL_run_id, get spectrum file from run
  # Actually, this is  not fully functional. Would need to get data_dir
  # from experiment record. TODO .
  } elsif (defined $SEL_run_id) {
    ($spec_file_basename, $extension) =
      $self->get_spec_file_basename_and_extension (
	      SEL_run_id => $SEL_run_id,
      );
    if (! $spec_file_basename) {
      die "No spectrum file for $SEL_run_id.";
    }
    if ( -e "$data_path/$spec_file_basename.mzML"){
      $spectrum_filepath = "$data_path/$spec_file_basename.mzML";
    }else{
      $spectrum_filepath = "$data_path/$spec_file_basename.mzXML";
    }
  # if still no spectrum file, assume base is same as transition file.
  } else {
    $spec_file_basename = $tran_file_basename;
    print "No spectrum filename given; assume same basename as transition file with .mzXML extension.\n";
    #$extension = 'mzML';
    if ( -e "$data_path/$spec_file_basename.mzML"){
      $spectrum_filepath = "$data_path/$spec_file_basename.mzML";
    }else{
      $spectrum_filepath = "$data_path/$spec_file_basename.mzXML";
    }
 
  }

  my $SEL_experiment_id = $self->get_SEL_experiment_id(
    SEL_run_id => $SEL_run_id,
  );
  print "Loading run $SEL_run_id, specfile $spec_file_basename, filepath $spectrum_filepath, expt $SEL_experiment_id\n" if ($VERBOSE);

### Purge if requested
  if ($purge) {
    print "First, purging.\n";
    $self->removeSRMExperiment(
      SEL_run_id => ${SEL_run_id},
      keep_experiments_and_runs => 1,
      verbose => $VERBOSE,
      quiet => $QUIET,
      testonly => $TESTONLY,
      debug => $DEBUG,
    );
  }


### Read through spectrum file and collect all the transitions measured.
  my $tx_measured_href =
  $self->collect_tx_from_spectrum_file (
    spectrum_filepath => $spectrum_filepath,
  );

### Read mQuest peakgroup file; store scores in mpro hash
  my $mpro_href = {};
  if ($mquest_file) {
    $self->read_mquest_peakgroup_file (
      mquest_file => $mquest_file,
      spec_file_basename => $spec_file_basename,
      mpro_href => $mpro_href,
      special_expt => $special_expt,
      verbose => $VERBOSE,
      quiet => $QUIET,
      testonly => $TESTONLY,
      debug => $DEBUG,
    );
  } else {
    print "No mQuest file given.\n" if ($VERBOSE);
  }

### Read mProphet peakgroup file; store scores in mpro hash
  if ($mpro_file) {
    $self->read_mprophet_peakgroup_file (
      mpro_file => $mpro_file,
      spec_file_basename => $spec_file_basename,
      mpro_href => $mpro_href,
      special_expt => $special_expt,
      verbose => $VERBOSE,
      quiet => $QUIET,
      testonly => $TESTONLY,
      debug => $DEBUG,
    );
  } else {
    print "No mProphet file given.\n" if ($VERBOSE);
  }

### Read transition file; store info in transdata hash.
  my $transdata_href = $self->read_transition_list(
    transition_file => $transition_file,
    tr_format => $tr_format,
    ataqs => $ataqs,
    special_expt => $special_expt,
    verbose => $VERBOSE,
    quiet => $QUIET,
    testonly => $TESTONLY,
    debug => $DEBUG,
  );

### Map transition file data to spectrum file data to get a list of
### transition groups included in both.
  my $tx_map_href = $self->map_transition_data_to_spectrum_file_data (
    transdata_href => $transdata_href,
    tx_measured_href => $tx_measured_href,
    q1_tolerance => $q1_tolerance,
    q3_tolerance => $q3_tolerance,
    mult_tg_per_q1 => $mult_tg_per_q1,
    verbose => $VERBOSE,
    quiet => $QUIET,
    testonly => $TESTONLY,
    debug => $DEBUG,
  );

### Transfer mquest/mprophet scores into transdata hash
  if ($mpro_file || $mquest_file) {
    $self->store_mprophet_scores_in_transition_hash (
      spec_file_basename => $spec_file_basename,
      transdata_href => $transdata_href,
      tx_map_href => $tx_map_href,
      mpro_href => $mpro_href,
      verbose => $VERBOSE,
      quiet => $QUIET,
      testonly => $TESTONLY,
      debug => $DEBUG,
    );
  } else {
    print "No mProphet or mQuest file given; no scores loaded.\n" if ($VERBOSE);
  }

### Load transition data into database. 
  $self->load_transition_data (
    SEL_run_id => $SEL_run_id,
    transdata_href => $transdata_href,
    tx_measured_href => $tx_measured_href,
    tx_map_href => $tx_map_href,
    q1_tolerance => $q1_tolerance,
    q3_tolerance => $q3_tolerance,
    load_peptide_ions => $load_peptide_ions,
    load_transition_groups => $load_transition_groups,
    load_transitions => $load_transitions,
    load_chromatograms => $load_chromatograms,
    load_scores_only => $load_scores_only,
    verbose => $VERBOSE,
    quiet => $QUIET,
    testonly => $TESTONLY,
    debug => $DEBUG,
  );

}
