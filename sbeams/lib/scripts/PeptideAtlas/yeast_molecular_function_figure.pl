#!/usr/local/bin/perl -w

###############################################################################
# Program     : yeast_molecular_function_figure.pl
# Author      : Nichole King <nking@systemsbiology.org>
# $Id:
#
# Description : 
#               Makes a figure of the number of Yeast PeptideAtlas genes
#               in each molecular_function bin along with the number of
#               genes per bin in the SGD database for contrast.
#
#               For yeast, the parent molecular function id is GO:0003674.
#               The children are 15 categories, only 14 of which appear to be
#               present in the modern GO for SGD? (missing protein_tag)
#
#        NOTE: At this time, this should only be used for Yeast (Sc).
#        The GO numbers for the molecular function children are for yeast
#        so human, etc. would have to be entered and design changed just
#        a little.
#
###############################################################################

use strict;
use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../perl";

use vars qw ($sbeams $sbeamsMOD $current_username
             $PROG_NAME $USAGE %OPTIONS $TEST $QUIET
             $atlas_build_id $PASS
            );

#### Set up SBEAMS core module
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

## PeptideAtlas classes
use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

## BioLink
use SBEAMS::BioLink::Tables;

## graphics libraries:
use GD;
use GD::Graph;
use GD::Graph::xylines;
use GD::Graph::xylinespoints;
use GD::Graph::xypoints;
use GD::Graph::bars;
use GD::Text;


$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

## USAGE:
$USAGE = <<EOU;
Usage: [OPTIONS] key=value key=value ...
Options:
  --test               test program

  --run                run program

  --atlas_build_id     id of atlas

 e.g.:  $PROG_NAME --run --atlas_build_id '73'

EOU


GetOptions(\%OPTIONS, "test", "run", "atlas_build_id:s");


if ( ($OPTIONS{"run"} && $OPTIONS{"atlas_build_id"}) || $OPTIONS{"test"} )
{

    $atlas_build_id =  $OPTIONS{"atlas_build_id"};


} else
{

    die "$USAGE";

};



## if test, using yeast atlas P>0.9 characteristics 
if ( $OPTIONS{"test"} )
{

    $atlas_build_id = '73';

    $TEST = $OPTIONS{"test"};

} else
{

    $TEST = 0;

}


## set default test pass to zero
$PASS = 0;


main();

exit(0);


###############################################################################
# main
###############################################################################
sub main
{

    ## validate user
    check_authentication();


    ##$sbeams->printPageHeader() unless ($QUIET);

    #### Print out the header
    ##$sbeams->printUserContext() if ($QUIET > 0);


    ## define the term hash for the molecular function bins.
    ## data structure is a hash with key = GO id
    ##                               value = term
    my %molecular_function_terms = set_term_hash( organism => 'sgd' );



    ## initialize the bins of children of molecular_function using
    ## the specified PeptideAtlas.
    ## the data structure is hash with key = term
    ##                                 value = number of genes in bin
    my %molecular_function_counts_atlas = 
        set_atlas_bins( term_hash_ref => \%molecular_function_terms );



    ## initialize the bins of children of molecular_function using the
    ## SGD database                    key = term
    ##                                 value = number of genes in bin
    my %molecular_function_counts_sgd = 
        set_sgd_bins( term_hash_ref => \%molecular_function_terms );



    if ($PASS == 0)
    {    

       #make_bar_graph( term_hash_ref => \%molecular_function_terms,
       #    atlas_counts_ref => \%molecular_function_counts_atlas,
       #    sgd_counts_ref => \%molecular_function_counts_sgd,
       #);

        make_percent_bar_graph( term_hash_ref => \%molecular_function_terms,
            atlas_counts_ref => \%molecular_function_counts_atlas,
            sgd_counts_ref => \%molecular_function_counts_sgd,
        );

    } else
    {

        die "Cannot make figure as haven't passed all tests";

    }


    ##$sbeams->printPageFooter() unless ($QUIET);

} ## end main


