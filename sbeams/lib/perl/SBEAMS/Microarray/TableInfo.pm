package SBEAMS::Microarray::TableInfo;

###############################################################################
# Program     : SBEAMS::Microarray::TableInfo
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Microarray module which returns
#               information about various tables.
#
###############################################################################

use strict;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Microarray::Settings;
use SBEAMS::Microarray::Tables;
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
    if ($table_name eq "hardware") {

        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT hardware_id,HT.name,make,model,serial_number,uri
		  FROM $TB_HARDWARE H
		  JOIN $TB_HARDWARE_TYPE HT
		       ON (H.hardware_type_id=HT.hardware_type_id)
		 WHERE H.record_status!='D'
            ~;
        }

        if ($info_key eq "FULLQuery") {
            return qq~
		SELECT H.*
		  FROM $TB_HARDWARE H
		  JOIN $TB_HARDWARE_TYPE HT
		       ON (H.hardware_type_id=HT.hardware_type_id)
		 WHERE H.record_status!='D'
            ~;
        }


    }


###############################################################################
    if ($table_name eq "software") {

        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT software_id,ST.name,version,operating_system,uri
		  FROM $TB_SOFTWARE S
		  JOIN $TB_SOFTWARE_TYPE ST
		       ON (S.software_type_id=ST.software_type_id)
		 WHERE S.record_status!='D'
            ~;
        }

        if ($info_key eq "FULLQuery") {
            return qq~
		SELECT S.*
		  FROM $TB_SOFTWARE S
		  JOIN $TB_SOFTWARE_TYPE ST
		       ON (S.software_type_id=ST.software_type_id)
		 WHERE S.record_status!='D'
            ~;
        }

    }


###############################################################################
    if ($table_name eq "slide_type") {

        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT slide_type_id,ST.name,organism_name AS 'organism',price
		  FROM $TBMA_SLIDE_TYPE ST
		  JOIN $TB_ORGANISM O
		       ON (ST.organism_id=O.organism_id)
		 WHERE ST.record_status!='D'
            ~;
        }

        if ($info_key eq "FULLQuery") {
            return qq~
		SELECT slide_type_id,ST.name,O.organism_name,price,ST.sort_order,
		       ST.date_created,ST.created_by_id,ST.date_modified,
		       ST.modified_by_id,ST.record_status
		  FROM $TBMA_SLIDE_TYPE ST
		  JOIN $TB_ORGANISM O
		       ON (ST.organism_id=O.organism_id)
		 WHERE ST.record_status!='D'
            ~;
        }

    }


###############################################################################
    if ($table_name eq "slide_type_cost") {

        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT slide_type_cost_id,name,cost_scheme_name,STC.price
		  FROM $TBMA_SLIDE_TYPE_COST STC
		  JOIN $TBMA_SLIDE_TYPE ST
		       ON (STC.slide_type_id=ST.slide_type_id)
		  JOIN $TBMA_COST_SCHEME CS
		       ON (STC.cost_scheme_id=CS.cost_scheme_id)
		 WHERE STC.record_status!='D'
            ~;
        }

    }


###############################################################################
    if ($table_name eq "labeling_method") {

        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT labeling_method_id,LM.name,xna_type,
		       dye_name,desired_micrograms,Ebase,MWbase,price
		  FROM $TBMA_LABELING_METHOD LM
		  LEFT JOIN $TBMA_XNA_TYPE XT
		       ON (LM.xna_type_id=XT.xna_type_id)
		  LEFT JOIN $TBMA_DYE D
		       ON (LM.dye_id=D.dye_id)
		 WHERE LM.record_status!='D'
            ~;
        }

        if ($info_key eq "FULLQuery") {
            return qq~
		SELECT LM.*
		  FROM $TBMA_LABELING_METHOD LM
		 WHERE LM.record_status!='D'
            ~;
        }

    }


###############################################################################
    if ($table_name eq "array_request") {

        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT array_request_id,username,n_slides,ST.name,
		       request_status
		  FROM $TBMA_ARRAY_REQUEST AR
		  LEFT JOIN $TB_USER_LOGIN U
		       ON (AR.contact_id=U.contact_id)
		  LEFT JOIN $TBMA_SLIDE_TYPE ST
		       ON (AR.slide_type_id=ST.slide_type_id)
		 WHERE AR.record_status!='D'
            ~;
        }

    }



