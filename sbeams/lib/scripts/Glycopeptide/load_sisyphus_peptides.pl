#!/usr/local/bin/perl -w

###############################################################################
#
# Description : Script will parse the peptide data from Paul L into tables
#
###############################################################################
our $VERSION = '1.00';


###############################################################################
# Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use File::Basename;
use Data::Dumper;

use Getopt::Long;
use FindBin;
use Cwd;

use lib "$FindBin::Bin/../../perl";

# Unbuffer STDOUT
$|++;

use vars (qw($DBRPEFIX));

#### Set up SBEAMS core module
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
my $sbeams = new SBEAMS::Connection;

use SBEAMS::Glycopeptide;
use SBEAMS::Glycopeptide::Tables;
use SBEAMS::Glycopeptide::Glyco_peptide_load;
my $glycopep = new SBEAMS::Glycopeptide;
$glycopep->setSBEAMS( $sbeams );



my $program = $FindBin::Script;
my %args = process_options();


{ # Main
  
  # Authenticate() or exit
  my $username = $sbeams->Authenticate(work_group => 'Glycopeptide_admin') ||
  printUsage('Authentication failed');
#  $sbeams->output_mode('tsv');
 	load_peptides();

} # end main


# Process options
sub process_options {
  my %args;
  unless (GetOptions(\%args, "verbose:i", "file:s", "testonly", "sample:s",)) {
    printUsage('Failed to fetch options');
  }
  printUsage('Missing required parameter "file"') unless $args{file};
  printUsage('Missing required parameter "sample"') unless $args{sample};
  return %args;
}

sub load_peptides {

# check tissue type
check_tissue( $args{sample} );

# open file
my $fh = new IO::File;
$fh->open( "< $args{file}" ) || die ( "Unable to open file $args{file}" );

my $token_cnt;
my %heads;

# loop through
while ( my $row = <$fh> ) {
  chomp $row;
  my @row =  split( /\t/, $row, -1);
  unless ( $token_cnt ) {
    $token_cnt = scalar @row;
    # Make them lower case for consistancy
    @row = map {lc($_)} @row;

    # Build header index hash
	  @heads{@row} = 0..$#row;

    # check headers
    check_headers(\%heads);
    next;
  }

  # lookup IPI record using accession.  FIXME if multiple IPI versions
  my $ipi_data = $glycopep->ipi_data_from_accession(ipi => $row[$heads{ipi}]);
  
  unless ( $ipi_data->{ipi_data_id} ) {
    # Warn and skip for now
    print STDERR "IPI $row[$heads{ipi}] doesn't exist, skipping\n";
    next;
  }

  # Make sure we are uppercase
  $row[$heads{'protein sequence'}] = uc($row[$heads{'protein sequence'}]);
  $row[$heads{'peptide sequence'}] = uc($row[$heads{'peptide sequence'}]);
  
  # Does protein seq match db seq?
#  for my $h ( keys(%heads) ) { print STDERR "key $h => $heads{$h}, leads to $row[$heads{$h}]\n"; }
  if ( !sequences_match( fseq => $row[$heads{'protein sequence'}], 
                            dbseq => $ipi_data->{protein_sequence})  ) {
    print STDERR "Sequence mismatch for IPI: $row[$heads{'ipi'}]\n";
# next;
  }

  # Is peptide repeat
  my $mcnt = $glycopep->match_count( protseq => $row[$heads{'protein sequence'}],
                                      pepseq => $row[$heads{'peptide sequence'}] );
  if ( $mcnt > 1 ) {
    print STDERR "Peptide position ambiguous\n";
    next;
  } elsif ( $mcnt == 0 ) {
    print STDERR "Peptide doesn't match given protein\n";
    next;
  }
      
  # map peptide
  my ( $beg, $end ) = $glycopep->map_peptide_to_protein( protseq => $row[$heads{'protein sequence'}],
                                                           pepseq => $row[$heads{'peptide sequence'}] );
  
  my $posn = $glycopep->get_site_positions( seq => $row[$heads{'peptide sequence'}] );
  unless ( defined $posn && scalar( @$posn ) ) {
    print STDERR "Can't find glycosites in specified sequence\n";
    next; 
  }

  if ( scalar( @$posn ) > 1 ) {
    print STDERR "Multiple glyco sites in peptide\n";
    next; 
  }

  # get glycosite
  my $glycosite = $glycopep->lookup_glycosite( start => $posn->[0] + $beg + 1,
                                                 ipi => $row[$heads{ipi}] );

  if ( !$glycosite ) {
    print STDERR "Unable to map glycosite\n";
    next;
  }

  # is identified peptide already there?
  my $identified_id = $glycopep->lookup_identified( sequence => $row[$heads{'peptide sequence'}] );
  my $exists = 0;
  if ( $identified_id ) {
    print "Wow, it exists: $identified_id\n";
    my $exists = $glycopep->lookup_id_to_ipi( identified_id => $identified_id,
                                              glyco_site_id => $glycosite );
  }
  # cache initial values for these
  my $ac = $sbeams->isAutoCommit();
  my $re = $sbeams->isRaiseError();

  # Isolate transaction
  $sbeams->initiate_transaction();
  eval {
    # insert identified_peptide
    if ( !$identified_id ) {
      push @row, $args{sample};
      $heads{sample} = $#row;
      $identified_id = $glycopep->insert_identified( \@row, \%heads );
      die "Unable to insert identified peptide" unless $identified_id
    }
    # insert id2ipi
    $identified_id = $glycopep->insert_id_to_ipi( $row );
    
    # insert pep2tissue 
    $glycopep->insert_pep_to_tissue();

  };
    if ( $@ ) {
      print STDERR "$@\n";
      $sbeams->rollback_transaction();
      exit;
    }  # End eval catch-error block
  $sbeams->commit_transaction();
  $sbeams->setAutoCommit( $ac );
  $sbeams->setRaiseError( $re );

}
}