#######################################################################
# check_authenticatation -- use SBEAMS authentication and exit if a 
#    username is not returned
#######################################################################
sub check_authentication
{

    exit unless ( $current_username =

        $sbeams->Authenticate(

        work_group=>'PeptideAtlas_admin')
    );

}


#######################################################################
#  set_term_hash -- set hash of keys = GO numbers, value = the GO term
#
#  NOTE, only set up to handle SG currently
####################################################################
sub set_term_hash 
{

    my %args = @_;

    my $organism = $args{'organism'};

    my %term_hash =  (
        "GO:0045735" =>   'nutrient reservoir activity',
        "GO:0045182" =>   'translation regulator activity',
        "GO:0003774" =>   'motor activity',
        "GO:0003824"  => 'catalytic activity',
        "GO:0004871"  => 'signal transducer activity',
        "GO:0005198"  => 'structural molecule activity',
        "GO:0005215"  => 'transporter activity',
        "GO:0005488"  => 'binding',
        "GO:0005554"  => 'molecular_function unknown',
        "GO:0016209"  => 'antioxidant activity',
        "GO:0030188"  => 'chaperone regulator activity',
        "GO:0030234"  => 'enzyme regulator activity',
        "GO:0030528"  => 'transcription regulator activity',
        "GO:0030533"  => 'triplet codon-amino acid adaptor activity',
        "GO:0031386"  => 'protein_tag',
    );


    if ($TEST)
    {

        my $num_terms = keys( %term_hash);

        if ( $num_terms == 15)
        {

            print "set_term_hash() PASSED test\n";

        } else
        {

            print "set_term_hash() FAILED test! ($!)\n";

            $PASS = 1;

        }

    }

    return %term_hash;

}


#######################################################################
#  set_atlas_bins - count the number of atlas genes per mf bin
####################################################################
sub set_atlas_bins
{

    my %args = @_;

    my $term_hash_ref = $args{term_hash_ref} || die "ERROR: Must pass term hash ($!)";

    my %term_hash= %{$term_hash_ref};


    ## NOTE: have to use BioLink name until LM finishes table installation...fix
    ## this following that

    ## SET-UP SQL statement
    my $sql = qq~
        SELECT B.biosequence_gene_name, GA.external_accession
        FROM $TBAT_PEPTIDE_INSTANCE PI
        JOIN $TBAT_PEPTIDE P ON (P.peptide_id = PI.peptide_id)
        JOIN $TBAT_PEPTIDE_MAPPING PM ON (PM.peptide_instance_id = PI.peptide_instance_id)
        JOIN $TBAT_BIOSEQUENCE B ON (B.biosequence_id = PM.matched_biosequence_id)
        JOIN $TBAT_BIOSEQUENCE_ANNOTATED_GENE BAG ON (BAG.biosequence_id = B.biosequence_id)
        JOIN BioLink.dbo.annotated_gene AG ON (BAG.annotated_gene_id = AG.annotated_gene_id)
        JOIN BioLink.dbo.gene_annotation GA ON (GA.annotated_gene_id = AG.annotated_gene_id)
        WHERE PI.atlas_build_id = '$atlas_build_id'
        AND GA.gene_annotation_type_id='1' 
        AND AG.organism_namespace_id='2'   
        AND (GA.external_accession like '%GO:0016209%'
        OR GA.external_accession like '%GO:0005488%' 
        OR GA.external_accession like '%GO:0003824%'
        OR GA.external_accession like '%GO:0030188%'
        OR GA.external_accession like '%GO:0030234%'
        OR GA.external_accession like '%GO:0005554%'
        OR GA.external_accession like '%GO:0003774%'
        OR GA.external_accession like '%GO:0045735%'
        OR GA.external_accession like '%GO:0031386%'
        OR GA.external_accession like '%GO:0004871%' 
        OR GA.external_accession like '%GO:0005198%'
        OR GA.external_accession like '%GO:0030528%'
        OR GA.external_accession like '%GO:0045182%'
        OR GA.external_accession like '%GO:0005215%'
        OR GA.external_accession like '%GO:0030533%')
    ~;
    ## GA.gene_annotation_type_id='1 is for molecular_function
    ## AG.organism_namespace_id='2' is for SGD
        
    
    my %test_hash = (
        "ARC35"   => "GO:0005198",
        "LAP3"    => "GO:0003676;GO:0008234;GO:0030528",
        "YPR118W" => "GO:0005554"
    );


    my %atlasBins = set_molecular_function_bins(
        term_hash_ref => \%term_hash,
        test_hash_ref => \%test_hash,
        sql_statement => $sql,
    );



    return %atlasBins;

}


