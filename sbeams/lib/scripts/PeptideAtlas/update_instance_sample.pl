#!/usr/local/bin/perl 

###############################################################################
# Program     : load_theo_proteotypic_scores.pl
# Author      : Ning Zhang <nzhang@systemsbiology.org>
# 
#
# Description : This script load the database for theoretical proteotypic scores
#
###############################################################################


## Import 3rd party modules
use strict;
use Getopt::Long;
use File::Basename;
use FindBin;

#### Set up SBEAMS modules
use lib "$FindBin::Bin/../../perl";
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

# don't buffer output
$|++;


## Globals
my $sbeams = new SBEAMS::Connection;
my $atlas = new SBEAMS::PeptideAtlas;
$atlas->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);
my $prog_name = basename( $0 );

# hash of peptide_sequence to arrayref of sequences to which it maps
my %peptide_mappings;

my %options;

## Process options
GetOptions( \%options, "verbose:s",
                       "testonly",
		                   "set_tag:s",
											 "build_id:i",
											 "identlist_file:s",) || usage( "Error processing options" );

for my $arg ( qw( ) ) {
  usage( "Missing required parameter $arg" ) unless $options{$arg};
}

main( %options );
exit(0);


sub getSearchBatch2Sample {
  my $sql = qq~
  SELECT proteomics_search_batch_id, sample_id
    FROM $TBAT_ATLAS_SEARCH_BATCH
  ~;
  my $sth = $sbeams->get_statement_handle( $sql );

  my %mapping;
  while( my $row = $sth->fetchrow_arrayref() ) {
		if ( $mapping{$row->[0]} ) {
			print "Doppelganger for $row->[0]\n";
		}
    $mapping{$row->[0]} = $row->[1];
  }
  return \%mapping;
}


sub usage {
  my $msg = shift || '';
  print <<"  EOU";
  $msg

  Usage: $prog_name [options]
  Options:
    --verbose n            Set verbosity level.  default is 0
    --testonly             If set, rows in the database are not changed or added
    --help                 print this usage and exit.

  EOU

  exit;
}


###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
###############################################################################
sub main {
	my %args = @_;
  my $current_username = $sbeams->Authenticate( work_group=>'PeptideAtlas_admin' ) || exit;
  handle_request();
} # end main



###############################################################################
# handle_request
###############################################################################
sub handle_request {

  my %args = @_;
	my $sb2sample = getSearchBatch2Sample();
	my %instance_cnts = read_identlist_file( $sb2sample );

#	for my $sb ( sort { $a <=> $b } keys ( %$sb2sample ) ) { print "$sb => $sb2sample->{$sb}\n"; }



} # end handleRequest



