#!/usr/local/bin/perl -w

use strict;
use DBI;
use Getopt::Long;
use File::Basename;

#use lib( '/net/dblocal/www/html/sbeams/lib/perl' );

use SBEAMS::Connection;
use SBEAMS::Connection::Tables;
use SBEAMS::PeptideAtlas::Tables;

$|++; # don't buffer output

my $args = process_args();
my $sb = SBEAMS::Connection->new();
my $dbh = $sb->getDBHandle();
$dbh->{RaiseError}++;

{ # Main 


  if ( $args->{show_builds} ) {
    show_builds();
  } else {
    get_aa_usage();
  }
} # End main

sub show_builds {
  my $sql = get_build_sql($args->{show_builds});
  my @results = $sb->selectSeveralColumns( $sql . " ORDER BY AB.atlas_build_id" );
  my $intro = ( $args->{show_builds} eq 'def' ) ?  'default' : 'all';
  print "Displaying $intro Atlas build info:\n\n";
  sleep 2;
  print "Build ID\tBuild name\torganism\tProbability\tRef DB\n";
  for my $row ( @results ) {
    $row->[5] = sprintf ( "%0.2f", $row->[5] );
    print join( "\t", @{$row}[0,1,3,5,3] ) . "\n";
  }

}

sub get_aa_usage {
  my %results;
  my $build_where = "WHERE AB.atlas_build_id = $args->{atlas_build}";
  my $nobs_and = "AND n_observations > $args->{n_obs_cutoff}" if $args->{n_obs_cutoff};
  $nobs_and ||= '';

  # Get some info
  my $sql = get_build_sql();
  $sql .= "\n  $build_where\n ";
#  AB.atlas_build_id, atlas_build_name, organism_name, set_name, BS.biosequence_set_id, organism_specialized_build, probability_threshold

  my $r = $sb->selectrow_arrayref( $sql );
  my $cutoff = sprintf ( "%0.2f", $r->[5] );
  print STDERR <<"  END";
  Build ID:\t$r->[0]
  Build Name:\t$r->[1]
  Organism:\t$r->[2]
  P cutoff:\t$cutoff
  Reference DB:\t$r->[3]
  END

  print STDERR "Fetching peptides from build $r->[1]\n";
  my $pepsql =<<"  END"; 
  SELECT DISTINCT peptide_accession, peptide_sequence
   FROM $TBAT_PEPTIDE_INSTANCE AB
   INNER JOIN $TBAT_PEPTIDE P
          ON ( AB.peptide_id = P.peptide_id )
  $build_where
  $nobs_and
  ORDER BY peptide_accession
  END

  $pepsql = $sb->evalSQL( $pepsql );
#  print STDERR "$pepsql\n";
  my $sth = $dbh->prepare( $pepsql );
  $sth->execute();

  my %aa;
  my $cnt;
  my $aa_cnt;
  while( my @row = $sth->fetchrow_array() ) {
    $cnt++;
    my @aa = split "", $row[1];
    for my $aa ( @aa ) {
      $aa{$aa}++;
      $aa_cnt++;
    }
#    last if $cnt > 5;
  }
  print STDERR "Found $aa_cnt amino acids in $cnt peptides\n";

  print STDERR "Fetching proteins from refdb $r->[3]\n";
  my $dbsql =<<"  END"; 
  SELECT biosequence_seq FROM $TBAT_BIOSEQUENCE
  WHERE biosequence_set_id = $r->[4]
  END

  my $sth = $dbh->prepare( $sb->evalSQL($dbsql) );
  $sth->execute();

  my %dbaa;
  my $dbcnt;
  my $dbaa_cnt;
  while( my @row = $sth->fetchrow_array() ) {
    $dbcnt++;
    my @aa = split "", $row[0];
    for my $aa ( @aa ) {
      $dbaa{$aa}++;
      $dbaa_cnt++;
    }
#    last if $dbcnt > 5;
  }

  print STDERR "Saw $dbaa_cnt total aa's in $dbcnt proteins\n";
  print "AA\tBuild $r->[0]\tRef DB\n";
#  print "AA\tAtlas %\tIPI %\tAtlas #\n";
  for my $aa (sort(keys( %aa) )) {
#    my $perc = sprintf( "%0.1f", $aa{$aa}/$aa_cnt * 100 );
    next if $aa =~ /[XBZ]/;
    print "$aa\t$aa{$aa}\t$dbaa{$aa}\n";
#    print "$aa\t$perc%\t$db_aa->{$aa}%\t($aa{$aa}) \n";
  }
}


