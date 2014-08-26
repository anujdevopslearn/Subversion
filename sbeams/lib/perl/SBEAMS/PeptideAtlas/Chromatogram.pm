package SBEAMS::PeptideAtlas::Chromatogram;

###############################################################################
# Class       : SBEAMS::PeptideAtlas::Chromatogram
# Author      : Terry Farrah <terry.farrah@systemsbiology.org>
#
=head1 SBEAMS::PeptideAtlas::Chromatogram

=head2 SYNOPSIS

  SBEAMS::PeptideAtlas::Chromatogram

=head2 DESCRIPTION

This is part of the SBEAMS::PeptideAtlas module which handles
things related to PeptideAtlas chromatograms

=cut
#
###############################################################################

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
require Exporter;
@ISA = qw();
$VERSION = q[$Id$];
@EXPORT_OK = qw();

#use lib "/users/tfarrah/perl/lib";

use SBEAMS::Connection qw( $log );
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::Settings;
use SBEAMS::PeptideAtlas::Tables;
#use IO::Uncompress;  # supercedes Compress::Zlib, but we don't have it.
use XML::TreeBuilder;   # a DOM parser
use XML::Writer; 
use Compress::Zlib;
use Data::Dumper;
use JSON;


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
# getChromatogramParameters: given a chromatogram_id, get a bunch
#   of params relevant to the chromatogram and store in parameters
#   hash
###############################################################################
sub getChromatogramParameters{
  my $self = shift;
  my %args = @_;
  my $SEL_chromatogram_id = $args{SEL_chromatogram_id};
  my $param_href = $args{param_href};

  my $sql = qq~
    SELECT distinct
	   SELR.spectrum_filename,
	   SELE.data_path,
	   SELPI.stripped_peptide_sequence,
	   SELPI.modified_peptide_sequence,
	   SELPI.monoisotopic_peptide_mass,
	   SELPI.peptide_charge,
	   SELTG.q1_mz as targeted_calculated_q1_mz,
	   SELTG.collision_energy,
	   SELTG.retention_time,
	   SELTG.isotype,
	   SELTG.experiment_protein_name,
	   SELPG.m_score,
	   SELPG.Tr,
	   SELPG.max_apex_intensity,
	   SELTG.SEL_transition_group_id,
	   SELE.experiment_title,
	   SELPI.is_decoy,
	   SELPI.q1_mz as calculated_q1_mz,
	   SELTG.isotype_delta_mass,
	   SELE.q1_tolerance,
	   SELE.q3_tolerance,
	   SELTG.S_N,
	   SELTG.light_heavy_ratio_maxapex
      FROM $TBAT_SEL_CHROMATOGRAM SELC
      JOIN $TBAT_SEL_TRANSITION_GROUP SELTG
	   ON ( SELTG.SEL_transition_group_id = SELC.SEL_transition_group_id )
      LEFT JOIN $TBAT_SEL_PEAK_GROUP SELPG
	   ON ( SELPG.SEL_chromatogram_id = SELC.SEL_chromatogram_id )
      LEFT JOIN $TBAT_SEL_PEPTIDE_ION SELPI
	   ON ( SELPI.SEL_peptide_ion_id = SELTG.SEL_peptide_ion_id )
      JOIN $TBAT_SEL_RUN SELR
	   ON ( SELR.SEL_run_id = SELTG.SEL_run_id )
      JOIN $TBAT_SEL_EXPERIMENT SELE
	   ON ( SELE.SEL_experiment_id = SELR.SEL_experiment_id )
     WHERE SELC.SEL_chromatogram_id = '$SEL_chromatogram_id'
     ;
  ~;
  #print "$sql<br>\n";
  my @rows = $sbeams->selectSeveralColumns( $sql );
  my $n_rows = scalar @rows;
  print "<P>ERROR: nothing returned for chromatogram_id $param_href->{'SEL_chromatogram_id'}.</P>\n"
     if ($n_rows == 0 );
  print "<P>WARNING: $n_rows rows of data returned for chromatogram $param_href->{'SEL_chromatogram_id'}! Only considering first.</P>\n"
     if ($n_rows > 1);
  my $results_aref = $rows[0];

  $param_href->{'spectrum_basename'} = $results_aref->[0];
  $param_href->{'spectrum_pathname'} = $results_aref->[1].'/'.$results_aref->[0];
  $param_href->{'pepseq'} = $results_aref->[2];
  $param_href->{'modified_pepseq'} = $results_aref->[3];
  $param_href->{'precursor_neutral_mass'} = $results_aref->[4];
  $param_href->{'precursor_charge'} = $results_aref->[5];
  $param_href->{'q1'} = $results_aref->[6];
  $param_href->{'ce'} = $results_aref->[7];
  $param_href->{'rt'} = $results_aref->[8] || 0;
  $param_href->{'isotype'} = $results_aref->[9];
  $param_href->{'protein_name'} = $results_aref->[10];
  $param_href->{'m_score'} = $results_aref->[11];
  $param_href->{'Tr'} = $results_aref->[12];
  $param_href->{'max_apex_intensity'} = $results_aref->[13];
  my $transition_group_id = $results_aref->[14];
  $param_href->{'transition_info'} =
      getTransitionInfo($transition_group_id);
  $param_href->{'experiment_title'} = $results_aref->[15];
  $param_href->{'is_decoy'} = $results_aref->[16];
  $param_href->{'calculated_q1'} = $results_aref->[17];
  $param_href->{'isotype_delta_mass'} = $results_aref->[18];
  $param_href->{'q1_tolerance'} = $results_aref->[19];
  $param_href->{'q3_tolerance'} = $results_aref->[20];
  $param_href->{'S_N'} = $results_aref->[21];
  $param_href->{'light_heavy_ratio_maxapex'} = $results_aref->[22];

      # Create a string describing this transition group.
      sub getTransitionInfo {
        my $transition_group_id = shift;
        my $sql = qq~
          SELECT q3_mz, frg_type, frg_nr, frg_z, frg_loss, relative_intensity
            FROM $TBAT_SEL_TRANSITION
           WHERE SEL_transition_group_id = '$transition_group_id'
        ~;
	my @rows = $sbeams->selectSeveralColumns($sql);

	# See if there are any relative_intensity (eri) values.
	# If there are, we will set eri to very small number for those rows
	# that have no value.
	my $any_eri = 0;
	for my $row (@rows) {
	  if ( defined $row->[5] && $row->[5] ne '' && $row->[5] > 0) {
	      $any_eri = 1;
	      last;
	  }
	}

        my $tx_info = "";
        for my $row (@rows) {
	  $row->[5] = 0.01
	     if ($any_eri && ($row->[5] eq '' || $row->[5] == 0));
          $tx_info .= "$row->[0],";  #q3
	  $tx_info .= "$row->[1]";   #frg_type
	  $tx_info .= "$row->[2]" if $row->[1] ne 'p'; #frg_nr
	  $tx_info .= "^$row->[3]" if $row->[3] > 1;   #frg_z
	  $tx_info .= "$row->[4]" if $row->[4] != 0;   #frg_loss
	  $tx_info .= ",$row->[5],"; #eri
        }
        return $tx_info;
      }
}

###############################################################################
# getNewChromatogramFilename
#   Create descriptive filename for chromatogram incorporating
#   timestamp
###############################################################################
sub getNewChromatogramFilename {
  my $self = shift;
  my %args = @_;
  my $spectrum_basename = $args{spectrum_basename};
  my $pepseq = $args{pepseq};

  my ($sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst)=localtime(time);
  my $timestamp = sprintf "%1d%02d%02d%02d%02d%02d-%02d",
     $year-110,$mon+1,$mday,$hour,$min,$sec,int(rand(100));
  my $chromgram_basename = "${spectrum_basename}_${pepseq}_${timestamp}";
  return $chromgram_basename;
}

###############################################################################
# writeJsonFile  -- deprecated
###############################################################################
sub writeJsonFile {
  my $self = shift;
  my %args = @_;
  my $json_string = $args{json_string};
  my $json_physical_pathname = $args{json_physical_pathname};

  open (JSON_FILE, ">$json_physical_pathname") ||
    die "writeJsonFile: can't open $json_physical_pathname for writing";
  print JSON_FILE $json_string;
  close JSON_FILE;
}

