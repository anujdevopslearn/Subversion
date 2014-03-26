package SBEAMS::PeptideAtlas::ConsensusSpectrum;

###############################################################################
# Class       : SBEAMS::PeptideAtlas::ConsensusSpectrum;
#
=head1 SBEAMS::PeptideAtlas::ConsensusSpectrum

=head2 SYNOPSIS

  SBEAMS::PeptideAtlas::ConsensusSpectrum

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

use SBEAMS::Connection qw( $log );
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

sub spectrum_search {
  my $self = shift;
  my %args = @_;

  for my $opt ( qw( seq ) ) {
    die( "Missing required parameter $opt" ) unless defined $args{$opt};
  }

  my $charge = ( !$args{charge} ) ? '' : "AND charge = '$args{charge}'";
  my $m_seq = ( !$args{m_seq} ) ? '' : "AND modified_sequence = '$args{m_seq}'";
  my $lib = ( !$args{lib_id} ) ? '' : "AND CLS.consensus_library_id = '$args{lib_id}'";

  my $sql =<<"  END";
  SELECT consensus_library_spectrum_id, sequence, charge, modifications, protein_name,
    mz_exact, consensus_spectrum_type_id, CLS.consensus_library_id, modified_sequence,
    protein_name_alt, consensus_library_name
    FROM $TBAT_CONSENSUS_LIBRARY_SPECTRUM CLS
    JOIN $TBAT_CONSENSUS_LIBRARY CL ON CL.consensus_library_id = CLS.consensus_library_id
    WHERE sequence = '$args{seq}'
    AND file_path IS NULL
    $charge
    $m_seq
    $lib
  END
  my @rows = $sbeams->selectSeveralColumns( $sql );
  return \@rows || [];
}

sub spectrum_search_origene {
  my $self = shift;
  my %args = @_;

  for my $opt ( qw( seq ) ) {
    die( "Missing required parameter $opt" ) unless defined $args{$opt};
  }

  my $charge = ( !$args{charge} ) ? '' : "AND charge = '$args{charge}'";
  my $m_seq = ( !$args{m_seq} ) ? '' : "AND modified_sequence = '$args{m_seq}'";
  my $lib = ( !$args{lib_id} ) ? '' : "AND CLS.consensus_library_id = '$args{lib_id}'";

  my $sql =<<"  END";
  SELECT consensus_library_spectrum_id, sequence, charge, modifications, protein_name,
    mz_exact, consensus_spectrum_type_id, CLS.consensus_library_id, modified_sequence,
    protein_name_alt, consensus_library_name
    FROM $TBAT_CONSENSUS_LIBRARY_SPECTRUM CLS
    JOIN $TBAT_CONSENSUS_LIBRARY CL ON CL.consensus_library_id = CLS.consensus_library_id
    WHERE sequence = '$args{seq}'
    AND consensus_library_name like 'origene%' 
    $charge
    $m_seq
    $lib
  END
  my @rows = $sbeams->selectSeveralColumns( $sql );
  return \@rows || [];
}


sub has_QTOF_stepping {
  my $self = shift;
  my %args = @_;

  for my $opt ( qw( seq ) ) {
    die( "Missing required parameter $opt" ) unless defined $args{$opt};
  }

  my $sql =<<"  END";
  SELECT consensus_library_spectrum_id 
    FROM $TBAT_CONSENSUS_LIBRARY_SPECTRUM CLS
    WHERE consensus_library_id = 244
    AND sequence = '$args{seq}'
  END
  my @rows = $sbeams->selectSeveralColumns( $sql );
  return ( scalar( @rows ) ) ? 1 : 0;
}

