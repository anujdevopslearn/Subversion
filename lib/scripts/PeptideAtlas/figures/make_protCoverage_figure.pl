#!/usr/local/bin/perl -w


#######################################################################
# make_protCoverage_figure.pl - make a figure of 
# sorted proteins vs protein coverage %.  
# serializes bin info and also writes 
# outfile protCoverageData.txt (for use by idl program for eps fig)
#
#  flags are:
# --test            test this code
# --run             run program
# --atlas_build_id  atlas build id
# --use_last_run    use data collected from last run of this program
#                   (de-serialization)
# --histogram       plot as a histogram

#USAGE: make_protCoverage_figure.pl --test
#       make_protCoverage_figure.pl --atlas_build_id '78' --run
#       make_protCoverage_figure.pl --atlas_build_id '78' --run --histogram
#
#   Author: N King
#######################################################################
use strict;
use Getopt::Long;
use FindBin;

## to create figure:
use GD;
use GD::Graph;
use GD::Graph::xylines;
use GD::Graph::xylinespoints;
use GD::Graph::xypoints;
use GD::Graph::bars;
use GD::Text;

use POSIX qw(ceil);


## for serialization 
use Storable qw(store retrieve freeze thaw dclone);


use lib "$FindBin::Bin/../../perl";

use vars qw ($sbeams $sbeamsMOD $current_username 
             $PROG_NAME $USAGE %OPTIONS $TEST 
             $outfig $atlas_build_id $useSerializedData
             $serDataFile $serTitleFile $makeHistogram
             $outfile
            );

#### Set up SBEAMS core module
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

## PeptideAtlas classes
use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;


$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


## USAGE:
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: [OPTIONS] key=value key=value ...
Options:
  --test            test this code
  --run             run program
  --atlas_build_id  atlas build id
  --use_last_run    use data collected from last run of this program
                    (serialization)
  --histogram       plot as a histogram

 e.g.:  $PROG_NAME --test
        $PROG_NAME --atlas_build_id '78' --run

EOU


GetOptions(\%OPTIONS, "test", "run", "atlas_build_id:s", "use_last_run",
"histogram");


if ( $OPTIONS{"test"} || $OPTIONS{"use_last_run"} ||
( $OPTIONS{"run"} && $OPTIONS{"atlas_build_id"}) )
{

    $TEST = $OPTIONS{"test"} || 0;

    $atlas_build_id = $OPTIONS{"atlas_build_id"} || "";

    $useSerializedData = $OPTIONS{"use_last_run"} || 0;

    $atlas_build_id = '78' if ($TEST);

    $makeHistogram = $OPTIONS{"histogram"} || 0;

} else
{

    print "$USAGE\n";

    exit(0);

}


$outfig = "protCoverage.png";

$serDataFile = "./.protCoverageData.ser";

$serTitleFile = "./.protCoverageTitle.ser";

$outfile = "./protCoverageData.txt";

main();

exit(0);


###############################################################################
# main
###############################################################################
sub main 
{

    #### Do the SBEAMS authentication and exit if a username is not returned
    exit unless ( $current_username = $sbeams->Authenticate(

        work_group=>'PeptideAtlas_admin')
    );


    ## check that can write to outfiles (also initializes ):
    check_files();


    handleRequest();


} ## end main


#######################################################################
# check_files -- check that can write to outfiles and initializes
#######################################################################
sub check_files()
{

    ## write new empty file:
    open(OUTFILE,">$outfig") or die "cannot write to $outfig";

    close(OUTFILE) or die "cannot close $outfig";

    open(OUTFILE,">$outfile") or die "cannot write to $outfile";

    close(OUTFILE) or die "cannot close $outfile";


    ## initialize serialized data file if not re-using the last one
    unless ($useSerializedData)
    {
        open(OUTFILE,">$serDataFile") or die "cannot write to $serDataFile";

        close(OUTFILE) or die "cannot close $serDataFile";

        open(OUTFILE,">$serTitleFile") or die "cannot write to $serTitleFile";

        close(OUTFILE) or die "cannot close $serTitleFile";

    }

}