#######################################################################
#  set_sgd_bins - count the number of SGD genes per mf bin
####################################################################
sub set_sgd_bins
{

    my %args = @_;

    my $term_hash_ref = $args{term_hash_ref} || die "ERROR: Must pass term hash ($!)";

    my %term_hash= %{$term_hash_ref};


    ## NOTE: have to use BioLink name until LM finishes table installation...fix
    ## this following that

    ## SET-UP sql statement
    my $sql = qq~
        SELECT AG.gene_name, GA.external_accession
        FROM BioLink.dbo.annotated_gene AG 
        JOIN BioLink.dbo.gene_annotation GA ON (GA.annotated_gene_id = AG.annotated_gene_id)
        WHERE GA.gene_annotation_type_id='1' 
        AND AG.organism_namespace_id='2'   
        AND (GA.external_accession like '%GO:0016209%'
        OR GA.external_accession like '%GO:0005488%' 
        OR GA.external_accession like '%GO:0003824%'
        OR GA.external_accession like '%GO:0030188%'
        OR GA.external_accession like '%GO:0030234%'
        OR GA.external_accession like '%GO:0005554%'
        OR GA.external_accession like '%GO:0003774%'
        OR GA.external_accession like '%GO:0045735%'
        OR GA.external_accession like '%GO:0031386%'
        OR GA.external_accession like '%GO:0004871%' 
        OR GA.external_accession like '%GO:0005198%'
        OR GA.external_accession like '%GO:0030528%'
        OR GA.external_accession like '%GO:0045182%'
        OR GA.external_accession like '%GO:0005215%'
        OR GA.external_accession like '%GO:0030533%')
    ~;
    ## GA.gene_annotation_type_id='1 is for molecular_function
    ## AG.organism_namespace_id='2' is for SGD
        

    my %test_hash = (
        "ZTA1"    => "GO:0005554",
        "ARC15"   => "GO:0003779;GO:0005198",
        "YFL054C" => "GO:0005215;GO:0015168;GO:0015250",
    );
        

    my %sgdBins = set_molecular_function_bins(
        term_hash_ref => \%term_hash,
        test_hash_ref => \%test_hash,
        sql_statement => $sql,
    );


    return %sgdBins;

}


