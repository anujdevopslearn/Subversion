#!/usr/local/bin/perl -w

###############################################################################
# Program     : 
# Author      : 
# $Id: 
#
# Description : 
#               
#
###############################################################################


###############################################################################
   # Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams $sbeamsMOD $q $current_username 
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG
            );


#### Set up SBEAMS core module
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:
  --verbose n            Set verbosity level.  default is 0
  --quiet                Set flag to print nothing at all except errors
  --debug n              Set debug flag

  --AtlasBuildID         atlas_build_id

 e.g.:  ./count_maps_to_hypothetical_proteins.pl --AtlasBuildID 57

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s",
        "AtlasBuildID:s" )) {

    die "\n$USAGE";

}



unless ( $OPTIONS{"AtlasBuildID"} ) {

    die "\nneed AtlasBuildID\n$USAGE";

}
   

my $atlas_build_id = $OPTIONS{"AtlasBuildID"};


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
  exit unless (
      $current_username = $sbeams->Authenticate(
          work_group=>'PeptideAtlas_admin')
  );


# $sbeams->printPageHeader() unless ($QUIET);

  handleRequest();

# $sbeams->printPageFooter() unless ($QUIET);


} # end main



###############################################################################
# handleRequest
###############################################################################
sub handleRequest {

    ## get biosequence_set_id from atlas_build
    my $sql;
    $sql = qq~
        SELECT biosequence_set_id
        FROM $TBAT_ATLAS_BUILD
        WHERE atlas_build_id = '$atlas_build_id'
        AND record_status != 'D'
    ~;

    my ($biosequence_set_id) = $sbeams->selectOneColumn($sql)
       or die "could not get biosequence_set_id from atlas_build".
       "for atlas_build_id = $atlas_build_id";


    ## get set_name from biosequence_set
    $sql = qq~
        SELECT set_name
        FROM $TBAT_BIOSEQUENCE_SET
        WHERE biosequence_set_id = '$biosequence_set_id'
    ~;

    my ($biosequence_set_name) = $sbeams->selectOneColumn($sql)
       or die "could not get biosequence_set_name from biosequence".
       "for biosequence_set_id = $biosequence_set_id";



    ## get hash, key=B.biosequence_name value = B.biosequence_desc for given B.biosequence_set_id
    $sql = qq~
        SELECT biosequence_name, biosequence_desc
        FROM $TBAT_BIOSEQUENCE
        WHERE biosequence_set_id = '$biosequence_set_id'
    ~;

    my %biosequence_name_desc_hash = $sbeams->selectTwoColumnHash($sql)
        or die "\nunable to process sql:\n$sql";

     

    ## Want to know how many descriptions contain the word
    ##   hypothetical, dubious, or uncharacterized
    ##    =~ /hypothetical/i   =~ /dubious/i   =~ /Uncharacterized/i
    ##
    ## Would be good to have context: How many biosequence_desc in total
    ## have hypothetical, dubious, or uncharacterized?  We mapped to xx out of xx.
    ## There are xx total biosequence_names, we mapped to xx out of xx.


    my $num_total_biosequence_names = keys ( %biosequence_name_desc_hash );
    my $num_hypothetical_biosequence_names = 0;
    my $num_dubious_biosequence_names = 0;
    my $num_uncharacterized_biosequence_names = 0;
    my $num_verified_biosequence_names = 0;
    my $num_pseudogene_tyorfs_biosequence_names = 0;

    foreach my $bioseq_nm ( keys %biosequence_name_desc_hash ) {

        my $bd = $biosequence_name_desc_hash{$bioseq_nm};

        if ( $bd  =~ /hypothetical/i ) {

            $num_hypothetical_biosequence_names++;

        } elsif ( $bd  =~ /dubious/i) {

            $num_dubious_biosequence_names++;

        } elsif ( $bd  =~ /Uncharacterized/i) {

            $num_uncharacterized_biosequence_names++;

        } elsif ( $bd  =~ /verified/i) {

            $num_verified_biosequence_names++;

        } elsif ( ($bd  =~ /pseudogene/i ) 
            || ($bd  =~ /pseudogene ty orf/i) || ($bd  =~ /ty orf/i) ) {

           $num_pseudogene_tyorfs_biosequence_names++;

        } else {

            print "$bd\n";

        }

    }

    my $n = keys (%biosequence_name_desc_hash);

    print "Total number of unique protein names in $biosequence_set_name = $n";

    ## check to make sure that $num_hypothetical_biosequence_names + $num_verified_biosequence_names =
    ## $num_total_biosequence_names
    my $check1 = $num_hypothetical_biosequence_names + $num_verified_biosequence_names 
        + $num_pseudogene_tyorfs_biosequence_names + $num_dubious_biosequence_names
        + $num_uncharacterized_biosequence_names;

    my $check2 = $num_total_biosequence_names;

    unless ( $check1 == $check2) {
        die "totals not equal\n\$num_hypothetical_biosequence_names = $num_hypothetical_biosequence_names\n".
        "\$num_verified_biosequence_names = $num_verified_biosequence_names\n".
        "\$num_pseudogene_tyorfs_biosequence_names = $num_pseudogene_tyorfs_biosequence_names\n".
        "\$num_dubious_biosequence_names = $num_dubious_biosequence_names\n".
        "\$num_uncharacterized_biosequence_names = $num_uncharacterized_biosequence_names\n".
        "( = $check1)\n".
        "\$num_total_biosequence_names = $num_total_biosequence_names";
    }
    

#   my (@peptide_accession, @biosequence_name, @biosequence_desc, @is_subpeptide_of);
    my %biosequence_name_hash; ## to store biosequence_names. key = biosequence_name
#   my %pep_accession_index_hash; ## key = peptide_accession, value = comma separated indices


    my $num_total_biosequence_names_mapped_to = 0;
    my $num_hypothetical_biosequence_names_mapped_to = 0;
    my $num_dubious_biosequence_names_mapped_to = 0;
    my $num_uncharacterized_biosequence_names_mapped_to = 0;
    my $num_verified_biosequence_names_mapped_to = 0;
    my $num_pseudogene_tyorfs_biosequence_names_mapped_to = 0;

    ## get peptide_accession, biosequence_name, biosequence_desc, is_subpeptide_of
    $sql = qq~
        SELECT P.peptide_accession, B.biosequence_name, B.biosequence_desc, PI.is_subpeptide_of
        FROM $TBAT_PEPTIDE_INSTANCE PI
        JOIN  $TBAT_PEPTIDE P
        ON (P.peptide_id = PI.peptide_id)
        JOIN  $TBAT_PEPTIDE_MAPPING PM
        ON (PI.peptide_instance_id = PM.peptide_instance_id)
        JOIN  $TBAT_BIOSEQUENCE B
        ON (PM.matched_biosequence_id = B.biosequence_id)
        WHERE PI.atlas_build_id = '$atlas_build_id'
        AND B.biosequence_set_id = '$biosequence_set_id'
    ~;

    my @rows = $sbeams->selectSeveralColumns($sql) or
        die "unable to process sql:\n$sql";

    my $i = 0;
    foreach my $row (@rows) {

        my ($pa, $bn, $bd, $iso) = @{$row};

#       $peptide_accession[$i] = $pa;
#       $biosequence_name[$i] = $bn;
#       $biosequence_desc[$i] = $bd;
#       $is_subpeptide_of[$i] = $iso;

        ## if haven't counted this biosequence_name yet
        unless ( exists $biosequence_name_hash{$bn} ) {
      
            $biosequence_name_hash{$bn} = $bn;

            $num_total_biosequence_names_mapped_to++;
           
            ## if biosequence_desc contains hypo...,dub..., or unchar...
            if ( $bd  =~ /hypothetical/i) {

                $num_hypothetical_biosequence_names_mapped_to++;

            }  elsif ($bd  =~ /dubious/i) {

                $num_dubious_biosequence_names_mapped_to++;

            }  elsif ( $bd  =~ /Uncharacterized/i) {

                $num_uncharacterized_biosequence_names_mapped_to++;

            } elsif ( $bd  =~ /verified/i) {

                $num_verified_biosequence_names_mapped_to++;

            } elsif ( ($bd  =~ /pseudogene/i ) 
            || ($bd  =~ /pseudogene ty orf/i) || ($bd  =~ /ty orf/i) ) {

                $num_pseudogene_tyorfs_biosequence_names_mapped_to++;

            }

        }

##      here, can later count peptide mappings, and use is_sub_peptide_of to ignore sub-peptides if want...
#       if ( exists $pep_accession_index_hash{$peptide_accession[$i]} ) {
# 
#           $pep_accession_index_hash{$peptide_accession[$i]} =
#           join ",", $pep_accession_index_hash{$peptide_accession[$i]}, $i;
# 
#       } else {
# 
#          $pep_accession_index_hash{$peptide_accession[$i]} = $i;
# 
#       }

        $i++;
    }

    my $fraction1 = sprintf "%.2f", $num_total_biosequence_names_mapped_to 
        / $num_total_biosequence_names ;
    
    my $fraction2;

    if ( $num_hypothetical_biosequence_names == 0 ) {

        $fraction2 = 0;

    } else {

        $fraction2 = sprintf "%.2f", $num_hypothetical_biosequence_names_mapped_to 
        / $num_hypothetical_biosequence_names || 0;

    }

    my $fraction3 = sprintf "%.2f", $num_dubious_biosequence_names_mapped_to 
        / $num_dubious_biosequence_names || 0;
    my $fraction4 = sprintf "%.2f", $num_uncharacterized_biosequence_names_mapped_to 
        / $num_uncharacterized_biosequence_names;
    my $fraction5 = sprintf "%.2f", $num_verified_biosequence_names_mapped_to 
        / $num_verified_biosequence_names;
    my $fraction6 = sprintf "%.2f", $num_pseudogene_tyorfs_biosequence_names_mapped_to 
        / $num_pseudogene_tyorfs_biosequence_names;


    print "\n----------------------------------------\n";
    print "Mapping to $biosequence_set_name\n";
    print "----------------------------------------\n";

    print "\nMapped to $num_total_biosequence_names_mapped_to".
    " proteins out of $num_total_biosequence_names proteins (=$fraction1)";

    print "\nMapped to $num_hypothetical_biosequence_names_mapped_to".
    " hypothetical proteins out of $num_hypothetical_biosequence_names (=$fraction2)";

    print "\nMapped to $num_dubious_biosequence_names_mapped_to".
    " dubious proteins out of $num_dubious_biosequence_names (=$fraction3)";

    print "\nMapped to $num_uncharacterized_biosequence_names_mapped_to".
    " uncharacterized proteins out of $num_uncharacterized_biosequence_names (=$fraction4)";

    print "\nMapped to $num_verified_biosequence_names_mapped_to".
    " verified proteins out of $num_verified_biosequence_names (=$fraction5)";

    print "\nMapped to $num_pseudogene_tyorfs_biosequence_names_mapped_to".
    " proteins in pseudo-genes or Ty ORFs out of ".
    " $num_pseudogene_tyorfs_biosequence_names (=$fraction6)\n\n";

} # end handleRequest