#######################################################################
# handleRequest
#######################################################################
sub handleRequest()
{

    ## hash with key = protein name, value = %coverage
    my %proteinCoverageHash;

    my %title;


    ## if requested last serialization, retrieve data
    if ($useSerializedData)
    {

        %title = %{ retrieve($serTitleFile) };

        %proteinCoverageHash = %{ retrieve($serDataFile) };

        test_protein_coverage(protein_hash_ref => 
            \%proteinCoverageHash) if ($TEST);

    } else
    {

        %proteinCoverageHash = get_protein_coverage_hash();

        my $tmp = get_atlas_build_name( 
            atlas_build_id => $atlas_build_id );

        $tmp = "$tmp($atlas_build_id)";

        $title{"title"} = $tmp;

        ## serialization:
        store(\%proteinCoverageHash, $serDataFile)
            or die "can't store data in $serDataFile ($!)";

        store(\%title, $serTitleFile)
            or die "can't store data in $serTitleFile ($!)";

    }


    if ($makeHistogram)
    {

        my (@data) = make_histogram_data(
            data_hash_ref => \%proteinCoverageHash,
            outfile => $outfile
        );


        plot_data_histogram( 
            data_ref => \@data,
            title => $title{"title"},
            y_title => "number of proteins in protein coverage bin",
            x_title => "protein coverage %",
            outfig => $outfig
        );

    } else
    {

        plot_data( 
            data_hash_ref => \%proteinCoverageHash,
            title => $title{"title"},
            x_title => "protein identity (sorted by coverage)",
            y_title => "protein coverage",
            outfig => $outfig
        );

    }

}

###############################################################################
# get_protein_coverage_hash
###############################################################################
sub get_protein_coverage_hash
{

    ## get hash with key = proteinName, value = 0
    my %prtHash = get_mapped_protein_hash();

    ## replace hash values with percentage of sequence matched
    %prtHash = calculate_percentage_matched(
        protein_hash_ref => \%prtHash
    );

    return %prtHash;

}

