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
use lib '/net/db/src/SSRCalc/ssrcalc';
use SSRCalculator;

#### Set up SBEAMS modules
use lib "$FindBin::Bin/../../perl";
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

use SBEAMS::Proteomics::PeptideMassCalculator;

use vars qw ($sbeams $atlas $q $current_username $PROG_NAME $USAGE %opts
             $QUIET $VERBOSE $DEBUG $TESTONLY $TESTVARS $CHECKTABLES );

# don't buffer output
$|++;

## Set up environment
$ENV{SSRCalc} = '/net/db/src/SSRCalc/ssrcalc';

## Globals
$sbeams = new SBEAMS::Connection;
$atlas = new SBEAMS::PeptideAtlas;
$atlas->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);
$PROG_NAME = basename( $0 );

my $massCalculator = new SBEAMS::Proteomics::PeptideMassCalculator;

my $SSRCalculator = new SSRCalculator;
$SSRCalculator->initializeGlobals3();
$SSRCalculator->ReadParmFile3();

# array of biosequence sequences
my @biosequences;

# hash of peptide_sequence to arrayref of sequences to which it maps
my %peptide_mappings;

# If update is chosen, we will updated info about a given peptide once, but
# only once.
my %updated_peptides;

## Process options
GetOptions( \%opts,"verbose:s","quiet","debug:s","testonly",
		           "list","purge_mappings","input_file:s", 'set_tag:s',
               'help', 'update_peptide_info' ) || usage( "Error processing options" );

# build list requested 
if ($opts{list}) {
  $atlas->listBiosequenceSets();
  exit;
} elsif ( $opts{help} ) {
  usage();
}

for my $arg ( qw( set_tag ) ) {
  usage( "Missing required parameter $arg" ) unless $opts{$arg};
}

$VERBOSE = $opts{"verbose"} || 0;
$QUIET = $opts{"quiet"} || 0;
$DEBUG = $opts{"debug"} || 0;
$TESTONLY = $opts{"testonly"} || 0;

if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
}



###############################################################################
# Set Global Variables and execute main()
###############################################################################
main();
exit(0);


###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
###############################################################################
sub main {

  #### Do the SBEAMS authentication and exit if a username is not returned
  $current_username = $sbeams->Authenticate( work_group=>'PeptideAtlas_admin' ) || exit;

  $sbeams->printPageHeader() unless ($QUIET);
  handleRequest();
  $sbeams->printPageFooter() unless ($QUIET);

} # end main