#######################################################################
#  set_molecular_function_bins - count the number of genes per mf bin
####################################################################
sub set_molecular_function_bins
{

    my %args = @_;

    my $term_hash_ref = $args{term_hash_ref} || die "ERROR: Must pass term hash ($!)";

    my %term_hash= %{$term_hash_ref};

    my $test_hash_ref = $args{test_hash_ref};

    my %test_hash = %{$test_hash_ref};

    my $sql_statement = $args{sql_statement} || die "ERROR:  Must pass sql statement ($!)";


    my %binsHash;

    ## %term_hash :  keys = GO id, value = the GO term
    foreach my $go_id (keys %term_hash)
    {

        $binsHash{ $go_id } = 0;

    }


    ## execute sql statement: 
    my @rows = $sbeams->selectSeveralColumns($sql_statement) or
        die "problem with query: $sql_statement\n ($!)";


    my %gene_go_id_hash;


    my ($key, $val);


    ## more than one return possible for a gene, so want to keep the longest
    ## string returned as it should hold the most complete set of mf children
    foreach my $row (@rows)
    {

        ($key, $val) = @{$row};

        my $new_go_string_length = length $val;

        
        my $existing_go_string_length = 0;

        ## get length of existing go string
        if ( exists $gene_go_id_hash{ $key } )
        {

            $existing_go_string_length = length ($gene_go_id_hash{ $key });

        }


        if ( $new_go_string_length > $existing_go_string_length)
        {

            $gene_go_id_hash{ $key } = $val;

        }

    }


    ## gene_go_id_hash:  keys = gene_name, value = string GA.external_accession 
    ## %term_hash :      keys = GO id, value = the GO term
    ## %binsHash  :      keys = GO id, value = num genes per bin
    ## %test_hash :      keys = gene_name, value = string GA.external_accession

    ## testing that a few expected key/value pairs are true
    if ($TEST)
    {

        foreach my $key (keys %test_hash)
        {

            if ( !($gene_go_id_hash{$key} eq $test_hash{$key}) )
            {

                print "set_molecular_function_bins FAILED test: $gene_go_id_hash{$key} !eq $test_hash{$key}\n";

                $PASS = 1;

            }

        }

        if ($PASS == 0)
        {

            print "set_molecular_function_bins PASSED test\n";

        }

    }


    ## gene_go_id_hash:  keys = gene_name, value = string GA.external_accession 
    ## %term_hash :      keys = GO id, value = the GO term
    ## %binsHash  :      keys = GO id, value = num genes per bin

    ## counting:
    foreach my $gene_name ( keys %gene_go_id_hash )
    {

        my @go_id_list = split(";", $gene_go_id_hash{ $gene_name });

        for (my $i = 0; $i <= $#go_id_list; $i++) 
        {

            ## have $gene_name and a GOid
             
            ## one extra check to make sure we're only counting bins we care about:
            if ( exists $binsHash{$go_id_list[$i]} )
            {

                $binsHash{$go_id_list[$i]} = $binsHash{$go_id_list[$i]} + 1; 

            }
             
        }

    }


    return %binsHash;

}

#######################################################################
#
# make_bar_graph
#
#######################################################################
sub make_bar_graph
{

    my %args = @_;

    my $term_hash_ref = $args{term_hash_ref} || die "ERROR: Must pass term hash ($!)";

    my %term_hash= %{$term_hash_ref};

    my $atlas_counts_ref = $args{atlas_counts_ref} || die "ERROR: Must pass atlas_counts_ref ($!)";

    my %atlas_counts = %{$atlas_counts_ref};

    my $sgd_counts_ref = $args{sgd_counts_ref} || die "ERROR: Must pass sgd_counts_ref ($!)";

    my %sgd_counts = %{$sgd_counts_ref};

    ##xxxxxxx   finish!
    ## %term_hash :      keys = GO id, value = the GO term
    ## %binsHash  :      keys = GO id, value = num genes per bin

    my (@x, @y, @y2, @data);

    my $ymax = 0;


    ## fill x, y, y2 and data arrays:
    foreach my $term ( keys %term_hash )
    {

        push(@x, $term_hash{$term});

        push(@y, $atlas_counts{$term});

        push(@y2, $sgd_counts{$term});

        $ymax = $sgd_counts{$term} if ( $sgd_counts{$term} > $ymax);

    }

    @data = ([@x], [@y], [@y2]);

    my $graph = new GD::Graph::bars( 512, 512);

#   $graph->set_x_label_font(gdMediumBoldFont);

#   $graph->set_y_label_font(gdMediumBoldFont);

#   $graph->set_x_axis_font(gdMediumBoldFont);

#   $graph->set_y_axis_font(gdMediumBoldFont);

#   $graph->set_title_font(gdGiantFont);

    $graph->set(
        line_width      => 2,
    #   title           => "Yeast PeptideAtlas (Jul 2005, P>0.9)",
        x_label         => "GO Molecular Function bin",
        y_label         => "Number of Genes",
        x_labels_vertical => 1,
        y_max_value     => $ymax,
        l_margin => 10,
        r_margin => 10,
        b_margin => 10,
        t_margin => 10,
        dclrs    => [ qw(lblue green) ],
        markers => [2,1],
        bgclr    => 'white',
        transparent   => 0,
        fgclr         => 'black',
        labelclr      => 'black',
        legendclr      => 'black',
        axislabelclr  => 'black',
        textclr      => 'black',
    ) or die $graph->error;
    #   bar_width  => 
    #   bar_spacing =>

    $graph->set_legend( "Yeast PeptideAtlas Genes", "All SGD Genes" );

    my $gd_image = $graph->plot( \@data ) or die $graph->error;

    open(PLOT, ">yeast_go_molecular_function.png") or die("Cannot open file for writing");

    # Make sure we are writing to a binary stream
    binmode PLOT;

    # Convert the image to PNG and print it to the file PLOT
    print PLOT $gd_image->png;

    close PLOT;

}
#######################################################################
#
# make_percent_bar_graph
#
#######################################################################
sub make_percent_bar_graph
{

    my %args = @_;

    my $term_hash_ref = $args{term_hash_ref} || die "ERROR: Must pass term hash ($!)";

    my %term_hash= %{$term_hash_ref};

    my $atlas_counts_ref = $args{atlas_counts_ref} || die "ERROR: Must pass atlas_counts_ref ($!)";

    my %atlas_counts = %{$atlas_counts_ref};

    my $sgd_counts_ref = $args{sgd_counts_ref} || die "ERROR: Must pass sgd_counts_ref ($!)";

    my %sgd_counts = %{$sgd_counts_ref};

    ##xxxxxxx   finish!
    ## %term_hash :      keys = GO id, value = the GO term
    ## %binsHash  :      keys = GO id, value = num genes per bin

    my (@x, @y, @data);

    my $ymax = 100;


    ## fill x, y, and data arrays:
    foreach my $term ( keys %term_hash )
    {

        my $tmp_y;

        if ( $sgd_counts{$term} == 0 )
        {

            $tmp_y = 0;

        } else
        {

            $tmp_y = 100. * ($atlas_counts{$term} / $sgd_counts{$term});

        }

        push(@x, $term_hash{$term});

        push(@y, $tmp_y );

    }

    @data = ([@x], [@y]);

    my $graph = new GD::Graph::bars( 512, 512);

#   $graph->set_x_label_font(gdMediumBoldFont);

#   $graph->set_y_label_font(gdMediumBoldFont);

#   $graph->set_x_axis_font(gdMediumBoldFont);

#   $graph->set_y_axis_font(gdMediumBoldFont);

#   $graph->set_title_font(gdGiantFont);

    $graph->set(
        line_width      => 2,
    #   title           => "Yeast PeptideAtlas (Jul 2005, P>0.9)",
        x_label         => "GO Molecular Function bin",
        y_label         => "Percentage of GO annotated SGD Genes",
        x_labels_vertical => 1,
        y_max_value     => $ymax,
        l_margin => 10,
        r_margin => 10,
        b_margin => 10,
        t_margin => 10,
        dclrs    => [ qw(green) ],
        markers => [2,1],
        bgclr    => 'white',
        transparent   => 0,
        fgclr         => 'black',
        labelclr      => 'black',
        legendclr      => 'black',
        axislabelclr  => 'black',
        textclr      => 'black',
    ) or die $graph->error;
    #   bar_width  => 
    #   bar_spacing =>

    $graph->set_legend( "Yeast PeptideAtlas Genes");

    my $gd_image = $graph->plot( \@data ) or die $graph->error;

    open(PLOT, ">yeast_go_molecular_function.png") or die("Cannot open file for writing");

    # Make sure we are writing to a binary stream
    binmode PLOT;

    # Convert the image to PNG and print it to the file PLOT
    print PLOT $gd_image->png;

    close PLOT;

}