########################################################################
# calculate_percentage_matched -
#    replace hash values with percentage of sequence matched
########################################################################
sub calculate_percentage_matched
{
    my %args = @_;

    my %hash;

    my $protein_hash_ref = $args{protein_hash_ref} or
        die "need protein hash reference ($!)";


    ## replace hash values with string of zeros the same
    ## size as protein sequence, and replace zeros with ones
    ## for peptide sequence match
    my %hash = make_mask_values_in_protein_hash(
        protein_hash_ref => $protein_hash_ref
    );


    ## count the matches and replace value with percentage matched
    foreach my $prot (keys %hash)
    {

        my $seq = $hash{$prot};

        my $seq_length = length $seq;

        my ($num_matched, $num_unmatched) = 0;

        # store every character into array:
        my @residues = split( undef, $seq);

        for (my $i = 0; $i<= $#residues; $i++)
        {

            if ($residues[$i] == "1")
            {

                $num_matched++;

            } else
            {

                $num_unmatched++;

            }

        }

        my $coverage = ($num_matched/$seq_length)*100.;

        $hash{$prot} = sprintf("%.1f", $coverage);

    }


    test_protein_coverage( protein_hash_ref => \%hash) if ($TEST);

    return %hash;

}


########################################################################
sub test_protein_coverage
{
    my %args = @_;

    my %hash;

    my $protein_hash_ref = $args{protein_hash_ref} or
        die "need protein hash reference ($!)";

    my %hash = %{ $protein_hash_ref };

    if ($TEST)
    {

        my $returned = $hash{"ENSP00000158302"};

        my $expected = 57.1;

        if ($returned == $expected)
        {

            print "TEST SUCCEEDED\n  protein coverage checks\n";

        } else 
        {

            print "TEST FAILED\n"
            .  "expected protein coverage $expected but estimated "
            .  " $returned ($!)\n";

        }

    }

}


########################################################################
# make_mask_values_in_protein_hash --
#     replace hash values with string of zeros the same
#     size as protei sequence, and replace zeros with ones
#     for peptide seaquence match
########################################################################
sub make_mask_values_in_protein_hash
{
    my %args = @_;

    my %hash;

    my $protein_hash_ref = $args{protein_hash_ref} or
        die "need protein hash reference ($!)";

    my %hash = %{ $protein_hash_ref };


    ## store string of proteins for sql into an array:
    my @proteinBatch = get_protein_batch_strings_for_sql(
        protein_hash_ref => \%hash
    );

    my $sql;

    for (my $i=0; $i <= $#proteinBatch; $i++)
    {

        my $protein_list = $proteinBatch[$i];

        $sql = qq~
            SELECT B.biosequence_name, B.biosequence_seq,
                PEP.peptide_sequence, PM.start_in_biosequence,
                PM.end_in_biosequence
            FROM $TBAT_ATLAS_BUILD AB
            JOIN $TBAT_PEPTIDE_INSTANCE PEPI ON
                (PEPI.atlas_build_id = AB.atlas_build_id)
            JOIN $TBAT_PEPTIDE_MAPPING PM ON
                (PM.peptide_instance_id = PEPI.peptide_instance_id)
            JOIN $TBAT_PEPTIDE PEP ON
                (PEP.peptide_id = PEPI.peptide_id)
            JOIN $TBAT_BIOSEQUENCE B ON 
                (PM.matched_biosequence_id = B.biosequence_id)
            WHERE B.biosequence_name IN ($protein_list)
            AND AB.atlas_build_id = '$atlas_build_id'
        ~;

        my @rows = $sbeams->selectSeveralColumns($sql) or
        die "statement failed: \n$sql\n ($!)";


        foreach my $row (@rows)
        {

            my ($prot, $prot_seq, $pep_seq, $start, $end) = @{$row};
           

            ## initialize values of protein hash if hasn't
            ## been done already. initializing to a string of
            ## zeros the same length as the protein's sequence
            if ( $hash{$prot} eq "0" )
            {

                my $n_zeros = length $prot_seq;

                for (my $n=1; $n < $n_zeros; $n++)
                {

                    $hash{$prot} = "$hash{$prot}" . "0";

                }

            }


            ## replace the values with 1's where there is a
            ## peptide residue match;
            ## use  $start - 1   and  $end - 1
            $start = $start - 1;

            $end = $end - 1;

            for (my $li = $start; $li <= $end; $li++)
            {

                substr($hash{$prot}, $li, 1, "1");

            }


            #print "$prot:$pep_seq\n" 
            #    . "    $start:$end\n"
            #    . "    $prot_seq\n"
            #    . "    $pep_seq\n"
            #    . "mask is: \n"
            #    . "    $hash{$prot}\n";
            # 
            #die;

        }

    }


    if ($TEST)
    {

        my $expected = "000000000000000000000000000011111111111111111111110000000000000000000000000000000000111111111111111111111111111110000000000000000000000000000000000111111111111111111111111111111000000111111110000011111111110000000111111111111111111111111111111111111111110011111111111111111111111111110000001111111111111111111111000111111111110000000000000000000000000000000001111111111111000";

        my $returned = $hash{"ENSP00000158302"};

        if ($expected eq $returned)
        {

            print "TEST SUCCEEDED:\n mask checks\n";

        } else
        {

            print "TEST FAILED :\n masks not equal\n";

        }

    }

    return %hash;

}



###############################################################################
# get_atlas_build_name 
###############################################################################
sub get_atlas_build_name
{

    my %args = @_;

    my $id = $args{atlas_build_id} || die "need atlas build id ($!)";

    my $sql = qq~
        SELECT atlas_build_name
        FROM $TBAT_ATLAS_BUILD
        where atlas_build_id = '$id'
    ~;

    my ($atlas_build_name) = $sbeams->selectOneColumn($sql) or
        die "unable to complete statement:\n$sql\n($!)";

    return $atlas_build_name;

}

###############################################################################
# get_mapped_protein_hash
###############################################################################
sub get_mapped_protein_hash
{

    ## get a hash of protein names if they've been mapped to
    my $sql = qq~
        SELECT B.biosequence_name, '0'
        FROM $TBAT_ATLAS_BUILD AB
        JOIN $TBAT_PEPTIDE_INSTANCE PEPI ON (PEPI.atlas_build_id = AB.atlas_build_id)
        JOIN $TBAT_PEPTIDE_MAPPING PM 
        ON (PM.peptide_instance_id = PEPI.peptide_instance_id)
        JOIN $TBAT_BIOSEQUENCE B ON (PM.matched_biosequence_id = B.biosequence_id)
        where AB.atlas_build_id = '$atlas_build_id'
    ~;

    ## make hash with key=protienName, value=0
    my %protHash = $sbeams->selectTwoColumnHash($sql) or
        die "unable to complete statement:\n$sql\n($!)";

    if ($TEST)
    {

        my $expectedN = 1234;

        my $returnedN = keys %protHash;

        if ( $returnedN != $expectedN )
        {

           print "TEST FAILED:\n" .
               "    returned $returnedN proteins but expected $expectedN\n";

        } else
        {

           print "TEST SUCCEEDED:\n" .
               "    returned $returnedN proteins\n";

        }

        #foreach my $k (sort keys %protHash)
        #{
        # 
        #   print "$protHash{$k}..";
        #  
        #}

    }

    return %protHash;

}

########################################################################
# get_protein_batch_strings_for_sql
########################################################################
sub get_protein_batch_strings_for_sql
{
    my %args = @_;

    my $protein_hash_ref = $args{protein_hash_ref} or
        die "need protein hash reference ($!)";

    my %hash = %{$protein_hash_ref};


    my @proteinBatchArray;

    ## Initialize count of number of proteins remaining for batch sql:
    my $n_remaining = keys %hash;

    my $n_batch = 10;

    my $count = 0;

    my $protString = "";

    my $n_proteins = keys %hash;

    foreach my $protein (sort keys %hash)
    {
 
        $n_proteins--;

        $count++;

        if (($protString eq "") || ($count == 1))
        {

            $protString = "'$protein'";

        } else
        {

            $protString = $protString . ",'$protein'";

        }
   
    
        if ($count == $n_batch || $n_proteins == 0)
        {

            push(@proteinBatchArray, $protString);

            $count = 0;

        }

    }

    if ($TEST)
    {
     
        my $expected_lastStr = 
            "'ENSP00000355330','ENSP00000355340','ENSP00000355342','ENSP00000355366'";

        my $lastStr = $proteinBatchArray[$#proteinBatchArray];

        if (!($lastStr eq $expected_lastStr))
        {

            print "TEST FAILED:\n" .
                "    last protein batch string is $lastStr\n";

        } else
        {

            print "TEST SUCCEEDED:\n" .
                "    protein batch strings ready\n";

        }

    }

    return @proteinBatchArray;

}


########################################################################
# plot_data
########################################################################
sub plot_data
{
    my %args = @_;

    my $data_hash_ref = $args{data_hash_ref} or die 
        "need data hash reference";

    my %data_hash = %{$data_hash_ref};

    my $title = $args{title};

    my $x_title = $args{x_title};

    my $y_title = $args{y_title};

    my $outfig = $args{outfig};


    my (@x, @y, @data);

    ## sort numerically by values:
    my @sortedKeys = sort{ $data_hash{$a} <=>  $data_hash{$b}} 
        keys %data_hash;

    my $count = 0;

    foreach my $key (@sortedKeys)
    {

        $count++;

        push(@x, $count);

        push(@y, $data_hash{$key});

    }


    #### Create a combined array
    @data = ([@x],[@y]);


    #my $graph = new GD::Graph::bars( 512, 512);
    #my $graph = new GD::Graph::xylines( 512, 512);
    #my $graph = new GD::Graph::xylinespoints( 512, 512);
    my $graph = new GD::Graph::xypoints( 512, 512);

    $graph->set_x_label_font(gdMediumBoldFont);
    $graph->set_y_label_font(gdMediumBoldFont);
    $graph->set_x_axis_font(gdMediumBoldFont);
    $graph->set_y_axis_font(gdMediumBoldFont);
    $graph->set_title_font(gdGiantFont);


    $graph->set( 
        line_width      => 2,
        title           => $title,
        y_label         => $y_title,
        x_label         => $x_title,
        x_min_value     => 0,
        x_max_value     => $count,
        y_min_value     => 0,
        y_max_value     => 100,
        y_number_format => sub{ return sprintf "%.0f",shift},
        x_number_format => sub{ return sprintf "%.0f",shift},
        l_margin => 10,
        r_margin => 10,
        b_margin => 10,
        t_margin => 10,
        dclrs    => [ qw(black) ],
        markers => [1],
        bgclr    => 'white', 
        transparent   => 0,
        fgclr         => 'black',
        labelclr      => 'black',
        legendclr      => 'black',
        axislabelclr  => 'black',
        textclr      => 'black',
    ) or die $graph->error;

    #   y_tick_number   => 10,
    #   long_ticks      => 1,
    #   bar_spacing     => 10,
    #   bar_width     => 2000,
    #   long_ticks      => 1,
    #   y_label_skip    => 2,


    ##Available line types are 1: solid, 2: dashed, 3: dotted, 4: dot-dashed.
    ##graph->set( line_types => [3, 2, 4] );
    #$graph->set( types => [qw(lines bars points area linespoints)] );
    #$graph->set( types => ['lines', undef, undef, 'bars'] );


#   $graph->set_legend( 
#       "Not Public (= unpublished)", "Public (usually published)" );

    my $gd_image = $graph->plot( \@data ) or die $graph->error;


    open(PLOT, ">$outfig") or die("Cannot open $outfig for writing");

    # Make sure we are writing to a binary stream
    binmode PLOT;

    # Convert the image to PNG and print it to the file PLOT
    print PLOT $gd_image->png;
    close PLOT;

}

########################################################################
# make_histogram_data
########################################################################
sub make_histogram_data
{
    my %args = @_;

    my $data_hash_ref = $args{data_hash_ref} or die 
        "need data hash reference";

    my %data_hash = %{$data_hash_ref};

    my $outfile = $args{outfile};


    my (@x, @y, @data);

    ## sort numerically by values:
    my @sortedKeys = sort{ $data_hash{$a} <=>  $data_hash{$b}} 
        keys %data_hash;

    my $count = 0;

    my $xmin = 0;

    my $xmax = 100;

    my $bin_sz = 10.0;

    my $half_bin_size = ($bin_sz/2.0);

    my $num_bins = ($xmax-$xmin)/$bin_sz;

    my (@bin_centers, @binned_data);

    for (my $i=0; $i < $num_bins; $i++)
    {

        my $bin_center = $xmin + ($bin_sz*($i + 0.5));

        $bin_centers[$i] = sprintf("%.2f", $bin_center);

        $binned_data[$i] = 0;

#       print "$i -- $bin_centers[$i] $binned_data[$i]\n";

    }
 
    ## will make bins 0-10, 10-20, 20-30, 30-40, ...
    #my @bin_centers = qw/ 5.0 15.0 25.0 35.0 45.0 55.0 65.0 75.0 85.0 95.0 /;
    #
    #my $num_bins = 10;

    ## this will be an array of size $num_bins, of the number of proteins per prot cov bin
    my (@binned_data) = 0;

    foreach my $key (@sortedKeys)
    {

        my $bin_number = (ceil($data_hash{$key}/$bin_sz)) - 1;

#       die "$data_hash{$key} is in bin $bin_number ..." . $data_hash{$key}/$bin_sz . "\n";

        $binned_data[$bin_number]++;

    }

    #for (my $i=0; $i<=$#bin_centers;$i++)
    #{
    # 
    #  print"$bin_centers[$i]  $binned_data[$i]\n";
    # 
    #}


    #### Create a combined array
    @data = ([@bin_centers],[@binned_data]);

    write_to_outfile( x_array_ref => \@bin_centers, 
        y_array_ref => \@binned_data);

    return @data;

}


########################################################################
# plot_data_histogram
########################################################################
sub plot_data_histogram
{
    my %args = @_;

    my $data_ref = $args{data_ref} or die 
        "need data reference";

    my $title = $args{title};

    my $x_title = $args{x_title};

    my $y_title = $args{y_title};

    my $outfig = $args{outfig};

    my @data = @{$data_ref};

    my $graph = new GD::Graph::bars( 512, 512);
    #my $graph = new GD::Graph::xylines( 512, 512);
    #my $graph = new GD::Graph::xylinespoints( 512, 512);
    #my $graph = new GD::Graph::xypoints( 512, 512);

    $graph->set_x_label_font(gdMediumBoldFont);
    $graph->set_y_label_font(gdMediumBoldFont);
    $graph->set_x_axis_font(gdMediumBoldFont);
    $graph->set_y_axis_font(gdMediumBoldFont);
    $graph->set_title_font(gdGiantFont);


    $graph->set( 
        line_width      => 2,
        title           => $title,
        y_label         => $y_title,
        x_label         => $x_title,
        x_min_value     => 0,
        x_max_value     => 100,
        y_number_format => sub{ return sprintf "%.0f",shift},
        x_number_format => sub{ return sprintf "%.0f",shift},
        l_margin => 10,
        r_margin => 10,
        b_margin => 10,
        t_margin => 10,
        dclrs    => [ qw(black) ],
        markers => [1],
        bgclr    => 'white', 
        transparent   => 0,
        fgclr         => 'black',
        labelclr      => 'black',
        legendclr      => 'black',
        axislabelclr  => 'black',
        textclr      => 'black',
    ) or die $graph->error;

    #   y_tick_number   => 10,
    #   long_ticks      => 1,
    #   bar_spacing     => 10,
    #   bar_width     => 2000,
    #   long_ticks      => 1,
    #   y_label_skip    => 2,


    ##Available line types are 1: solid, 2: dashed, 3: dotted, 4: dot-dashed.
    ##graph->set( line_types => [3, 2, 4] );
    #$graph->set( types => [qw(lines bars points area linespoints)] );
    #$graph->set( types => ['lines', undef, undef, 'bars'] );


#   $graph->set_legend( 
#       "Not Public (= unpublished)", "Public (usually published)" );

    my $gd_image = $graph->plot( \@data ) or die $graph->error;


    open(PLOT, ">$outfig") or die("Cannot open $outfig for writing");

    # Make sure we are writing to a binary stream
    binmode PLOT;

    # Convert the image to PNG and print it to the file PLOT
    print PLOT $gd_image->png;
    close PLOT;

}


########################################################################
# write_to_outfile -- writes x and y arrays to outfile in 2 columns
########################################################################
sub write_to_outfile
{
    my %args = @_;

    my $x_array_ref = $args{x_array_ref} or die 
        "need x array reference";

    my $y_array_ref = $args{y_array_ref} or die 
        "need y array reference";

    my @x_array= @{$x_array_ref};

    my @y_array= @{$y_array_ref};


    open(OUTFILE,">$outfile") or die "cannot write to $outfile";

    for (my $i=0; $i <= $#x_array; $i++)
    {

        print OUTFILE "$x_array[$i]\t$y_array[$i]\n";

    }

    close(OUTFILE) or die "cannot close $outfile";

}