###############################################################################
# handleRequest
###############################################################################
sub handleRequest {

  my %args = @_;

  ##### PROCESS COMMAND LINE opts AND RESTRICTIONS #####
  #### Set the command-line options
  my $bioseq_set_tag = $opts{"set_tag"};
  my $delete_set_tag = $opts{"delete_set"};
  my $input_file = $opts{"input_file"};

  my $set_id = getBioseqSetID( %opts );

  #### If specified, read the file in to fill the table
  if ( $input_file ) {
    print "Fill table\n";
    fillTable( bioseq_set_id => $set_id,
	               source_file => $input_file );
  } elsif ( $opts{purge_mappings} ) {
    print "purge mappings\n";
    purgeMappings( $set_id )
  }



  return;

} # end handleRequest

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
  my $ssrcalc = getSSRValues();
  my $mw = getMWValues();
  my $pI = getpIValues();

  my %cached;
  my %uncached;

  my %nmap;
  my %nexmap;

  #Then loop over the $source_file
  open(INFILE,$source_file) or
    die("ERROR[$SUB]: Cannot open file '$source_file'");

  my $cnt = 0;
  my %match_cnt;
  my $t0 = time();
  my %fill_stats;
  while ( my $line = <INFILE> ) {
    
    # Skip header line
    next unless $cnt++;

    chomp($line);
    my @columns = split("\t",$line, -1);

    
# proteotypic_peptide_id
# matched_peptide_id
# preceding_residue
# peptide_sequence
# following_residue
# peptidesieve_ICAT
# detectabilitypredictor_score
# peptide_isoelectric_point
# molecular_weight
# SSRCalc_relative_hydrophobicity
# peptidesieve_score
# espp_score
# apex_score
# combined_predictor_score

# 0 Protein
# 1 Pre
# 2 Peptide
# 3 Fol
# 4 apex
# 5 espp
# 6 detectability_predictor
# 7 peptide_sieve
# 8 Combined_Score
# 9 n_prot_map
# 10 n_exact_map
# 11 n_gen_loc

    # Hard-coded n_columns check
    if ( scalar( @columns ) != 12 ) {
      $fill_stats{bad_line}++;
      next;
    }

    my $proName = $columns[0];
    my $prevAA = $columns[1];
    my $pepSeq = $columns[2];
    my $endAA = $columns[3];

    my $apex = $columns[4];
    my $espp = $columns[5];
    my $detect = $columns[6];
    my $pepsieve = $columns[7];
    my $combined = $columns[8];


    # These are three new cols added by calcNGenomeLocation script
    my $n_prot_mappings = $columns[9] || 0;
    my $n_exact_prot_mappings = $columns[10] || 0;
    my $n_genome_locations = $columns[11] || 0;

    # Decoys are duds!
    
    if ( $proName =~ /^DECOY_/ ) {
      $fill_stats{decoy}++;
      next; 
    }
    
    # Does biosequence match a biosequence_id?
    unless( $acc_to_id->{$proName} ) {
      print STDERR "$proName failed to match a bioseq_id\n";
      if ( $proName =~ /sp\|([^|]*)\|.*$/ ) {
        $proName = $1;
      }
      unless( $acc_to_id->{$proName} ) {
        print STDERR "WARN: $proName failed to match a bioseq_id, skipping\n";
        $fill_stats{prot_match}++;
        next;
      }
    }
#    print "$proName matched_bioseq_id $acc_to_id->{$proName}\n";
  
    # Is this a new one OR are we in update mode?
    my $full_seq_key = $prevAA . $pepSeq . $endAA;

    if ( !$proteopepseq_to_id->{$full_seq_key} || $opts{update_peptide_info} ) {

      # We've already updated this peptide during this run.
      if ( $updated_peptides{$full_seq_key} ) {
        $fill_stats{already_updated}++;
      } else {

        # We shall not easily pass this way again
        $updated_peptides{$full_seq_key}++;
  
        # now need to get $matched_pep_id
        my $matched_pep_id;
      
        $matched_pep_id = $pepseq_to_id->{$pepSeq};
  
        # calc relative hydrophobicity if necessary
        if ( !defined $ssrcalc->{$pepSeq} || $opts{update_peptide_info} ) {
           $ssrcalc->{$pepSeq} = getRelativeHydrophobicity( $pepSeq );
        }
  
        if ( !$mw->{$pepSeq} || $opts{update_peptide_info} ) {
          eval {
            $mw->{$pepSeq} = $massCalculator->getPeptideMass( sequence => $pepSeq,
                                                             mass_type => 'monoisotopic' ) || '';
          };
          if ( $@ ) {
            $mw->{$pepSeq} ||= ''; 
            print STDERR "WARN: Mass Calculator failed: $pepSeq\n";
          }
        }
  
        if ( !$pI->{$pepSeq} || $opts{update_peptide_info} ) {
          $pI->{$pepSeq} = getPeptidePI( $pepSeq ) || '';
        }
  
  
  # PTP
  # proteotypic_peptide_id
  # matched_peptide_id
  # preceding_residue
  # peptide_sequence
  # following_residue
  # peptidesieve_ESI
  # peptidesieve_ICAT
  # detectabilitypredictor_score
  # peptide_isoelectric_point
  # molecular_weight
  # SSRCalc_relative_hydrophobicity    
   
  # PTP_MAPPING
  # proteotypic_peptide_mapping_id
  # proteotypic_peptide_id
  # source_biosequence_id
  # n_genome_locations
  # n_protein_mappings
  # n_exact_protein_mappings    
  
  
        # Insert row in proteotypic_peptide
        my %rowdata=( matched_peptide_id => $matched_pep_id,
                       preceding_residue => $prevAA,
                        peptide_sequence => $pepSeq,
                       following_residue => $endAA,
                      peptidesieve_score => $pepsieve,
                              apex_score => $apex,
                              espp_score => $espp,
            detectabilitypredictor_score => $detect,
                combined_predictor_score => $combined,
         ssrcalc_relative_hydrophobicity => $ssrcalc->{$pepSeq},
                        molecular_weight => $mw->{$pepSeq},
               peptide_isoelectric_point => $pI->{$pepSeq},
                     );
  
  
        # We will either update or insert
        if ( $proteopepseq_to_id->{$full_seq_key} ) {
  
          $fill_stats{update_peptide}++;
          $sbeams->updateOrInsertRow( update => 1,
                                 table_name  => $TBAT_PROTEOTYPIC_PEPTIDE,
                                 rowdata_ref => \%rowdata,
                                     verbose => $VERBOSE,
                                          PK => 'proteotypic_peptide_id',
                                    PK_value => $proteopepseq_to_id->{$full_seq_key},
                                 testonly    => $TESTONLY );
  
        } else {
          $fill_stats{insert_peptide}++;
          $proteopepseq_to_id->{$full_seq_key} = $sbeams->updateOrInsertRow(
                                              insert => 1,
                                         table_name  => $TBAT_PROTEOTYPIC_PEPTIDE,
                                         rowdata_ref => \%rowdata,
                                         verbose     => $VERBOSE,
                                        return_PK    => 1,
                                                  PK => 'proteotypic_peptide_id',
                                         testonly    => $TESTONLY );

          die "ERROR: Unable to insert proteotypic peptide!" if !$proteopepseq_to_id->{$full_seq_key};
        } # End update or insert block

      } # End "was this update done this run" block

    } # End if new pp entry OR update_mode block

    # By here we should have a biosequence_id and a proteotypic peptide_id
    # Is it already in the datbase?  FIXME - should this be revisited for 
    # for update mode? - for now will recommend purge followed by update mode
    if ( $proteopep_mapping->{$proteopepseq_to_id->{$full_seq_key} . $acc_to_id->{$proName}} ) {
      #print "Skipping, this thing is already in the database!\n";
    } else {
      # Insert row in proteotypic_peptide_mapping
#      proteotypic_peptide_mapping_id     proteotypic_peptide_id     source_biosequence_id     n_genome_locations     n_protein_mappings     n_exact_protein_mappings    

      # This conditional stops us from mapping the same exact sequence 2x, but 
      # 1) doesn't cache the results from the initial peptide mapping in the event of different flanking aa's, and
      # 2) doesn't get the info, if available, from the database.
#      if ( !$nmap{$pepSeq} || !$nexmap{$prevAA.$pepSeq.$endAA} ) {


# This is now done ahead of time, keeps us from doing it during load
#        ($nmap{$pepSeq}, $nexmap{$prevAA.$pepSeq.$endAA} ) = mapSeqs( seq => $pepSeq,
#                                                                      paa => $prevAA,
#                                                                      faa => $endAA );
#      }
#      print "new mapping says $nmap{$pepSeq}, original was $n_prot_mappings!\n";
#      if ( $nmap{$pepSeq} == $n_prot_mappings ) {
#        $match_cnt{ok}++;
#      } else {
#        $match_cnt{ok}++;
#      }


      $fill_stats{insert_mapping}++;
      my %rowdata=( 
                 source_biosequence_id => $acc_to_id->{$proName},
                proteotypic_peptide_id => $proteopepseq_to_id->{$prevAA.$pepSeq.$endAA},
                 source_biosequence_id => $acc_to_id->{$proName},
                    n_protein_mappings => $n_prot_mappings,
                    n_genome_locations => $n_genome_locations,
              n_exact_protein_mappings => $n_exact_prot_mappings );

       my $map = $sbeams->updateOrInsertRow( insert => 1,
                                        table_name  => $TBAT_PROTEOTYPIC_PEPTIDE_MAPPING,
                                        rowdata_ref => \%rowdata,
                                        verbose     => $VERBOSE,
                                       return_PK    => 1,
                                        testonly    => $TESTONLY );

    } 
    print '*' unless( $cnt % 100 );
    unless( $cnt % 5000 ) {
      my $t1 = time();
      my $td = $t1 - $t0;
      print " - $td sec";
#      print " -  loaded $cnt records in $td seconds, ". sprintf( "%0.1f", $cnt/$td )  . " records per second ";
      print "\n"; 
    }
     
    
  } # End file reading loop
  close(INFILE);
  $fill_stats{total_records} = $cnt;
  for my $k ( sort( keys( %fill_stats ) ) ) {
    print "$k => $fill_stats{$k}\n";
  }

} # end fillTable

