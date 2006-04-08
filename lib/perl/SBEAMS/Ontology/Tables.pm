package SBEAMS::Ontology::Tables;

###############################################################################
# Program     : SBEAMS::Ontology::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Ontology module which provides
#               a level of abstraction to the database tables.
#
###############################################################################


use strict;

use SBEAMS::Connection::Settings;


use vars qw(@ISA @EXPORT 
    $TBON_ONTOLOGY
    $TBON_ONTOLOGY_TERM
    $TBON_ONTOLOGY_TERM_RELATIONSHIP
    $TBON_QUERY_OPTION

);


require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TBON_ONTOLOGY
    $TBON_ONTOLOGY_TERM
    $TBON_ONTOLOGY_TERM_RELATIONSHIP
    $TBON_QUERY_OPTION

);


#### Get the appropriate database prefixes for the SBEAMS core and this module
my $core = $DBPREFIX{Core};
my $mod = $DBPREFIX{Ontology};

$TBON_ONTOLOGY                     = "${mod}ontology";
$TBON_ONTOLOGY_TERM                = "${mod}ontology_term";
$TBON_ONTOLOGY_TERM_RELATIONSHIP   = "${mod}ontology_term_relationship";
$TBON_QUERY_OPTION                 = "${mod}query_option";



