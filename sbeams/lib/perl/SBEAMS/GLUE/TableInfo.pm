package SBEAMS::GLUE::TableInfo;

###############################################################################
# Program     : SBEAMS::GLUE::TableInfo
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::GLUE module which returns
#               information about various tables.
#
###############################################################################

use strict;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::GLUE::Settings;
use SBEAMS::GLUE::Tables;
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



    if ($table_name eq "GL_interaction") {

        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT I.interaction_id,
			BE1.bioentity_name,BES1.bioentity_state_name,RF1.regulatory_feature_name,
			IT.interaction_type_name,
			BE2.bioentity_name,BES2.bioentity_state_name,RF2.regulatory_feature_name
		  FROM $TBGL_INTERACTION I
		  LEFT JOIN $TBGL_INTERACTION_TYPE IT ON ( I.interaction_type_id = IT.interaction_type_id )
		  LEFT JOIN $TBGL_BIOENTITY BE1 ON ( I.bioentity1_id = BE1.bioentity_id )
		  LEFT JOIN $TBGL_BIOENTITY BE2 ON ( I.bioentity2_id = BE2.bioentity_id )
		  LEFT JOIN $TBGL_BIOENTITY_STATE BES1 ON ( I.bioentity1_state_id = BES1.bioentity_state_id )
		  LEFT JOIN $TBGL_BIOENTITY_STATE BES2 ON ( I.bioentity2_state_id = BES2.bioentity_state_id )
		  LEFT JOIN $TBGL_REGULATORY_FEATURE RF1 ON ( I.regulatory_feature1_id = RF1.regulatory_feature_id )
		  LEFT JOIN $TBGL_REGULATORY_FEATURE RF2 ON ( I.regulatory_feature2_id = RF1.regulatory_feature_id )
		 WHERE I.record_status != 'D'
		   AND ( BE1.record_status != 'D' OR BE1.record_status IS NULL )
		   AND ( BE2.record_status != 'D' OR BE2.record_status IS NULL )
		   AND ( BES1.record_status != 'D' OR BES1.record_status IS NULL )
		   AND ( BES2.record_status != 'D' OR BES2.record_status IS NULL )
		   AND ( RF1.record_status != 'D' OR RF1.record_status IS NULL )
		   AND ( RF2.record_status != 'D' OR RF2.record_status IS NULL )
            ~;
        }

        if ($info_key eq "FULLQuery") {
            return qq~
		SELECT I.*
		  FROM $TBGL_INTERACTION I
		 --WHERE I.record_status!='D'
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
