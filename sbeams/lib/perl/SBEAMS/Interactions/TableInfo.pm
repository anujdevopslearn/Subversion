package SBEAMS::Interactions::TableInfo;

###############################################################################
# Program     : SBEAMS::Interactions::TableInfo
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Interactions module which returns
#               information about various tables.
#
###############################################################################

use strict;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Interactions::Settings;
use SBEAMS::Interactions::Tables;
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



    if ($table_name eq "IN_interaction") {

        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT I.interaction_id,
			BE1.bioentity_common_name,BES1.bioentity_state_name,RF1.regulatory_feature_name,
			IT.interaction_type_name,
			BE2.bioentity_common_name,BES2.bioentity_state_name,RF2.regulatory_feature_name,
			PUB.pubmed_id
		  FROM $TBIN_INTERACTION I
		  LEFT JOIN $TBIN_INTERACTION_TYPE IT ON ( I.interaction_type_id = IT.interaction_type_id )
		  LEFT JOIN $TBIN_BIOENTITY BE1 ON ( I.bioentity1_id = BE1.bioentity_id )
		  LEFT JOIN $TBIN_BIOENTITY BE2 ON ( I.bioentity2_id = BE2.bioentity_id )
		  LEFT JOIN $TBIN_BIOENTITY_STATE BES1 ON ( I.bioentity1_state_id = BES1.bioentity_state_id )
		  LEFT JOIN $TBIN_BIOENTITY_STATE BES2 ON ( I.bioentity2_state_id = BES2.bioentity_state_id )
		  LEFT JOIN $TBIN_REGULATORY_FEATURE RF1 ON ( I.regulatory_feature1_id = RF1.regulatory_feature_id )
		  LEFT JOIN $TBIN_REGULATORY_FEATURE RF2 ON ( I.regulatory_feature2_id = RF1.regulatory_feature_id )
			LEFT JOIN $TBIN_PUBLICATION PUB ON (I.publication_id = PUB.publication_id)
		 WHERE I.record_status != 'D'
            ~;
        }