###############################################################################
# specfile2json - Create a .json string representing a given chromatogram
###############################################################################
sub specfile2json {
  my $self = shift;
  my %args = @_;
  my $param_href = $args{param_href};    # describes desired chromatogram

#--------------------------------------------------
#   my $pepseq = $args{pepseq};
#   my $isotype = $args{isotype};
#   my $is_decoy = $args{is_decoy};
#   my $experiment = $args{experiment};
#   my $spectrum_file = $args{spectrum_file};
#   my $chromatogram_id = $args{chromatogram_id};
#   my $isotype_delta_mass = $param_href->{isotype_delta_mass};
#-------------------------------------------------- 

  my $mass = $args{mass};
  my $charge = $args{charge};
  my $q1_tolerance = $args{q1_tolerance};
  my $q3_tolerance = $args{q3_tolerance};
  my $ms2_scan = $args{ms2_scan};
  my $top_html = $args{top_html};

  my $rt = $param_href->{rt} || $param_href->{Tr} || 0;
  my $target_q1 = $param_href->{q1} || $param_href->{precursor_mz};
  my $tx_info = $param_href->{transition_info};

  my $count = 0;
  my $proton_mass = 1.00727646688; # from J Eng to edeutsch via 08July2011 email.

  my $target_q1_2;   #if we look up Q1 for both +2, +3

  # Calculate Q1 if not given
  if (! defined $target_q1) {
    if ( defined $mass) {
      if ( defined $charge) {
	      $target_q1 = $mass / $charge + $proton_mass;
      } else {
	    # If neither Q1 nor charge given, get +2 and +3 traces.
  
        unless( $param_href->{use_pepname} ) {
          $target_q1 = $mass / 3 + $proton_mass;
          $target_q1_2 = $mass / 2 + $proton_mass;
        }
      }
    } else {
      # 12/02/11: this is currently caught in ShowChromatogram.
      die "specfile2json: Need Q1, pepseq, or precursor_neutral_mass";
    }
  }

  # Read scans for $q1 into a hash
  my $traces_href = specfile2traces(
    spectrum_pathname => $param_href->{spectrum_pathname},
    target_q1 => $target_q1,
    q1_tolerance => $q1_tolerance,
    q3_tolerance => $q3_tolerance,
    tx_info => $tx_info,    #optional
    ms2_scan => $ms2_scan,
    param_href => $param_href
  );
  
  # If we have a second Q1, add that to the hash
  if ( defined $target_q1_2) {
    my $traces_href_2 = specfile2traces(
      spectrum_pathname => $param_href->{spectrum_pathname},
      target_q1 => $target_q1_2,
      q1_tolerance => $q1_tolerance,
      q3_tolerance => $q3_tolerance,
      tx_info => $tx_info, 
      # no need to get ms2_scan b/c we got the first time.
      #ms2_scan => $ms2_scan,
    );
    my %combined_tx = ();
    if ( $traces_href->{'tx'} ) {
      %combined_tx = %{$traces_href->{'tx'}};
    }
    if ( $traces_href_2->{'tx'} ) {
      #%combined_tx = %{$traces_href_2->{'tx'}};
      %combined_tx = (%combined_tx, %{$traces_href_2->{'tx'}});
    }

    # these 2 lines added 03/08/12
    my %combined_traces = (%{$traces_href}, %{$traces_href_2});
    $traces_href = \%combined_traces;
    $traces_href->{'tx'} = \%combined_tx;
  }

  # Unpack and store the transition info string, if provided
  store_tx_info_in_traces_hash (
    tx_info => $tx_info,
    traces_href => $traces_href,
    q3_tolerance => $q3_tolerance,
  ) if ($tx_info);

  # Create and return .json string.
  return traces2json(
    %args,
    traces_href => $traces_href,
    tx_info => $tx_info,
    rt => $rt,
#--------------------------------------------------
#     pepseq => $pepseq,
#     mass => $mass,
#     isotype_delta_mass => $isotype_delta_mass,
#     charge => $charge,
#     isotype => $isotype,
#     is_decoy => $is_decoy,
#     experiment => $experiment,
#     spectrum_file => $spectrum_file,
#     chromatogram_id => $chromatogram_id,
#-------------------------------------------------- 
    top_html => $top_html,
  );
}


###############################################################################
# specfile2traces
# Read the chromatograms for a particular peptide from an spectrum file
#  and store  the time & intensity information in a hash.
###############################################################################
sub specfile2traces {

  my %args = @_;
  my $spectrum_pathname = $args{'spectrum_pathname'};
  my $tx_info = $args{'tx_info'};

  my $traces_href;

  # Extract lists of Q3, fragment ions, from tx_info string, which is in form
  # Q3,ion,rel_intensity,Q3,ion,rel_intensity, ...
  my @q3_array;
  my @frg_ion_array;
  #print $tx_info, "\n";
  # Without final -1 arg, trailing empty elements are stripped by split().
  # WITH final -1 arg, an extra empty element ends up being added, because
  # the list ends in a comma. So we subtract 1 when calculating $n.
  my @tx_info_elements = split(",",$tx_info, -1);
  my $n = scalar @tx_info_elements - 1;
  #print "$n tx_info_elements\n";
  for (my $i=0; $i < $n; $i +=3) {
    push (@q3_array, $tx_info_elements[$i]);
    push (@frg_ion_array, $tx_info_elements[$i+1]);
  }


  # Parse the spectrum file according to filetype and obtain a hash of
  # time/intensity traces.
  if ($spectrum_pathname =~ /\.mzML/) {
    $traces_href = mzML2traces(
      %args,
      q3_aref=>\@q3_array,
      frg_ion_aref=>\@frg_ion_array,
    );
  } elsif ($spectrum_pathname =~ /\.mzXML/) {
    $traces_href = mzXML2traces(
      %args,
      q3_aref=>\@q3_array,
      frg_ion_aref=>\@frg_ion_array,
    );
  } else {
    die "specfile2traces(): ${spectrum_pathname} invalid filetype; must be .mzML or .mzXML";
  }

  return $traces_href;
}

