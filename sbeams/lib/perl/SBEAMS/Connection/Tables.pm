package SBEAMS::Connection::Tables;

###############################################################################
# Program     : SBEAMS::Connection::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Connection module which provides
#               a level of abstraction to the database tables.
#
# SBEAMS is Copyright (C) 2000-2002 by Eric Deutsch
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################

use strict;

use SBEAMS::Connection::Settings;


use vars qw(@ISA @EXPORT 
    $TB_USER_LOGIN
    $TB_WORK_GROUP
    $TB_USER_WORK_GROUP
    $TB_USER_CONTEXT
    $TB_RECORD_STATUS
    $TB_PRIVILEGE
    $TB_CONTACT_TYPE
    $TB_CONTACT
    $TB_ORGANIZATION_TYPE
    $TB_ORGANIZATION
    $TB_PROJECT
    $TB_USER_PROJECT_PERMISSION
    $TB_GROUP_PROJECT_PERMISSION
    $TB_DBXREF

    $TB_TABLE_COLUMN
    $TB_TABLE_PROPERTY
    $TB_TABLE_GROUP_SECURITY
    $TB_SQL_COMMAND_LOG
    $TB_USAGE_LOG
    $TB_HELP_TEXT
    $TB_MISC_OPTION
    $TB_CACHED_RESULTSET

);

require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_USER_LOGIN
    $TB_WORK_GROUP
    $TB_USER_WORK_GROUP
    $TB_USER_CONTEXT
    $TB_RECORD_STATUS
    $TB_PRIVILEGE
    $TB_CONTACT_TYPE
    $TB_CONTACT
    $TB_ORGANIZATION_TYPE
    $TB_ORGANIZATION
    $TB_PROJECT
    $TB_USER_PROJECT_PERMISSION
    $TB_GROUP_PROJECT_PERMISSION
    $TB_DBXREF

    $TB_TABLE_COLUMN
    $TB_TABLE_PROPERTY
    $TB_TABLE_GROUP_SECURITY
    $TB_SQL_COMMAND_LOG
    $TB_USAGE_LOG
    $TB_HELP_TEXT
    $TB_MISC_OPTION
    $TB_CACHED_RESULTSET

);


$TB_USER_LOGIN          = 'user_login';
$TB_WORK_GROUP          = 'work_group';
$TB_USER_WORK_GROUP     = 'user_work_group';
$TB_USER_CONTEXT        = 'user_context';
$TB_RECORD_STATUS       = 'record_status';
$TB_PRIVILEGE           = 'privilege';
$TB_CONTACT_TYPE        = 'contact_type';
$TB_CONTACT             = 'contact';
$TB_ORGANIZATION_TYPE   = 'organization_type';
$TB_ORGANIZATION        = 'organization';
$TB_PROJECT             = 'project';
$TB_USER_PROJECT_PERMISSION     = 'user_project_permission';
$TB_GROUP_PROJECT_PERMISSION    = 'group_project_permission';

$TB_DBXREF              = $DBPREFIX{Proteomics}.'dbxref';


$TB_TABLE_COLUMN        = 'table_column';
$TB_TABLE_PROPERTY      = 'table_property';
$TB_TABLE_GROUP_SECURITY= 'table_group_security';
$TB_SQL_COMMAND_LOG     = 'sql_command_log';
$TB_USAGE_LOG           = 'usage_log';
$TB_HELP_TEXT           = 'help_text';
$TB_MISC_OPTION         = 'misc_option';
$TB_CACHED_RESULTSET    = 'cached_resultset';


###############################################################################

1;

__END__

###############################################################################
###############################################################################
###############################################################################

=head1 SBEAMS::Connection::Tables

SBEAMS Core table definitions

=head2 SYNOPSIS

See SBEAMS::Connection for usage synopsis.

=head2 DESCRIPTION

This pm defines the physical table names for the abstract table variables.


=head2 METHODS

=over

=item * none



=back

=head2 BUGS

Please send bug reports to the author

=head2 AUTHOR

Eric Deutsch <edeutsch@systemsbiology.org>

=head2 SEE ALSO

SBEAMS::Connection

=cut