# 0: search_batch_id
# 1: spectrum_query
# 2: peptide_accession
# 3: peptide_sequence
# 4: preceding_residue
# 5: modified_peptide_sequence
# 6: following_residue
# 7: charge
# 8: probability
# 9: massdiff
# 10: protein_name
# 11: adjusted_probability
# 12: n_adjusted_observations
# 13: n_sibling_peptides
# _________________________
sub read_identlist_file {

	my $sp2sample = shift;

	open IDLIST, $options{identlist_file} || die "Unable to open $options{identlist_file}\n";

	# hash of sample_id => peptide instance counts
	my %mappings;

	while ( my $line = <IDLIST> ) {
		chomp $line;
		my @line = split( "\t", $line, -1 );

		if ( !$

	}
}



__DATA__


##############################################################################
#getBioseqSetID  -- return a bioseq_set_id
##############################################################################
sub getBioseqSetID {
  my $SUB = 'getBioseqSetID';
  my %args = @_;

  print "INFO[$SUB] Getting bioseq_set_id....." if ($VERBOSE);
  my $bioseq_set_tag = $args{set_tag} or
    die("ERROR[$SUB]: parameter set_tag not provided");
  
  my $sql = qq~
    SELECT biosequence_set_id
      FROM $TBAT_BIOSEQUENCE_SET
     WHERE set_tag = '$bioseq_set_tag'
  ~;

  
  my ($bioseq_set_id) = $sbeams->selectOneColumn($sql);

  print "bioseq_set_id: $bioseq_set_id\n" if ($VERBOSE);
  return $bioseq_set_id;
}

###############################################################################
# getAtlasBuildID -- Return an atlas_build_id
###############################################################################
sub getAtlasBuildID {
  my $SUB = 'getAtlasBuildID';
  my %args = @_;

  print "INFO[$SUB] Getting atlas_build_id..." if ($VERBOSE);

  my $bioseq_set_id  = $args{bioseq_set_id} or
    die("ERROR[$SUB]: parameter bioseq_set_id not provided");

  my $sql = qq~
    SELECT atlas_build_id,atlas_build_name
      FROM $TBAT_ATLAS_BUILD
     WHERE record_status != 'D'
           AND biosequence_set_id = '$bioseq_set_id'
     ORDER BY atlas_build_name
  ~;

  my ($atlas_build_id) = $sbeams->selectOneColumn($sql);

  print "$atlas_build_id\n" if ($VERBOSE);
  return $atlas_build_id;

} # end getAtlasBuildID



###############################################################################
# fillTable, fill $TBAT_proteotypic_peptide
###############################################################################
sub fillTable{
  my $SUB = 'fillTable';
  my %args = @_;

  my $bioseq_set_id = $args{bioseq_set_id};
  
  my $source_file = $args{source_file} ||  
                       usage("ERROR[$SUB]: parameter source_file not provided");

  unless ( -e $source_file ) {
    usage("ERROR[$SUB]: Cannot find file '$source_file'");
  }

  print "get bioseq info\n";
  # Get biosequence set info
  my ($acc_to_id, $seq_to_id ) = getBioSeqData( $bioseq_set_id );
  # This is global, do this once so mapping can run in a sub
  @biosequences = keys( %$seq_to_id );

  print "get peptide info\n";
  # then get pepseq and pepid
  my $pepseq_to_id = getPeptideData();

  print "get proteotypic peptides\n";
  # Fetch existing paa . seq . faa items, to avoid inserting doubles
  my $proteopepseq_to_id = getProteotypicPeptideData();

  print "get proteotypic peptide mappings\n";
  my $proteopep_mapping = getProteotypicPeptideMapData();

  # Cache peptide ssrcalc, mw, nmappings
  my %ssrcalc;
  my %mw;
  my %pI;
  my %nmap;
  my %nexmap;

  #Then loop over the $source_file
  open(INFILE,$source_file) or
    die("ERROR[$SUB]: Cannot open file '$source_file'");

  my $proName;
  my $prevAA;
  my $pepSeq;
  my $endAA;
  my $paragScoreESI;
  my $paragScoreICAT;
  my $indianaScore;

  my $cnt = 0;
  while ( my $line = <INFILE> ) {
    $cnt++;

    chomp($line);
    my @columns = split("\t",$line, -1);
    $proName = $columns[0];
    $prevAA = $columns[1];
    $pepSeq = $columns[2];
    $endAA = $columns[3];
    $paragScoreESI = $columns[4];
    $paragScoreICAT = $columns[5];
    $indianaScore = $columns[6];

    # Decoys are duds!
    next if $proName =~ /^DECOY_/;
    
    # Does biosequence match a biosequence_id?
    unless( $acc_to_id->{$proName} ) {
      print STDERR "$proName failed to match a bioseq_id\n";
      exit;
    }

#    print "$proName matched_bioseq_id $acc_to_id->{$proName}\n";

    # Is this a new one?
    if ( ! $proteopepseq_to_id->{$prevAA . $pepSeq . $endAA} ) {

      # now need to get $matched_pep_id
      my $matched_pep_id;
    
      $matched_pep_id = $pepseq_to_id->{$pepSeq};

      # calc relative hydrophobicity if necessary
      if ( !defined $ssrcalc{$pepSeq} ) {
         
         $ssrcalc{$pepSeq} = getRelativeHydrophobicity( $pepSeq );

      }

      if ( !$mw{$pepSeq} ) {
        eval {
        $mw{$pepSeq} = $massCalculator->getPeptideMass( sequence => $pepSeq,
                                                         mass_type => 'monoisotopic' ) || '';
        };
        if ( $@ ) {
          print STDERR "Mass Calculator failed: $pepSeq\n";
          next;
        }
      }

      if ( !$pI{$pepSeq} ) {
        $pI{$pepSeq} = getPeptidePI( $pepSeq ) || '';
      }

      # Insert row in proteotypic_peptide
      my %rowdata=( matched_peptide_id => $matched_pep_id,
                     preceding_residue => $prevAA,
                      peptide_sequence => $pepSeq,
                     following_residue => $endAA,
                      peptidesieve_ESI => $paragScoreESI,
                     peptidesieve_ICAT => $paragScoreICAT,
          detectabilitypredictor_score => $indianaScore,
       ssrcalc_relative_hydrophobicity => $ssrcalc{$pepSeq},
       molecular_weight                => $mw{$pepSeq}, 
       peptide_isoelectric_point       => $pI{$pepSeq} 
                   );
    
       my $protpep_id = $sbeams->updateOrInsertRow( insert => 1,
                                               table_name  => $TBAT_PROTEOTYPIC_PEPTIDE,
                                               rowdata_ref => \%rowdata,
                                               verbose     => $VERBOSE,
                                              return_PK    => 1,
                                               testonly    => $TESTONLY );

       if ( !$protpep_id ) {
         print STDERR "Unable to insert proteotypic peptide!\n";
         exit;
       }
       $proteopepseq_to_id->{$prevAA.$pepSeq.$endAA} = $protpep_id;

    } # End if new pp entry

    # By here we should have a biosequence_id and a proteotypic peptide_id
    # Is it already in the datbase?
    if ( $proteopep_mapping->{$proteopepseq_to_id->{$prevAA . $pepSeq . $endAA} . $acc_to_id->{$proName}} ) {
#      print "Skipping, this thing is already in the database!";
    } else {
      # Insert row in proteotypic_peptide_mapping
#      proteotypic_peptide_mapping_id     proteotypic_peptide_id     source_biosequence_id     n_genome_locations     n_protein_mappings     n_exact_protein_mappings    
      
      # This conditional stops us from mapping the same exact sequence 2x, but 
      # 1) doesn't cache the results from the initial peptide mapping in the event of different flanking aa's, and
      # 2) doesn't get the info, if available, from the database.
      if ( !$nmap{$pepSeq} || !$nexmap{$prevAA.$pepSeq.$endAA} ) {
        ($nmap{$pepSeq}, $nexmap{$prevAA.$pepSeq.$endAA} ) = mapSeqs( seq => $pepSeq,
                                                                      paa => $prevAA,
                                                                      faa => $endAA );
      }

        
      my %rowdata=( 
                 source_biosequence_id => $acc_to_id->{$proName},
                proteotypic_peptide_id => $proteopepseq_to_id->{$prevAA.$pepSeq.$endAA},
                    n_genome_locations => 99,
                    n_protein_mappings => $nmap{$pepSeq},
              n_exact_protein_mappings => $nexmap{$prevAA.$pepSeq.$endAA} );
    
       my $map = $sbeams->updateOrInsertRow( insert => 1,
                                        table_name  => $TBAT_PROTEOTYPIC_PEPTIDE_MAPPING,
                                        rowdata_ref => \%rowdata,
                                        verbose     => $VERBOSE,
                                       return_PK    => 1,
                                        testonly    => $TESTONLY );

    } 
    print '*' unless( $cnt % 100 );
    print "\n" unless( $cnt % 5000 );
     
    
  } # End file reading loop
  close(INFILE);

} # end fillTable

sub getRelativeHydrophobicity {
  my $seq = shift || return '';
  my $rh = '';
  if ( $SSRCalculator->checkSequence($seq) ) {
    $rh = $SSRCalculator->TSUM3($seq);
  }
  return $rh;
}

sub getPeptidePI {
  my $seq = shift || return '';
  my $pI = $atlas->calculatePeptidePI( sequence => $seq );
  return $pI;
}

sub mapSeqs {
  my %args = @_;
  my $seq = $args{seq} || return( '', '' );
  my $paa = $args{paa} || return( '', '' );
  my $faa = $args{faa} || return( '', '' );

  my @exmatches;
  my @matches;
#  print "Checking mapping with seq = $seq, p = $paa, f = $faa\n";

  if ( $peptide_mappings{$args{seq}} ) {
#    print "we've seen $args{seq}, using cached values\n";
    @matches = @{$peptide_mappings{$args{seq}}};
  } else {
    @matches = grep( /$seq/, @biosequences );
  }
#  print "We have " . scalar( @matches ) . " matches\n";

#  for my $seq ( @matches ) {
  my $expep = '';
  if ( $paa eq '-' ) {
    $expep = $seq . $faa;
#    print "Trying to match $expep at the beginning, because $paa must eq '-'!\n";
    @exmatches = grep( /^$expep/, @matches );
  } elsif ( $faa eq '-' ) {
    $expep = $paa . $seq;
#    print "Trying to match $expep at the end\n";
    @exmatches = grep( /$expep$/, @matches );
  } else {
    $expep = $paa . $seq . $faa;
#    print "Trying to match $expep in the middle\n";
    @exmatches = grep( /$expep/, @matches );
  }
#  print join( "::", @matches ) . "\n";
#  print "We have " . scalar( @exmatches ) . " matches with $paa$seq$faa\n\n";

#  }
  return ( scalar( @matches ), scalar( @exmatches ) );
}


sub getProteotypicPeptideMapData {
  my $sql = qq~
  SELECT proteotypic_peptide_id, source_biosequence_id 
    FROM $TBAT_PROTEOTYPIC_PEPTIDE_MAPPING
  ~;
  my $sth = $sbeams->get_statement_handle( $sql );

  my %mapping;
  while( my $row = $sth->fetchrow_arrayref() ) {
    $mapping{$row->[0] . $row->[1]}++;
  }
  return \%mapping;
}

sub getProteotypicPeptideData {
  my $sql = qq~
  SELECT preceding_residue || peptide_sequence || following_residue, 
         proteotypic_peptide_id
    FROM $TBAT_PROTEOTYPIC_PEPTIDE
  ~;
  my $sth = $sbeams->get_statement_handle( $sql );

  my %seq_to_id;
  while( my $row = $sth->fetchrow_arrayref() ) {
    $seq_to_id{$row->[0]} = $row->[1];
  }
  return \%seq_to_id;
}

sub getBioSeqData {
  my $bioseq_set_id = shift || usage( "missing required param bioseq_set_id" );

  my $sql = qq~
     SELECT biosequence_name, biosequence_id, biosequence_seq
       FROM $TBAT_BIOSEQUENCE
      WHERE biosequence_set_id = '$bioseq_set_id'
      AND biosequence_name NOT LIKE 'DECOY_%'
  ~;

  my $sth = $sbeams->get_statement_handle( $sql );
  my %seq_to_id;
  my %acc_to_id;
  while( my $row = $sth->fetchrow_arrayref() ) {
    $acc_to_id{$row->[0]} = $row->[1];
    $seq_to_id{$row->[2]} ||= [];
    push @{$seq_to_id{$row->[2]}}, $row->[1];
  }
  return ( \%acc_to_id, \%seq_to_id );
}

sub getPeptideData {
  my $sql = qq~
  SELECT peptide_sequence, peptide_id
    FROM $TBAT_PEPTIDE
  ~;
  my $sth = $sbeams->get_statement_handle( $sql );
  my %seq_to_id;
  while( my $row = $sth->fetchrow_arrayref() ) {
    $seq_to_id{$row->[0]} = $row->[1];
  }
  return \%seq_to_id;
}

sub usage {
  my $msg = shift || '';
  print <<"  EOU";
  $msg


  Usage: $prog_name [options]
  Options:
    --verbose n            Set verbosity level.  default is 0
    --quiet                Set flag to print nothing at all except errors
    --debug n              Set debug flag
    --testonly             If set, rows in the database are not changed or added
    --list                 If set, list the available builds and exit
    --help                 print this usage and exit.
    --delete_set           If set, will delete the records of of specific biosequence set in the table
    --set_tag              Name of the biosequence set tag  
    --update_peptide_info  will update existing information on pI, MW, SSRCalc, protein/genome mappings 
    --input_file           Name of the file that has Parag and Indiana scores

   e.g.: $prog_name --list
         $prog_name --set_tag \'YeastCombNR_20070207_ForwDecoy\' --input_file \'proteotypic_peptide.txt\'
       $prog_name --delete_set \'YeastCombNR_20070207_ForwDecoy\'
  EOU

  exit;
}