sub get_build_sql {
  my $type = shift || '';

  my $sql =<<"  END";
  SELECT AB.atlas_build_id, atlas_build_name, organism_name, set_name, BS.biosequence_set_id,
         probability_threshold
  FROM $TBAT_ATLAS_BUILD AB
  JOIN $TBAT_BIOSEQUENCE_SET BS ON BS.biosequence_set_id = AB.biosequence_set_id
  JOIN $TB_ORGANISM O ON BS.organism_id = O.organism_id
  END

  if ( $type eq 'def' ) {
    $sql .= "\n  JOIN $TBAT_DEFAULT_ATLAS_BUILD  DAB ON AB.atlas_build_id = DAB.atlas_build_id \n";
  }
  return $sql;
}


sub process_args {
  my %args;

  GetOptions(\%args, 'atlas_build=i', 'n_obs_cutoff:i', 'show_builds:s', 
                     'percentages', 'organism:s', 'help' );
#      'tsv_file=s' 

  print_usage() if $args{help};
  if ( $args{show_builds} ) {
    $args{show_builds} = 'def' unless $args{show_builds} eq 'all';  
  }

  my $err;
  for my $k ( qw( atlas_build ) ) {
    next if $args{show_builds};
    $err .= ( $err ) ? ", $err" : "Missing required parameter(s) $k" if !defined $args{$k};
  }
  print_usage( $err ) if $err;
  $args{n_obs_cutoff} ||= 0;

  return \%args;
}

sub print_usage {
  my $msg = shift || '';
  my $sub = basename( $0 );
  print <<"  END";
      $msg

usage: $sub -a build_id [ -t outfile -n obs_cutoff -s [all|def] ]

   -a, --atlas_build    (Numeric) atlas build ID to query 
   -n, --n_obs_cutoff   Only show peptides observed > n times (default 0)
   -s, --show_builds    Print info about builds in db 
   -p, --percentages    Return information as percentages instead of raw counts 
   -h, --help           Print usage
  END
#   -t, --tsv_file       print output to specified file rather than stdout
# End of the line
  exit;
}

__DATA__

sub get_db_aa {
  my $file = shift;

# Uncomment to use IPI canned
#  print "using canned version\n";
# print "Saw 26317132 aa in 60397 proteins\n";
#  return get_ipi_nums();

# Uncomment to use YEAST canned
#  print "using canned version\n";
# print "Saw 3019081 aa in 6714 proteins\n";
#  return get_yeast_nums();

# Uncomment to use ENSP canned
  print "using canned version\n";
  print "Saw 23659384 aa in 48218 proteins\n";
  return get_ensp_nums();

  
#  return get_ipi_perc();
  open FIL, "$file" || die "Unable to open file $file";
  my $cnt;
  my $aa_cnt;
  my %aa;
  while ( my $line = <FIL> ) {
    if ( $line =~ /^>/ ) {
      $cnt++;
      next;
    }
    $line =~ s/\s//g;
    $line =~ s/\*//g;
    if ( $line !~ /^[A-Za-z]*$/ ){
      die "Trouble with line $cnt: $line";
    }
    my @aa = split "", $line;
    for my $aa ( @aa ) {
      $aa{$aa}++;
      $aa_cnt++;
    }
#    last if $cnt > 10;
  }
  print "Saw $aa_cnt aa in $cnt proteins\n";
  for my $aa (sort(keys( %aa)) ) {
    print "$aa => $aa{$aa},\n";
  }
  for my $aa (sort(keys( %aa)) ) {
    $aa{$aa} = sprintf( "%0.1f", $aa{$aa}/$aa_cnt * 100 );
    print "$aa => $aa{$aa},\n";
  }
  exit;
  return \%aa;
}