sub getSSRValues {
  print "get SSR Calc values\n";
  my $sql = qq~
  SELECT DISTINCT peptide_sequence, SSRCalc_relative_hydrophobicity 
  FROM $TBAT_PROTEOTYPIC_PEPTIDE
  ~;
  my $sth = $sbeams->get_statement_handle( $sql );
  my %ssr;
  while( my @row = $sth->fetchrow_array() ) {
    $ssr{$row[0]} = $row[1];
  }
  return \%ssr;
}

sub getpIValues {
  print "get pI values\n";
  my $sql = qq~
  SELECT DISTINCT peptide_sequence, peptide_isoelectric_point 
  FROM $TBAT_PROTEOTYPIC_PEPTIDE
  ~;
  my $sth = $sbeams->get_statement_handle( $sql );
  my %pi;
  while( my @row = $sth->fetchrow_array() ) {
    $pi{$row[0]} = $row[1];
  }
  return \%pi;
}

sub getMWValues {
  print "get MW values\n";
  my $sql = qq~
  SELECT DISTINCT peptide_sequence, molecular_weight 
  FROM $TBAT_PROTEOTYPIC_PEPTIDE
  ~;
  my $sth = $sbeams->get_statement_handle( $sql );
  my %mw;
  while( my @row = $sth->fetchrow_array() ) {
    $mw{$row[0]} = $row[1];
  }
  return \%mw;
}

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

