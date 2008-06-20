#!/usr/local/bin/perl -w

###############################################################################
# Program     : agilent_low_level_processor.pl
# Author      : Bruz Marzolf <bmarzolf@systemsbiology.org>
#
# Description : This script takes a set of Agilent arrays in a project and
#               converts Agilent FE outputs to a format that is GeneSpring-
#               readable and named by sample, and also runs CSV files through
#               the Java preprocess and postSAM.pl
#
###############################################################################
our $VERSION = '1.00';

=head1 NAME

agilent_low_level_processor.pl - Low-level processing of Agilent array data


=head1 SYNOPSIS

  --project_id <id of project to process>  [OPTIONS]
Options:
    --verbose <num>    Set verbosity level.  Default is 0
    --quiet            Set flag to print nothing at all except errors
    --debug n          Set debug flag    

=head1 DESCRIPTION

This script takes a set of Agilent arrays in a project and converts Agilent FE
outputs to a format that is GeneSpring-readable and named by sample, and also
runs CSV files through the Java preprocess and postSAM.pl


=head2 EXPORT

Nothing


=head1 SEE ALSO

SBEAMS::Microarray::Affy;
SBEAMS::Microarray::Affy_file_groups;

SBEAMS::Microarray::Settings; #contains the default file extensions and file path to find Affy files of interest

=head1 AUTHOR

Bruz Marzolf, E<lt>bmarzolf@localdomainE<gt>

=cut

###############################################################################
# Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use File::Basename;
use Data::Dumper;
use XML::XPath;
use XML::Parser;
use XML::XPath::XMLParser;

use Getopt::Long;
use FindBin;
use Cwd;

use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams $q $sbeams_affy $sbeams_affy_groups
  $PROG_NAME $USAGE %OPTIONS
  $VERBOSE $QUIET $DEBUG
  $DATABASE
  $TESTONLY
  $PROJECT_ID
  $CURRENT_USERNAME
  $SBEAMS_SUBDIR
  $PIPELINE_PATH
  $JAVA_PATH
  $NORMALIZED_ANNOTATED_PATH
  $GENESPRING_PATH
  $AGILENTFE_OUTPUT_PATH
);

#### Set up SBEAMS core module
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Microarray::Tables;

$sbeams = new SBEAMS::Connection;

$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;

my @run_modes = qw(add_new update delete);

$USAGE = <<EOU;
$PROG_NAME is used to perform low-level processing of Agilent array data 


Usage: $PROG_NAME --project_id <id of project to process>  [OPTIONS]
Options:
    --verbose <num>    Set verbosity level.  Default is 0
    --quiet            Set flag to print nothing at all except errors
    --debug n          Set debug flag  

EOU

#### Process options
unless (
  GetOptions( \%OPTIONS, "project_id:i", "verbose:i", "quiet", "debug:i" ) )
{
  print "$USAGE";
  exit;
}

$VERBOSE    = $OPTIONS{verbose} || 0;
$QUIET      = $OPTIONS{quiet};
$DEBUG      = $OPTIONS{debug} || 0;
$TESTONLY   = $OPTIONS{testonly};
$PROJECT_ID = $OPTIONS{project_id};

if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
  print "  PROJECT_ID = $PROJECT_ID\n";
}

###############################################################################
# Set Global Variables and execute main()
###############################################################################

$PIPELINE_PATH             = "/net/arrays/Pipeline";
$AGILENTFE_OUTPUT_PATH     = "/net/arrays/Spotfinding/AgilentFE_Output";
$JAVA_PATH                 = $sbeams->get_java_path();
$NORMALIZED_ANNOTATED_PATH =
  "$PIPELINE_PATH/output/project_id/$PROJECT_ID/NormalizedAnnotatedArrays";
$GENESPRING_PATH = "$PIPELINE_PATH/output/project_id/$PROJECT_ID/ForGeneSpring";

main();
exit(0);