###############################################################################
# mzML2traces
# Read the chromatograms for a particular Q1 from an mzML file and store
# the time & intensity information in a hash.
###############################################################################
sub mzML2traces {
  my %args = @_;
  my $spectrum_pathname = $args{spectrum_pathname};
  my $target_q1 = $args{target_q1};
  my $ms2_scan = $args{ms2_scan};
  my $q1_tolerance = $args{q1_tolerance};
  my $q3_tolerance = $args{q3_tolerance};
  my @q3_array = @{ $args{'q3_aref'} };
  my @frg_ion_array = @{ $args{'frg_ion_aref'} };
  my $tx_info = $args{tx_info} || '';

  my @q3_found_array;
  my %traces;

  # Process each chromatogram
  my @target_cgrams;
  my $ms2_rt;

  my $parse_entire_file = 1;
  my $stime = time();
  if ( $args{param_href}->{use_pepname} ) {
    $parse_entire_file = 0;
    my $offset = `tail -10 $spectrum_pathname | grep indexListOffset `;
    my @offsets;
    if ( $offset =~ /<indexListOffset>(\d+)\<\/indexListOffset>/i ) {
      my $off = $1;
      open MZML, $spectrum_pathname;
      print "opening $spectrum_pathname, looking for $offset<br>\n";

      seek( MZML, $off, 0 );
      while ( my $line = <MZML> ) {
#        $line =~ s/[<>]//g;
        if ( $line =~ /$args{param_href}->{peptide}/ ) {
#          <offset idRef="AQUA4SWATH_HumanEbhardt_EASGLSADSLAR(UniMod:267)/2_y4">13468467</offset>
          if ( $line =~ /\<offset\s+idRef[^>]+\>(\d+)\<\/offset\>/ ) {
            my $offset = $1;
            push @offsets, $offset;
          } else {
            $log->warn( "Didn't find offset in $line" );
          }
        } else {
        }
#        last unless $line =~ /offset/;
      }

      for my $off ( @offsets ) {
        seek( MZML, $off, 0 );
        my $scan = '';
        while ( my $line = <MZML> ) {
          $scan .= $line;
          if ( $line =~ /<\/chromatogram/ ) {
            last;
          }
        }
        my $mzMLtree = XML::TreeBuilder->new();
        $mzMLtree->parse($scan) || die "No parse for you!";
        my @allcgrams = $mzMLtree->find_by_tag_name('chromatogram');
        for my $cgram ( @allcgrams ) {
          my $id = $cgram->attr('id');
          my @id = split( /_/, $id );
          if ( $id[0] =~ /DECOY/ ) {
            if ( $id[4] ) {
              push @target_cgrams, [ $id[0] . '_' . $id[3], $id[4], $cgram ];
            } else {
              push @target_cgrams, [ $id[0] . '_' . $id[2], $id[3], $cgram ];
            }
          } elsif ( $args{param_href}->{peptide} eq 'TIC' ) {
            push @target_cgrams, [ '' , 'Total Ion Current', $cgram ];
          } else {
            if ( $id[3] ) {
              push @target_cgrams, [ $id[2] , $id[3], $cgram ];
            } else {
              push @target_cgrams, [ $id[1] , $id[2], $cgram ];
            }
          }
        }
      }
      $parse_entire_file = 0;
    } else {
      print STDERR "tail -10 $spectrum_pathname | grep indexListOffset <br>\n";
    }

  }


  if ( $parse_entire_file ) {
    # Initialize parser and parse the file.
    my $mzMLtree = XML::TreeBuilder->new();
    $mzMLtree->parse_file($spectrum_pathname) || die
    "Couldn't parse $spectrum_pathname";
    my @allcgrams = $mzMLtree->find_by_tag_name('chromatogram');
    my @alloffsets = $mzMLtree->find_by_tag_name('offset');
  
    my $ncgrams = scalar (@allcgrams);
    my $noffsets = scalar (@alloffsets);
  
    # If ms2_scan provided, get MS2 retention time
    if ($ms2_scan) {
      my @allspectra = $mzMLtree->find_by_tag_name('spectrum');
      for my $spectrum (@allspectra) {
        my $index = $spectrum->attr('index');
        if ($index == $ms2_scan) {
  	my @cvParams = $spectrum->find_by_tag_name('cvParam');
  	for my $cvParam (@cvParams) {
  	  my $name = $cvParam->attr('name');
  	  if ($name eq 'scan start time') {
  	    $ms2_rt = $cvParam->attr('value');
  	  }
  	}
        }
      }
    }
  
    for my $cgram (@allcgrams) {
      my $id = $cgram->attr('id');
      my ($q1, $q3, $sample, $period, $experiment, $transition,);
      # If this is a parsable chromatogram ID, get its infos
      if ( ($id =~
  	/.*SRM.*\s+Q1=(\S+)\s+Q3=(\S+)\s+sample=(\S+)\s+period=(\S+)\s+experiment=(\S+)\s+transition=(\S+)/) #QTRAP data from Cima and Ralph Schiess
        ||
        ($id =~ /SRM SIC Q1=(\S+) Q3=(\S+)/) #QQQ data from SRMAtlas
        ||
        ($id =~ /SRM SIC (\S+),(\S+)/) #TSQ data from Nathalie
         ) {
        $q1 = $1;
        $q3 = $2;
        $sample = $3;
        $period = $4;
        $experiment = $5;
        $transition = $6;
  
        # If this is close to our target Q1 ...
        if (($q1 <= $target_q1+$q1_tolerance) && ($q1 >= $target_q1-$q1_tolerance)) {
  
  	      # If tx_info provided, check to see if this is one of the Q3s we want
        	if ($tx_info) {
        	  my $q3_match = check_q3_against_list ( q3 => $q3,
                                              q3_aref => \@q3_array,
                                         q3_tolerance => $q3_tolerance,
                                        q3_found_aref => \@q3_found_array,
                                                 );
              
            next unless $q3_match;
            if ($q3_match > 1) {
              print "<p>WARNING: mzML Q3 $q3 matched >1 target Q3 for target Q1=${target_q1}.<br>Q1 tolerance = $q1_tolerance  Q3 tolerance = $q3_tolerance</p>\n";
            }
          }
          push @target_cgrams, [ $q1, $q3, $cgram ];
        } else {
          next;
        }
      } elsif ( $args{param_href}->{use_pepname} ) {
        if ( $id =~ /$args{param_href}->{peptide}/ ) {
          my @id = split( /_/, $id );
  
          if ( $id[0] =~ /DECOY/ ) {
  #          print "decoy, " . join( ':::', @id ) . "<br>\n";
            push @target_cgrams, [ $id[0] . '_' . $id[3], $id[4], $cgram ];
          } else {
#            print "fwd, " . join( ':::', @id ) . "<br>\n";
            push @target_cgrams, [ $id[2] , $id[3], $cgram ];
          }
        }
      }# end if parsable chromatogram ID
    } # end all cgrams
  } # End if index elsif loop
  my $etime = time();
  my $tdelta = $etime - $stime;
  print "Took $tdelta seconds to read chromatogram<br>\n";


  for my $cgram_row ( @target_cgrams ) {
    my $q1 = $cgram_row->[0];
    my $q3 = $cgram_row->[1];
    my $cgram = $cgram_row->[2];
#    print "q1 is $q1, q3 is $q3<br>\n";
	#### The code below should duplicate code in
	#### mMap.pl (of the mProphet suite). Updates, fixes to one
	#### should be copied to the other.

	# Process the time and intensity arrays for this cgram
	my @binaryDataArrayLists =
	$cgram->find_by_tag_name('binaryDataArrayList');

	my $n = scalar @binaryDataArrayLists;
	my @binaryDataArrays =
	$binaryDataArrayLists[0]->find_by_tag_name('binaryDataArray');
	$n = scalar @binaryDataArrays;


	my ( $time_aref, $int_aref);
	my $n_time = 0;
	my $n_int = 0;

	my $n_data_arrays = scalar @binaryDataArrays;

	# Process the time and intensity arrays for this cgram.
	# Usually, time is first and intensity second.
	for (my $i=0; $i < $n_data_arrays; $i++) {

	  my @cvParam = $binaryDataArrays[$i]->find_by_tag_name('cvParam');
	  my @binary = $binaryDataArrays[$i]->find_by_tag_name('binary');

	  my $compression = 'no';
	  my $unit_name;
	  my $array_type;
	  my $precision;

	  # Process the cvParams for this binaryDataArray
	  for my $cvParam (@cvParam) {
	    if (defined $cvParam->{'name'}) {
		if ($cvParam->{'name'} =~ '(\S+) compression') {
		$compression = $1;
	      } elsif ($cvParam->{'name'} =~ '(\d+)-bit float') {
		$precision = $1;
	      } elsif ($cvParam->{'name'} =~ '(\S+) array') {
		$array_type = $1;
		$unit_name = $cvParam->{'unitName'};
	      }
	    }
	  }

	  # Decode the binary array
	  if (defined $binary[0]->content) {
	    my $aref = decode_base64binaryArray(
	      binaryArray=>$binary[0]->content->[0],
	      compression=>$compression,
	      precision=>$precision,
	      swap=>0,
	    );

	    # Get times
	    if ($array_type eq 'time') {
	      my $time_unit = defined $unit_name ? $unit_name : 'second';
	      my $time_factor = 1.0;
	      $time_factor *= 60.0 if ($time_unit eq 'hour');
	      $time_factor /= 60 if ($time_unit eq 'second');
	      $time_aref = $aref;
	      $n_time = scalar @{$time_aref};
	      # convert all times to minutes
	      for (my $i=0; $i<$n_time; $i++) {
		$time_aref->[$i] *= $time_factor;
	      }
	    # Get intensities
	    } elsif ($array_type eq 'intensity') {
	      $int_aref = $aref;
	      $n_int = scalar @{$int_aref};
	    } else {
	      print "Warning: unknown binaryDataArray type ${array_type}.\n";
	    }
	  } else {
	    print "Warning: binaryDataArray lacks content element.\n";
	  }
	}


	#--------------------------------------------------
	# print "<br>Times:&nbsp;";
	# for (my $i=0; $i<$n_time; $i++) {
	#   print "$time_aref->[$i]&nbsp;&nbsp;";
	# }
	# print "<br>Intensities:&nbsp;";
	# for (my $i=0; $i<$n_int; $i++) {
	#   print "$int_aref->[$i]&nbsp;&nbsp;";
	# }
	# print "<br>";
	#-------------------------------------------------- 
	die "$n_time timepoints, $n_int intensities!" if ($n_time != $n_int);

	####
	#### End of duplicated code
	####

  # This was an attempt to sample the data, but for the TIC plots it seems
  # that this always skews the data
  if ( $args{param_href}->{peptide} eq 'TIC' ) {
#	  print "$n_time timepoints, $n_int intensities!<br>\n";
#   print "Thinning the herd!<br>\n";
#    ( $int_aref, $time_aref ) = thin_the_herd( 2, $int_aref, $time_aref );
#    $n_time = scalar( @{$time_aref} );
#    $n_int = scalar( @{$int_aref} );
#	  print "$n_time timepoints, $n_int intensities!<br>\n";
  }

	# Store info in traces hash
	for (my $i=0; $i<$n_time; $i++) {
	  my $time = $time_aref->[$i];
	  my $intensity = $int_aref->[$i];
	  $traces{'tx'}->{$q1}->{$q3}->{'rt'}->{$time} = $intensity;
	  $traces{'tx'}->{$q1}->{$q3}->{'q1'} = $q1;
	}
	$traces{'ms2_rt'} = $ms2_rt;

  } # end for each target chromatogram

  return (\%traces);
}

# Sample data for large datasets
sub thin_the_herd_random {
  my $srate = shift;
  my $aref_1 = shift;
  my $aref_2 = shift;
  my @array_1;
  my @array_2;
  my $lim = scalar( @{$aref_1} );
  my $idx = 0;
  while ( $idx < $lim ) {
    $idx += int(rand( $srate ) ); 
    push @array_1, $aref_1->[$idx];
    push @array_2, $aref_2->[$idx];
  }
#  print "array 1 has " . scalar( @array_1 ) . " total entries <br>\n";
  $aref_1 = \@array_1;
#  print "arrayref 1 has " . scalar( @{$aref_1} ) . " total entries <br>\n";
  $aref_2 = \@array_2;
  return ( $aref_1, $aref_2 );
}

# Sample data for large datasets
sub thin_the_herd {
  my $srate = shift;
  my $aref_1 = shift;
  my $aref_2 = shift;
  my @array_1;
  my @array_2;
  my $lim = scalar( @{$aref_1} );
#  print "Lim $lim, rate $srate <br>\n";
  for ( my $idx = 0; $idx <= $lim; $idx++ ) {
    if ( $idx % $srate ) {
#      print "$idx mod $srate is TRUE <br>\n" if $idx < 100;
      next;
    } else {
#      print "$idx mod $srate is FALSE <br>\n" if $idx < 100;
    }
    push @array_1, $aref_1->[$idx];
    push @array_2, $aref_2->[$idx];
  }
#  print "array 1 has " . scalar( @array_1 ) . " total entries <br>\n";
  $aref_1 = \@array_1;
#  print "arrayref 1 has " . scalar( @{$aref_1} ) . " total entries <br>\n";
  $aref_2 = \@array_2;
  return ( $aref_1, $aref_2 );
}

###############################################################################
# mzXML2traces
# Read the scans for a particular Q1 from an mzXML file and store
# the time & intensity information in a hash. Handle two types of mzXML:
# q3/intensity pairs encoded in array, or each pair stored in indiv.
# scans
###############################################################################

