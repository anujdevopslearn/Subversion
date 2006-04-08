#!/usr/local/bin/perl -T

###############################################################################
# Program     : importLayoutInfo.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script important array_layout detail data.
#
###############################################################################


###############################################################################
# Get the script set up with everything it will need
###############################################################################
use strict;
use vars qw ($sbeams $dbh $PROGRAM_FILE_NAME
             $current_contact_id $current_username
             $current_work_group_id $current_work_group_name
             $current_project_id $current_project_name);
use lib qw (../..);
use lib qw (/net/arrays/Pipeline/tools/lib);
require 'QuantitationFile.pl';

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;

$sbeams = new SBEAMS::Connection;
$| = 1;


###############################################################################
# Global Variables
###############################################################################
$PROGRAM_FILE_NAME = 'importLayoutInfo.pl';
main();


###############################################################################
# Main Program:
#
# Call $sbeams->Authentication and stop immediately if authentication
# fails else continue.
###############################################################################
sub main { 

    #### Do the SBEAMS authentication and exit if a username is not returned
    exit unless ($current_username =
        $sbeams->Authenticate(work_group=>'Microarray_admin'));

    #### Print the header, do what the program does, and print footer
    $sbeams->printTextHeader();
    showMainPage();
    $sbeams->printTextFooter();

} # end main


###############################################################################
# Show the main welcome page
###############################################################################
sub showMainPage {

    $current_username = $sbeams->getCurrent_username;


    $sbeams->printUserContext(style=>'TEXT');
    print "\n";

    my $sqlquery = "SELECT layout_id,source_filename FROM array_layout";
    my %layouts = $sbeams->selectTwoColumnHash($sqlquery);

    my ($layout_id,$nrows,$element,$i,$key,$value,$igene);
    my (%data);

    foreach $layout_id (keys %layouts) {
    ##for ($layout_id=1; $layout_id<2; $layout_id++) {

      print "array_layout = $layout_id; file = $layouts{$layout_id}\n";
      $sqlquery = "SELECT COUNT(*) FROM array_element WHERE layout_id='$layout_id'";
      ($nrows) = $sbeams->selectOneColumn($sqlquery);
      print "There are $nrows elements for this layout_id\n";

      #### If no data for this array_layout have been loaded yet, do it
      if ($nrows < 1) {

        #### Read the key file
        %data = readKeyFile(inputfilename=>"$layouts{$layout_id}");

        #### Pull out the column titles & tags and print them out
        my @column_tags = @{$data{column_tags}};
        my @column_titles = @{$data{column_titles}};
        for ($element=0; $element<=$#column_tags; $element++) {
          printf("%22s = %s\n",$column_tags[$element],$column_titles[$element]);
        }

        #### Create the list of columns to insert
        my $column_textlist = "layout_id," . join(",",@column_tags);
        my @index_list = (0..$#column_tags);
        my (@data_list,$data_textlist);

        #### For yeast, also put gene_name and orf_name into reference
        #### and reference2
        if ($layouts{$layout_id} =~ /yeast/i) {
          $column_textlist .= ",reference,reference2";
          push (@index_list,5,6);
        }


        my @tmpgenearray = @{$data{genes}};
        my $ngenes = $#tmpgenearray + 1;
        print "Uploading data for $ngenes genes to database...\n";

        #### Uploading data to database
        ##for ($igene=0; $igene<5; $igene++) {
        for ($igene=0; $igene<$ngenes; $igene++) {
          @data_list = ("'$layout_id'");

          foreach $i (@index_list) {
            $value = ${${$data{genes}}[$igene]}[$i];
            $value =~ s/\'/\'\'/g;
            push (@data_list,"'$value'");
          }
          $data_textlist = join(",",@data_list);

          $sqlquery =  qq~
		INSERT INTO array_element ( $column_textlist )
		VALUES ( $data_textlist )
          ~;


          print $sqlquery;
          #$sbeams->executeSQL($sqlquery);

          print "$igene.. " if ($igene % 1000 == 0);

        }

      }

      print "\n";
    }



} # end showMainPage