sub get_QTOF_stepping {
  my $self = shift;
  my %args = @_;

  for my $opt ( qw( seq ) ) {
    die( "Missing required parameter $opt" ) unless defined $args{$opt};
  }

  my %libmap = ( 242 => 'low',
                 243 => 'mlow', 
                 244 => 'medium',
                 245 => 'mhigh', 
                 246 => 'high' );
	my $libs = join( ',', keys( %libmap ));

  my $sql =<<"  END";
  SELECT modified_sequence, charge, consensus_library_id, 
         consensus_library_spectrum_id 
    FROM $TBAT_CONSENSUS_LIBRARY_SPECTRUM CLS
    WHERE consensus_library_id IN ( $libs )
    AND sequence = '$args{seq}'
  END
  my %ce;
  return \%ce if $sbeams->isGuestUser();

  for my $row ( $sbeams->selectSeveralColumns( $sql ) ) {
    my $key = $row->[0] . $row->[1];
    $ce{$key} ||= {};
    $ce{$key}->{$libmap{$row->[2]}} = $row->[3];
  }
  return \%ce;

}

#+ 
# Routine to extract spectrum peaks from a raw or gzipped sptxt file. Split
# apart from process_spectrum_record 2014-03-11
#- 
sub get_spectrum_peaks {

	my $self = shift;
	my %args = @_;
#  use Data::Dumper;
#  die Dumper( %args );

  for my $arg ( qw( file_path entry_idx ) ) {
    die $arg unless defined $args{$arg};
  }

  my @lines;
  if ( $args{bgzipped} ) {
    for my $arg ( qw( rec_len ) ) {
      die $arg unless defined $args{$arg};
    }
    my $bgz_out = `/tools/bin/bgzip -b $args{entry_idx} -s $args{rec_len} -c -d $args{file_path} `;
    @lines = split( /\n/, $bgz_out );
  } else {
    if ( ! -e $args{file_path} ) {
      $log->warn( "missing sptxt file $args{file_path}" );
      if ( -e "$args{file_path}.gz" ) {
        $log->warn( "sptxt file is seen as gzipped, please inform an administrator $args{file_path}.gz" );
      }
      return undef;
    }
    open FIL, $args{file_path} || die "Unable to open library file $args{file_path}";
    seek ( FIL, $args{entry_idx}, 0 );
    my $cnt = 0;
    my $name_seen = 0;
    while ( my $line = <FIL> ) {
      # First record should be Name: sequence/charge
      if ( $cnt++ < 2 && !$name_seen ) {
        if ( $line =~ /^Name:/ ) {
          $name_seen++;
        } elsif ( $cnt > 1 ) {
          $log->warn( "Spectrum record does not contain Name: $line\n" );
        } else {
          if ( $line ) {
            $log->warn( "First line of spectrum record is not Name: $line\n" );
          }
        }
      }
      last if $line =~ /^\s*$/ && $cnt > 2; # fudge factor to help off-by-one indexing.
      push @lines, $line;
    }
    close FIL;
  }

  if ( $args{return_record_as_array} ) {
    return \@lines;
  }

  my $spectrum = $self->process_spectrum_record( %args, lines => \@lines );
  return $spectrum;

  # deprecated debugging stuff!
  my @keys = sort( keys( %{$spectrum} ) );
  my $specdump = "Spectrum has " . scalar( @keys ) . " keys:\n";
  for my $key ( @keys ) {
    my $ref = ref $spectrum->{$key} || 'SCALAR';
    $specdump .= "$key is a(n) $ref ";
    if ( $ref eq 'ARRAY' ) {
      $specdump .= " with " . scalar( @{$spectrum->{$key}} ) . " entries\n";
    } elsif ( $ref eq 'HASH' ) {
      $specdump .= " with " . scalar( keys( %{$spectrum->{$key}} ) ) . " keys\n";
    } else {
      $specdump .= " with " . length( $spectrum->{$key} ) . " characters\n";
    }
  }
  $log->warn( $specdump );
}