sub get_ipi_nums {
  return { A => 1841393,
           B => 67,
           C => 603139,
           D => 1229870,
           E => 1854882,
           F => 932285,
           G => 1763164,
           H => 695002,
           I => 1119370,
           K => 1488734,
           L => 2583265,
           M => 561740,
           N => 921425,
           P => 1714680,
           Q => 1264388,
           R => 1518949,
           S => 2212529,
           T => 1424025,
           V => 1572115,
           W => 334939,
           X => 3874,
           Y => 677232,
           Z => 65 };

sub get_ipi_perc {
  return { A => 7.0,
           B => 0.0,
           C => 2.3,
           D => 4.7,
           E => 7.0,
           F => 3.5,
           G => 6.7,
           H => 2.6,
           I => 4.3,
           K => 5.7,
           L => 9.8,
           M => 2.1,
           N => 3.5,
           P => 6.5,
           Q => 4.8,
           R => 5.8,
           S => 8.4,
           T => 5.4,
           V => 6.0,
           W => 1.3,
           X => 0.0,
           Y => 2.6,
           Z => 0.0 };
}

sub get_yeast_nums {
  return { 
A => 165299,
C => 39853,
D => 173775,
E => 194201,
F => 136339,
G => 149481,
H => 65862,
I => 198386,
K => 219584,
L => 289136,
M => 63475,
N => 184380,
P => 132446,
Q => 118145,
R => 134562,
S => 273404,
T => 178519,
V => 168440,
W => 31557,
Y => 102237
            };
}

sub get_yeast_perc {
  return { 
A => 5.5,
C => 1.3,
D => 5.8,
E => 6.4,
F => 4.5,
G => 5.0,
H => 2.2,
I => 6.6,
K => 7.3,
L => 9.6,
M => 2.1,
N => 6.1,
P => 4.4,
Q => 3.9,
R => 4.5,
S => 9.1,
T => 5.9,
V => 5.6,
W => 1.0,
Y => 3.4,
            };
}

sub get_ensp_perc {
  return { 
A => 7.0,
C => 2.2,
D => 4.8,
E => 7.1,
F => 3.6,
G => 6.6,
H => 2.6,
I => 4.3,
K => 5.8,
L => 9.9,
M => 2.2,
N => 3.6,
P => 6.3,
Q => 4.8,
R => 5.7,
S => 8.3,
T => 5.3,
U => 0.0,
V => 6.0,
W => 1.2,
X => 0.0,
Y => 2.6,
   };
}

sub get_ensp_nums {
  return { 
 A => 1646521,
C => 532092,
D => 1126503,
E => 1687634,
F => 852632,
G => 1564438,
H => 616165,
I => 1027001,
K => 1360678,
L => 2339218,
M => 510249,
N => 850023,
P => 1502366,
Q => 1136290,
R => 1348726,
S => 1967430,
T => 1260741,
U => 9,
V => 1413107,
W => 292958,
X => 1,
Y => 624602

    
            };
}

}process_args {
  my %args;
  GetOptions(\%args, 'mzfile=s', 'hitfile=s', 'tolerance=i', 'verbose', 'ox_met:i', 'identified' );
  for my $k ( qw( mzfile hitfile tolerance ) ) {
    unless ( $args{$k} ) {
      print <<"      END";
Missing argument $k:

usage: $0 -m mz input file -h hit file -t mass tolerance (ppm) [-v -o]

   -m, --mzfile      Name of file with mz data
   -h, --hitfile     Name of output file
   -t, --tolerance   Mass tolerance in parts per million
   -v, --verbose     More informative output
   -i, --identified  Query vs. identified peptides (default is predicted).
   -o, --ox_met      Allow specified number of oxidized mets ( 1 or 2 only )
      END
      exit;
    }
  }

  return \%args;
}

