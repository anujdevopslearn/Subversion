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

use List::Util qw[min max];

use SBEAMS::Connection qw($log);
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::Settings;
use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::PeptideAtlas::Annotations;
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
# collect_q1s_from_spectrum_file
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
# get_SEL_run_id
###############################################################################

sub get_SEL_run_id {
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $spec_file_basename = $args{spec_file_basename};

  my $sql = qq~
    SELECT SEL_run_id FROM $TBAT_SEL_RUN SELR
   WHERE SELR.spectrum_filename LIKE '$spec_file_basename.%';
  ~;
  my @run_ids = $sbeams->selectOneColumn($sql);
  my $n_run_ids = scalar @run_ids;
  if (! $n_run_ids) {
    die "No entry in SEL_run matches spectrum file basename ${spec_file_basename}.";
  } elsif ($n_run_ids > 1) {
    die "More than one SEL_run record matches ${spec_file_basename}.";
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
# read_mprophet_peakgroup_file
###############################################################################

sub read_mprophet_peakgroup_file {
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $mpro_file  = $args{mpro_file};
  my $spec_file_basename = $args{spec_file_basename};
  my $special_expt = $args{special_expt};
  my $VERBOSE = $args{'verbose'} || 0;
  my $QUIET = $args{'quiet'} || 0;
  my $TESTONLY = $args{'testonly'} || 0;
  my $DEBUG = $args{'debug'} || 0;

#peakgroup_id
#pg_ALYYDLISSPDIHGTYK.3_0_target_0
#pg_ALYYDLISSPDIHGTYK.3_0_target_3

#peak_group_id
#Seattle_peps_RT_posCon_decoy_recal_01.mzXML ALYYDLISSPDIHGTYK.3 0 1
#Seattle_peps_RT_posCon_decoy_recal_01.mzXML ALYYDLISSPDIHGTYK.3 0 3

#transition_group_record decoy   mrm_prophet_score
#VPFLPGDSDLDQLTR_5       FALSE   1.40132731713868


  # First, set up a universal lookup table of possible header strings
  # We store it this way because it's easy to read and maintain.
  my %possible_headers = (
       log10_max_apex_intensity => [ qw( log10_max_apex_intensity ) ],
                          decoy => [ qw( decoy ) ],
                        protein => [ qw( protein ) ],
                  peak_group_id => [ qw( peak_group_id ) ],
                   peakgroup_id => [ qw( peakgroup_id ) ],
                        m_score => [ qw( m_score ) ],
			#mrm_prophet_score is from M-Y's file for Ulli's data
                        d_score => [ qw( d_score mrm_prophet_score ) ],
                      file_name => [ qw( file_name ) ],  # Ruth 2011 only
        transition_group_pepseq => [ qw( transition_group_pepseq ) ], #Ruth 2011
        # I think the record below is simply a result of M-Y creating custom file
        transition_group_record => [ qw( transition_group_record ) ], #Ulli
		             Tr => [ qw( tr ) ],  # Ruth 2011 only?
  );

  # Now reverse the direction of the hash to make it easier to use.
  my %header_lookup;
  for my $header (keys %possible_headers) {
    for my $s (@{$possible_headers{$header}}) {
      $header_lookup{$s} = $header;
      #print "header_lookup for $s is $header\n";
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

    # if this header is recognized ...
    if ($header = $header_lookup{ lc $field }) {
      $idx{$header} = $i;
      print "idx for $header is $i\n" if ($DEBUG);
    }
    $i++;
  }

  ### Read and store each line of mProphet file
  ### NOTE!
  ### The mProphet file for Ruth_prelim contains one line per peakgroup.
  ### The one for Ruth's 2011 data contains only one line per pep, for the top
  ### peakgroup! This code seems to stumble along for both.
  print "Processing mProphet file!\n" if ($VERBOSE);
  my ($decoy, $log10_max_apex_intensity, $protein,  $stripped_pepseq, $modified_pepseq,
    $charge, $peak_group,  $m_score, $d_score, $Tr);

  my $mpro_href;
  my $spectrum_file;
  while ($line = <MPRO_FILE>) {
    chomp $line;
    @fields = split('\t', $line);
    $log10_max_apex_intensity = (defined $idx{log10_max_apex_intensity}) ?
         $fields[$idx{log10_max_apex_intensity}] : 0 ;
    $protein = (defined $idx{protein}) ? $fields[$idx{protein}] : '' ;
    $Tr = (defined $idx{Tr}) ? $fields[$idx{Tr}] : 0 ;  #retention time for best peak group

    #if ($special_expt eq 'ruth_prelim') {
    if ( defined $idx{peak_group_id} ) {  # Ruth
      $_ = $fields[$idx{peak_group_id}]; #this field has 5 bits of info!
      ($spectrum_file, $modified_pepseq, $charge, $decoy, $peak_group) =
             /(\S+) (\S+?)\.(\S+) (\d) (\d+)/;
    #} elsif ($special_expt eq 'ruth_2011') {
    } elsif ( defined $idx{peakgroup_id} ) {  # Can we rely on this, omit prev?
                                             # we never get here; test is same as
					     # previous test!
      $_ = $fields[$idx{peakgroup_id}]; #this field has 5 bits of info as well!
      my $dummy;
      ($stripped_pepseq, $charge, $decoy, $dummy, $peak_group) =
            /pg_(\S+?)\.(\d)_(\d)_target_(dummy)?(\d)/;
      $modified_pepseq = $fields[$idx{transition_group_pepseq}];
      $spectrum_file = $fields[$idx{file_name}] . ".mzXML";

    } elsif ( defined $idx{transition_group_record} ) {   #Ulli's data
      $spectrum_file = "${spec_file_basename}.mzXML";

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
      $decoy = ( $fields[$idx{decoy}] =~ /TRUE/ );
      $decoy = 0 if (!$decoy);
      $modified_pepseq = $stripped_pepseq;
      #print "$modified_pepseq $suffix\n";
    }

    if ($charge =~ /decoy/) {
      $charge =~ /(\S+)\.decoy/;
      $charge = $1;
    };

    $peak_group = 1 if (! $peak_group); #temporary?

    $spectrum_file =~ /(\S+)\.\S+/;
    my $this_file_basename = $1;

    print "$this_file_basename, $modified_pepseq, $charge, $decoy, $peak_group\n" if ($VERBOSE)>1;
    my ($m_score, $d_score);
    $m_score =  $fields[$idx{m_score}] if (defined $idx{m_score});
    $d_score =  $fields[$idx{d_score}] if (defined $idx{d_score});

    # 06/15/11: removed check for !$decoy from below -- why did I have it?
    if ($this_file_basename && $modified_pepseq && (defined $peak_group)) {
      my @chargelist;
      if ($charge) {
	@chargelist = ($charge);
      } else {
        @chargelist = (1, 2, 3);
      }
      for my $charge (@chargelist) {
	$mpro_href->{$this_file_basename}->{$modified_pepseq}->{$charge}->{$decoy}->{$peak_group}->{log10_max_apex_intensity} = $log10_max_apex_intensity;
	$mpro_href->{$this_file_basename}->{$modified_pepseq}->{$charge}->{$decoy}->{$peak_group}->{protein} = $protein; #probably unnecessary
	$mpro_href->{$this_file_basename}->{$modified_pepseq}->{$charge}->{$decoy}->{$peak_group}->{m_score} = $m_score;
	$mpro_href->{$this_file_basename}->{$modified_pepseq}->{$charge}->{$decoy}->{$peak_group}->{d_score} = $d_score;
	$mpro_href->{$this_file_basename}->{$modified_pepseq}->{$charge}->{$decoy}->{$peak_group}->{Tr} = $Tr;
	print 'Storing $mpro_href->{',$this_file_basename,'}->{',$modified_pepseq,'}->{',$charge,'}->{',$decoy,'}->{',$peak_group,'}->{m_score} = ', $mpro_href->{$this_file_basename}->{$modified_pepseq}->{$charge}->{$decoy}->{$peak_group}->{m_score}, "\n" if ($VERBOSE > 1);
	print 'Storing $mpro_href->{',$this_file_basename,'}->{',$modified_pepseq,'}->{',$charge,'}->{',$decoy,'}->{',$peak_group,'}->{Tr} = ', $mpro_href->{$this_file_basename}->{$modified_pepseq}->{$charge}->{$decoy}->{$peak_group}->{Tr}, "\n" if ($VERBOSE > 1);
	print 'Storing $mpro_href->{',$this_file_basename,'}->{',$modified_pepseq,'}->{',$charge,'}->{',$decoy,'}->{',$peak_group,'}->{log10_max_apex_intensity} = ', $mpro_href->{$this_file_basename}->{$modified_pepseq}->{$charge}->{$decoy}->{$peak_group}->{log10_max_apex_intensity}, "\n" if ($VERBOSE > 1);
      }
    } else {
      print "Not storing mProphet scores. file_basename = $this_file_basename modified_pepseq = $modified_pepseq decoy = $decoy peak_group = $peak_group\n" if ($VERBOSE > 1);
    }
  }
  return $mpro_href;
}

###############################################################################
# read_transition_list -- return infos about transitions in a hash
###############################################################################
sub read_transition_list {
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $transition_file  = $args{transition_file};
  my $tr_format = $args{tr_format};
  my $ataqs = $args{ataqs};
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

#--------------------------------------------------
#     mQuest:
#     Q1      Q3      dwelltime       Tr_recalibrated
#     transition_group_id     CE      protein_name    relative_intensity
#     transition_name decoy   stripped_sequence       mod     isotype
#     prec_z
#             frg_type        frg_nr  frg_z   DP      Tr_original     RT
# 	    c1      c3      dataset mod_seq organism
# 	    target_decoy_transition_group_id        decoy_algorithm
#-------------------------------------------------- 


    my %possible_headers = (
			   q1_mz => [ qw( q1 q1_mz ), ],
			   q3_mz => [ qw( q3 q3_mz ), ],
			      ce => [ qw( ce ), ],
			      rt => [ qw( rt ), ],
		    protein_name => [ qw( protein_name protein ), 'protein ipi' ],
	       stripped_sequence => [ qw( stripped_sequence sequence peptide_seq peptide ) ],
			 isotype => [ qw( isotype heavy/light modified ) ],
			  prec_z => [ qw( prec_z q1_z ), 'q1 z',  ],
			frg_type => [ qw( frg_type ), 'fragment type', 'ion type' ],
			  frg_nr => [ qw( frg_nr ), 'ion number',  ],
			   frg_z => [ qw( frg_z ), 'q3 z',  ],
      trfile_transition_group_id => [ qw( transition_group_id ) ],
		    modification => [ qw( modification modified_sequence ) ],
	      relative_intensity => [ qw( relative_intensity intensity ) ],
		  intensity_rank => [ qw( ), 'intensity rank',  ],
		        is_decoy => [ qw( decoy ), ],
    );

    # Now reverse the direction of the hash to make it easier to use.
    my %header_lookup;
    for my $header (keys %possible_headers) {
      for my $s (@{$possible_headers{$header}}) {
	$header_lookup{$s} = $header;
      }
    }

    # Finally, associate each header string with its position in this particular
    # transition file.
    my $line = <TRAN_FILE>;
    chomp $line;
    my @fields = split($sep, $line);
    my $i = 0;
    for my $field (@fields) {
      my $header;
      # if this header is recognized ...
      if ($header = $header_lookup{lc $field}) {
	$idx{$header} = $i;
      }
      $i++;
    }
  } # end read transition file header

  
  ### Read and store each line of transition file
  my $transdata_href;
  my  $modified_peptide_sequence;

  print "Processing transition file!\n" if ($VERBOSE);
  while (my $line = <TRAN_FILE>) {
    # Store select fields into transdata_href hash
    # and load into SEL_transitions and SEL_transition_groups, if requested.
    my @fields = split($sep, $line);
    my $q1_mz = $fields[$idx{q1_mz}];
    my $q3_mz = $fields[$idx{q3_mz}];
    $transdata_href->{$q1_mz}->{collision_energy} = $fields[$idx{ce}]
        if defined $idx{ce};
    $transdata_href->{$q1_mz}->{protein_name} = $fields[$idx{protein_name}]
        if defined $idx{protein_name};

    # Skip these; retention time peptides that are sold by Biognosys
    next if ( ($special_expt =~ /ruth/) &&
              ($transdata_href->{$q1_mz}->{protein_name} =~ /Tr_peps_set/) );

    my $stripped_sequence = $fields[$idx{stripped_sequence}]
        if defined $idx{stripped_sequence};
    $transdata_href->{$q1_mz}->{stripped_peptide_sequence} = $stripped_sequence;
    $transdata_href->{$q1_mz}->{isotype} = $fields[$idx{isotype}]
        if defined $idx{isotype};
    if ($ataqs && ( defined $idx{ataqs_modstring} ) ) {
      if ($fields[$idx{ataqs_modstring}] =~ /AQUA/) {
	$transdata_href->{$q1_mz}->{isotype} = 'heavy'
      } else {
	$transdata_href->{$q1_mz}->{isotype} = 'light'
      }
    }
    $transdata_href->{$q1_mz}->{peptide_charge} = $fields[$idx{prec_z}]
        if defined $idx{prec_z};
    $transdata_href->{$q1_mz}->{transitions}->{$q3_mz}->{frg_type} =
        $fields[$idx{frg_type}] if defined $idx{frg_type};
    $transdata_href->{$q1_mz}->{transitions}->{$q3_mz}->{frg_nr} =
        int($fields[$idx{frg_nr}]) if defined $idx{frg_nr};
    $transdata_href->{$q1_mz}->{transitions}->{$q3_mz}->{frg_z} =
        int($fields[$idx{frg_z}]) if defined $idx{frg_z};
    $transdata_href->{$q1_mz}->{transitions}->{$q3_mz}->{is_decoy} =
        ( (defined $idx{is_decoy}) && $fields[$idx{is_decoy}] ) ||
	  ( uc($stripped_sequence) =~ /^[KR]/)  # reverse pepseq. Ulli's data.
	  || 0;
    if (($idx{relative_intensity}) && $fields[$idx{relative_intensity}]) {
      $transdata_href->{$q1_mz}->{transitions}->{$q3_mz}->{relative_intensity} =
						  $fields[$idx{relative_intensity}];
    # transform intensity rank to relative intensity by taking inverse
    } elsif (($idx{intensity_rank}) && $fields[$idx{intensity_rank}]) {
      my $relative_intensity;
      if ($fields[$idx{intensity_rank}]) {
	$transdata_href->{$q1_mz}->{transitions}->{$q3_mz}->{relative_intensity} =
						  1/$fields[$idx{intensity_rank}];
      } else {
	$transdata_href->{$q1_mz}->{transitions}->{$q3_mz}->{relative_intensity} = 0;
      }
    }

    # Get modified peptide sequence, needed for reading mProphet file.
    # For Ruth's preliminary data, extract from transition group id
    if ($special_expt eq 'ruth_prelim') {
      my $trfile_transition_group_id = $fields[$idx{trfile_transition_group_id}];
      print $trfile_transition_group_id, "\n" if ($VERBOSE > 2);
      $trfile_transition_group_id =~ /^(\S+)\./;
      $transdata_href->{$q1_mz}->{modified_peptide_sequence} = $1;
      $transdata_href->{$q1_mz}->{modified_peptide_sequence} =~
          s/B/C\[160\]/g;
    # Else, check for modified sequence in its own field
    } elsif (defined $idx{modification}) {
      $transdata_href->{$q1_mz}->{modified_peptide_sequence} =
		$fields[$idx{modification}];
      if ($special_expt eq 'ruth_2011') {
	$transdata_href->{$q1_mz}->{modified_peptide_sequence} =~
	s/\[C160\]/C\[160\]/g;
      }
    # Else, take the stripped sequence (even if null).
    } else {
      $transdata_href->{$q1_mz}->{modified_peptide_sequence} =
		$stripped_sequence;
    }

    # If there is a modified pepseq but no stripped, strip.
    if ( $transdata_href->{$q1_mz}->{modified_peptide_sequence} &&
         ( ! $transdata_href->{$q1_mz}->{stripped_peptide_sequence} )) {
      my $modseq = 
	   $transdata_href->{$q1_mz}->{modified_peptide_sequence};
      $transdata_href->{$q1_mz}->{stripped_peptide_sequence} =
	SBEAMS::PeptideAtlas::Annotations::strip_mods($modseq);
    }

    print "$transdata_href->{$q1_mz}->{stripped_peptide_sequence} $transdata_href->{$q1_mz}->{modified_peptide_sequence} +$transdata_href->{$q1_mz}->{peptide_charge} q1=$q1_mz q3=$q3_mz\n"
       if ($VERBOSE > 1);

  }
  return $transdata_href;
}

###############################################################################
# store_mquest_scores_in_transition_hash
###############################################################################

sub store_mquest_scores_in_transition_hash {
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $mpro_href = $args{mpro_href};
  my $transdata_href = $args{transdata_href};
  my $spec_file_basename = $args{spec_file_basename};
  my $VERBOSE = $args{'verbose'} || 0;
  my $QUIET = $args{'quiet'} || 0;
  my $TESTONLY = $args{'testonly'} || 0;
  my $DEBUG = $args{'debug'} || 0;

  print "Getting the mProphet scores for each transition group!\n" if ($VERBOSE);

  for my $q1_mz (keys %{$transdata_href}) {
    # Grab the mProphet score(s) for each transition group.
    my $modified_pepseq = $transdata_href->{$q1_mz}->{modified_peptide_sequence};
    my $charge = $transdata_href->{$q1_mz}->{peptide_charge};
    my $decoy = 0;
    print "Getting mProphet scores for $spec_file_basename, $modified_pepseq, $charge, $decoy\n"
      if ($VERBOSE > 1);
    # For Ruth 2011 expt., mProphet file gives scores for only top peakgroup,
    # but for ruth_prelim it gives scores for all peakgroups.
    # Store them all.
    my $best_m_score = 0;
    my $best_d_score = 0;
    my $Tr = 0;
    my $log10_max_apex_intensity = 0;
    for my $pg (keys %{$mpro_href->{$spec_file_basename}->{$modified_pepseq}->{$charge}->{$decoy}} ) {
      my $m_score = $mpro_href->{$spec_file_basename}->{$modified_pepseq}->{$charge}->{$decoy}->{$pg}->{m_score};
      my $d_score = $mpro_href->{$spec_file_basename}->{$modified_pepseq}->{$charge}->{$decoy}->{$pg}->{d_score};
      #print "Found m_score $m_score\n" if ($VERBOSE > 2);
      $log10_max_apex_intensity = $mpro_href->{$spec_file_basename}->{$modified_pepseq}->{$charge}->{$decoy}->{$pg}->{log10_max_apex_intensity};
      $Tr = $mpro_href->{$spec_file_basename}->{$modified_pepseq}->{$charge}->{$decoy}->{$pg}->{Tr};
      $transdata_href->{$q1_mz}->{peak_groups}->{$pg}->{m_score} = $m_score;
      if ($m_score) {
	if (!$best_m_score || (abs($m_score) < abs($best_m_score))) {
	  $best_m_score = $m_score;
	  $best_d_score = $d_score;
	}
	print '$mpro_href->{',$spec_file_basename,'}->{',$modified_pepseq,'}->{',$charge,'}->{',$decoy,'}->{',$pg,'}->{m_score} = ', $m_score, "\n" if ($VERBOSE > 1);
      } else {
	print 'No m_score for $mpro_href->{',$spec_file_basename,'}->{',$modified_pepseq,'}->{',$charge,'}->{',$decoy,'}->{',$pg,'}->{m_score}', "\n"  if ($VERBOSE > 1);
      }
    }
    # Store the max m_score. Store the most recent Tr, intensity (they should all be identical).
    $transdata_href->{$q1_mz}->{best_m_score} = $best_m_score;
    $transdata_href->{$q1_mz}->{best_d_score} = $best_d_score;
    #print "Storing best_m_score $best_m_score\n" if ($VERBOSE > 2);
    $transdata_href->{$q1_mz}->{Tr} = $Tr;
    $transdata_href->{$q1_mz}->{log10_max_apex_intensity} = $log10_max_apex_intensity;
  }
}

###############################################################################
# store_mprophet_scores_in_transition_hash
###############################################################################

sub store_mprophet_scores_in_transition_hash {
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $mpro_href = $args{mpro_href};
  my $transdata_href = $args{transdata_href};
  my $spec_file_basename = $args{spec_file_basename};
  my $VERBOSE = $args{'verbose'} || 0;
  my $QUIET = $args{'quiet'} || 0;
  my $TESTONLY = $args{'testonly'} || 0;
  my $DEBUG = $args{'debug'} || 0;

  print "Getting the mProphet scores for each transition group!\n" if ($VERBOSE);

  # For each measured Q1
  for my $q1_mz (keys %{$transdata_href}) {
    # Grab the mProphet score(s) for this Q1's transition group.
    my $modified_pepseq = $transdata_href->{$q1_mz}->{modified_peptide_sequence};
    my $charge = $transdata_href->{$q1_mz}->{peptide_charge};
    my $decoy = 0;
    print "Getting mProphet scores for $spec_file_basename, $modified_pepseq, $charge, $decoy\n"
      if ($VERBOSE > 1);
    # For Ruth 2011 expt., mProphet file gives scores for only top peakgroup,
    # but for ruth_prelim it gives scores for all peakgroups.
    # Store them all.
    my $best_m_score = 0;
    my $Tr = 0;
    my $log10_max_apex_intensity = 0;
    # For each peak_group we have info on, get the scores.
    for my $pg (keys %{$mpro_href->{$spec_file_basename}->{$modified_pepseq}->{$charge}->{$decoy}} ) {
      my $m_score = $mpro_href->{$spec_file_basename}->{$modified_pepseq}->{$charge}->{$decoy}->{$pg}->{m_score};
      #print "Found m_score $m_score\n" if ($VERBOSE > 2);
      $log10_max_apex_intensity = $mpro_href->{$spec_file_basename}->{$modified_pepseq}->{$charge}->{$decoy}->{$pg}->{log10_max_apex_intensity};
      $Tr = $mpro_href->{$spec_file_basename}->{$modified_pepseq}->{$charge}->{$decoy}->{$pg}->{Tr};
      $transdata_href->{$q1_mz}->{peak_groups}->{$pg}->{m_score} = $m_score;
      # Keep the m_score for the highest scoring peakgroup (should be #1)
      # There's funny business here due to mix-up of d_score/m_score. Can
      #  be simplified!
      if ($m_score) {
	if (!$best_m_score || (abs($m_score) < abs($best_m_score))) { $best_m_score = $m_score; }
	print '$mpro_href->{',$spec_file_basename,'}->{',$modified_pepseq,'}->{',$charge,'}->{',$decoy,'}->{',$pg,'}->{m_score} = ', $m_score, "\n" if ($VERBOSE > 1);
      } else {
	print 'No m_score for $mpro_href->{',$spec_file_basename,'}->{',$modified_pepseq,'}->{',$charge,'}->{',$decoy,'}->{',$pg,'}->{m_score}', "\n"  if ($VERBOSE > 1);
      }
    }
    # Store the max m_score. Store the most recent Tr, intensity (they should all be identical).
    $transdata_href->{$q1_mz}->{scores}->{$decoy}->{best_m_score} = $best_m_score;
    #print "Storing best_m_score $best_m_score\n" if ($VERBOSE > 2);
    $transdata_href->{$q1_mz}->{scores}->{$decoy}->{Tr} = $Tr;
    $transdata_href->{$q1_mz}->{scores}->{$decoy}->{log10_max_apex_intensity} =
          $log10_max_apex_intensity;
  }
}


###############################################################################
# map_peps_to_swissprot
###############################################################################
 
sub map_peps_to_swissprot {
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $SEL_experiment_id = $args{'SEL_experiment_id'};
  my $glyco = $args{'glyco'};
  my $VERBOSE = $args{'verbose'} || 0;
  my $QUIET = $args{'quiet'} || 0;
  my $TESTONLY = $args{'testonly'} || 0;
  my $DEBUG = $args{'debug'} || 0;

  print "Mapping peptides to Swiss-Prot identifiers!\n" if ($VERBOSE);

  # Get organism ID for this experiment
  my $sql = qq~
  SELECT S.organism_id FROM $TBAT_SEL_EXPERIMENT SELE
  JOIN $TBAT_SAMPLE S
  ON S.sample_id = SELE.sample_id
  WHERE SELE.SEL_experiment_id = '$SEL_experiment_id'
  ~;
  my ($organism_id) = $sbeams->selectOneColumn($sql);
  if (! defined $organism_id ) {
    print "map_peps_to_swissprot: No organism ID for experiment ${SEL_experiment_id}.\n";
    return;
  }

  # Get ID for latest BSS for this organism
  my $sql = qq~
  SELECT BSS.biosequence_set_id FROM $TBAT_BIOSEQUENCE_SET BSS
  WHERE BSS.organism_id = '$organism_id';
  ~;
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

  # Read all Swiss-Prot entries in this organism's latest biosequence set
  # into a hash according to protein sequence. Store accession(s) and,
  # optionally, biosequence_id for each seq in the hash.
  my $prots_href = read_prots_into_hash (
    prot_file => $set_path,
    store_biosequence_id => 0,
    verbose => $VERBOSE,
    quiet => $QUIET,
    testonly => $TESTONLY,
    debug => $DEBUG,
  );
  my @biosequences = keys %{$prots_href};
  my $n_bss = scalar @biosequences;

  # Create a hash of all peptide ions in this experiment,
  # mapping peptide sequence to SEL_peptide_ion_id
  my $sql = qq~
  SELECT SELPI.stripped_peptide_sequence, SELPI.SEL_peptide_ion_id 
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


  # For each pepseq, use grep to map to prots.
  # Store mapping in $peps_href.
  print "Using grep to map each pep to its prots.\n" if $VERBOSE;
  for my $pepseq (@pepseqs) {
    print "Mapping $pepseq\n" if $VERBOSE;

    map_pep_to_prots(
      pepseq => $pepseq,
      prots_href => $prots_href,
      peps_href => $peps_href,
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
    for my $SEL_peptide_ion_id
	(split (/,/, $peps_href->{$pepseq}->{SEL_peptide_ion_ids_string} )) {
	  print " SEL_peptide_ion_id $SEL_peptide_ion_id\n" if $VERBOSE;
      # For each protein the peptide maps to
      # Cima/Schiess data -- we are not getting any acc's here!
      print "   acc string: $peps_href->{$pepseq}->{accessions_string}\n"
        if ($VERBOSE > 2);
      for my $acc (split ( /,/, $peps_href->{$pepseq}->{accessions_string} ) ) {
	print "  accession $acc\n" if $VERBOSE;
	my $rowdata_ref;
	$rowdata_ref->{protein_accession} = $acc;
	$rowdata_ref->{SEL_peptide_ion_id} = $SEL_peptide_ion_id;

	# See if this mapping is already loaded
	my $sql = qq~
	SELECT * FROM $TBAT_SEL_PEPTIDE_ION_PROTEIN
	WHERE protein_accession = '$acc'
	AND SEL_peptide_ion_id = '$peps_href->{$pepseq}->{SEL_peptide_ion_id}'
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



###############################################################################
# find_q1_in_list -- true if q1 is found in list, within a tolerance window
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
# load_transition_data -- load data for this run into SBEAMS database
###############################################################################
sub load_transition_data {
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $SEL_run_id = $args{SEL_run_id};
  my $transdata_href = $args{transdata_href};
  my $q1_measured_aref = $args{q1_measured_aref};
  my $spec_file_basename = $args{spec_file_basename};
  my $load_chromatograms = $args{load_chromatograms};
  my $load_transitions = $args{load_transitions};
  my $load_peptide_ions = $args{load_peptide_ions};
  my $load_transition_groups = $args{load_transition_groups};
  my $VERBOSE = $args{'verbose'} || 0;
  my $QUIET = $args{'quiet'} || 0;
  my $TESTONLY = $args{'testonly'} || 0;
  my $DEBUG = $args{'debug'} || 0;

  my $rowdata_ref;
  my $calculator = new SBEAMS::Proteomics::PeptideMassCalculator;

  print "Loading data into SBEAMS!\n" if ($VERBOSE);

#--------------------------------------------------
#   # Get SEL_run_id from spectrum_filename
#   my $sql = qq~
#     SELECT SEL_run_id FROM $TBAT_SEL_RUN SELR
#    WHERE SELR.spectrum_filename LIKE '$spec_file_basename.%';
#   ~;
#   my ($SEL_run_id) = $sbeams->selectOneColumn($sql);
#-------------------------------------------------- 

  # For each Q1 in the transition list
  for my $q1_mz (keys %{$transdata_href}) {

    # Skip if not actually measured in run currently being loaded.
    # Happens frequently if one transition list serves for multiple runs.
    my $was_scanned = find_q1_in_list (
      q1_mz=>$q1_mz,
      list_aref=>$q1_measured_aref,
      tol=>0.005,
    );
    if ( ! $was_scanned) {
      print "Q1 $q1_mz does not appear in this spectrum file.\n" if ($VERBOSE);
      next;
    }

    # See if this peptide ion was measured as a decoy and/or as a real pep.
    my @q3_list = keys %{$transdata_href->{$q1_mz}->{transitions}};
    my $q3_decoy_aref = [];
    my $q3_real_aref = [];
    my $measured_as_decoy = 0;
    my $measured_as_real = 0;
    # For all the Q3s for this Q1, see if decoy or real.
    for my $q3_mz (@q3_list) {
      if ($transdata_href->{$q1_mz}->{transitions}->{$q3_mz}->{is_decoy}) {
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

	# Load peptide ion, if not already loaded. One peptide ion per
	#  modified_peptide_sequence + peptide_charge + is_decoy.
	# Also store stripped_peptide_sequence, monoisotopic_peptide_mass (calculated),
	#  and Q1_mz (calculated)
	$rowdata_ref = {};  #reset
	$rowdata_ref->{stripped_peptide_sequence} =
	     $transdata_href->{$q1_mz}->{stripped_peptide_sequence};
	$rowdata_ref->{modified_peptide_sequence} = 
	     $transdata_href->{$q1_mz}->{modified_peptide_sequence};
	$rowdata_ref->{peptide_charge} = $transdata_href->{$q1_mz}->{peptide_charge};
	# In peptide_ion, store calculated m/z, not the one used in the transition list,
	#  because this ion might be used by several experiments.
	$rowdata_ref->{q1_mz} = $calculator->getPeptideMass(
	   sequence => $rowdata_ref->{modified_peptide_sequence},
	   mass_type => 'monoisotopic',
	   charge => $rowdata_ref->{peptide_charge},
	);
	$rowdata_ref->{monoisotopic_peptide_mass} = $calculator->getPeptideMass(
	   sequence => $rowdata_ref->{modified_peptide_sequence},
	   mass_type => 'monoisotopic',
	 );

	$rowdata_ref->{is_decoy} = $is_decoy_char;

	my $sql =qq~
	SELECT SEL_peptide_ion_id
	FROM $TBAT_SEL_PEPTIDE_ION
	WHERE stripped_peptide_sequence = '$rowdata_ref->{stripped_peptide_sequence}'
	AND q1_mz = '$rowdata_ref->{q1_mz}'
	AND is_decoy = 'rowdata_ref->{is_decoy}'
	~;

	my @existing_peptide_ions = $sbeams->selectOneColumn($sql);
	my $n_existing_pi = scalar @existing_peptide_ions;

	#print "$n_existing_pi $rowdata_ref->{stripped_peptide_sequence} $rowdata_ref->{q1_mz} $is_decoy_char\n";

	my $peptide_ion_id;
	if ( $load_peptide_ions && ! $n_existing_pi ) {
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
	    print "WARNING: multiple peptide ions found for q1
	    $rowdata_ref->{q1_mz}, $rowdata_ref->{stripped_peptide_sequence}, is_decoy = $is_decoy_char; using first\n" unless ($QUIET);
	    $peptide_ion_id = $existing_peptide_ions[0];
	  } elsif ($n_existing_pi == 0) {
	    print "ERROR: no peptide ion found for q1  $rowdata_ref->{q1_mz}, $rowdata_ref->{stripped_peptide_sequence}, is_decoy=$is_decoy_char\n";
	  } else  {
	    $peptide_ion_id = $existing_peptide_ions[0];
	    print "Peptide ion $peptide_ion_id (pepseq
	    $rowdata_ref->{stripped_peptide_sequence}, Q1 $rowdata_ref->{q1_mz}), is_decoy=$is_decoy_char  already loaded\n" if $VERBOSE > 2;
	  }
	}

	# Now, load transition group.
	# NEW. Don't need to check whether already loaded.
	$rowdata_ref = {};  #reset
	# NEW. Move the next three rows to above.
	#$rowdata_ref->{stripped_peptide_sequence} = $transdata_href->{$q1_mz}->{stripped_peptide_sequence};
	#$rowdata_ref->{modified_peptide_sequence} = $transdata_href->{$q1_mz}->{modified_peptide_sequence};
	#$rowdata_ref->{peptide_charge} = $transdata_href->{$q1_mz}->{peptide_charge};
	$rowdata_ref->{q1_mz} = $q1_mz;
	$rowdata_ref->{SEL_peptide_ion_id} = $peptide_ion_id;
	$rowdata_ref->{SEL_run_id} = $SEL_run_id;
	$rowdata_ref->{collision_energy} = $transdata_href->{$q1_mz}->{collision_energy};
	$rowdata_ref->{isotype} = $transdata_href->{$q1_mz}->{isotype};

	# Added 08/27/11
	$rowdata_ref->{m_score} = $transdata_href->{$q1_mz}->{scores}->{$is_decoy}->{best_m_score};
	$rowdata_ref->{d_score} = $transdata_href->{$q1_mz}->{scores}->{$is_decoy}->{best_d_score};
	$rowdata_ref->{max_apex_intensity} =
	  $transdata_href->{$q1_mz}->{scores}->{$is_decoy}->{log10_max_apex_intensity};
	if (! $rowdata_ref->{m_score} ) { $rowdata_ref->{m_score} = 'NULL' };
	if (! $rowdata_ref->{d_score} ) { $rowdata_ref->{d_score} = 'NULL' };
	if (! $rowdata_ref->{max_apex_intensity} ) { $rowdata_ref->{max_apex_intensity} = 'NULL' };

	# NEW. change to experiment_protein_name. 07/06/11: discovered that
	#  I accidentally changed the right side of the assignment to
	#  experiment_protein_name, as well. Changed back, but didn't test.
	$rowdata_ref->{experiment_protein_name} = $transdata_href->{$q1_mz}->{protein_name};
	# NEW. Compute fragment_ions string and store in field of same name. Like this ...
	my @ion_list;
	my @q3_list = $is_decoy ? @{$q3_decoy_aref} : @{$q3_real_aref} ;
	#my $n_q3 = scalar @q3_list;
	#print "$is_decoy $n_q3\n";
	for my $q3_mz (@q3_list) {
	  my $frg_href;
	  $frg_href->{frg_type} = $transdata_href->{$q1_mz}->{transitions}->{$q3_mz}->{frg_type};
	  $frg_href->{frg_nr} = $transdata_href->{$q1_mz}->{transitions}->{$q3_mz}->{frg_nr};
	  $frg_href->{frg_z} = $transdata_href->{$q1_mz}->{transitions}->{$q3_mz}->{frg_z};
	  $frg_href->{neutral_loss} = 0;
	  push (@ion_list, $frg_href);
	}
	my $fragment_ions = $self->encode_transition_group_list (tg_aref=>\@ion_list);
	$rowdata_ref->{fragment_ions} = $fragment_ions;

	# NEW. Moved this code to peptide_ion.
#    my $sql =qq~
#	SELECT SEL_transition_group_id
#	FROM $TBAT_SEL_TRANSITION_GROUP
#       WHERE stripped_peptide_sequence = '$rowdata_ref->{stripped_peptide_sequence}'
#	 AND q1_mz = '$rowdata_ref->{q1_mz}'
#	~;

#    my @existing_transition_groups = $sbeams->selectOneColumn($sql);
#    my $n_existing_tg = scalar @existing_transition_groups;

	# Load a SEL_transition_group record, or, if already loaded,
	# get its SEL_transition_group_id number.
	# NEW. Don't need to check whether already loaded.
	my $transition_group_id = 0;
	#if ( $load_transition_groups && ! $n_existing_tg ) 
	if ( $load_transition_groups ) {
	  $transition_group_id = $sbeams->updateOrInsertRow(
	    insert=>1,
	    table_name=>$TBAT_SEL_TRANSITION_GROUP,
	    rowdata_ref=>$rowdata_ref,
	    PK => 'SEL_transition_group_id',
	    return_PK => 1,
	    verbose=>$VERBOSE,
	    testonly=>$TESTONLY,
	  );
	}

	# Load a chromatogram record for this transition group

	$rowdata_ref = {};  #reset
	$rowdata_ref->{SEL_transition_group_id} = $transition_group_id;

	my $chromatogram_id = 0;
	if ($load_chromatograms) {
	  $chromatogram_id = $sbeams->updateOrInsertRow(
	    insert=>1,
	    table_name=>$TBAT_SEL_CHROMATOGRAM,
	    rowdata_ref=>$rowdata_ref,
	    PK => 'SEL_chromatogram_id',
	    return_PK => 1,
	    verbose => $VERBOSE,
	    testonly=> $TESTONLY,
	  );
	}

	# NEW. Load a peak group record for this chromatogram, if we have peak group infos.
	if ($load_chromatograms &&
	  (
	    #$transdata_href->{$q1_mz}->{scores}->{$is_decoy}->{best_m_score} ||
	    $transdata_href->{$q1_mz}->{scores}->{$is_decoy}->{Tr} ||
	    $transdata_href->{$q1_mz}->{scores}->{$is_decoy}->{log10_max_apex_intensity} )) {
	  $rowdata_ref = {};  #reset
	  $rowdata_ref->{SEL_chromatogram_id} = $chromatogram_id;
	  #$rowdata_ref->{m_score} = $transdata_href->{$q1_mz}->{scores}->{$is_decoy}->{best_m_score};
	  $rowdata_ref->{Tr} = $transdata_href->{$q1_mz}->{scores}->{$is_decoy}->{Tr};
	  $rowdata_ref->{max_apex_intensity} =
	    $transdata_href->{$q1_mz}->{scores}->{$is_decoy}->{log10_max_apex_intensity};
	  $rowdata_ref->{rank} = 1;  # will change when we load multiple peak groups
	  #if (! $rowdata_ref->{m_score} ) { $rowdata_ref->{m_score} = 'NULL' };
	  if (! $rowdata_ref->{Tr} ) { $rowdata_ref->{Tr} = 'NULL' };
	  if (! $rowdata_ref->{max_apex_intensity} ) { $rowdata_ref->{max_apex_intensity} = 'NULL' };

	  my $peak_group_id = 0;
	  $peak_group_id = $sbeams->updateOrInsertRow(
	    insert=>1,
	    table_name=>$TBAT_SEL_PEAK_GROUP,
	    rowdata_ref=>$rowdata_ref,
	    PK => 'SEL_peak_group_id',
	    return_PK => 1,
	    verbose => $VERBOSE,
	    testonly=> $TESTONLY,
	  );
	}


	# Now, finally, load a record for each transition for current decoy state
	# (q3_list contains only those transitions for this decoy state.)
	for my $q3_mz (@q3_list) {
	  $rowdata_ref = {};  #reset
	  $rowdata_ref->{SEL_transition_group_id} = $transition_group_id;
	  $rowdata_ref->{q3_mz} = $q3_mz;
	  $rowdata_ref->{frg_type} =
	    $transdata_href->{$q1_mz}->{transitions}->{$q3_mz}->{frg_type};
	  $rowdata_ref->{frg_nr} =
	    $transdata_href->{$q1_mz}->{transitions}->{$q3_mz}->{frg_nr};
	  $rowdata_ref->{frg_z} =
	    $transdata_href->{$q1_mz}->{transitions}->{$q3_mz}->{frg_z};
	  $rowdata_ref->{relative_intensity} =
	    $transdata_href->{$q1_mz}->{transitions}->{$q3_mz}->{relative_intensity};

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

	  if ($n_existing_tr) {
	    $transition_id = $existing_transitions[0];
	    print "Transition $transition_id (TG_id $transition_group_id, Q3 $q3_mz) already loaded\n" if $VERBOSE > 2;
	  }
	  if ($load_transitions && ! $n_existing_tr) {
	    $transition_id = $sbeams->updateOrInsertRow(
	      insert=>1,
	      table_name=>$TBAT_SEL_TRANSITION,
	      rowdata_ref=>$rowdata_ref,
	      PK => 'SEL_transition_id',
	      return_PK => 1,
	      verbose => $VERBOSE,
	      testonly=> $TESTONLY,
	    );
	  }
	#print "  Loaded transition ID: $transition_id\n" if $VERBOSE > 2;
	} # end for each Q3 measured for this Q1 & decoy state
      } # end if this Q1 was measured for this decoy state
    } # end for each possible decoy state
  } # end for each Q1 in the transition list
}



###############################################################################
# removeSRMExperiment -- removes records for an SRM experiment
###############################################################################
sub removeSRMExperiment {
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $SEL_experiment_id = $args{'SEL_experiment_id'};
  my $keep_experiments_and_runs = $args{'keep_experiments_and_runs'} || 0;
  my $VERBOSE = $args{'verbose'} || 0;
  my $QUIET = $args{'quiet'} || 0;
  my $TESTONLY = $args{'testonly'} || 0;
  my $DEBUG = $args{'debug'} || 0;

  my $database_name = $DBPREFIX{PeptideAtlas};

   # First, get SEL_runs in this experiment.
   my $sql = qq~
     SELECT SEL_run_id
       FROM $TBAT_SEL_RUN 
     WHERE SEL_experiment_id = $SEL_experiment_id
   ~;
   my @run_ids = $sbeams->selectOneColumn($sql);
   my $run_id_string = join (",", @run_ids);

   # Next, get SEL_peptide_ion records that belong
   # to this experiment, and turn the list into a SQL format string.
   $sql = qq~
     SELECT SELPI.SEL_peptide_ion_id
       FROM $TBAT_SEL_PEPTIDE_ION SELPI
       JOIN $TBAT_SEL_TRANSITION_GROUP SELTG
         ON SELTG.SEL_peptide_ion_id = SELPI.SEL_peptide_ion_id
      WHERE SELTG.SEL_run_id in ($run_id_string)
   ~;
   my @peptide_ion_ids = $sbeams->selectOneColumn($sql);
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
     print "Purging experiment $SEL_experiment_id; keeping expt & run records.\n" if $VERBOSE;

     #don't delete experiment OR run records
     delete $table_child_relationship{SEL_EXPERIMENT};
     $sbeams->deleteRecordsAndChildren(
       table_name => 'SEL_run',
       table_child_relationship => \%table_child_relationship,
       delete_PKs => \@run_ids,
       delete_batch => 1000,
       database => $database_name,
       verbose => $VERBOSE,
       testonly => $TESTONLY,
       keep_parent_record => 1,
    );
  } else {
     print "Purging experiment $SEL_experiment_id; removing expt & run records.\n" if $VERBOSE;
      $sbeams->deleteRecordsAndChildren(
         table_name => 'SEL_experiment',
         table_child_relationship => \%table_child_relationship,
         delete_PKs => [ $SEL_experiment_id ],
         delete_batch => 1000,
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

# Input: an unsorted list of hrefs (frg_type frg_nr frg_z neutral_loss)
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
    return -1 if ($a->{'neutral_loss'} < $b->{'neutral_loss'});
    return  1 if ($a->{'neutral_loss'} > $b->{'neutral_loss'});
    return 0;

    sub lower_frg_type {
      my $a = shift; my $b = shift;
      return 0 if (lc($a) eq lc($b));
      return 1 if (lc($a) eq 'y');
      return 0 if (lc($b) eq 'y');
      return 1 if (lc($a) eq 'b');
      return 0 if (lc($b) eq 'b');
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
    $encoded_tg .= "-$ion->{'neutral_loss'}" if ($ion->{'neutral_loss'} > 0);
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
  my $VERBOSE = $args{'verbose'} || 0;
  my $QUIET = $args{'quiet'} || 0;
  my $TESTONLY = $args{'testonly'} || 0;
  my $DEBUG = $args{'debug'} || 0;

  my $prots_href;
  my $line;
  my $acc;
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

    $line =~ s/[\r\n]+//g;
    if ($line =~ /\>/) {
      if ($line =~ /^>\s*(\S+)/) {
	my $next_acc = $1;
	if ( $current_seq &&     # check for Swiss-Prot accession
	    ( ( $acc =~ /^[ABOPQ]\w{5}$/ ) ||
	      ( $acc =~ /^[ABCOPQ]\w{5}-\d{1,2}$/ ) ) ) {
	  if ($prots_href->{$current_seq}) {
	    $prots_href->{$current_seq}->{accessions_string} .= ",$acc";
	  } else {
	    $prots_href->{$current_seq}->{accessions_string} = $acc;
	  }
	}
	$current_seq = '';
	$acc = $next_acc;
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
# map_pep_to_prots
###############################################################################
sub map_pep_to_prots {
  my %args = @_;
  my $pepseq = $args{'pepseq'};
  my $prots_href = $args{'prots_href'};
  my $peps_href = $args{'peps_href'};
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

  # Store the accessions of these as a list, in string format, in the peptide hash
  for my $match (@matches) {
    my @bs_ids = split (/,/, $prots_href->{$match}->{bs_ids_string});
    my @accessions = split (/,/, $prots_href->{$match}->{accessions_string});
    foreach my $acc (@accessions) {
      if ( defined $peps_href->{$pepseq}->{accessions_string} ) {
	 $peps_href->{$pepseq}->{accessions_string} .= ",$acc";
      } else {
	 $peps_href->{$pepseq}->{accessions_string} = "$acc";
      }
      print "   acc string: $prots_href->{$match}->{accessions_string}\n"
        if ($VERBOSE > 2);
    }
  }
}