#+ 
# Routine to process records from a spectrum passed as an array
#- 
sub process_spectrum_record {

	my $self = shift;
	my %args = @_;

  my $collect_peaks;
  my %spectrum = ( n_peaks => 0,
                   masses => [],
                   intensities => [],
                   labels => [],
                   original_intensity => 1,
                   max_intensity => 1,
                   full_name => '' );

  if ( !$args{lines} ) {
    $log->warn( "No lines!" );
    return \%spectrum;
  }

  my $peak_cnt;

  for my $line ( @{$args{lines}} ) {

    # Nreps=2/2 
    if ( $line =~ /Nreps=(\d+\/\d+)\s+/ ) {
      $spectrum{replicates} = $1;
    }
    # OrigMaxIntensity=2.3e+03
    if ( $line =~ /OrigMaxIntensity=(\S+)\s+/ ) {
      $spectrum{original_intensity} = $1;
    }
    #PrecursorIntensity=5.7e+04
    if ( $line =~ /PrecursorIntensity=(\S+)\s+/ ) {
      $spectrum{precursor_intensity} = $1;
    }

    #FullName: X.VLDVNDNAPK.X/2
    if ( $line =~ /FullName:\s+(\S+)\s*/ ) {
      $spectrum{full_name} = $1;
#      print STDERR "Fullname is $spectrum{full_name}\n";
    }

    if ( $line =~ /^NumPeaks:\s+(\d+)\s*$/ ) {
      $spectrum{n_peaks} = $1;
      $collect_peaks++;
      next;
    } elsif ( $line =~ /^NumPeaks/ ) {
      die "Why didn't $line trip it!";
    }
    next unless $collect_peaks;

    my ( $mass, $intensity, $annot ) = $line =~ /(\S+)\s+(\S+)\s+(\S+)\s.*$/;
    my @annot = split( /\//, $annot );

    if ( $args{strip_unknowns} ) {
			next if $annot[0] =~ /^\?$/;
		}

    push @{$spectrum{labels}}, $annot[0];

    push @{$spectrum{masses}}, $mass;

    # User wants intensities normalized to precursor m/z 
    if ( $args{precursor_normalize} ) {
   #   $intensity = sprintf( "%0.4f", (($intensity*($spectrum{original_intensity}/10000))/($spectrum{precursor_intensity}/10000)) );
      $intensity = sprintf( "%0.4f", (($intensity)/($spectrum{precursor_intensity}/10000)) );
    # User wants real intensities instead of norm to 10K
    } 
		if ( $args{denormalize} ) {
      $spectrum{denormalized}++;
      $intensity = sprintf( "%0.4f", $intensity*($spectrum{original_intensity}/10000) );
    }

    # Cache the max intensity
    $spectrum{max_intensity} = $intensity if $intensity > $spectrum{max_intensity};
    $spectrum{max_intensity} ||= '';
    push @{$spectrum{intensities}}, $intensity;

    if ( $annot =~ /^(p\^\d)\// ) {
      $spectrum{postfrag_precursor_intensity} = sprintf( "%0i", $intensity);
    }

#    print STDERR "pushing $1 and $2 to the m/i arrays\n";
    $peak_cnt++;
    if ( $peak_cnt > $spectrum{n_peaks} ) {
      $log->warn( "Past our due date with $line\n" );
      last;
    }
  }
  return \%spectrum;
}

sub get_top_n_peaks {
  my $self = shift;
  my %args = ( n_peaks => 5, @_ );

  return '' unless $args{spectra};

  my $spectrum = $args{spectra};

#  $spectrum = { masses => [], 
#                intensities => [],
#                labels => [],
#                original_intensity => #,
#                n_peaks => # }

  my @peaks;
  for ( my $i = 0; $i <= $spectrum->{n_peaks}; $i++ ) {
    # only look for b/y ions
    next unless $spectrum->{labels}->[$i] =~ /^[yb]/i;
    next if $spectrum->{labels}->[$i] =~ /\i$/i;

    if ( $args{precursor_exclusion} ) {
      my $min = $spectrum->{mz} - $args{precursor_exclusion};
      my $max = $spectrum->{mz} + $args{precursor_exclusion};

      if (  $spectrum->{masses}->[$i] > $min && $spectrum->{masses}->[$i] < $max ) {
#        die "Excluded $spectrum->{masses}->[$i] ( $spectrum->{labels}->[$i] ) becuase min is $min and max is $max from  $spectrum->{mz} - $args{precursor_exclusion}";
        next;
      }
    }
#    next unless $spectrum->{labels}->[$i] eq 'y8';
#    print STDERR "$spectrum->{labels}->[$i] has $spectrum->{intensities}->[$i]\n";
    my $peak = { label => $spectrum->{labels}->[$i],
                  mass => $spectrum->{masses}->[$i],
             intensity => $spectrum->{intensities}->[$i] };
    $peak->{intensity} *=  ($spectrum->{original_intensity}/10000) if $args{denormalize};
    push @peaks, $peak;
  }

  my %peaks;
  my @peak_list;
  if ( $args{peak_list} ) {
    my %peak_hash;
    for my $peak ( @{$args{peak_list}} ) {
      $peak_hash{$peak}++;
    }
    for my $peak ( @peaks ) {
      if ( $peak_hash{$peak->{label}} ) {
        $peaks{$peak->{label}} = $peak->{intensity};
      }
    }
  } else {
    my @ordered = sort { $b->{intensity} <=> $a->{intensity} } ( @peaks );
    for my $peak ( @ordered ) {
      $peaks{$peak->{label}} = $peak->{intensity};
      push @peak_list, $peak->{label};
      last if scalar( @peak_list ) >= $args{n_peaks};
    }
    return ( \%peaks, \@peak_list );
  }
  return \%peaks;
}


##### Start safe

sub getConsensusLinksSAVE {

  my $self = shift;

  my %args = @_;
  my $seq_and = '';
  if ( $args{modified_sequence} ) {
    my $sequence = $args{modified_sequence};
    $sequence =~ s/\[\d+\]//g;
    $seq_and = "AND sequence = '$sequence'\n";
  }

  # Force production for now
  $TBAT_CONSENSUS_LIBRARY_SPECTRUM = 'peptideatlas.dbo.consensus_library_spectrum';
  $TBAT_CONSENSUS_LIBRARY = 'peptideatlas.dbo.consensus_library';

  my %libs = ( it => {}, qtof => {}, qtrap => {}, CE => {}, qqq => {},
          low => {}, mlow => {}, medium => {}, mhigh => {}, high=> {} );

  print "Getting IT libs<BR>\n";
  my $it_sql = qq~
  SELECT modified_sequence, consensus_library_spectrum_id, charge
  FROM $TBAT_CONSENSUS_LIBRARY_SPECTRUM 
  WHERE consensus_library_id = 16
  $seq_and
  ~;
  my $sth = $sbeams->get_statement_handle( $it_sql );
  while ( my @row = $sth->fetchrow_array() ) {
    $libs{it}->{$row[0]. $row[2]} = $row[1];
  }
  print "Getting qqq libs with $seq_and<BR>\n";

  my $qqq_sql = qq~
  SELECT modified_sequence, consensus_library_spectrum_id, charge
  FROM $TBAT_CONSENSUS_LIBRARY_SPECTRUM 
  WHERE consensus_library_id = 292
  $seq_and
  ~;
  my $sth = $sbeams->get_statement_handle( $qqq_sql );
  while ( my @row = $sth->fetchrow_array() ) {
    $libs{qqq}->{$row[0]. $row[2]} = $row[1];
  }

  print "Getting qtof libs<BR>\n";

  my $qtof_sql = qq~
  SELECT modified_sequence, consensus_library_spectrum_id, charge
  FROM $TBAT_CONSENSUS_LIBRARY_SPECTRUM
  WHERE consensus_library_id = 279
  $seq_and
  ~;
#  print $qtof_sql;
  my $sth = $sbeams->get_statement_handle( $qtof_sql );
  while ( my @row = $sth->fetchrow_array() ) {
    $libs{qtof}->{$row[0]. $row[2]} = $row[1];
  }

  print "Getting qtrap libs<BR>\n";
  my $qtrap_sql = qq~
  SELECT modified_sequence, consensus_library_spectrum_id, charge
  FROM $TBAT_CONSENSUS_LIBRARY_SPECTRUM
  WHERE consensus_library_id = 282
  $seq_and
  ~;
  my $sth = $sbeams->get_statement_handle( $qtrap_sql );
  while ( my @row = $sth->fetchrow_array() ) {
    $libs{qtrap}->{$row[0]. $row[2]} = $row[1];
  }


#  my %libmap = ( 21 => 'medium', 22 => 'high', 23 => 'low', 24 => 'mhigh', 25 => 'mlow', 26 => 'avg' );
#  my %libmap = ( 29 => 'medium', 30 => 'high', 31 => 'low', 32 => 'mhigh', 33 => 'mlow', 27 => 'avg' );
  print "Getting CE libs<BR>\n";
  my %libmap = ( 277 => 'low',
                 278 => 'mlow', 
                 279 => 'medium',
                 280 => 'mhigh', 
                 281 => 'high' );
	my $libs = join( ',', keys( %libmap ));
  my $ce_sql = qq~
  SELECT modified_sequence, consensus_library_spectrum_id, charge, consensus_library_id
  FROM peptideatlas.dbo.consensus_library_spectrum 
  WHERE consensus_library_id IN ( $libs ) 
  $seq_and
  ~;
  my $sth = $sbeams->get_statement_handle( $ce_sql );
  while ( my @row = $sth->fetchrow_array() ) {
    $libs{$libmap{$row[3]}}->{$row[0]. $row[2]} = $row[1];
    $libs{CE}->{$row[0]. $row[2]}++;
  }

  return \%libs;

}

sub hasCESet {
  my $self = shift;
  my %args = @_;

  return unless $args{pabst_build_id};
  my $sql = qq~
  SELECT COUNT(*) 
  FROM $TBAT_PABST_BUILD_RESOURCE PBR
  WHERE resource_type = 'qtof_ce_set'
  AND pabst_build_id = $args{pabst_build_id}
  ~;

  my $has_ce = 0;
  my $sth = $sbeams->get_statement_handle( $sql );
  while ( my @row = $sth->fetchrow_array() ) {
    $has_ce++ if $row[0];
  }
  return $has_ce;
}

sub hasChromatograms {
  my $self = shift;
  my %args = @_;

  return unless $args{pabst_build_id};
  my $sql = qq~
  SELECT COUNT(*) 
  FROM $TBAT_PABST_BUILD_RESOURCE PBR
  WHERE resource_type = 'chromatogram_set'
  AND pabst_build_id = $args{pabst_build_id}
  ~;

  my $has_chromats = 0;
  my $sth = $sbeams->get_statement_handle( $sql );
  while ( my @row = $sth->fetchrow_array() ) {
    $has_chromats++ if $row[0];
  }
  return $has_chromats;
}

sub getConsensusSources {
  my $self = shift;
  my %args = @_;

  return unless $args{pabst_build_id};
  my $sql = qq~
  SELECT DISTINCT instrument_type_name, IT.instrument_type_id, resource_id
  FROM $TBAT_PABST_BUILD_RESOURCE PBR
  JOIN $TBAT_CONSENSUS_LIBRARY CL ON CL.consensus_library_id = PBR.resource_id
  JOIN $TBAT_INSTRUMENT_TYPE IT on IT.instrument_type_id = PBR.instrument_type_id
  WHERE resource_type = 'spectral_lib'
  AND pabst_build_id = $args{pabst_build_id}
  ~;

  my $sth = $sbeams->get_statement_handle( $sql );
  my %src;
  while ( my @row = $sth->fetchrow_array() ) {
    if ( $args{lib_ids} ) {
      $src{$row[0]} = $row[2];
    } else {
      $src{$row[0]} = $row[1];
    }
  }
  return \%src;
}


sub getConsensusLinks {

  my $self = shift;
  my %args = @_;
  my $seq_and = '';
  if ( $args{modified_sequence} ) {
    my $sequence = $args{modified_sequence};
    $sequence =~ s/\[\d+\]//g;
    $seq_and = "AND sequence = '$sequence'\n";
  }


  # Force production for now
  $TBAT_CONSENSUS_LIBRARY_SPECTRUM = 'peptideatlas.dbo.consensus_library_spectrum';
  $TBAT_CONSENSUS_LIBRARY = 'peptideatlas.dbo.consensus_library';

  my %libs = ( it => {}, qtof => {}, qtrap => {}, CE => {}, qqq => {},
          low => {}, mlow => {}, medium => {}, mhigh => {}, high=> {} );

  my %imap = ( IonTrap => 'it',
               QTOF => 'qtof',
               QTrap4000 => 'qtrap',
               QTrap5500 => 'qtrap',
               QQQ => 'qqq' );

  my %libmap;
  if ( !$args{organism} ) {
    $log->error( "Missing required argument 'organism'" );
    return {};
  }
  my $srcs = $self->getConsensusSources( pabst_build_id => $args{pabst_build_id},
                                                lib_ids => 1 );
  if ( $sbeams->isGuestUser() && !$args{super_guest} ) {
    my $project_ids = $sbeams->getAccessibleProjects();
    my $sql = qq~
    SELECT MAX(consensus_library_id) 
    FROM $TBAT_CONSENSUS_LIBRARY
    WHERE organism_id = $args{organism}
    AND project_id IN ( $project_ids )
    ~;

    my $sth = $sbeams->get_statement_handle( $sql );
    while ( my @row = $sth->fetchrow_array() ) {
      $libmap{$row[0]} = 'it';
      last;
    }

  } elsif ( $srcs ) { 
    for my $src ( keys( %{$srcs} ) ) {
      $libmap{$srcs->{$src}} = $imap{$src};
      $libmap{$srcs->{$src}} = 'medium' if $imap{$src} eq 'qtof';
    }

  } elsif ( $args{organism} eq 40 ) {

    %libmap = ( 
                329  => 'it',
                330 => 'qtrap',
               );

  } else {

#    %libmap = ( 307 => 'low',
#                308 => 'mlow', 
#                309 => 'medium',
#                310 => 'mhigh', 
#                311 => 'high',
#                 16 => 'it',
#                312 => 'qqq',
#                306 => 'qtrap',
#               );
  }

  if ( $args{glyco} ) {

    %libmap = ( 
                327 => 'medium',
                326  => 'it',
                328 => 'qtrap',
               );


  }

  if ( $args{has_ce} ) {
    if ( $libmap{333} ) {
      $libmap{336} = 'low';
      $libmap{337} = 'mlow';
      $libmap{338} = 'mhigh';
      $libmap{339} = 'high';
    } else {
      $libmap{320} = 'low';
      $libmap{321} = 'mlow';
      $libmap{323} = 'mhigh';
      $libmap{324} = 'high';
    }
  }

	my $libs = join( ',', keys( %libmap ));

	return ( \%libs ) unless $libs;

  my $ce_sql = qq~
  SELECT modified_sequence, consensus_library_spectrum_id, charge, consensus_library_id
  FROM peptideatlas.dbo.consensus_library_spectrum 
  WHERE consensus_library_id IN ( $libs ) 
  $seq_and
  ~;

  my $sth = $sbeams->get_statement_handle( $ce_sql );
  while ( my @row = $sth->fetchrow_array() ) {
    $libs{$libmap{$row[3]}}->{$row[0]. $row[2]} = $row[1];
    if ( grep /$libmap{$row[3]}/, ( qw( low mlow medium mhigh high ) )  ) {
      $libs{CE}->{$row[0]. $row[2]}++;
    }
    $libs{qtof}->{$row[0]. $row[2]} = $row[1] if $libmap{$row[3]} eq 'medium';
  }
  if ( $libs{qtof} ) { 
    for my $type ( qw( low mlow medium mhigh high ) ) {
      $libs{$type} ||= {};
    }
  }

  return \%libs;

}

1;