sub purgeMappings {
  my $bioseq_set_id = shift;
  if ( $opts{purge_mappings} && $bioseq_set_id ) {
    print "purging mappings for biosequence set $opts{set_tag}, press cntl-c to abort\n";
    sleep 1;
  } else {
    die "Must provide bioseq_set";
  }
  my $proteopep_mapping = getProteotypicPeptideMapData( $bioseq_set_id );
  print "Found " . scalar( keys( %{$proteopep_mapping} ) ) . " mappings\n";

  my @ids;
  my $cnt = 1;
  for my $id ( keys( %{$proteopep_mapping} ) ) {
    push @ids, $id;
    if ( scalar( @ids == 100 ) ) {
      my $id_list = join( ',', @ids );
      my $sql = qq~
      DELETE FROM $TBAT_PROTEOTYPIC_PEPTIDE_MAPPING
      WHERE proteotypic_peptide_id IN ( $id_list )
      ~;
      $sbeams->do( $sql );
      @ids = ();
      print '*';
      print "\n" unless $cnt++ % 50;
    }
  }
  print "\n";
  my $id_list = join( ',', @ids );
  my $sql = qq~
  DELETE FROM $TBAT_PROTEOTYPIC_PEPTIDE_MAPPING
  WHERE proteotypic_peptide_id IN ( $id_list )
  ~;
  $sbeams->do( $sql ) if $id_list;
}


sub getProteotypicPeptideMapData {
  my $bioseq_set_id = shift;

  my $sql = qq~
  SELECT DISTINCT proteotypic_peptide_id, source_biosequence_id 
    FROM $TBAT_PROTEOTYPIC_PEPTIDE_MAPPING
  ~;
  if ( $bioseq_set_id ) {
    chomp $sql;
    $sql = qq~
    $sql PPM
    JOIN $TBAT_BIOSEQUENCE B 
    ON B.biosequence_id = PPM.source_biosequence_id
    WHERE biosequence_set_id = $bioseq_set_id
    ORDER BY proteotypic_peptide_id ASC
    ~;
  }

  my $sth = $sbeams->get_statement_handle( $sql );

  my %mapping;
  while( my $row = $sth->fetchrow_arrayref() ) {
    if ( $bioseq_set_id ) { 
      $mapping{$row->[0]}++;
    } else {
      $mapping{$row->[0] . $row->[1]}++;
    }
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


  Usage: $PROG_NAME [opts]
  Options:
    --verbose n            Set verbosity level.  default is 0
    --quiet                Set flag to print nothing at all except errors
    --debug n              Set debug flag
    --testonly             If set, rows in the database are not changed or added
    --list                 If set, list the available builds and exit
    --help                 print this usage and exit.
    --purge_mappings       Delete peptide mappings pertaining to this set
    --set_tag              Name of the biosequence set tag  
    --update_peptide_info  will update info in proteotypic_peptide table, e.g.
                           pI, mw, SSRCalc, Peptide Sieve.  Does *not* currently
                           update info in proteotypic_peptide_mapping table, so
                           one should run purge_mappings first and then update.
    --input_file           Name of file with PepSeive and Indiana scores, as 
                           well as n_mapping info.
                           

   e.g.: $PROG_NAME --list
         $PROG_NAME --set_tag \'YeastCombNR_20070207_ForwDecoy\' --input_file \'proteotypic_peptide.txt\'
       $PROG_NAME --delete_set \'YeastCombNR_20070207_ForwDecoy\'
  EOU

  exit;
}

__DATA__
Protein	Pre	Peptide	Fol	apex	espp	detectability_predictor	peptide_sieve	Combined_Score	n_prot_map	n_exact_map	n_gen_loc
A0A183	K	EEECEGD	-	0	0.14118	0.692383	0.00242656	0.0556295938627146585	1	1	0
