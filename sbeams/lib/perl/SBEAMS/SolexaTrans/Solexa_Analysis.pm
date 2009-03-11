###############################################################################
# Program     : SBEAMS::SolexaTrans::Solexa_Analysis
# Author      : Denise Mauldin <dmauldin@systemsbiology.org>
# $Id: Solexa_Analysis.pm 5560 2008-01-10 01:09:11Z dcampbel $
#
# Description :  Module which implements various methods for the analysis of
# Solexa array files.
# 
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
#
###############################################################################



{package SBEAMS::SolexaTrans::Solexa_Analysis;
	
our $VERSION = '1.00';

####################################################
=head1 NAME

SBEAMS::SolexaTrans::Solexa_Analysis - Methods to analize a group of solexa files
SBEAMS::Solexa

=head1 SYNOPSIS

 use SBEAMS::Connection::Tables;
 use SBEAMS::SolexaTrans::Tables;
 
 use SBEAMS::SolexaTrans::Solexa;
 use SBEAMS::SolexaTrans::Solexa_file_groups;

 my $sbeams_solexa_groups = new SBEAMS::SolexaTrans::Solexa_file_groups;

$sbeams_solexa_groups->setSBEAMS($sbeams);		#set the sbeams object into the sbeams_solexa_groups


=head1 DESCRIPTION


=head2 EXPORT

None by default.



=head1 SEE ALSO

SBEAMS::SolexaTrans::Solexa;
lib/scripts/Solexa/load_solexa_files.pl

=head1 AUTHOR

Denise Mauldin <lt>dmauldin@systemsbiology.org<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 by Denise Mauldin

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.3 or,
at your option, any later version of Perl 5 you may have available.


=cut
##############################################################
use strict;
use vars qw($sbeams);		

use File::Basename;
use File::Find;
use File::Path;
use Data::Dumper;
use Carp;
use FindBin;

use SBEAMS::Connection qw($log);

use base qw(SBEAMS::SolexaTrans::Solexa);		
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::Settings qw( $PHYSICAL_BASE_DIR );
use SBEAMS::SolexaTrans::Tables;
use SBEAMS::SolexaTrans::Analysis_Data;
use SBEAMS::SolexaTrans::Settings qw( $SOLEXA_TMP_DIR );

my $R_program = SBEAMS::SolexaTrans::Settings->get_local_R_exe_path( 'obj_placeholder' );
my $R_library = SBEAMS::SolexaTrans::Settings->get_local_R_lib_path( 'obj_placeholder' );

#our $PHYSICAL_BASE_DIR;

###############################################################################
# Receive the main SBEAMS object
###############################################################################
sub setSBEAMS {
    my $self = shift;
    $sbeams = shift;
    return($sbeams);
}


###############################################################################
# Provide the main SBEAMS object
###############################################################################
sub getSBEAMS {
    my $self = shift;
    return($sbeams);
}



	
}#closing bracket for the package

1;
