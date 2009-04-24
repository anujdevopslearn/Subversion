#!/usr/local/bin/perl -w


# This program will export an atlas build as an sbeams table XML document.  
# See notes at /doc/PeptideAtlas/export_atlas_build.txt for more details.

use DBI;
use Getopt::Long;
use FindBin qw( $Bin );

use lib "$Bin/../../perl";
use SBEAMS::Connection::Settings qw( $DBCONFIG $DBINSTANCE );
use SBEAMS::Connection;
use SBEAMS::PeptideAtlas::Tables;
use strict;

my $sbeams = SBEAMS::Connection->new();

$|++; # don't buffer output
my $args = processArgs();

{ # MAIN

  printUsage( "Missing required parameter build_id" ) unless $args->{build_id};

  my $file = write_export_xml();
  run_data_export( $file );
}

sub run_data_export {
  my $expfile = shift;
  my $outfile = "/tmp/atlas_build_$args->{build_id}.xml";

  # Make the user deal with this
  die "File $outfile exists" if -e $outfile;

  my $synstr = 'matched_biosequence_id=biosequence_id,lab_id=organization_id,primary_contact_id=contact_id,supervisor_contact_id=contact_id,PI_contact_id=contact_id,parent_organization_id=organization_id,department_id=organization_id,group_id=organization_id';

  my $cmd = "$Bin/../Core/DataExport.pl -c $expfile -o $outfile -r -q --synonym $synstr -p 0";
  my @result = system( "$cmd" );

  my $pcmd = "perl -pi -e 's/(atlas_build_id=)$args->{build_id}(&amp)/" . '${1}1${2}' . "/' $outfile";
  @result = system( "$pcmd" );
}


sub write_export_xml {
  undef local $/;

  my $xml = qq~
  <export_command_list>
    <export_data table_name="AT_atlas_build_sample" qualifiers="atlas_build_id=ATLAS_BUILD_ID"></export_data>
    <export_data table_name="AT_default_atlas_build" qualifiers="atlas_build_id=ATLAS_BUILD_ID"></export_data>
    <export_data table_name="AT_spectra_description_set" qualifiers="atlas_build_id=ATLAS_BUILD_ID"></export_data>
    <export_data table_name="AT_search_key" qualifiers="atlas_build_id=ATLAS_BUILD_ID"></export_data>
    <export_data table_name="AT_peptide_instance_search_batch" qualifiers="peptide_instance_id IN ( SELECT DISTINCT peptide_instance_id FROM $TBAT_PEPTIDE_INSTANCE WHERE atlas_build_id=ATLAS_BUILD_ID )"></export_data>
    <export_data table_name="AT_peptide_mapping" qualifiers="peptide_instance_id IN ( SELECT DISTINCT peptide_instance_id FROM $TBAT_PEPTIDE_INSTANCE WHERE atlas_build_id=ATLAS_BUILD_ID )"></export_data>
    <export_data table_name="AT_modified_peptide_instance_search_batch" qualifiers="modified_peptide_instance_id IN ( SELECT DISTINCT modified_peptide_instance_id FROM $TBAT_MODIFIED_PEPTIDE_INSTANCE MPI JOIN $TBAT_PEPTIDE_INSTANCE PI ON PI.peptide_instance_id = MPI.peptide_instance_id WHERE atlas_build_id=ATLAS_BUILD_ID  )"></export_data>
    <export_data table_name="AT_proteotypic_peptide_mapping" qualifiers="source_biosequence_id IN ( SELECT DISTINCT biosequence_id FROM $TBAT_BIOSEQUENCE B JOIN $TBAT_ATLAS_BUILD AB ON AB.biosequence_set_id = B.biosequence_set_id WHERE atlas_build_id=ATLAS_BUILD_ID )">
    </export_data>
  </export_command_list>
  ~;

  $xml =~ s/ATLAS_BUILD_ID/$args->{build_id}/g;
  die "TBAT!\n: $xml" if $xml =~ /TBAT/;

  my $file = "/tmp/atlas_exp_$args->{build_id}.exp";

  # Make the user deal with this
  die "File $file exists" if -e $file;

  open( XML, ">$file" ) || die "Unable to open file: $file";
  print XML $xml;
  close XML;
  return( $file );
}

sub printUsage {
  my $err = shift || '';
  print( <<"  EOU" );
   $err
   
   Usage: $0 -b build_id

    -b, --build_id      Specify atlas build ID to export 
     
  EOU
  exit;
}

sub processArgs {
  my %args;
  unless( GetOptions ( \%args, 'build_id:i' ) ) {
    printUsage("Error with options, please check usage:");
  }

  return \%args;
}

__DATA__
# Removed from table list; 
#<export_data table_name="AT_sample_publication" qualifiers="sample_id IN ( SELECT DISTINCT sample_id FROM TBAT_ATLAS_BUILD_SAMPLE WHERE atlas_build_id=ATLAS_BUILD_ID )"></export_data>
#<export_data table_name="AT_atlas_search_batch_parameter" qualifiers="atlas_search_batch_id IN ( SELECT DISTINCT atlas_search_batch_id FROM TBAT_ATLAS_BUILD_SEARCH_BATCH WHERE atlas_build_id=ATLAS_BUILD_ID )"></export_data>
#  <export_data table_name="AT_atlas_search_batch_parameter_set" qualifiers="atlas_search_batch_id IN ( SELECT DISTINCT atlas_search_batch_id FROM TBAT_ATLAS_BUILD_SEARCH_BATCH WHERE atlas_build_id=ATLAS_BUILD_ID )"></export_data>
# <export_data table_name="AT_peptide_instance_sample" qualifiers="peptide_instance_id IN ( SELECT DISTINCT peptide_instance_id FROM TBAT_PEPTIDE_INSTANCE WHERE atlas_build_id=ATLAS_BUILD_ID )"></export_data>
#
#   <export_data table_name="AT_modified_peptide_instance_sample" qualifiers="modified_peptide_instance_id IN ( select modified_peptide_instance_id FROM TBAT_MODIFIED_PEPTIDE_INSTANCE WHERE peptide_instance_id IN ( SELECT DISTINCT peptide_instance_id FROM TBAT_PEPTIDE_INSTANCE WHERE atlas_build_id=ATLAS_BUILD_ID ) )"></export_data>

__DATA__
