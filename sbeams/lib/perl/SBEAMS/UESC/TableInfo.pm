package SBEAMS::UESC::TableInfo;

###############################################################################
# Program     : SBEAMS::UESC::TableInfo
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::UESC module which returns
#               information about various tables.
#
###############################################################################

use strict;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::UESC::Settings;
use SBEAMS::UESC::Tables;
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



    if ($table_name eq "UESC_stain") {
        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT stain_id,tissue_type_name,antibody_name,stain_name,
                       annotated_image_file,raw_image_file,image_file_date,
                       stain_description
		  FROM $TBUESC_STAIN S
		  LEFT JOIN $TBUESC_TISSUE_TYPE TT
		       ON ( S.tissue_type_id = TT.tissue_type_id )
		  LEFT JOIN $TBUESC_ANTIBODY A
		       ON ( S.antibody_id = A.antibody_id )
		 WHERE S.record_status!='D'
		 ORDER BY A.sort_order,A.antibody_name,S.stain_name
            ~;
        }

    }


    if ($table_name eq "UESC_antibody") {
        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT antibody_id,antibody_name,antibody_description,comment, sort_order
		  FROM $TBUESC_ANTIBODY A
		 WHERE A.record_status!='D'
		 ORDER BY sort_order,antibody_name
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