sub sequences_match {
  my %args = @_;
  my $fseq = $args{fseq};
  my $dbseq =  $args{dbseq};
  for my $seq( $dbseq, $fseq ) {
    $seq = uc($seq);
  }
  return 1 if $dbseq eq $fseq;
  print STDERR "dbseq is " . length( $dbseq ) . ", fseq is " .  length( $fseq ) . " amino acids\n";
  my @f = split "", $fseq;
  my @d = split "", $dbseq;
  for( my $i = 0; $i <= $#f; $i++ ) {
    next if $f[$i] eq $d[$i];
    print STDERR "$f[$i] ne $d[$i] at position $i\n";
  }
  return 0;
}

sub check_headers {
  my $heads = shift;
  my @known = ( 'experiment ID', # NA
                'description',  # Protein Name
                'ipi_link',     # IPI
                'peptide sequence', # Identified Sequences
                'ipi.h_m.xrefs::sequence', # protein sequence 
                'ipi.h_m.xrefs::sosui',  # NA
                'ipi.h_m.xrefs::tm',   # TM
                'ipi.h_m.xrefs::sec_mem_class', #  Protein Location   
                'ipi.h_m.xrefs::sigp',  # signalP   
                'entrez::summary',   # Summary
                'protein probability', # NA
                'initial probability' # Peptide ProPhet
               );
  for my $key ( @known ) {
    die "Bad data format: heading $key missing\n" unless defined $heads->{lc($key)};
  }
  # Map cols to those we know...
  $heads->{'protein_name'} = $heads->{'description'};
  $heads->{'ipi'} = $heads->{'ipi_link'};
  $heads->{'identified_sequences'} = $heads->{'peptide sequence'};
  $heads->{'tm'} = $heads->{'ipi.h_m.xrefs::tm'};
  $heads->{'protein_location'} = $heads->{'ipi.h_m.xrefs::sec_mem_class'};
  $heads->{'signalp'} = $heads->{'ipi.h_m.xrefs::sigp'};
  $heads->{'protein_sequence'} = $heads->{'ipi.h_m.xrefs::sequence'};
  $heads->{'summary'} = $heads->{'entrez::summary'};
  $heads->{'peptide_prophet'} = $heads->{'initial probability'};

}

# If tissue type exists, use it, else die.
sub check_tissue {
  my $sample = shift;
  my $cnt = $sbeams->selectrow_array( <<"  END" );
  SELECT COUNT(*) FROM $TBGP_GLYCO_SAMPLE
  WHERE sample_name = '$args{sample}'
  END
  printUsage( "Unknown sample type $args{sample}" ) unless $cnt;
}

# Prints optional message + usage notes and exits.
sub printUsage {
  my $msg = shift || '';
my $usage = <<EOU;
$msg

$program is used load ipi data. 

Usage: $program --file [OPTIONS]
Options:
    --verbose <num>    Set verbosity level.  Default is 0
    --file <file path> file path to the file to upload
    --testonly         Information in the database is not altered
    --release          Version of the IPI database
    --sample           Sample/Cell type from which data are derived.

 
$program -f <path to file> -v 2.28 -s Lymphocytes
EOU
  print "\n$usage\n";
  exit;
}