###############################################################################
    if ($table_name eq "slide_model") {

        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT slide_model_id,vendor_name,model_name,contact_id,comment
		  FROM $TBMA_SLIDE_MODEL
		 WHERE record_status!='D'
            ~;
        }

    }




###############################################################################
    if ($table_name eq "slide_lot") {

        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT slide_lot_id,SM.vendor_name,SM.model_name,lot_number,
		       date_received,SL.comment
		  FROM $TBMA_SLIDE_LOT SL
		  LEFT JOIN $TBMA_SLIDE_MODEL SM
		       ON (SL.slide_model_id=SM.slide_model_id)
		 WHERE SL.record_status!='D'
            ~;
        }

    }


###############################################################################
    if ($table_name eq "printing_batch") {

    }


###############################################################################
    if ($table_name eq "slide") {

        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT slide_id,lot_number,slide_number
		  FROM $TBMA_SLIDE S
		  LEFT JOIN $TBMA_SLIDE_LOT SL
		       ON (S.slide_lot_id=SL.slide_lot_id)
		 WHERE S.record_status!='D'
		   AND SL.record_status!='D'
            ~;
        }

    }


###############################################################################
    if ($table_name eq "array_layout") {

    }



###############################################################################
    if ($table_name eq "array") {

        # Removed multi-insert capability because individual linking to
        # requested_array_slide_id's and array_name added and that makes
        # things more complicated.  Could still be added with additional
        # code functionality
        #return "slide_id" if ($info_key eq "MULTI_INSERT_COLUMN");

    }


###############################################################################
    if ($table_name eq "labeling") {

    }



###############################################################################
    if ($table_name eq "hybridization") {

    }



###############################################################################
    if ($table_name eq "array_scan") {

    }


###############################################################################
    if ($table_name eq "array_quantitation") {

    }


###############################################################################
    if ($table_name eq "MA_affy_array") {

    	if ($info_key eq "BASICQuery") {
            return qq~
			SELECT afa.affy_array_id, 
			afa.file_root, 
			f.file_path, 
			s.name AS "Array_Type", 
			afa.processed_date,
			afa.affy_array_sample_id,
			u.username
			FROM $TBMA_AFFY_ARRAY afa 
			JOIN $TBMA_FILE_PATH f ON (afa.file_path_id=f.file_path_id)
			JOIN $TBMA_SLIDE_TYPE s ON (afa.array_type_id = s.slide_type_id)
			JOIN $TB_USER_LOGIN u ON (afa.user_id = u.user_login_id) 
			WHERE afa.record_status !='D'
			AND f.record_status!='D'
			AND s.record_status!='D'
			AND u.record_status!='D'  
            ~;
        }
    
    }

###############################################################################
    if ($table_name eq "MA_affy_array_sample") {
	
	if ($info_key eq "BASICQuery") {
            return qq~
    			SELECT afs.affy_array_sample_id,
			p.name                   AS "Project_Name", 
			afs.sample_tag,
			afs.full_sample_name, 
			afs.sample_group_name,
			organ.organization, 
			o.organism_name          AS "Organism",
			afs.strain_or_line, 
			afs.individual, 
			MOT2.name                AS "Sex",
			afs.age, 
			afs.organism_part        AS "Organism_Part", 
			afs.cell_line, 
			afs.cell_type, 
			afs.disease_state, 
			afs.rna_template_mass    AS "RNA_template_mass__ng",
			afs.affy_sample_protocol_ids,  
			afs.protocol_deviations, 
			afs.sample_description,
			afs.sample_preparation_date, 
			afs.treatment_description,
			afs.comment
			FROM $TBMA_AFFY_ARRAY_SAMPLE afs 
			JOIN $TB_ORGANISM o ON (afs.organism_id = o.organism_id)
			LEFT JOIN $TB_PROJECT p ON ( afs.project_id = p.project_id)
			LEFT JOIN $TB_MGED_ONTOLOGY_TERM MOT2 ON ( MOT2.MGED_ontology_term_id = afs.sex_ontology_term_id ) 
			LEFT JOIN $TB_ORGANIZATION organ ON (afs.sample_provider_organization_id = organ.organization_id)
			WHERE
			afs.record_status!='D'
			AND o.record_status!='D' 
			AND p.record_status != 'D'
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