###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
###############################################################################
sub main {

#### Try to determine which module we want to affect
  my $module     = $sbeams->getSBEAMS_SUBDIR();
  my $work_group = 'unknown';
  if ( $module eq 'Microarray' ) {
    $work_group = "Microarray_admin";
    $DATABASE   = $DBPREFIX{$module};
    print "DATABASE '$DATABASE'\n" if ($DEBUG);
  }

#### Do the SBEAMS authentication and exit if a username is not returned
  exit
    unless ( $CURRENT_USERNAME =
    $sbeams->Authenticate( work_group => $work_group, ) );

## Presently, force module to be microarray and work_group to be Microarray_admin  XXXXXX what does this do and is it needed
  if ( $module ne 'Microarray' ) {
    print
      "WARNING: Module was not Microarray.  Resetting module to Microarray\n";
    $work_group = "Microarray_admin";
    $DATABASE   = $DBPREFIX{$module};
  }

  $sbeams->printPageHeader() unless ($QUIET);
  handleRequest();
  $sbeams->printPageFooter() unless ($QUIET);

}    # end main

###############################################################################
# handleRequest
#
# Handles the core functionality of this script
###############################################################################
sub handleRequest {
  my %args     = @_;
  my $SUB_NAME = "handleRequest";

  print "Gather arrays from project $PROJECT_ID\n";
  my @project_arrays = get_arrays_for_project();

  print "Verifying existence of quantitation files for project $PROJECT_ID\n";
  foreach my $array (@project_arrays) {
    my $id          = $array->[0];
    my $name        = "$array->[2]($array->[3]) vs. $array->[4]($array->[5])";
    my $quant_file  = $array->[6];
    my $layout_file = $array->[7];

    if ( -e $quant_file ) {
      print "$quant_file Verified -- Samples $name -- Layout $layout_file\n"
        if $VERBOSE >= 5;
    }
    else {
      print "ERROR: $quant_file -- Samples $name -- Layout $layout_file "
        . "missing. Notify Array Core</A><BR>\n";
      die;
    }
  }

  # make sure the folder for the outputs exist
  if ( !( -e $NORMALIZED_ANNOTATED_PATH ) ) {
    `mkdir $NORMALIZED_ANNOTATED_PATH`;
  }
  if ( !( -e $GENESPRING_PATH ) ) {
    `mkdir $GENESPRING_PATH`;
  }

  print "Running preprocess and postSAM on each array\n";
  foreach my $array (@project_arrays) {
    my $id           = $array->[0];
    my $sample1_name = $array->[2];
    my $sample1_dye  = $array->[3];
    my $sample2_name = $array->[4];
    my $sample2_dye  = $array->[5];
    my $quant_file   = $array->[6];
    my $layout_file  = $array->[7];

    my ( $preprocess_output, $postSAM_output );
    if ( $sample2_name eq "" ) {
      $preprocess_output = "$NORMALIZED_ANNOTATED_PATH/$sample1_name.rep";
      $postSAM_output    = "$NORMALIZED_ANNOTATED_PATH/$sample1_name.txt";
    }
    else {
      $preprocess_output =
          "$NORMALIZED_ANNOTATED_PATH/"
        . $sample1_name . "_v_"
        . $sample2_name . ".rep";
      $postSAM_output =
          "$NORMALIZED_ANNOTATED_PATH/"
        . $sample1_name . "_v_"
        . $sample2_name . ".txt";
    }

    print "preprocess output: $preprocess_output\n"
      . "postSAM output: $postSAM_output\n\n"
      if $VERBOSE >= 4;

    if ( -e $postSAM_output ) {
      print "$postSAM_output already exists\n" if $VERBOSE >= 4;
    }
    else {

      # run Java preprocess, integrating high and low channels
      my $command_line =
          "$JAVA_PATH/bin/java -Xmx512M -jar /net/arrays/bin/preprocess.jar "
        . "-o $preprocess_output "
        . "-q $quant_file -m $layout_file " . "-i";
      print "running command line: $command_line\n" if $VERBOSE >= 3;
      my $results = `$command_line`;

      # run postSAM
      $command_line =
"perl /net/arrays/bin/postSAM.pl $preprocess_output $layout_file $postSAM_output";
      $results = `$command_line`;
      print "running command line: $command_line\n" if $VERBOSE >= 3;

      # remove temporary preprocess output
      $command_line = "rm $preprocess_output";
      $results      = `$command_line`;

      # progress indicator
      print ".";
    }
  }

  print "\n";

  print "Determining number of arrays per each slide\n";
  my %arrays_per_slide;
  foreach my $array (@project_arrays) {
    my $array_name = $array->[1];

    if ( $array_name =~ /(\d{12})(\d{1})/ ) {
      my $barcode      = $1;
      my $array_number = $2;

      if ( $array_number > $arrays_per_slide{$barcode} ) {
        $arrays_per_slide{$barcode} = $array_number;
        print "Max array number for $barcode increased to $array_number\n"
          if $VERBOSE >= 6;
      }
    }
  }

  print "Making GeneSpring files for each array\n";
  foreach my $array (@project_arrays) {
    my $id           = $array->[0];
    my $array_name   = $array->[1];
    my $sample1_name = $array->[2];
    my $sample1_dye  = $array->[3];
    my $sample2_name = $array->[4];
    my $sample2_dye  = $array->[5];

    # make sure the array name is in Agilent barcode + ISB array number format
    if ( $array_name =~ /(\d{12})(\d{1})/ ) {
      my $barcode            = $1;
      my $array_number       = $2;
      my $agilent_array_name =
        ISB_to_Agilent( $array_number, $arrays_per_slide{$barcode} );

      print "Found Agilent array: name = $array_name, barcode = $barcode,"
        . "array_number = $array_number, agilent_array_name = $agilent_array_name\n"
        if $VERBOSE >= 5;

      # map Agilent-style channel names to samples
      my %channels;
      if ( $sample1_dye =~ /Cy(\d)/ ) {
        $channels{"Cyanine$1H"} = $sample1_name . "H";
        $channels{"Cyanine$1L"} = $sample1_name . "L";
      }
      if ( $sample2_dye =~ /Cy(\d)/ ) {
        $channels{"Cyanine$1H"} = $sample2_name . "H";
        $channels{"Cyanine$1L"} = $sample2_name . "L";
      }

      foreach my $channel ( keys %channels ) {
        my @agilent_files =
          glob(
          "$AGILENTFE_OUTPUT_PATH/$barcode*$channel*$agilent_array_name.txt");

        print "For channel $channel, found files: @agilent_files\n"
          if $VERBOSE >= 1;

        if ( $#agilent_files > -1 ) {
          $channels{$channel} =~ /(.*)(H|L)/;
          my $sample_name = $1;
          my $intensity   = $2;
          generate_genespring_files( $agilent_files[0], $barcode,
            $agilent_array_name, $sample_name, $intensity );
        }
      }
    }
  }

  print "\n\n";
}

