package SBEAMS::ProteinStructure::TableInfo;

###############################################################################
# Program     : SBEAMS::ProteinStructure::TableInfo
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::ProteinStructure module which returns
#               information about various tables.
#
###############################################################################

use strict;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::ProteinStructure::Settings;
use SBEAMS::ProteinStructure::Tables;
use SBEAMS::Connection::Tables;


###############################################################################
# Constructor
###############################################################################
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    return($self);
}


###############################################################################
# Return Table Info
#
# Return the required information about the specified Table
###############################################################################
sub returnTableInfo {
    my $self = shift;
    my $table_name = shift || croak("parameter table_name not specified");
    my $info_key = shift || croak("parameter info_key not specified");

    my @row;
    my $sql_query;
    my $result;


###############################################################################
#
# First we have table-specific overrides of the default answers
#
# This is mostly just Queries now.  This should be pushed out into a
# nicely formatted file of queries.
#
###############################################################################
###############################################################################
    if ($table_name eq "blxxxxxx") {

        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT hardware_id,HT.name,make,model,serial_number,uri
		  FROM xxxxxxxx H
		  JOIN xxxxxxxxx HT
		       ON (H.hardware_type_id=HT.hardware_type_id)
		 WHERE H.record_status!='D'
            ~;
        }

        if ($info_key eq "FULLQuery") {
            return qq~
		SELECT H.*
		  FROM xxxxxxx H
		  JOIN xxxxxx HT
		       ON (H.hardware_type_id=HT.hardware_type_id)
		 WHERE H.record_status!='D'
            ~;
        }


    }


###############################################################################

    #### Obtain main SBEAMS object and fall back to its TableInfo handler
    my $sbeams = $self->getSBEAMS();
    my @temp_result = $sbeams->returnTableInfo($table_name,$info_key);
    return @temp_result;

}



###############################################################################
# getParentProject
#
# Return the parent project of a record in a table which might govern
# whether the proposed INSERT or UPDATE function may proceed.
###############################################################################
sub getParentProject {
  my $self = shift;
  my %args = @_;
  my $SUB_NAME = "getParentProject";

  #### Decode the argument list
  my $table_name = $args{'table_name'}
    || die("ERROR: $SUB_NAME: Parameter table_name not passed");
  my $action = $args{'action'}
    || die("ERROR: $SUB_NAME: Parameter action not passed");
  my $parameters_ref = $args{'parameters_ref'}
    || die("ERROR: $SUB_NAME: Parameter parameters_ref not passed");

  #### Make sure action is one of INSERT,UPDATE,DELETE
  unless ($action =~ /^INSERT$|^UPDATE$|^DELETE$/) {
    die("ERROR: $SUB_NAME: action must be one of INSERT,UPDATE,DELETE");
  }

  #### Get sbeams object, we'll need it for queries
  my $sbeams = $self->getSBEAMS();


  #############################################################################
  #### Process actions for individual tables

  #### If table is PS_biosequence_annotation
  if ($table_name eq "PS_biosequence_annotation") {

    #### Extract the biosequence_id that this annotation will belong to
    my $biosequence_id = $parameters_ref->{biosequence_id} ||
	die("ERROR: $SUB_NAME: biosequence_id not valid");

    #### If the user wants to INSERT, stand pat
    if ($action eq 'INSERT') {
      #### Nothing to do

    #### Else for an UPDATE or DELETE, get from biosequence_id table
    #### and verify it against the value in parameters
    } elsif ($action eq 'UPDATE' || $action eq 'DELETE') {
      $biosequence_id = $parameters_ref->{biosequence_id} ||
	die("ERROR: $SUB_NAME: biosequence_id not valid");

      my $biosequence_annotation_id =
	$parameters_ref->{biosequence_annotation_id} ||
	die("ERROR: $SUB_NAME: biosequence_annotation_id not valid");

      my $sql = qq~
	SELECT BSA.biosequence_id
	  FROM $TBPS_BIOSEQUENCE_ANNOTATION BSA
	 WHERE BSA.biosequence_annotation_id = '$biosequence_annotation_id'
	   AND BSA.record_status > ''
      ~;
      my ($check) = $sbeams->selectOneColumn($sql);

      if ($check != $biosequence_id) {
	die("ERROR: $SUB_NAME: Failed check that biosequence_id in paramters ".
	    "matches the value already in the table.  This should never ".
	    "happen.  Please report the error.");
      }

    #### Else action is invalid
    } else {
      die("ERROR: $SUB_NAME: action must be one of INSERT,UPDATE,DELETE");
    }


    my $sql = qq~
      SELECT BSS.project_id
        FROM $TBPS_BIOSEQUENCE BS
       INNER JOIN $TBPS_BIOSEQUENCE_SET BSS
             ON ( BS.biosequence_set_id = BSS.biosequence_set_id )
       WHERE BS.biosequence_id = '$biosequence_id'
         AND BSS.record_status != 'D'
    ~;
    my ($project_id) = $sbeams->selectOneColumn($sql);

    return($project_id) if ($project_id);
    die("ERROR: SUB_NAME: Invalid biosequence_id");
  }



  return;

}



###############################################################################
1;

__END__
###############################################################################
###############################################################################
###############################################################################
