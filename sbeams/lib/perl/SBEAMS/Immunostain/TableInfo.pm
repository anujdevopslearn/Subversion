package SBEAMS::Immunostain::TableInfo;

###############################################################################
# Program     : SBEAMS::Immunostain::TableInfo
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Immunostain module which returns
#               information about various tables.
#
###############################################################################

use strict;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Immunostain::Settings;
use SBEAMS::Immunostain::Tables;
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


    if ($table_name eq "IS_stained_slide") {
        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT stained_slide_id,project_tag,tissue_type_name,
                       specimen_block_name,antibody_name,stain_name,
                       stain_description
		  FROM $TBIS_STAINED_SLIDE SS
		  LEFT JOIN $TB_PROJECT P ON ( SS.project_id = P.project_id )
		  LEFT JOIN $TBIS_SPECIMEN_BLOCK SB
		       ON ( SS.specimen_block_id = SB.specimen_block_id )
		  LEFT JOIN $TBIS_SPECIMEN S
		       ON ( SB.specimen_id = S.specimen_id )
		  LEFT JOIN $TBIS_TISSUE_TYPE TT
		       ON ( S.tissue_type_id = TT.tissue_type_id )
		  LEFT JOIN $TBIS_ANTIBODY A
		       ON ( SS.antibody_id = A.antibody_id )
		 WHERE SS.record_status!='D'
		 ORDER BY project_tag,tissue_type_name,specimen_block_name,
                       A.sort_order,A.antibody_name,SS.stain_name
            ~;
        }

    }


    if ($table_name eq "IS_slide_image") {
        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT slide_image_id,project_tag,
                       specimen_block_name,antibody_name,stain_name,image_name,
                       image_magnification,raw_image_file,processed_image_file,
                       annotated_image_file
		  FROM $TBIS_SLIDE_IMAGE SI
		  LEFT JOIN $TBIS_STAINED_SLIDE SS
                       ON ( SI.stained_slide_id = SS.stained_slide_id )
		  LEFT JOIN $TB_PROJECT P ON ( SS.project_id = P.project_id )
		  LEFT JOIN $TBIS_SPECIMEN_BLOCK SB
		       ON ( SS.specimen_block_id = SB.specimen_block_id )
		  LEFT JOIN $TBIS_SPECIMEN S
		       ON ( SB.specimen_id = S.specimen_id )
		  LEFT JOIN $TBIS_TISSUE_TYPE TT
		       ON ( S.tissue_type_id = TT.tissue_type_id )
		  LEFT JOIN $TBIS_ANTIBODY A
		       ON ( SS.antibody_id = A.antibody_id )
		 WHERE SS.record_status!='D'
		 ORDER BY project_tag,tissue_type_name,specimen_block_name,
                       A.sort_order,A.antibody_name,SS.stain_name,
                       SI.image_magnification,SI.image_name
            ~;
        }

    }


    if ($table_name eq "IS_antibody") {
        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT antibody_id,antibody_name,antibody_description,comment, sort_order
		  FROM $TBIS_ANTIBODY A
		 WHERE A.record_status!='D'
		 ORDER BY sort_order,antibody_name
            ~;
        }

    }



    if ($table_name eq "IS_stain_cell_presence") {
        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT SCP.stain_cell_presence_id,stain_name,cell_type_name,
                       level_name,SCP.at_level_percent,SCP.comment
                  FROM $TBIS_STAIN_CELL_PRESENCE SCP
		  LEFT JOIN $TBIS_STAINED_SLIDE SS
                       ON ( SCP.stained_slide_id = SS.stained_slide_id )
		  LEFT JOIN $TBIS_CELL_TYPE CT
		       ON ( SCP.cell_type_id = CT.cell_type_id )
		  LEFT JOIN $TBIS_CELL_PRESENCE_LEVEL CPL
		       ON ( SCP.cell_presence_level_id = CPL.cell_presence_level_id )
		 WHERE SCP.record_status!='D'
		 ORDER BY stain_name,cell_type_name,CPL.sort_order,level_name
            ~;
        }

    }









###############################################################################

    #### Obtain main SBEAMS object and fall back to its TableInfo handler
    my $sbeams = $self->getSBEAMS();
    my @temp_result = $sbeams->returnTableInfo($table_name,$info_key);
    return @temp_result;

}

1;

__END__
###############################################################################
###############################################################################
###############################################################################
