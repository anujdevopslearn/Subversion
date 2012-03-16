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


sub get_spectrum_peaks {
	my $self = shift;
	my %args = @_;

  for my $arg ( qw( file_path entry_idx ) ) {
		$log->printStack( 'warn' );
    die $arg unless defined $args{$arg};
  }

#  print "Looking in file $args{file_path} for index $args{entry_idx}\n";

  open FIL, $args{file_path} || die "Unable to open library file $args{file_path}";
  seek ( FIL, $args{entry_idx}, 0 );
  my $collect_peaks;
  my %spectrum = ( n_peaks => 0,
                   masses => [],
                   intensities => [],
                   labels => [],
                   original_intensity => 1,
                   max_intensity => 1,
                   full_name => '' );

  my $cnt = 0;
  my $peak_cnt;
  while ( my $line = <FIL> ) {
    $cnt++;
    chomp $line;

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
    last if $line =~ /^\s*$/;

    my ( $mass, $intensity, $annot ) = $line =~ /(\S+)\s+(\S+)\s+(\S+)\s.*$/;
    my @annot = split( /\//, $annot );

    if ( $args{strip_unknowns} ) {
			next if $annot[0] =~ /^\?$/;
		}

    push @{$spectrum{labels}}, $annot[0];

    push @{$spectrum{masses}}, $mass;

#    if ( $annot[0] eq 'y8' ) {
#      print STDERR "pushing $mass and $intensity for $annot[0]\n";
#    }

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
      print STDERR "Past our due date with $line\n";
      last;
    }
  }
#  print " saw $cnt total rows for $args{file_path} entry $args{entry_idx}!\n";
#  print STDERR " masses: " . scalar( @{$spectrum{masses}} ) . " entries";
#  print STDERR " intensities: " . scalar( @{$spectrum{intensities}} ) . " entries";
#
my $example = qq~
Name: AAAAASAAGPGGLVAGK/2
LibID: 1
MW: 1340.7401
PrecursorMZ: 670.3700
Status: Normal
FullName: X.AAAAASAAGPGGLVAGK.X/2
Comment: AvePrecursorMz=670.7645 BestRawSpectrum=QT07072010_ISBHJKXXX000035_W1_P3-r001.mzML.1161415.1161415.2 BinaryFileOffset=6362 CollisionEnergy=31.4 ConsFracAssignedPeaks=0.720 DotConsensus=0.89,0.01;0/2 FracUnassigned=0.29,2/5;0.32,7/20;0.38,886/1299 Inst=1/quadrupole,2,0 MassDiffCounts=1/0:2 MaxRepSN=18.8 Mods=0 NAA=17 NISTProtein=1/ISBHJKXXX000035 NMC=0 NTT=1 Nreps=2/2 OrigMaxIntensity=2.3e+03 Parent=670.37 Pep=Tryptic PrecursorIntensity=5.7e+04 Prob=1.0000 ProbRange=1,1,1,1 Protein=1/1/ISBHJKXXX000035 RepFracAssignedPeaks=0.325 RepNumPeaks=1060.0/239.0 RetentionTime=1158.0,1161.4,1154.6 SN=200.0 Sample=1/interact-ipro.pep.xml,2,2 Se=1^K2:ex=4.0000e-04/0.0000e+00,fv=7.1410/0.3379,hs=481.0000/10.0000,ns=236.5000/5.5000,pb=0.9992/0.0000 Spec=Consensus TotalIonCurrent=3.6e+05
NumPeaks: 150
70.0642 1703.7  IPA/-0.00,IPA/-0.00     2/2 0.0000|0.07
72.0817 1145.5  b1/0.04,b2^2/0.04,IVA/0.00,IVA/0.00     2/2 0.0000|0.01
84.0833 531.1   y2-35^2/-0.97   2/2 0.0040|0.51
86.0968 1252.8  ILA/0.00,ILA/0.00       2/2 0.0022|0.47
102.0594        398.2   y2^2/-0.51,y1-46/0.95   2/2 0.0028|0.64
115.0859        2260.5  a2/-0.00,y3-46^2/-0.00  2/2 0.0000|0.06
120.0795        244.4   y3-35^2/-0.49   2/2 0.0021|0.15
127.0866        678.6   ?       2/2 0.0000|0.14
129.1022        1619.6  y1-18/-0.00,y3-17^2/-0.47,y3-18^2/0.02,a4^2/0.02        2/2 0.0000|0.19
130.0892        892.9   y1-17/0.00      2/2 0.0036|0.15
139.0673        376.4   y3^2/0.98       2/2 0.0208|0.00
143.0809        7889.9  b4^2/-0.00,b2/-0.00     2/2 0.0000|0.10
144.0798        917.4   b2i/-0.00       2/2 0.0031|0.45
147.1094        1130.3  y1/-0.00        2/2 0.0019|0.03
148.1146        261.9   y1i/0.00        2/2 0.0074|0.04
155.0817        346.8   ?       2/2 0.0033|0.03
159.0737        770.6   y2-46/0.94      2/2 0.0019|0.40


~;

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


######################## END SAFE


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

  my %libmap;
  if ( !$args{organism} ) {
    $log->error( "Missing required argument 'organism'" );
    return {};
  }

  if ( $args{organism} != 2 || $sbeams->isGuestUser() ) {

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

  } else {

    %libmap = ( 300 => 'low',
                301 => 'mlow', 
                302 => 'medium',
                303 => 'mhigh', 
                304 => 'high',
                 16 => 'it',
                293 => 'qqq',
                306 => 'qtrap',
               );
  }

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
    if ( $row[3] > 276 && $row[3] < 282 ) {
      $libs{CE}->{$row[0]. $row[2]}++;
    }
    next unless $row[3] == 279;
    $libs{qtof}->{$row[0]. $row[2]} = $row[1];
  }

  return \%libs;

}

1;

