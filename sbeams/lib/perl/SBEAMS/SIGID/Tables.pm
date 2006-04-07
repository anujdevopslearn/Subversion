package SBEAMS::SIGID::Tables;

###############################################################################
# Program     : SBEAMS::SIGID::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::SIGID module which provides
#               a level of abstraction to the database tables.
#
###############################################################################


use strict;

use SBEAMS::Connection::Settings;


use vars qw(@ISA @EXPORT 
    $TB_ORGANISM

    $TBSI_BIOSEQUENCE_SET
    $TBSI_DBXREF
    $TBSI_BIOSEQUENCE
    $TBSI_BIOSEQUENCE_PROPERTY_SET

    $TBSI_PATIENT
    $TBSI_PATIENT_TYPE
    $TBSI_BLOOD_CULTURE
    $TBSI_CEREBROSPINAL_FLUID_CULTURE
    $TBSI_DISEASE_SPECIFICATION
    $TBSI_ANTIBIOTIC_TREATMENT
    $TBSI_PATIENT_GENETIC_HISTORY
    $TBSI_PATIENT_HOSPITAL_HISTORY
    $TBSI_PATIENT_HISTORY
    $TBSI_ETHNICITY
    $TBSI_BIRTH_COUNTRY
    $TBSI_GLASGOW_SCORE


    $TBSI_QUERY_OPTION

);


require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_ORGANISM

    $TBSI_BIOSEQUENCE_SET
    $TBSI_DBXREF
    $TBSI_BIOSEQUENCE
    $TBSI_BIOSEQUENCE_PROPERTY_SET
    $TBSI_QUERY_OPTION

);


#### Get the appropriate database prefixes for the SBEAMS core and this module
my $core = $DBPREFIX{Core};
my $mod = $DBPREFIX{SIGID};

$TB_ORGANISM                      = "${core}organism";

$TBSI_BIOSEQUENCE_SET       = "${mod}biosequence_set";
$TBSI_DBXREF                = "${mod}dbxref";
$TBSI_BIOSEQUENCE           = "${mod}biosequence";
$TBSI_BIOSEQUENCE_PROPERTY_SET   = "${mod}biosequence_property_set";
$TBSI_QUERY_OPTION          = "${mod}query_option";

$TBSI_PATIENT                     = "${mod}patient";
$TBSI_PATIENT_TYPE                ="${mod}patient_type";
$TBSI_BLOOD_CULTURE               ="${mod}blood_culture";
$TBSI_CEREBROSPINAL_FLUID_CULTURE ="${mod}cerebrospinal_fluid_culture";
$TBSI_DISEASE_SPECIFICATION       ="${mod}disease_specification";
$TBSI_ANTIBIOTIC_TREATMENT        ="${mod}antibiotic_treatment";
$TBSI_PATIENT_GENETIC_HISTORY     ="${mod}patient_genetic_history";
$TBSI_PATIENT_HOSPITAL_HISTORY    ="${mod}patient_hospital_history";
$TBSI_PATIENT_HISTORY             ="${mod}patient_history";
$TBSI_ETHNICITY                   ="${mod}ethnicity";
$TBSI_BIRTH_COUNTRY               ="${mod}birth_country";
$TBSI_GLASGOW_SCORE               ="${mod}glasgow_score";