sub get_arrays_for_project {
  my $sql = qq~
	SELECT	A.array_id,A.array_name,
	ARSM1.name AS 'Sample1Name',D1.dye_name AS 'sample1_dye',
	ARSM2.name AS 'Sample2Name',D2.dye_name AS 'sample2_dye',
	AQ.stage_location,
	AL.source_filename
  FROM $TBMA_ARRAY_REQUEST AR
  LEFT JOIN $TBMA_ARRAY_REQUEST_SLIDE ARSL ON ( AR.array_request_id = ARSL.array_request_id )
  LEFT JOIN $TBMA_ARRAY_REQUEST_SAMPLE ARSM1 ON ( ARSL.array_request_slide_id = ARSM1.array_request_slide_id AND ARSM1.sample_index=0)
  LEFT JOIN $TBMA_LABELING_METHOD LM1 ON ( ARSM1.labeling_method_id = LM1.labeling_method_id )
  LEFT JOIN $TBMA_DYE D1 ON ( LM1.dye_id = D1.dye_id )
  LEFT JOIN $TBMA_ARRAY_REQUEST_SAMPLE ARSM2 ON ( ARSL.array_request_slide_id = ARSM2.array_request_slide_id AND ARSM2.sample_index=1)
  LEFT JOIN $TBMA_LABELING_METHOD LM2 ON ( ARSM2.labeling_method_id = LM2.labeling_method_id )
  LEFT JOIN $TBMA_DYE D2 ON ( LM2.dye_id = D2.dye_id )
  LEFT JOIN $TBMA_ARRAY A ON ( A.array_request_slide_id = ARSL.array_request_slide_id )
  LEFT JOIN $TBMA_ARRAY_SCAN ASCAN ON ( A.array_id = ASCAN.array_id )
  LEFT JOIN $TBMA_ARRAY_QUANTITATION AQ ON ( ASCAN.array_scan_id = AQ.array_scan_id )
  LEFT JOIN $TBMA_ARRAY_LAYOUT AL ON ( A.layout_id = AL.layout_id )
 WHERE AR.project_id=$PROJECT_ID
   AND AQ.array_quantitation_id IS NOT NULL
   AND AR.record_status != 'D'
   AND A.record_status != 'D'
   AND ASCAN.record_status != 'D'
   --AND AQ.record_status != 'D'
   AND AQ.data_flag != 'BAD'
 ORDER BY A.array_id
     ~;

  return $sbeams->selectSeveralColumns($sql);
}

