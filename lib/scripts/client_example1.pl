#!/usr/local/bin/perl

###############################################################################
# Program     : client_example1.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script provides an example of the remote HTTP
#               client interface to SBEAMS.
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


  use strict;
  use FindBin;
  use lib "$FindBin::Bin/../perl";
  use SBEAMS::Client;
  use Data::Dumper;

  main();
  exit;


###############################################################################
# main
###############################################################################
sub main {

  #### Create SBEAMS client object and define SBEAMS server URI
  my $sbeams = new SBEAMS::Client;
  #my $server_uri = "http://localhost:10080/sbeams";
  my $server_uri = "https://db.systemsbiology.net/sbeams";


  #### Define the desired command and parameters
  my $server_command = "PeptideAtlas/BrowseBioSequence.cgi";
  my $command_parameters = {
    biosequence_set_id => 20,
    biosequence_gene_name_constraint => "bo%",
    #output_mode => "tsv",
    #apply_action => "QUERY",
  };


  #### Another example getting the contents of table PR_dbxref
  if (0 == 1) {
    $server_command = "PeptideAtlas/ManageTable.cgi";
    $command_parameters = {
      TABLE_NAME => "BL_dbxref",
      output_mode => "tsv",
      apply_action => "",
    };
  }



  #### Fetch the desired data from the SBEAMS server
  my $resultset = $sbeams->fetch_data(
    server_uri => $server_uri,
    server_command => $server_command,
    command_parameters => $command_parameters,
  );


  #### Stop if the fetch was not a success
  unless ($resultset->{is_success}) {
    print "ERROR: Unable to fetch data.\n\n";
    exit;
  }


  #### Since we got a successful resultset, print some things about it
  unless ($resultset->{data_ref}) {
    print "ERROR: Unable to parse data result.  See raw_response.\n\n";
    exit;
  }


  #### Print the raw dump
  #print $resultset->{raw_response},"\n\n";


  #### Print the members of the returned structure
  print "resultset:\n";
  while ( my ($key,$value) = each %{$resultset}) {
    if ($key eq 'raw_response') {
      print "  $key = <FULL DATA RESPONSE>\n";
    } else {
      print "  $key = $value\n";
    }
  }

  #### Print out the column list array and hash
  print "\n";
  print Dumper($resultset->{column_list_ref}),"\n";
  #print Dumper($resultset->{column_hash_ref}),"\n";


  #### Print the number of columns and rows
  print "Number of columns: ",scalar(@{$resultset->{column_list_ref}}),"\n";
  print "Number of data rows: ",scalar(@{$resultset->{data_ref}}),"\n\n";


  #### Print two selected columns of data
  my $column_index = $resultset->{column_hash_ref}->{biosequence_name};
  my $column_index2 = $resultset->{column_hash_ref}->{biosequence_gene_name};
  if (defined($column_index)) {
    print $resultset->{column_list_ref}->[$column_index2],"\t",
      $resultset->{column_list_ref}->[$column_index],"\n";
    print "---------------------------------\n";
    foreach my $row (@{$resultset->{data_ref}}) {
      print $row->[$column_index2],"\t",$row->[$column_index],"\n";
    }
  }
  print "\n";

}