#		   AND ( BE1.record_status != 'D' OR BE1.record_status IS NULL )
#		   AND ( BE2.record_status != 'D' OR BE2.record_status IS NULL )
#		   AND ( BES1.record_status != 'D' OR BES1.record_status IS NULL )
#		   AND ( BES2.record_status != 'D' OR BES2.record_status IS NULL )
#		   AND ( RF1.record_status != 'D' OR RF1.record_status IS NULL )
#		   AND ( RF2.record_status != 'D' OR RF2.record_status IS NULL )

        if ($info_key eq "FULLQuery") {
            return qq~
		SELECT I.*
		  FROM $TBIN_INTERACTION I
		 --WHERE I.record_status!='D'
            ~;
        }


    }

    if ($table_name eq "IN_interaction_group") {

        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT IG.interaction_group_id,
		        P.name AS "project_name", O.organism_name, interaction_group_name,
			  interaction_group_description
		  FROM $TBIN_INTERACTION_GROUP IG
		  LEFT JOIN $TB_PROJECT P ON ( IG.project_id = P.project_id )
		  LEFT JOIN $TB_ORGANISM O ON ( IG.organism_id = O.organism_id )
		 WHERE IG.record_status != 'D'
		   AND ( P.record_status != 'D' OR P.record_status IS NULL )
		   AND ( O.record_status != 'D' OR O.record_status IS NULL )
            ~;
        }

        if ($info_key eq "FULLQuery") {
            return qq~
		SELECT I.*
		  FROM $TBIN_INTERACTION_GROUP I
		 --WHERE I.record_status!='D'
            ~;
        }


      }

    if ($table_name eq "IN_bioentity") {

        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT B.bioentity_id,
		        O.organism_name, BT.bioentity_type_name, bioentity_common_name,
                        bioentity_canonical_name, bioentity_full_name, bioentity_aliases,
                        BS.biosequence_name,B.comment
		  FROM $TBIN_BIOENTITY B
		  LEFT JOIN $TB_ORGANISM O ON ( B.organism_id = O.organism_id )
		  LEFT JOIN $TBIN_BIOENTITY_TYPE BT ON ( B.bioentity_type_id = BT.bioentity_type_id )
		  LEFT JOIN $TBIN_BIOSEQUENCE BS ON (B.biosequence_id = BS.biosequence_id )
		 WHERE B.record_status != 'D'
		   AND ( O.record_status != 'D' OR O.record_status IS NULL )
		   AND ( BT.record_status != 'D' OR BT.record_status IS NULL )
            ~;
        }

        if ($info_key eq "FULLQuery") {
            return qq~
		SELECT B.*
		  FROM $TBIN_BIOENTITY B
		 WHERE 1 = 1
		 --AND B.record_status!='D'
            ~;
        }


      }


    if ($table_name eq "IN_assay") {

        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT A.assay_id,
		        assay_name, AT.assay_type_name, ST.sample_type_name,
			P.publication_name
		  FROM $TBIN_ASSAY A
		  LEFT JOIN $TBIN_ASSAY_TYPE AT ON ( A.assay_type_id = AT.assay_type_id )
		  LEFT JOIN $TBIN_SAMPLE_TYPE ST ON ( A.sample_type_id = ST.sample_type_id )
		  LEFT JOIN $TBIN_PUBLICATION P ON ( A.publication_id = P.publication_id )
		 WHERE A.record_status != 'D'
		   AND ( AT.record_status != 'D' OR AT.record_status IS NULL )
		   AND ( ST.record_status != 'D' OR ST.record_status IS NULL )
		   AND ( P.record_status != 'D' OR P.record_status IS NULL )
            ~;
        }

        if ($info_key eq "FULLQuery") {
            return qq~
		SELECT A.*
		  FROM $TBIN_ASSAY A
		 --WHERE A.record_status!='D'
            ~;
        }


      }


    if ($table_name eq "IN_sample_type") {

        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT sample_type_id,
		       sample_type_name, sample_type_description, O.organism_name, ST.comment
		  FROM $TBIN_SAMPLE_TYPE ST
		  LEFT JOIN $TB_ORGANISM O ON ( ST.organism_id = O.organism_id )
		WHERE ST.record_status != 'D'
		   AND ( O.record_status != 'D' OR O.record_status IS NULL )
            ~;
        }

        if ($info_key eq "FULLQuery") {
            return qq~
		SELECT ST.*
		  FROM $TBIN_SAMPLE_TYPE ST
		 --WHERE ST.record_status!='D'
            ~;
        }


      }



    if ($table_name eq "IN_publication") {

        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT publication_id,pubmed_ID,publication_name,
		       publication_category_name AS "Category",
		       title,
		       full_manuscript_file,
		       uri
		  FROM $TBIN_PUBLICATION P
		  LEFT JOIN $TBIN_PUBLICATION_CATEGORY PC
                       ON (P.publication_category_id = PC.publication_category_id)
		 WHERE 1 =1
                   AND P.record_status!='D'
		   AND ( PC.record_status!='D' OR PC.record_status IS NULL )
		 ORDER BY publication_id
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

  #### Get sbeams object, needed for Core tables and SQL queries
  my $sbeams = $self->getSBEAMS();

  #### Define the project_id, starting as undef, it gets filled if there is one
  my $project_id;

  #### Check to see if this is a Core table that has project control
  $project_id = $sbeams->getParentProject(
    table_name => $table_name,
    action => $action,
    parameters_ref => $parameters_ref,
  );
  return($project_id) if ($project_id);


  #############################################################################
  #### Process actions for individual tables

  #### If table is xxxx
  if ($table_name eq "xxxx") {

    #### If the user wants to INSERT, determine how it fits into project
    if ($action eq 'INSERT') {

    #### Else for an UPDATE or DELETE, determine how it fits into project
    } elsif ($action eq 'UPDATE' || $action eq 'DELETE') {

    }

    return($project_id) if ($project_id);
  }


  #### No information for this table so return undef
  return;

}



###############################################################################
1;

__END__
###############################################################################
###############################################################################
###############################################################################