sub mzXML2traces {
  my %args = @_;
  my $spectrum_pathname = $args{spectrum_pathname};
  my $target_q1 = $args{target_q1};
  my $q1_tolerance = $args{q1_tolerance};
  my $q3_tolerance = $args{q3_tolerance};
  my @q3_array = @{ $args{'q3_aref'} };
  my @frg_ion_array = @{ $args{'frg_ion_aref'} };
  my $tx_info = $args{tx_info} || '';

  my @q3_found_array;
  my %traces;

  #Parse the file without using a parser.
  my ($scan, $time, $q1, $q3, $intensity);
  my $intensity_aref;
  open (MZXML, $spectrum_pathname);
  #open (MZXML, $param_href->{spectrum_pathname});
  while (my $line = <MZXML>) {
    # New scan.
    if ($line =~ /<scan num="(\d+)"/) {
      $scan = $1;
      # maybe need to check when scans start at 0
      #print "Q1: $q1\n";
      # Score data from previous scan if it's for the target Q1
      if (($scan > 1) &&
	($q1 <= $target_q1+$q1_tolerance) &&
	($q1 >= $target_q1-$q1_tolerance)) {
	# If intensity array,  get the q3, intensity pairs and store each one
	if ($intensity_aref) {
	  my @intensities = @{$intensity_aref};
	  while (@intensities) {
	    # TODO: if (defined $tx_info), only store scan if $q3 matches
	    # a Q3 in $tx_info.
	    my $q3 = shift @intensities;

	    # If tx_info provided, check to see if this is one of the Q3s we want
	    my $q3_match;
	    if ($tx_info) {
	      $q3_match = check_q3_against_list (
		q3 => $q3,
		q3_aref => \@q3_array,
		q3_tolerance => $q3_tolerance,
		q3_found_aref => \@q3_found_array,
	      );
	      next unless $q3_match;
	      if ($q3_match > 1) {
		print "<p>WARNING: mzML Q3 $q3 matched >1 target Q3 for target Q1=${target_q1}.<br>Q1 tolerance = $q1_tolerance  Q3 tolerance = $q3_tolerance</p>\n";
	      }
	    }
	    my $intensity = shift @intensities;
	    $traces{'tx'}->{$q1}->{$q3}->{'rt'}->{$time} = $intensity;
	    $traces{'tx'}->{$q1}->{$q3}->{'q1'} = $q1;
	  }
	  # Else we have only one q3, intensity pair. Store it.
	} else {
	  # If tx_info provided, check to see if this is one of the Q3s we want
	  my $q3_match=1;
	  if ($tx_info) {
	    $q3_match = check_q3_against_list (
	      q3 => $q3,
	      q3_aref => \@q3_array,
	      q3_tolerance => $q3_tolerance,
	      q3_found_aref => \@q3_found_array,
	    );
	  }
	  if ($q3_match > 1) {
	    print "<p>WARNING: mzML Q3 $q3 matched >1 target Q3 for target Q1=${target_q1}.<br>Q1 tolerance = $q1_tolerance  Q3 tolerance = $q3_tolerance</p>\n";
	  }
	  if ( $q3_match ) {
	    $traces{'tx'}->{$q1}->{$q3}->{'rt'}->{$time} = $intensity;
	    $traces{'tx'}->{$q1}->{$q3}->{'q1'} = $q1;
	  }
	}
	undef $intensity_aref;
      }
      # Data for current scan.
    } elsif ($line =~ /retentionTime="PT(\S+)(\w)"/) {
      # Report RT in seconds.
      # Complete parser of this element, type="xs:duration",
      # would be more complicated.
      my $n = $1;
      my $units = $2;
      # NOTE: most/all of the sprintf field width specifiers below are useless
      # because the whitespace gets lost via the javascript.
      $time = sprintf ("%0.3f", ($units eq 'S') ? $n/60 :   #seconds
	($units eq 'H') ? $n*60 :   #hours
	$n);      #minutes
    } elsif ($line =~ /basePeakIntensity="(\S*?)"/) {
      $intensity = $1;
    } elsif ($line =~ /basePeakMz="(\S*?)"/) {
      $q3 = $1;
      # sometimes, multiple peaks are encoded in a single <scan>
    } elsif ($line =~ /compressedLen.*\>(.+)\<.peaks>/) {
      #print $1, "<br>\n";
      $intensity_aref = decode_base64binaryArray(
	binaryArray=>$1,
        compression=>0,    # is compression possible? Check schema.
        precision=>32,
        swap=>1,
      );
      #for my $elt (@{$intensity_aref}) { print "$elt\n"; }
    } elsif ($line =~ /<precursorMz.*>(\S+)<.precursorMz>/) {
      $q1 = $1;
    }
  }
  close MZXML;
  return (\%traces);
}


###############################################################################
# check_q3_against_list
# See if given Q3 is in a list of target Q3s, within a given tolerance.
#   If it is, make a note of it in q3_found_array.
#   Warn if we already saw it before.
#   This is inefficient as it performs the same arithmetic many times.
###############################################################################
sub check_q3_against_list {
  my %args = @_;
  my $q3 = $args{'q3'};
  my @q3_array = @{ $args{'q3_aref'} };
  my $q3_tolerance = $args{'q3_tolerance'};
  my @q3_found_array = @{ $args{'q3_found_aref'} };

  my $q3_match = 0;
  for (my $i=0; $i < scalar @q3_array; $i++) {
    my $target_q3 = $q3_array[$i];
    if (($q3 <= $target_q3+$q3_tolerance) &&
        ($q3 >= $target_q3-$q3_tolerance)) {
      if (defined  $args{'q3_found_aref'}) {
	if ($q3_found_array[$i]) {
	  print "<p>WARNING: target Q3=${target_q3} found in spectrum file more than once for specified Q1. Q3 tolerance = $q3_tolerance</p>\n";
	  $q3_found_array[$i]++;
	} else {
	  $q3_found_array[$i]=1;
	}
      }
      $q3_match++;
      last;
    }
  }
  return $q3_match;
}