sub ISB_to_Agilent {
  my $arrayNumber    = shift @_;
  my $arraysPerSlide = shift @_;

  my %conversion;
  if ( $arraysPerSlide == 2 ) {
    %conversion = (
      '2' => '1_1',
      '1' => '1_2',
    );
  }
  elsif ( $arraysPerSlide == 4 ) {
    %conversion = (
      '4' => '1_1',
      '3' => '1_2',
      '2' => '1_3',
      '1' => '1_4',
    );
  }
  elsif ( $arraysPerSlide == 8 ) {
    %conversion = (
      '8' => '1_1',
      '6' => '1_2',
      '4' => '1_3',
      '2' => '1_4',
      '7' => '2_1',
      '5' => '2_2',
      '3' => '2_3',
      '1' => '2_4',
    );
  }
  else {
    die "Error trying to convert array number for $arrayNumber\n";
  }

  return $conversion{"$arrayNumber"};
}

sub generate_genespring_files {
  my $agilent_file       = shift @_;
  my $barcode            = shift @_;
  my $agilent_array_name = shift @_;
  my $sample_name        = shift @_;
  my $intensity          = shift @_;

  my $out_file =
      $GENESPRING_PATH . "/"
    . $sample_name . "-"
    . $intensity . " ("
    . $barcode . "_"
    . $agilent_array_name . ")" . ".txt";

  # Only generate the file if it doesn't already exist
  if ( !( -e $out_file ) ) {
    print "barcode: $barcode, agilent number: $agilent_array_name, "
      . "sample name: $sample_name\n"
      if $VERBOSE >= 3;
    open IN,  $agilent_file;
    open OUT, ">$out_file";

    my $lineNumber = 1;
    while ( my $line = <IN> ) {
      if ( $lineNumber == 3 ) {
        print "line 3 was $line" if $VERBOSE >= 3;
        my @elements = split /\t/, $line;
        print "column 21: $elements[21]\n" if $VERBOSE >= 3;
        $elements[21] = $barcode . $elements[21];
        $line = join "\t", @elements;
        print "line 3 is $line" if $VERBOSE >= 3;
      }
      print OUT $line;
      $lineNumber += 1;
    }

    # progress indicator
    print ".";
  }
}
