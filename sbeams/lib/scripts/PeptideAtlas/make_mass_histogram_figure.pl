#!/usr/local/bin/perl -w

#######################################################################
#
#  flags are:
# --test            test this code
# --run             run program
# --atlas_build_id  atlas build id
# --use_last_run    use data collected from last run of this program
#                   (serialization)
# --histogram       plot as a histogram
#
#USAGE: make_mass_histogram_figure.pl --test
#       make_mass_histogram_figure.pl --atlas_build_id '78' --run
#       make_mass_histogram_figure.pl --atlas_build_id '78' --run --histogram
#
#   Author: Nichole King
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

use AvgMolWgt::AvgMolWgt;

use POSIX qw(ceil floor);


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


$outfig = "pepMass.png";

$serDataFile = "./.pepMassData.ser";

$serTitleFile = "./.pepMassTitle.ser";

$outfile = "./pepMassData.txt";

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


    ## make sure that user is on atlas:
    check_host();


    ## check that can write to outfiles (also initializes ):
    check_files();


    handleRequest();


} ## end main


#######################################################################
# check_host -- check that host name is atlas as we need to write to
#   /sbeams/
#######################################################################
sub check_host()
{

    ## make sure that this is running on atlas for queries
    my $uname = `uname -a`;

    if ($uname =~ /.*(atlas).*/)
    {

        # continue

    } else
    {

        die "you must run this on atlas";

    }

}

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

    ## hash with key = peptide sequence, value = avg mol wgt
    my %pepMassHash;

    my %title;


    ## if requested last serialization, retrieve data
    if ($useSerializedData)
    {

        %title = %{ retrieve($serTitleFile) };

        %pepMassHash = %{ retrieve($serDataFile) };

        test_peptide_mass(peptide_hash_ref => 
            \%pepMassHash) if ($TEST);

    } else
    {

        %pepMassHash = get_peptide_mass_hash(
            atlas_build_id => $atlas_build_id);

        my $tmp = get_atlas_build_name( 
            atlas_build_id => $atlas_build_id );

        $tmp = "$tmp($atlas_build_id)";

        $title{"title"} = $tmp;

        ## serialization:
        store(\%pepMassHash, $serDataFile)
            or die "can't store data in $serDataFile ($!)";

        store(\%title, $serTitleFile)
            or die "can't store data in $serTitleFile ($!)";

    }


    if ($makeHistogram)
    {

        my (@data) = make_histogram_data(
            data_hash_ref => \%pepMassHash,
            outfile => $outfile,
        );


        plot_data_histogram( 
            data_ref => \@data,
            title => $title{"title"},
            y_title => "number of peptides with avg mol wgt",
            x_title => "average molecular weight",
            outfig => $outfig
        );

    } else
    {

        plot_data( 
            data_hash_ref => \%pepMassHash,
            title => $title{"title"},
            x_title => "peptide identity (sorted, just a place holder)",
            y_title => "peptide avg mol wgt",
            outfig => $outfig
        );

    }

}

###############################################################################
# get_peptide_mass_hash
###############################################################################
sub get_peptide_mass_hash
{

    my %args = @_;

    my $atlas_build_id = $args{ atlas_build_id } || die "need atlas build id";

    ## get hash with key = peptide sequence, value = 0
    my %pepHash = get_peptide_hash( atlas_build_id => $atlas_build_id);

    ## replace hash values with avg mol wgt of sequences
    %pepHash = calculate_avg_mol_wgts(
        peptide_hash_ref => \%pepHash
    );


    return %pepHash;

}

########################################################################
# calculate_avg_mol_wgts
########################################################################
sub calculate_avg_mol_wgts
{
    my %args = @_;

    my %hash;

    my $peptide_hash_ref = $args{peptide_hash_ref} or
        die "need peptide hash reference ($!)";

    %hash = %{ $peptide_hash_ref };

    ##  get avg molec wgt for sequence
    foreach my $pep (keys %hash)
    {
        $hash{$pep} = AvgMolWgt::calcAvgMolWgt( sequence => $pep );
    }


    test_peptide_mass( peptide_hash_ref => \%hash) if ($TEST);

    return %hash;

}


########################################################################
sub test_peptide_mass
{
    my %args = @_;

    my %hash;

    my $peptide_hash_ref = $args{peptide_hash_ref} or
        die "need pep hash reference ($!)";

    my %hash = %{ $peptide_hash_ref };

    ## put a test here, eh

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
# get_peptide_hash
###############################################################################
sub get_peptide_hash
{

    my %args = @_;

    my $atlas_build_id = $args{atlas_build_id} || "die need atlas build id";

    ## get a hash of peptide sequences 
    my $sql = qq~
        SELECT P.peptide_sequence, '0'
        FROM $TBAT_PEPTIDE P
        JOIN $TBAT_PEPTIDE_INSTANCE PEPI ON (PEPI.peptide_id = P.peptide_id)
        where PEPI.atlas_build_id = '$atlas_build_id'
    ~;

    ## make hash with key=peptide sequence, value=0
    my %pepHash = $sbeams->selectTwoColumnHash($sql) or
        die "unable to complete statement:\n$sql\n($!)";

    if ($TEST)
    {
 
        my $expectedN = 1058;
 
        my $returnedN = keys %pepHash;
 
        if ( $returnedN != $expectedN )
        {
 
            print "TEST FAILED:\n" .
                "    returned $returnedN peptides but expected $expectedN\n";
 
         } else
         {
 
            print "TEST SUCCEEDED:\n" .
                "    returned $returnedN peptides\n";
 
         }

    }

    return %pepHash;

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


    ## here, x is peptide sequence, y is peptide mass

    my (@x, @y, @data);

    ## sort numerically by values:
    my @sortedKeys = sort{ $data_hash{$a} <=>  $data_hash{$b}} 
        keys %data_hash;

    my $count = 0;

    ## rounded to the lowest 100:
    my $xminData = $data_hash{$sortedKeys[0]};

    my $xmin = (floor( $xminData/100.)) * 100;


    ## rounded to the highest 100:
    my $xmaxData = $data_hash{$sortedKeys[$#sortedKeys]};

    my $xmax = (ceil( $xmaxData/100.)) * 100;

#   print "xmin = $xminData rounded to $xmin, xmax = $xmaxData rounded to $xmax\n";

    ## want bins of size 100 Da
    my $bin_sz = 100;

    my $num_bins = ($xmax-$xmin)/$bin_sz;
   
    my (@bin_centers, @binned_data);

    for (my $i=0; $i < $num_bins; $i++)
    {

        my $bin_center = $xmin + ($bin_sz*($i + 0.5));

        $bin_centers[$i] = $bin_center;

        $binned_data[$i] = 0;

#       print "$i -- $bin_center $binned_data[$i]\n";

    } 


    ## this will be an array of size $num_bins, of the number of proteins per prot cov bin
    my (@binned_data) = 0;

    foreach my $key (@sortedKeys)
    {

        my $bin_number = (floor( ($data_hash{$key} - $xmin)/$bin_sz ));

#       die "$data_hash{$key} is in bin $bin_number ..." . $data_hash{$key}/$bin_sz . "\n";

        $binned_data[$bin_number]++;

    }


#   for (my $i=0; $i < $num_bins; $i++)
#   {
#
#       print "$i -- $bin_centers[$i]  $binned_data[$i] \n";
#
#   }


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

    my @data = @{ $data_ref };

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
        y_number_format => sub{ return sprintf "%.0f",shift},
        x_number_format => sub{ return sprintf "%.0f",shift},
        x_labels_vertical => 1,
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

