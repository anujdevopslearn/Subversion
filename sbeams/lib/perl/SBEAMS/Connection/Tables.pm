package SBEAMS::Connection::Tables;

###############################################################################
# Program     : SBEAMS::Connection::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Connection module which provides
#               a level of abstraction to the database tables.
#
###############################################################################


use strict;
use vars qw(@ISA @EXPORT 
    $TB_USER_LOGIN
    $TB_WORK_GROUP
    $TB_USER_WORK_GROUP
    $TB_USER_CONTEXT
    $TB_RECORD_STATUS
    $TB_PRIVILEGE
    $TB_CONTACT
    $TB_CONTACT_TYPE
    $TB_ORGANIZATION
    $TB_PROJECT
    $TB_DBXREF

    $TB_TABLE_COLUMN
    $TB_TABLE_PROPERTY
    $TB_TABLE_GROUP_SECURITY
    $TB_SQL_COMMAND_LOG
    $TB_USAGE_LOG
    $TB_HELP_TEXT

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
    $TB_CONTACT
    $TB_CONTACT_TYPE
    $TB_ORGANIZATION
    $TB_PROJECT
    $TB_DBXREF

    $TB_TABLE_COLUMN
    $TB_TABLE_PROPERTY
    $TB_TABLE_GROUP_SECURITY
    $TB_SQL_COMMAND_LOG
    $TB_USAGE_LOG
    $TB_HELP_TEXT

);


$TB_USER_LOGIN          = 'user_login';
$TB_WORK_GROUP          = 'work_group';
$TB_USER_WORK_GROUP     = 'user_work_group';
$TB_USER_CONTEXT        = 'user_context';
$TB_RECORD_STATUS       = 'record_status';
$TB_PRIVILEGE           = 'privilege';
$TB_CONTACT             = 'contact';
$TB_CONTACT_TYPE        = 'contact_type';
$TB_ORGANIZATION        = 'organization';
$TB_PROJECT             = 'project';

$TB_DBXREF              = 'proteomics.dbo.dbxref';


$TB_TABLE_COLUMN        = 'table_column';
$TB_TABLE_PROPERTY      = 'table_property';
$TB_TABLE_GROUP_SECURITY= 'table_group_security';
$TB_SQL_COMMAND_LOG     = 'sql_command_log';
$TB_USAGE_LOG           = 'usage_log';
$TB_HELP_TEXT           = 'help_text';


