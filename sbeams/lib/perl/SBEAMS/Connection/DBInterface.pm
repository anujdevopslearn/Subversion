package SBEAMS::Connection::DBInterface;

###############################################################################
# Program     : SBEAMS::Connection::DBInterface
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Connection module which handles
#               general communication with the database.
#
###############################################################################


use strict;
use vars qw(@ERRORS $dbh $sth $q);
use CGI::Carp qw(fatalsToBrowser croak);
use DBI;
use Data::ShowTable;

use SBEAMS::Connection::DBConnector;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;

$q       = new CGI;


###############################################################################
# Global variables
###############################################################################
$dbh = SBEAMS::Connection::DBConnector::getDBHandle();


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
# apply Sql Change
#
# All INSERT, UPDATE, DELETE SQL commands initiated by the user should be
# delivered here first so that all permission checking and logging of the
# commands takes place.
###############################################################################
sub applySqlChange {
    my $self = shift || croak("parameter self not passed");
    my $sql_query = shift || croak("parameter sql_query not passed");
    my $current_contact_id = shift
       || croak("parameter current_contact_id not passed");
    my $table_name = shift || croak("parameter table_name not passed");
    my $record_identifier = shift
       || croak("parameter record_identifier not passed");

    # Privilege that a certain work_group has over a table_group
    my $table_group_privilege_id;
    # Privilege that a certain user has within a work_group
    my $user_work_group_privilege_id;
    # Privilege that a certain user has given himself within the user_context
    my $user_context_privilege_id;
    my $nrows = 0;

    my $current_privilege_id = 999;
    my $privilege_id;
    my @row;
    my $result = "CODE ERROR";
    my $returned_PK;
    @ERRORS = ();


    # Get the names of all the permission levels
    my %level_names = $self->SelectTwoColumnHash("
	SELECT privilege_id,name FROM $TB_PRIVILEGE");


    # Extract the first word, hopefully INSERT, UPDATE, or DELETE
    $sql_query =~ /\s*(\w*)/;
    my $sql_action = uc($1);


    # New method of checking table/group/user level permissions
    my $current_work_group_id = $self->getCurrent_work_group_id();
    my $current_work_group_name = $self->getCurrent_work_group_name();
    my $check_privilege_query = qq!
	SELECT UC.contact_id,UC.work_group_id,TGS.table_group,
		TGS.privilege_id,UWG.privilege_id,UC.privilege_id
	  FROM table_group_security TGS
	  LEFT JOIN user_context UC ON ( TGS.work_group_id=UC.work_group_id )
  	  LEFT JOIN table_property TP ON ( TGS.table_group=TP.table_group )
	  LEFT JOIN user_work_group UWG ON ( TGS.work_group_id=UWG.work_group_id
	       AND UC.contact_id=UWG.contact_id )
	 WHERE TGS.work_group_id='$current_work_group_id'
	   AND TP.table_name='$table_name'
	   AND UWG.contact_id='$current_contact_id'
    !;

    my $sth = $dbh->prepare("$check_privilege_query") or croak $dbh->errstr;
    my $rv  = $sth->execute or croak $dbh->errstr;
    #push(@ERRORS, "Returned Permissions:");
    $nrows = 0;
    while (@row = $sth->fetchrow_array) {
      #push(@ERRORS, "---> ".join(" | ",@row));
      $table_group_privilege_id = $row[3];
      $user_work_group_privilege_id = $row[4];
      $user_context_privilege_id = $row[5];
      $nrows++;
    }
    $sth->finish;


    # If no rows came back, the table/work_group relationship is not defined
    if ($nrows==0) {
      push(@ERRORS, "The privilege of your current work group
        ($current_work_group_name) is not defined for this table");
      $result = "DENIED";
    }


    # Don't know how to handle multiple rows yet
    if ($nrows>1) {
      push(@ERRORS, "Multiple permissions were found, and I don't know what
        to do.  Please contact <B>edeutsch</B> about this error");
      $result = "DENIED";
    }


    $privilege_id=99;
    if ($table_group_privilege_id > 0) {
      $privilege_id=$table_group_privilege_id;
    }

    if (defined($user_work_group_privilege_id) &&
        $user_work_group_privilege_id>$privilege_id) {
      $privilege_id=$user_work_group_privilege_id;
    }

    if (defined($user_context_privilege_id) &&
        $user_context_privilege_id>$privilege_id) {
      $privilege_id=$user_context_privilege_id;
    }

    my ($privilege_name) = $self->selectOneColumn("
	SELECT name FROM $TB_PRIVILEGE WHERE privilege_id='$privilege_id'");


    if ($privilege_id >= 40) {
      push(@ERRORS, "You do not have privilege to write to this table.");
      $result = "DENIED";
    }


    elsif ($sql_action eq "INSERT") {
      $sth = $dbh->prepare("$sql_query") or croak $dbh->errstr;
      $rv  = $sth->execute or croak $dbh->errstr;
      $result = "SUCCESSFUL";

      # Find out what the IDENTITY value for this INSERT was so it can
      # be reported back.
      # This is current MS SQL SERVER SPECIFIC.  A different command
      # would be required for a different database.
      my $check_auto_incr_value_query = qq!
        SELECT SCOPE_IDENTITY()
      !;

      my $sth = $dbh->prepare("$check_auto_incr_value_query")
        or croak $dbh->errstr;
      my $rv  = $sth->execute or croak $dbh->errstr;
      @row = $sth->fetchrow_array;
      ($returned_PK) = @row;
      $sth->finish;
    }


    elsif ( ($sql_action eq "UPDATE") or ($sql_action eq "DELETE") ) {

      # Get modified by, group_owner, status of record to be affected
      my $check_permission_query = qq!
        SELECT T.modified_by_id,T.owner_group_id,T.record_status
          FROM $table_name T
--          LEFT JOIN $TB_USER_CONTEXT UC ON (T.owner_group_id.UC.work_group_id)
         WHERE T.$record_identifier!;
      $sth = $dbh->prepare("$check_permission_query") or croak $dbh->errstr;
      $rv  = $sth->execute or croak $dbh->errstr;
      @row = $sth->fetchrow_array;
      my ($modified_by_id,$owner_group_id,$record_status) = @row;
      $sth->finish;


      my $permission="DENIED";
      $permission="ALLOWED" if ( ($record_status ne "L")
                             and ($privilege_id <= 20) );
      $permission="ALLOWED" if ( ($record_status eq "M")
                             and ($privilege_id <= 30) );
      $permission="ALLOWED" if ( ($record_status ne "L")
                             and ($privilege_id <= 25)
                             and ($owner_group_id == $current_work_group_id) );
      $permission="ALLOWED" if ( $modified_by_id==$current_contact_id );

      if ($permission eq "ALLOWED") {
        $sth = $dbh->prepare("$sql_query") or croak $dbh->errstr;
        $rv  = $sth->execute or croak $dbh->errstr;
        $result = "SUCCESSFUL";
      } else {
        push(@ERRORS, "You do not have permission to $sql_action this record.");
        push(@ERRORS, "Your privilege level is $privilege_name.");
        push(@ERRORS, "You are not the owner of this record.")
          if ($current_contact_id!=$modified_by_id);
        push(@ERRORS, "The group owner of this record ($owner_group_id) is not the same as your current working group ($current_work_group_id = [$current_work_group_name]).")
          if ($owner_group_id != $current_work_group_id);
        push(@ERRORS, "This record is Locked.")
          if ($record_status eq "L");
        $result = "DENIED";
      }

    }


    my $altered_sql_query = $sql_query;
    $altered_sql_query =~ s/'/"/g;
    my $log_query = qq!
        INSERT INTO $TB_SQL_COMMAND_LOG
               (created_by_id,result,sql_command)
        VALUES ($current_contact_id,'$result','$altered_sql_query')
    !;

    my $sth = $dbh->prepare("$log_query") or croak $dbh->errstr;
    my $rv  = $sth->execute or croak $dbh->errstr;
    $sth->finish;


    return ($result,$returned_PK,@ERRORS);
}


###############################################################################
# SelectOneColumn
#
# Given a SQL statement which returns exactly one column, return an array
# containing the results of that query.
###############################################################################
sub selectOneColumn {
    my $self = shift || croak("parameter self not passed");
    my $sql_query = shift || croak("parameter sql_query not passed");

    my @columns;

    my $sth = $dbh->prepare("$sql_query") or croak $dbh->errstr;
    my $rv  = $sth->execute or croak $dbh->errstr;

    while (my @row = $sth->fetchrow_array) {
        push(@columns,$row[0]);
    }

    $sth->finish;

    return @columns;

}


###############################################################################
# SelectTwoColumnHash
#
# Given a SQL statement which returns exactly two columns, return a hash
# containing the results of that query.
###############################################################################
sub SelectTwoColumnHash {
    my $self = shift || croak("parameter self not passed");
    my $sql_query = shift || croak("parameter sql_query not passed");

    my %hash;

    my $sth = $dbh->prepare("$sql_query") or croak $dbh->errstr;
    my $rv  = $sth->execute or croak $dbh->errstr;

    while (my @row = $sth->fetchrow_array) {
        $hash{$row[0]} = $row[1];
    }

    $sth->finish;

    return %hash;

}


###############################################################################
# executeSQL
#
# Execute the supplied SQL statement with no return value.
###############################################################################
sub executeSQL {
    my $self = shift || croak("parameter self not passed");
    my $sql_query = shift || croak("parameter sql_query not passed");

    my $sth = $dbh->prepare("$sql_query") or croak $dbh->errstr;
    my $rv  = $sth->execute or croak $dbh->errstr;

    $sth->finish;

    return 0;

}



###############################################################################
# getLastInsertedPK
#
# Execute the supplied SQL statement with no return value.
###############################################################################
sub getLastInsertedPK {
    my $self = shift || croak("parameter self not passed");

    my $sql_query = "SELECT SCOPE_IDENTITY()";
    my ($returned_PK) = $self->selectOneColumn($sql_query);
    return $returned_PK;

}



###############################################################################
# build Option List
#
# Given an SQL query which returns exactly two columns (option value and
# option description), an HTML <OPTION> list is returned.  If a second
# parameter is supplied, the option VALUE which matches will be SELECTED.
###############################################################################
sub buildOptionList {
    my $self = shift;
    my $sql_query = shift;
    my $selected_option = shift;
    my $selected_flag;

    my %selected_options;
    my @tmp = split(",",$selected_option);
    my $element;
    foreach $element (@tmp) {
      $selected_options{$element}=1;
    }

    my $options="";
    my $sth = $dbh->prepare("$sql_query") or croak $dbh->errstr;
    my $rv  = $sth->execute or croak $dbh->errstr;

    while (my @row = $sth->fetchrow_array) {
        $selected_flag="";
        $selected_flag=" SELECTED"
          if ($selected_options{$row[0]});
        $options .= qq!<OPTION$selected_flag VALUE="$row[0]">$row[1]\n!;
    } # end while

    $sth->finish;

    return $options;

}


###############################################################################
# Get Record Status Options
#
# Returns the record status option list.
###############################################################################
sub getRecordStatusOptions {
    my $self = shift;
    my $selected_option = shift;

    $selected_option = "N" unless $selected_option gt "";

    my $sql_query = qq!
        SELECT record_status_id, name
          FROM $TB_RECORD_STATUS
         ORDER BY sort_order!;

    return $self->buildOptionList($sql_query,$selected_option);

} # end getRecordStatusOptions


###############################################################################
# DisplayQueryResult
#
# Executes a query and displays the results as an HTML table
###############################################################################
sub displayQueryResult {
    my $self = shift;
    my $sql_query = shift or croak "parameter \$sql_query not passed";
    my $url_cols_ref = shift;
    my $flag = shift;
    my $hidden_cols_ref = shift;

    $sth = $dbh->prepare("$sql_query") or croak $dbh->errstr;
    my $rv  = $sth->execute or croak $dbh->errstr;

    #print $sth->{NUM_OF_FIELDS},"<BR>\n";
    #print join ("|",@{ $sth->{TYPE} }),"<BR>\n";
    my @TDformats=('BGCOLOR=#E0E0E0 NOWRAP');

    if ( $flag eq "printable") {

      ShowHTMLTable { titles=>$sth->{NAME},
	types=>$sth->{TYPE},
	widths=>$sth->{PRECISION},
	row_sub=>\&fetchNextRow,
        table_attrs=>'WIDTH=675 BORDER=1 CELLPADDING=2 CELLSPACING=2',
        tformats=>['BOLD'],
        url_keys=>$url_cols_ref,
        hidden_cols=>$hidden_cols_ref,
        THformats=>['BGCOLOR=#C0C0C0'],
        TDformats=>['NOWRAP']
	};

    } else {

      ShowHTMLTable { titles=>$sth->{NAME},
	types=>$sth->{TYPE},
	widths=>$sth->{PRECISION},
	row_sub=>\&fetchNextRow,
        table_attrs=>'BORDER=0 CELLPADDING=2 CELLSPACING=2',
        tformats=>['FONT COLOR=red,BOLD'],
        url_keys=>$url_cols_ref,
        hidden_cols=>$hidden_cols_ref,
        THformats=>['BGCOLOR=#C0C0C0'],
        TDformats=>\@TDformats
	};
    }

    print "\n";

    $sth->finish;

    return 1;

} # end displayQueryResult


###############################################################################
# fetchNextRow called by ShowHTMLTable
###############################################################################
sub fetchNextRow {
    my $flag = shift @_;
    if ($flag) {return $sth->execute;}  # do a "rewind"
    return $sth->fetchrow_array;
}


###############################################################################
# processTableDisplayControls
#
# Displays and processes a set of crude table display controls
###############################################################################
sub processTableDisplayControls {
    my $self = shift;
    my $TABLE_NAME = shift;

    my $detail_level  = $q->param('detail_level') || "BASIC";
    my $where_clause  = $q->param('where_clause');
    my $orderby_clause  = $q->param('orderby_clause');

    if ( $where_clause =~ /delete|insert|update/i ) {
      croak "Syntax error in WHERE clause"; }
    if ( $orderby_clause =~ /delete|insert|update/i ) {
      croak "Syntax error in ORDER BY clause"; }

    my $full_orderby_clause;
    my $full_where_clause;
    $full_where_clause = "AND $where_clause" if ($where_clause);
    $full_orderby_clause = "ORDER BY $orderby_clause" if ($orderby_clause);

    # If a user typed ", he probably meant ' instead, so replace since "
    # will fail.  This is a bit rude, because what if the user really meant "
    # then he should use [ and ]
    $full_where_clause =~ s/"/'/g;
    $full_orderby_clause =~ s/"/'/g;

    # If a user typed ", we need to escape them for the form printing
    $where_clause =~ s/"/&#34;/g;
    $orderby_clause =~ s/"/&#34;/g;


    my $basic_flag = "";
    my $full_flag = "";
    $basic_flag = " SELECTED" if ($detail_level eq "BASIC");
    $full_flag = " SELECTED" if ($detail_level eq "FULL");

    print qq!
        <BR><HR SIZE=5 NOSHADE><BR>
        <FORM METHOD="post">
            <SELECT NAME="detail_level">
              <OPTION$basic_flag VALUE="BASIC">BASIC
              <OPTION$full_flag VALUE="FULL">FULL
            </SELECT>
        <B>WHERE</B><INPUT TYPE="text" NAME="where_clause"
                     VALUE="$where_clause" SIZE=25>
        <B>ORDER BY</B><INPUT TYPE="text" NAME="orderby_clause"
                     VALUE="$orderby_clause" SIZE=25>
        <INPUT TYPE="hidden" NAME="TABLE_NAME" VALUE="$TABLE_NAME">
        <INPUT TYPE="submit" NAME="redisplay" VALUE="DISPLAY"><P>
    !;


    return ($full_where_clause,$full_orderby_clause);

} # end processTableDisplayControls






###############################################################################

1;

__END__
###############################################################################
###############################################################################
###############################################################################

=head1 NAME

SBEAMS::Connection::DBControl - Perl extension for providing common database methods

=head1 SYNOPSIS

  Used as part of this system

    use SBEAMS::Connection;
    $adb = new SBEAMS::Connection;

    $dbh = $adb->getDBHandle();   

    This needs to change!

=head1 DESCRIPTION

    This module is inherited by the SBEAMS::Connection module, 
    although it can be used on its own. Its main function
    is to provide a single set of database methods to be used 
    by all programs included in this application.

=head1 METHODS

=item B<applySqlChange()>

=head1 AUTHOR

Eric Deutsch <edeutsch@systemsbiology.org>

=head1 SEE ALSO

perl(1).

=cut