###############################################################################
# traces2json_old
# Given a hash containing time & intensity information for a Q1,
#  write a json data object suitable for Chromavis.
###############################################################################
sub traces2json_old {
  my %args = @_;
  my $traces_href = $args{traces_href};

  my $pepseq = $args{	pepseq};
  my $mass = sprintf "%0.4f", $args{ mass};
  my $charge = $args{charge};
  my $isotype = $args{isotype};
  my $isotype_delta_mass = $args{isotype_delta_mass};
  my $is_decoy = $args{is_decoy};
  my $experiment = $args{experiment};
  my $spectrum_file = $args{spectrum_file};
  $spectrum_file =~ ".*/(.*)" ;
  $spectrum_file = $1;
  my $chromatogram_id = $args{chromatogram_id};

  my %traces = %{$traces_href};
  my $rt = $args{rt};
  my $tx_info = $args{tx_info};
  my $top_html = $args{top_html};

  my $json_string = "{";

  # Remove newlines from top_html
  $top_html =~ s/\n/ /g;
  # Write auxiliary infos, if provided
  $json_string .= qq~
   "info" : [
      {
         "top_html" : "$top_html"
      }
   ],
~;

#         "pepseq": "$pepseq",
#         "mass": "$mass",
#         "charge": "$charge",
#         "isotype": "$isotype",
#         "isotype_delta_mass": "$isotype_delta_mass",
#         "is_decoy": "$is_decoy",
#         "experiment": "$experiment",
#         "spectrum_file": "$spectrum_file",
#         "chromatogram_id": "$chromatogram_id",

  # Open data_json element
  $json_string .= qq~   "data_json" : [\n~;

  # Create list of Q1, Q3 pairs sorted by frg_ion (stored as format y2+2-18)
  # First, store in a more convenient data structure, keyed by 
  # Q1 and then by frg_type
  # (Ideally, would do a better sort, according to 
  # frg_z, frg_type, frg_nr, frg_loss)
  my %ion_hash;
  my @sorted_unique_q1_list = ();
  # Basic list of common fragment types in sensible order.
  my @frg_types = ('y', 'b', 'z', 'a', 'x', 'c', 'p');
  my $frg_types = join '', @frg_types;
  for my $q1 ( sort { $a <=> $b } keys %{$traces_href->{'tx'}}) {
    push @sorted_unique_q1_list, $q1;
    for my $q3 ( sort { $a <=> $b } keys %{$traces{'tx'}->{$q1}}) {
      my $frg_ion = $traces{'tx'}->{$q1}->{$q3}->{frg_ion};
      my $frg_type = substr($frg_ion,0,1);
      # Add this frg_type to basic list if not there already.
      # Rarely/never needed
      if ( ( index $frg_types, $frg_type) == -1 ) {
	push (@frg_types, $frg_type);
	$frg_types = $frg_types . $frg_type;
      }
      $ion_hash{$q1}->{$frg_type}->{ion_q3s}->{$frg_ion} = $q3;
    }
  }
  # Do the sort
  my @sorted_q1_list = ();
  my @sorted_q3_list = ();
  for my $q1 ( @sorted_unique_q1_list ) {
    for my $frg_type (@frg_types) {
      for my $frg_ion
      ( sort
	  keys %{$ion_hash{$q1}->{$frg_type}->{ion_q3s}} ) {
	push @sorted_q1_list, $q1;
	push @sorted_q3_list,
	  $ion_hash{$q1}->{$frg_type}->{ion_q3s}->{$frg_ion};
      }
    }
  }


  my $count = 0;
  for my $q1 ( @sorted_q1_list ) {
    my $q3 = shift @sorted_q3_list ;
      $count++;
      $json_string .= sprintf qq~      {\n~;
      my $label = '';
      if ($tx_info) {
      # if (defined $traces{'tx'}->{$q1}->{$q3}->{frg_ion}) {
	$label .= sprintf "%-5s ", $traces{'tx'}->{$q1}->{$q3}->{frg_ion};
      } else {
	$label .= sprintf "%3.3d ", $count;
      }


      $label .=  sprintf "%7.3f / %7.3f",  $traces{'tx'}->{$q1}->{$q3}->{'q1'}, $q3;
      $label .= sprintf (" ERI: %0.1f", $traces{'tx'}->{$q1}->{$q3}->{'eri'} )
	if ($traces{'tx'}->{$q1}->{$q3}->{'eri'});
      $json_string .= qq~         "label" : "$label",\n~;
      $json_string .= qq~         "eri" : $traces{'tx'}->{$q1}->{$q3}->{'eri'},\n~
        if ($traces{'tx'}->{$q1}->{$q3}->{'eri'});
      $json_string .= qq~         "data" : [\n~;
      # Write each pair of numbers in Dick's JSON format.
      my $first = 1;
      for my $time (sort {$a <=> $b} keys %{$traces{'tx'}->{$q1}->{$q3}->{'rt'}}) {
        if (! $first) {
        $json_string .= sprintf ",\n";
        }
        $first = 0;
	my $intensity = $traces{'tx'}->{$q1}->{$q3}->{'rt'}->{$time};
	$json_string .= sprintf qq~            {\n               "time" : %0.4f,\n               "intensity" : %0.5f\n            }~, $time, $intensity;
      }
      # Close this chromatogram in JSON object
      $json_string .= qq~\n         ],\n~;
      $json_string .= sprintf qq~         "full" : "COUNT: %2.2d Q1:%0.3f Q3:%0.3f"\n~, $count, $traces{'tx'}->{$q1}->{$q3}->{'q1'}, $q3;
      $json_string .= qq~      }\n~;
  }
  # Close data_json
  $json_string .= "   ]";

  # Write the retention time marker, if value provided
  if (! $rt ) {
    $rt = $traces{'ms2_rt'};
  }
  if ($rt )  {
    my $formatted_rt = sprintf "%0.3f", $rt;
    $json_string .= qq~,\n   "vmarker_json" : [\n      {\n         "id" : "$formatted_rt",\n"value" : $rt\n      }\n   ]~;
  } else {
    $json_string .= qq~,\n   "vmarker_json" : []~;
  }

  $json_string .= "\n";
  $json_string .= "}\n";

  return $json_string;
}

###############################################################################
# traces2json
# Given a hash containing time & intensity information for a Q1,
#  write a json data object suitable for Chromavis.
###############################################################################
sub traces2json {
  my %args = @_;
  my $traces_href = $args{traces_href};
  $args{traces_href} = {};

#--------------------------------------------------
#   my $pepseq = $args{	pepseq};
#   my $mass = sprintf "%0.4f", $args{ mass};
#   my $charge = $args{charge};
#   my $isotype = $args{isotype};
#   my $isotype_delta_mass = $args{isotype_delta_mass};
#   my $is_decoy = $args{is_decoy};
#   my $experiment = $args{experiment};
#   my $spectrum_file = $args{spectrum_file};
#   $spectrum_file =~ ".*/(.*)" ;
#   $spectrum_file = $1;
#   my $chromatogram_id = $args{chromatogram_id};
#-------------------------------------------------- 

  my %traces = %{$traces_href};
  my $rt = $args{rt};
  my $tx_info = $args{tx_info};
  my $top_html = $args{top_html};

  my $json_string = '{';

  # Open data_json element
  my $json = new JSON;
  my $json_href;

  my @sorted_q1_list = ();
  my @sorted_q3_list = ();

  if ($tx_info) {
    # If we have frg_ion info, create list of Q1, Q3 pairs
    # sorted by frg_ion (stored as format y2+2-18).
    # First, store in a more convenient data structure, keyed by 
    # Q1 and then by frg_type
    # (Ideally, would do a better sort, according to 
    # frg_z, frg_type, frg_nr, frg_loss)
    my %ion_hash;
    my @sorted_unique_q1_list = ();
    # Basic list of common fragment types in sensible order.
    my @frg_types = ('y', 'b', 'z', 'a', 'x', 'c', 'p');
    my $frg_types = join '', @frg_types;
    for my $q1 ( sort { $a <=> $b } keys %{$traces_href->{'tx'}}) {
      push @sorted_unique_q1_list, $q1;
      for my $q3 ( sort { $a <=> $b } keys %{$traces{'tx'}->{$q1}}) {
	my $frg_ion = $traces{'tx'}->{$q1}->{$q3}->{frg_ion};
	my $frg_type = substr($frg_ion,0,1);
	# Add this frg_type to basic list if not there already.
	# Rarely/never needed
	if ( ( index $frg_types, $frg_type) == -1 ) {
	  push (@frg_types, $frg_type);
	  $frg_types = $frg_types . $frg_type;
	}
	$ion_hash{$q1}->{$frg_type}->{ion_q3s}->{$frg_ion} = $q3;
      }
    }
    # Do the sort
    for my $q1 ( @sorted_unique_q1_list ) {
      for my $frg_type (@frg_types) {
	for my $frg_ion
	( sort
	  keys %{$ion_hash{$q1}->{$frg_type}->{ion_q3s}} ) {
	  push @sorted_q1_list, $q1;
	  push @sorted_q3_list,
	  $ion_hash{$q1}->{$frg_type}->{ion_q3s}->{$frg_ion};
	}
      }
    }
  # If we don't have tx_info, don't sort by frg_ion.
  } else {
    for my $q1 ( sort { $a <=> $b } keys %{$traces_href->{'tx'}}) {
      for my $q3 ( sort { $a <=> $b } keys %{$traces{'tx'}->{$q1}}) {
	push (@sorted_q1_list, $q1);
	push (@sorted_q3_list, $q3);
      }
    }
  }


  my $count = 0;
  for my $q1 ( @sorted_q1_list ) {
    my $q3 = shift @sorted_q3_list ;
    $count++;
    my %data_element;
    my $str = sprintf "COUNT: %2.2d Q1:%0.3f Q3:%0.3f", $count, $traces{'tx'}->{$q1}->{$q3}->{'q1'}, $q3;
    $data_element{'full'} = $str;
    my $label = '';
    if ($tx_info) {
      $label .= sprintf "%-5s ", $traces{'tx'}->{$q1}->{$q3}->{frg_ion};
    } else {
      $label .= sprintf "%3.3d ", $count;
    }


    $label .=  sprintf "%7.3f / %7.3f",  $traces{'tx'}->{$q1}->{$q3}->{'q1'}, $q3;
    if ( $traces{'tx'}->{$q1}->{$q3}->{'eri'} ) {
      $label .= sprintf (" ERI: %0.1f", $traces{'tx'}->{$q1}->{$q3}->{'eri'} )
    }
    if ( $args{param_href}->{use_pepname} ) {
      $label = ( $q1 =~ /DECOY/ ) ? 'DECOY ' . $q3 : $q3;
    }
    $data_element{'label'} = $label;
    $data_element{'eri'} = $traces{'tx'}->{$q1}->{$q3}->{'eri'} +0 #force to int
    if ($traces{'tx'}->{$q1}->{$q3}->{'eri'});
    # Write each pair of numbers in Dick's JSON format.
    for my $time (sort {$a <=> $b} keys %{$traces{'tx'}->{$q1}->{$q3}->{'rt'}}) {
      my $intensity = $traces{'tx'}->{$q1}->{$q3}->{'rt'}->{$time};
      my %timepoint;
      $timepoint{'time'} = $time + 0;
      $timepoint{'intensity'} = $intensity + 0;
      push @{$data_element{'data'}}, {%timepoint};
    }
    push @{$json_href->{'data_json'}}, {%data_element};
  }

  # Write the retention time marker, if value provided
  if (! $rt ) {
    $rt = $traces{'ms2_rt'};
  }
  if ($rt )  {
    my $formatted_rt = sprintf "%0.3f", $rt;
    $json_href->{'vmarker_json'}->[0]{'id'} = $formatted_rt;
    $json_href->{'vmarker_json'}->[0]{'value'} = $rt;
  } else {
    $json_href->{'vmarker_json'} = [];
  }

  # Remove newlines from top_html
  $top_html =~ s/\n/ /g;
  # Write auxiliary infos (no longer needed; all are codified in
  # $top_html  02/28/12 )
#--------------------------------------------------
#   $json_href->{'info'}->[0]{'pepseq'} = $pepseq;
#   $json_href->{'info'}->[0]{'mass'} = $mass;
#   $json_href->{'info'}->[0]{'charge'} = $charge;
#   $json_href->{'info'}->[0]{'isotype'} = $isotype;
#   $json_href->{'info'}->[0]{'isotype_delta_mass'} = $isotype_delta_mass;
#   $json_href->{'info'}->[0]{'is_decoy'} = $is_decoy;
#   $json_href->{'info'}->[0]{'experiment'} = $experiment;
#   $json_href->{'info'}->[0]{'spectrum_file'} = $spectrum_file;
#   $json_href->{'info'}->[0]{'chromatogram_id'} = $chromatogram_id;
#-------------------------------------------------- 
  $json_href->{'info'}->[0]{'top_html'} = $top_html;

  $json = $json->pretty([1]);  # print json objects with indentation, etc.
  $json_string = $json->encode($json_href);

  return $json_string;
}

###############################################################################
# store_tx_info_in_traces_hash
#   Given a string containing Q3,frg_ion,intensity triplets, store
#   this info in the portion of the traces hash for this Q3
###############################################################################
sub store_tx_info_in_traces_hash {
  my %args = @_;
  my $tx_info = $args{tx_info};
  my $traces_href = $args{traces_href};
  my %traces = %{$traces_href};
  my $tol = $args{q3_tolerance};

  my %tx_info_values;
  my @values = split(",",$tx_info);
  while (@values) {
    # get a q3, fragment ion, expected intensity triplet
    my $q3 = shift @values;
    my $frg_ion = shift @values;
    my $int = shift @values;
    # see if we have data for this q3
    for my $data_q1 (keys %{$traces{'tx'}}) {
      for my $data_q3 (keys %{$traces{'tx'}->{$data_q1}}) {
	if (($q3 <= $data_q3+$tol) && ($q3 >= $data_q3-$tol)) {
	  # if we do, store the fragment ion and the eri
	  $traces{'tx'}->{$data_q1}->{$data_q3}->{'frg_ion'} = $frg_ion;
	  $traces{'tx'}->{$data_q1}->{$data_q3}->{'eri'} = $int if (defined $int);
	  last;
	}
      }
    }
  }
}

###############################################################################
# decode_base64binaryArray
###############################################################################

sub decode_base64binaryArray {
  my %args = @_;
  my $base64_string = $args{binaryArray} ||
    die ("decode_mzMLbinaryArray: need binaryArray argument");
  my $precision = $args{precision} || 32;
  my $compression = $args{compression} || 0;
  $compression = 0 if ($compression =~ /^no$/i);
  my $swap = $args{swap} || 0;
  my $format;

  my $decoded = decode_base64($base64_string);
  if ($compression) {
    if ($compression =~ /^zlib$/i) {
      $decoded = uncompress($decoded);
    } else {
      die "Unknown compression type |$compression|";
    }
  }
  $decoded = byteSwap($decoded, $precision) if $swap;
  if ($precision == 32) {
    $format = "f*";  #float
  } elsif ($precision == 64) {
    $format = "d*";  #double
  } else {
    die "Unknown precision $precision";
  }
  my @array = unpack($format, $decoded);
  return \@array;
}



###############################################################################
# byteSwap: Exchange the order of each pair of bytes in a string.
###############################################################################
sub byteSwap {
  my $in = shift || die("byteSwap: no input");

  my $out = '';
  for (my $i = 0; $i < length($in); $i+=4) {
    $out .= reverse(substr($in,$i,4));
  }
  return($out);
}

###############################################################################
# mzML2json_using_PCE - Create a .json file representing a given chromatogram
#   This makes use of the ATAQS peptideChromatogramExtractor, but
#   it is slow and it wasn't working for PASSEL for unknown reasons.
#    08/23/11: DEPRECATED, because it's slow to call out.
#    12/05/11: mzML2json, initially a copy of this subroutine,
#    has now diverged a lot.
###############################################################################
sub mzML2json_using_PCE {

  my $self = shift;
  my %args = @_;
  my $param_href = $args{param_href};
  my $physical_tmp_dir = $args{physical_tmp_dir};
  my $chromgram_basename = $args{chromgram_basename};

	my $pepseq = $args{pepseq};
	my $mass = $args{mass};
	my $charge = $args{charge};
	my $isotype = $args{isotype};
	my $is_decoy = $args{decoy};
	my $experiment = $args{experiment};
	my $spectrum_file = $args{spectrum_file};
	my $chromatogram_id = $args{chromatogram_id};

  my ($ion, $ion_charge, $pepseq, $spectrum_pathname,
	$ce, $rt, $delta_rt, $fragmentor, $precursor_neutral_mass);

  $precursor_neutral_mass = $param_href->{'precursor_neutral_mass'};
  $spectrum_pathname = $param_href->{'spectrum_pathname'};
  $pepseq = $param_href->{'pepseq'};
  $ce = $param_href->{'ce'} || 99;
  $rt = $param_href->{'rt'} || $param_href->{'Tr'} || 99;
  $delta_rt = $param_href->{'delta_rt'} || 99 ;
  $fragmentor = $param_href->{'fragmentor'} || 125;

  # Get charge 2, 3 Q1 values for this peptide.
  my $q1_charge3 = $precursor_neutral_mass / 3 + 1.00727638;
  my $q1_charge2 = $precursor_neutral_mass / 2 + 1.00727638;

  # Get the Q3 for all transitions for this peptide. 
  # Open mzML file for reading
  open(MZML, $spectrum_pathname) || print "<p>Can't open mzML file $spectrum_pathname.</p>\n";

  my $line;
  # Look for <index name="chromatogram"
  while ($line = <MZML>) {
    last if ($line =~ /<index name="chromatogram"/);
  }
  # Look for Q1=xxxxx Q3=xxxx
  # If Q1 within 0.01 of desired, save exact value plus Q3 value
  my $q3;
  my (@q1_list, @q3_list, @charge_list);
  my $tolerance = 0.01;
  while ($line = <MZML>) {
    if ($line =~ /Q1=(\S+) Q3=(\S+)/) {
      my $this_q1 = $1; my $this_q3 = $2;
      # CLEANUP
      if (abs($this_q1-$q1_charge2) < $tolerance) {
	push (@q1_list, $this_q1);
	push (@q3_list, $this_q3);
	push (@charge_list, 2);
      } elsif (abs($this_q1-$q1_charge3) < $tolerance) {
	push (@q1_list, $this_q1);
	push (@q3_list, $this_q3);
	push (@charge_list, 3);
      }
    }
  }
  close MZML;
#
  # Now, make the .tsv file for PeptideChromatogramExtractor.
  # Standard ATAQS format.
  my $tsv_pathname = "$physical_tmp_dir/$chromgram_basename.tsv";
  # For some reason, I can't write to tmp, only to images/tmp.
  # Hmmph!
  open (TSV, ">$tsv_pathname") || print "<p>Can't open $tsv_pathname for writing!</p>\n";
  print TSV "Dynamic MRM\n";
  print TSV "Compound Name\tISTD?\tPrecursor Ion\tMS1 Res\tProduct Ion\tMS2 Res\tFragmentor\tCollision Energy\tRet Time (min)\tDelta Ret Time\tPolarity\n";

  # Trick PeptideChromatogramExtractor to put traces for all charges
  # into a single .txt file, by including the same charge digit in all
  # pepnames. Might be better to change ataqs2json to combine several
  # .txt files into one .json file. CLEANUP.
  my $first_charge = $charge_list[0];
  for my $q1 (@q1_list) {
    my $q3 = shift @q3_list;
    my $charge = shift @charge_list;
    # $ion and $ion_charge are currently bogus, but they are needed for the
    # pepname syntax
    $ion = "y1"; $ion_charge = "1";
    my $pepname = $pepseq . "." . $first_charge . $ion . "-" .$ion_charge;
    print TSV "$pepname\t".
	      "FALSE\t".
	      "$q1\t".
	      "Wide\t".
	      "$q3\t".
	      "Unit\t".
	      "$fragmentor\t".
	      "$ce\t".
	      "$rt\t".
	      "$delta_rt\t".
	      "Positive\n";
     # In case multiple traces per charge, increment ion_charge to
     # allow unique pepnames
     $ion_charge++;
  }
  close TSV;
  #print "<!-- TSV pathname: $tsv_pathname -->\n";

  # Now! run the java program to extract the traces for the
  # transitions described in the .tsv file and store in a .txt file
  my ${pa_java_home} = "$PHYSICAL_BASE_DIR/lib/java/SBEAMS/SRM";
  my $user = $chromgram_basename;
  my $java_wrapper =
    "${pa_java_home}/PeptideChromatogramExtractor.sh ".
    "$tsv_pathname $spectrum_pathname $user $rt";

  my $shell_result = `pwd 2>&1`;
  #print "<!-- Current working directory: $shell_result -->\n";
  #print "<!-- Running Java wrapper: $java_wrapper -->\n";
  my $shell_result = `$java_wrapper 2>&1`;
  # This does not seem to be printing the errors.
  #print "<!-- Java wrapper result: $shell_result -->\n";

  # Convert the .txt file into a .json files for chromatogram viewer,
  # then delete it. (Original early 2011 code handled multiple files;
  # when would we ever have multiple files? "One for each distinct
  # mod_pep and charge combo", it says in wrapper script.)
  my @txt_files = split (" ",  `ls ${pa_java_home}/$user*.txt`);
  if ((scalar @txt_files) > 1) {
    #print "<!-- Warning: multiple files ${pa_java_home}/${user}*.txt -->\n";
  } elsif ((scalar @txt_files) < 1) {
    die "mzML2json_using_PCE(): No files match ${pa_java_home}/${user}*.txt";
  }
  my $pce_txt_file = $txt_files[0];
  #print "<!-- Converting $pce_txt_file to json -->\n";
  my $json_string = $self->PCEtxt2json (
    rt => $rt,
    pce_txt_file => $pce_txt_file,
  );
  `rm -f $pce_txt_file`;
#
  my $json_string;
  return $json_string;
}


###############################################################################
# PCEtxt2json - convert PeptideChromatogramExtractor .txt files to .json
###############################################################################
sub PCEtxt2json {

  my $self = shift;
  my %args = @_;
  my $rt = $args{rt};
  my $target_q1 = $args{target_q1};
  my $tx_info = $args{tx_info};
  my $pce_txt_file = $args{pce_txt_file};

  use MIME::Base64;

#--------------------------------------------------
# a JSON object for the chromatogram,
#  is simply one or more lists (named "data") of (time, intensity)
#   (or, for RT marker, (id, value)) pairs:
#      var data_json = [
#        { full : 'Q1:590.337 Q3:385.22 Z1:3 Z3:1 CE:16.5 ION:y3',
#         label : '$num Q1:590.337 Q3:385.22',
#           data : [{time : 2898.333, intensity : 40.166},
#                   {time : 3056.667, intensity : -0.052}, ...
#                   {id : 'Retention Time', value : 1200}, ...
#                  ]},
#          ...
#-------------------------------------------------- 

  open (TXT, $pce_txt_file) ||
     die "PCEtxt2json: can't open $pce_txt_file for reading.";
  my $json_string = "{";

# Open data_json element
  $json_string .= "data_json : [\n";

  my $count = 0;

  while (my $line = <TXT>) {
    # First line in Mi-Youn's text file has some infos: read them.
    chomp $line;
    $line =~ /Q1:(\S+) Q3:(\S+) Z1:(\S+) Z3:(\S+) CE:(\S+) ION:(\S+)/;
    my ($q1, $q3, $z1, $z3, $ce, $ion) = ($1, $2, $3, $4, $5, $6);
    $count++;

    # Read next input line.
    $line = <TXT>;
    # Strip punctuation from input line. What's left is a list of numbers.
    $line =~ s/\(//g;
    $line =~ s/\)//g;
    $line =~ s/,//g;
    my @numbers = split(' ', $line);

    # Open this chromatogram in JSON object
    $json_string .= "  {  full : 'COUNT: $count Q1:$q1 Q3:$q3 Z1:$z1 Z3:$z3 CE:$ce ION:$ion',\n";
    #my $label = "ION:$ion";
    my $label =  sprintf "%3d  Q1:$q1 Q3:$q3", $count;
    $json_string .= "    label : '$label',\n";
    $json_string .= "     data : [\n";

    # Write each pair of numbers in Dick's JSON format.
    while (@numbers) {
      my $time = shift @numbers;
      my $intensity = shift @numbers;
      $json_string .= "          {time : $time, intensity : $intensity},\n";
    }
    # TO DO : strip final comma, says Dick.

    # Close this chromatogram in JSON object
    $json_string .= "        ]},\n";
    # TO DO : strip final comma, says Dick.
  }
  close TXT;

# Close data_json
  $json_string .= "]\n";

# Write the retention time marker, if value provided
  if ($rt )  {
    my $formatted_rt = sprintf "%0.3f", $rt;
    $json_string .= ", vmarker_json : [ {id : '$formatted_rt', value : $rt} ]\n";
  } else {
    $json_string .= ", vmarker_json : [  ]\n";
  }
  $json_string .= "}\n";
  return $json_string;
}

###############################################################################
# getTopHTMLforChromatogramViewer
###############################################################################
sub getTopHTMLforChromatogramViewer {

  my $self = shift;
  my %args = @_;
  my $param_href = $args{param_href};
  my $seq = $args{seq};
  my $precursor_charge = $args{precursor_charge};
  my $spectrum_basename = $args{spectrum_basename};

  my $precursor_rt = $param_href->{rt};
  my $best_peak_group_rt = $param_href->{Tr};
  my $max_apex_intensity = $param_href->{'max_apex_intensity'};
  my $light_heavy_ratio_maxapex =
    $param_href->{'light_heavy_ratio_maxapex'};
  my $S_N = $param_href->{'S_N'};
  my $m_score = $param_href->{m_score};
  my $top_html = "";

  #$top_html .= $sbeams->get_MSIE_javascript_error();
  $top_html .= "<p><big>";
  $top_html .= " DECOY" if $param_href->{is_decoy} eq 'Y';
  $top_html .= " <b>$seq</b></big> ";
  my $mass = $args{precursor_neutral_mass};
  if ($mass) {
    $mass += $param_href->{isotype_delta_mass}
       if (($param_href->{isotype_delta_mass}) &&
	   ($param_href->{'isotype'} =~ /heavy/i));
    my $mass_s = sprintf "%0.3f", $mass;
    $top_html .= "($mass_s Daltons) </b>\n";
  }
  $top_html .= "<b><big>+$precursor_charge</big></b>\n"
     if $param_href->{precursor_charge};
  $top_html .= "<b><big>, $param_href->{isotype}</big></b>\n"
     if $param_href->{isotype};
  $top_html .= "<br><b>Peptide: </b> $param_href->{pepseq}\n"
     if $param_href->{peptide};
  $top_html .= "<br><b>Instrument: </b> $param_href->{instrument_name}\n"
     if $param_href->{instrument_name};
  $top_html .= "<br><b>Experiment: </b> $param_href->{experiment_title}\n"
     if $param_href->{experiment_title};
  unless ($param_href->{no_specfile}) {
    $top_html .= "<br><b>Spectrum file:</b> ";
    $top_html .= "<br>" if (length($spectrum_basename) > 55); 
    $top_html .= "$spectrum_basename\n";
  }
  if ($precursor_rt) {
    $precursor_rt = sprintf "%0.3f", ${precursor_rt}/60;
    $top_html .= "<br>Precursor RT\: $precursor_rt\n";
  }
  $top_html .= "<br><b>Chromatogram ID: </b>$param_href->{SEL_chromatogram_id}\n"
     if $param_href->{SEL_chromatogram_id};
  $top_html .= "<br><b><u>mQuest:</u></b>&nbsp;" unless $param_href->{no_mquest};
  my $mquest_params_displayed=0;
  if ($best_peak_group_rt) {
    my $best_peak_group_rt_s = sprintf "%0.3f", ${best_peak_group_rt}/60;
    $top_html .= "<b>best pg RT</b>=$best_peak_group_rt_s&nbsp;\n";
    $mquest_params_displayed++;
  }
  if ($S_N) {
    my $S_N_s = sprintf "%0.3f", $S_N;
    $top_html .= "<b>S/N</b>=$S_N_s&nbsp;\n";
    $mquest_params_displayed++;
  }
  if ($max_apex_intensity) {
    my $max_apex_intensity_s = sprintf "%0.3f", $max_apex_intensity;
    $top_html .= "<b>log max apex intens</b>=$max_apex_intensity_s&nbsp;\n";
    $mquest_params_displayed++;
  }
  $top_html .= "<br>" if $mquest_params_displayed == 3;
  if ($light_heavy_ratio_maxapex) {
    my $light_heavy_ratio_maxapex_s = sprintf "%0.3f",
        $light_heavy_ratio_maxapex;
    $top_html .=
        "<b>light/heavy maxapex</b>=$light_heavy_ratio_maxapex_s&nbsp;\n";
    $mquest_params_displayed++;
  }
  $top_html .= "<br>" if $mquest_params_displayed == 3;
  if ($m_score) {
    $top_html .= "<br><b>mProphet:</b> ";
    my $m_score_s = sprintf "%0.3f", $m_score;
    $top_html .= "m_score=$m_score_s\n";
    $mquest_params_displayed++;
  }
  return $top_html;
}

###############################################################################
# getTopHTMLfromJson
###############################################################################
sub getTopHTMLfromJson {
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $json_string = $args{'json_string'};

  my $json = new JSON;
  # This is giving an error. Maybe now's the time to CREATE the json
  # string using the JSON package!
  my $json_href = $json->decode($json_string);
  my $top_html = $json_href->{info}->[0]{'top_html'};
  return $top_html;
}


###############################################################################
# readJsonChromatogramIntoResultsetHash -
#   read json object into array. Store array plus
#   list of column headers in a hash of format expected by writeResultSet.
###############################################################################
sub readJsonChromatogramIntoResultsetHash {

  my $self = shift;
  my %args = @_;
  my $param_href = $args{param_href};
  my $json_string = $args{json_string};
  my $json_physical_pathname = $args{json_physical_pathname};
  my %dataset;
  my @chromatogram_array = ();

  # If a string is provided, use it. Otherwise, try opening the file.
  # Best to pass in a string, though.
  if ( ! $json_string ) {
    open (JSON_FILE, $json_physical_pathname) ||
    die "Can't open .json file $json_physical_pathname";
    #@json_lines = <JSON_FILE>;
    $json_string = join (' ', <JSON_FILE>);
    close JSON_FILE;
  }

  my $json = new JSON;
  my $json_href = $json->decode( $json_string );

  my ($trace_num, $time, $q1, $q3, $intensity);
  $trace_num = 0;

  for my $entry ( @{$json_href->{'data_json'}} ) {
    $trace_num++;
    my $full_label = $entry->{'full'};
    ($q1, $q3) = ($full_label =~ /Q1:(\d+\.\d+)\s+Q3:(\d+\.\d+)/);
    for my $timepoint (@{$entry->{'data'}}) {
      $time = $timepoint->{'time'};
      $intensity = $timepoint->{'intensity'};
      #print "<br>$time $q3 $intensity<br>\n";
      push (@chromatogram_array, [$trace_num, $time, $q1, $q3, $intensity]);
    }
  }

  $dataset{data_ref} = \@chromatogram_array;
  $dataset{column_list_ref} = ['trace_num', 'seconds', 'Q1', 'Q3', 'intensity'];
  return \%dataset;
}

###############################################################################
# getBottomHTMLforChromatogramViewer
###############################################################################
sub getBottomHTMLforChromatogramViewer {

  my $self = shift;
  my %args = @_;
  my $param_href = $args{param_href};
  my $rs_set_name = $args{rs_set_name};

  my $bottom_html =  qq~
  <BR>Download chromatogram in Format: 
  <a href="$CGI_BASE_DIR/GetResultSet.cgi/$rs_set_name.tsv?rs_set_name=$rs_set_name&format=tsv">TSV</a>,
  <a href="$CGI_BASE_DIR/GetResultSet.cgi/$rs_set_name.xls?rs_set_name=$rs_set_name&format=excel">Excel</a>
  <BR><BR>
  ~;

  return $bottom_html;
}

###############################################################################
# getTransitionGroupInfo_from_sptxt        Nabbed from Eric's
#  /net/db/projects/spectraComparison/FragmentationComparator.pm
###############################################################################
sub getTransitionGroupInfo_from_sptxt {
  my $self = shift || croak("parameter self not passed");
  my %args = @_;
  my $pepseq = $args{pepseq};
  my $charge = $args{charge};
  my $sptxt_pathname = $args{sptxt_pathname};
  my $target_peptideIon = $pepseq . "/" . $charge;

  my $q1;
  my $transition_info = '';

  my $forceCysToAlkylate = 1;

  open(INFILE,$sptxt_pathname)
     || die("ERROR: Cannot open file '$sptxt_pathname'");
  my $line;
  my $peptideIon;
  my $is_match = 0;
  my $nMatches = 0;
  my $fulltext = '';

  while ($line = <INFILE>) {
    my $full_line = $line;
    $line =~ s/\r\n//g; #strip newline; but why not use chomp?
    next if ($line =~ /^#/);  # skip comments.
    if ($line =~ /^Name: (.+)/) {
      $peptideIon = $1;

      #### Hack to work around non-alkylation
      if ( $forceCysToAlkylate && $peptideIon =~ /C[A-Z]/ ) {
	$peptideIon =~ s/C/C[160]/g;
      }

      # Check stripped pepseq, also. ?
#      $is_match = ($peptideIon eq $target_peptideIon);
      $is_match = ( $peptideIon eq $target_peptideIon ) ? 1 : 0;

      if ( !$is_match && $pepseq =~ /N\[115\]/ ) {
        $target_peptideIon =~ s/N\[115\]/D/g;
        $is_match = ( $peptideIon eq $target_peptideIon ) ? 1 : 0;
      }

      print "<!-- target $target_peptideIon -->\n" if $is_match;

    }
    if ($is_match) {
      $fulltext .= $full_line;
      if ($line =~ /^PrecursorMZ: (.+)/i) {
	$q1 = $1;
      }
      if ($line =~ /^NumPeaks: (.+)/) {
	my $nPeaks = $1;
	for (my $i=0; $i< $nPeaks; $i++) {
	  $line = <INFILE>;
	  $fulltext .= $line;
	  my ($mz,$int,$explanations) = split(/\s+/,$line);

	  if ($explanations =~ /^([by])(\d+)([-\d]*)(\^\d)*\/([-\.\d]+)/) {
	    my $variance = $5;
	    #if (abs($variance) <= $matchTolerance) {
	    my $series = $1;
	    my $ordinal = $2;

	    #### Handle the neutral loss if present
	    my $neutralLoss = $3;
	    if (!defined($neutralLoss) || $neutralLoss eq '') {
	      $neutralLoss = 0;
	    } else {
	    }

	    #### Handle the option charge designation
	    my $fragmentCharge = $4;
	    if (!defined($fragmentCharge)) {
	      $fragmentCharge = 1;
	    } else {
	      $fragmentCharge =~ s/\^//;
	    }

	    my @tmp;
	    #### For now, ignore neutral losses until we're ready to
	    #### handle them everywhere
	    if ($neutralLoss) {
	    } else {
	      # is this the correct format?
	      $transition_info .= "$mz,$series$ordinal+$fragmentCharge,,";
	    }

	    #}
	  } else {
	    $transition_info .= "$mz,,,";
	  }
	}
	$nMatches++;
      }
    }
  }

  die "$nMatches matches for $peptideIon in $sptxt_pathname! Last one used."
    if ($nMatches > 1);

  close(INFILE);
  return($q1, $transition_info, $fulltext);
}

###############################################################################
# getChromatogramInfo
#    Given some parameters defining a chromatogram, return that chromatogram
#    as a json object that can be read by Chromavis. Called from both
#    getChromatogramInfo wrapper cgi and from PeptideAtlas page
#    ShowChromatogram cgi.
###############################################################################
sub getChromatogramInfo {

  #### Process the arguments list
  my $self = shift;
  my $parameters_href = shift;

  # Create a chromatogram object so we can use its methods
  my $cgram = new SBEAMS::PeptideAtlas::Chromatogram;
  $cgram->setSBEAMS($sbeams);

  # Get all necessary info from database using chromatogram_id, if
  # provided. Else, we assume info was passed in via parameters or that we
  # can get it from an .sptxt file.

  if ( $parameters_href->{'SEL_chromatogram_id'} ) {
    $cgram->getChromatogramParameters(
      SEL_chromatogram_id => $parameters_href->{'SEL_chromatogram_id'},
      param_href => $parameters_href,
    );
  }

  # Fetch some of the parameters into scalar variables.
  my $precursor_charge = $parameters_href->{'precursor_charge'};
  my $pepseq = $parameters_href->{'pepseq'};
  my $modified_pepseq = $parameters_href->{'modified_pepseq'} || $pepseq;
  my $spectrum_pathname = $parameters_href->{'spectrum_pathname'} ||
  die 'getChromatogramInfo(): Need parameter spectrum_pathname';
  my $spectrum_basename = $parameters_href->{'spectrum_basename'};
  $spectrum_pathname =~ /.*(\..*)/; my $filename_extension = $1;
  if (! $spectrum_basename ) {
    $spectrum_pathname =~ /.*\/(\S+?)\.${filename_extension}/;
    $spectrum_basename = $1;
  }
  my $precursor_neutral_mass = $parameters_href->{'precursor_neutral_mass'};
  my $machine = $parameters_href->{'machine'};
  my $sptxt_fulltext = '';

  # Check that we can obtain or calculate a Q1 or precursor_neutral_mass.
  if ( ! defined $parameters_href->{q1} ) {
    # see if there is an sptxt file to go with the spectrum_pathname
    my $sptxt_pathname = $spectrum_pathname;
    $sptxt_pathname =~ s/${filename_extension}/\.sptxt/ ;
    if (-e $sptxt_pathname) {
       ($parameters_href->{'q1'},
        $parameters_href->{'transition_info'},
        $sptxt_fulltext ) =
      $cgram->getTransitionGroupInfo_from_sptxt (
	pepseq => $modified_pepseq,
	charge => $precursor_charge,
	sptxt_pathname => $sptxt_pathname,
      );
      # if there is no sptxt, and no precursor mass, try to calculate the
      # mass from the pepseq. If no pepseq either, we can't proceed.
    } elsif ( ! defined $precursor_neutral_mass ) {
      if ( defined $modified_pepseq )  {
	use SBEAMS::Proteomics::PeptideMassCalculator;
	my $calculator = new SBEAMS::Proteomics::PeptideMassCalculator;
	$parameters_href->{'precursor_neutral_mass'} =
	  $calculator->getPeptideMass( sequence=>$modified_pepseq );
      } else {
	die "Cannot find transition info. Must provide PASSEL SEL_chromatogram_id--OR--spectrum_pathname for an mzML that has an .sptxt file of same name--OR--q1, pepseq, or precursor_neutral_mass param (plus optional precursor_charge and/or optional transition_info param with format Q3,ion,rel_intens,Q3,ion,rel_intens, ...)";
      }
    }
  }

  # Get the HTML for the top of the chromatogram viewer page
  my $top_html = $cgram->getTopHTMLforChromatogramViewer (
    param_href => $parameters_href,
    seq => $parameters_href->{'modified_pepseq'},
    precursor_neutral_mass => $parameters_href->{'precursor_neutral_mass'},
    precursor_charge => $parameters_href->{'precursor_charge'},
    spectrum_basename => $spectrum_basename,
  );

  #### Extract chromatogram data from spectrum file
  ####  into a json data structure
  my $json_string = $cgram->specfile2json(
    param_href => $parameters_href,
    mass => $parameters_href->{'precursor_neutral_mass'},
    charge => $parameters_href->{'precursor_charge'},
#--------------------------------------------------
#     pepseq => $parameters_href->{'modified_pepseq'},
#     isotype => $parameters_href->{'isotype'},
#     is_decoy => $parameters_href->{'is_decoy'},
#     experiment => $parameters_href->{'experiment_title'},
#     spectrum_file => $parameters_href->{'spectrum_pathname'},
#     chromatogram_id => $parameters_href->{'SEL_chromatogram_id'},
#-------------------------------------------------- 
    q1_tolerance => $parameters_href->{'q1_tolerance'} || 0.07,
    q3_tolerance => $parameters_href->{'q3_tolerance'} || 0.07,
    ms2_scan => $parameters_href->{'scan'},
    top_html => $top_html,
  );

  return $json_string, $sptxt_fulltext;

}

###############################################################################
=head1 BUGS

Please send bug reports to SBEAMS-devel@lists.sourceforge.net

=head1 AUTHOR

Terry Farrah (terry.farrah@systemsbiology.org)

=head1 SEE ALSO

perl(1).

=cut
###############################################################################
1;

__END__
###############################################################################
###############################################################################
###############################################################################
