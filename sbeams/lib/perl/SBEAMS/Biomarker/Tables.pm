package SBEAMS::Biomarker::Tables;

###############################################################################
# Program     : SBEAMS::Biomarker::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Biomarker module which provides
#               a level of abstraction to the database tables.
#
###############################################################################


use strict;

use SBEAMS::Connection::Settings;


use vars qw(@ISA @EXPORT 
            $TB_ORGANISM
            $TB_ORGANIZATION
            $TB_PROTOCOL
            $TB_PROTOCOL_TYPE

            $TBBL_BIOSEQUENCE_SET
            $TBBL_DBXREF
            $TBBL_BIOSEQUENCE
            $TBBL_BIOSEQUENCE_PROPERTY_SET
            $TBBL_QUERY_OPTION

            $TBBM_TISSUE_TYPE
    
            $TBBM_GRADIENT_PROGRAM
            $TBBM_INSTRUMENT

            $TBBM_ATTRIBUTE
            $TBBM_ATTRIBUTE_TYPE
            $TBBM_BIO_GROUP
            $TBBM_BIOSAMPLE
            $TBBM_BIOSAMPLE_ATTRIBUTE
            $TBBM_BIOSAMPLE_TYPE
            $TBBM_BIOSOURCE
            $TBBM_BIOSOURCE_ATTRIBUTE
            $TBBM_BIOSOURCE_DISEASE
            $TBBM_DISEASE
            $TBBM_DISEASE_TYPE
            $TBBM_DATA_ANALYSIS
            $TBBM_ANALYSIS_FILE
            $TBBM_EXPERIMENT
            $TBBM_EXPERIMENT_TYPE
            $TBBM_MS_RUN
            $TBBM_MS_RUN_SAMPLE
            $TBBM_STORAGE_LOCATION
            $TBBM_TREATMENT
            $TBBM_TREATMENT_TYPE
);


require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw ( $TBBL_BIOSEQUENCE_SET
               $TBBL_DBXREF
               $TBBL_BIOSEQUENCE
               $TBBL_BIOSEQUENCE_PROPERTY_SET
               $TBBL_QUERY_OPTION

               $TBBM_TISSUE_TYPE
               $TB_ORGANISM
               $TB_ORGANIZATION
    
               $TB_PROTOCOL
               $TB_PROTOCOL_TYPE
               $TBBM_INSTRUMENT
               $TBBM_GRADIENT_PROGRAM

               $TBBM_ATTRIBUTE
               $TBBM_ATTRIBUTE_TYPE
               $TBBM_BIO_GROUP
               $TBBM_BIOSAMPLE
               $TBBM_BIOSAMPLE_ATTRIBUTE
               $TBBM_BIOSAMPLE_TYPE
               $TBBM_BIOSOURCE
               $TBBM_BIOSOURCE_ATTRIBUTE
               $TBBM_BIOSOURCE_DISEASE
               $TBBM_DISEASE
               $TBBM_DISEASE_TYPE
               $TBBM_DATA_ANALYSIS
               $TBBM_ANALYSIS_FILE
               $TBBM_EXPERIMENT
               $TBBM_EXPERIMENT_TYPE
               $TBBM_MS_RUN
               $TBBM_MS_RUN_SAMPLE
               $TBBM_STORAGE_LOCATION
               $TBBM_TREATMENT
               $TBBM_TREATMENT_TYPE
             );


#### Get the appropriate database prefixes for the SBEAMS core and this module
my $core = $DBPREFIX{Core};
my $prot = $DBPREFIX{Proteomics};
my $glyco = $DBPREFIX{GlycoPeptide} || 'GlycoPeptideModuleNotDefinedInSBEAMS.conf';
my $bl   = $DBPREFIX{BioLink};
my $mod  = $DBPREFIX{Biomarker} || 'BiomarkerModuleNotDefinedInSBEAMS.conf';

$TB_ORGANISM                    = "${core}organism";
$TB_ORGANIZATION                = "${core}organization";
$TB_PROTOCOL                    = "${core}protocol";
$TB_PROTOCOL_TYPE               = "${core}protocol_type";

# Chose to specify external db tables as TBBM
$TBBM_TISSUE_TYPE               = "${glyco}tissue_type";

$TBBM_INSTRUMENT                = "${prot}instrument";
$TBBM_GRADIENT_PROGRAM          = "${prot}gradient_program";

$TBBL_BIOSEQUENCE_SET           = "${bl}biosequence_set";
$TBBL_DBXREF                    = "${bl}dbxref";
$TBBL_BIOSEQUENCE               = "${bl}biosequence";
$TBBL_BIOSEQUENCE_PROPERTY_SET  = "${bl}biosequence_property_set";
$TBBL_QUERY_OPTION              = "${bl}query_option";

$TBBM_BIO_GROUP           = "${mod}BMRK_bio_group";
$TBBM_BIOSOURCE           = "${mod}BMRK_biosource";
$TBBM_BIOSAMPLE           = "${mod}BMRK_biosample";
$TBBM_DISEASE             = "${mod}BMRK_disease";
$TBBM_DISEASE_TYPE        = "${mod}BMRK_disease_type";
$TBBM_ATTRIBUTE_TYPE      = "${mod}BMRK_attribute_type";
$TBBM_ATTRIBUTE           = "${mod}BMRK_attribute";
$TBBM_BIOSOURCE_ATTRIBUTE = "${mod}BMRK_biosource_attribute";
$TBBM_BIOSAMPLE_ATTRIBUTE = "${mod}BMRK_biosample_attribute";
$TBBM_BIOSAMPLE_TYPE      = "${mod}BMRK_biosample_type";
$TBBM_BIOSOURCE_DISEASE   = "${mod}BMRK_biosource_disease";
$TBBM_STORAGE_LOCATION    = "${mod}BMRK_storage_location";
$TBBM_ANALYSIS_FILE       = "${mod}BMRK_analysis_file";
$TBBM_DATA_ANALYSIS       = "${mod}BMRK_data_analysis";
$TBBM_EXPERIMENT          = "${mod}BMRK_experiment";
$TBBM_EXPERIMENT_TYPE     = "${mod}BMRK_experiment_type";
$TBBM_MS_RUN              = "${mod}BMRK_ms_run";
$TBBM_MS_RUN_SAMPLE       = "${mod}BMRK_ms_run_sample";
$TBBM_TREATMENT           = "${mod}BMRK_treatment";
$TBBM_TREATMENT_TYPE      = "${mod}BMRK_treatment_type";


1;
