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
use vars qw(@ERRORS $dbh $sth $q $resultset_ref);
use CGI::Carp qw(fatalsToBrowser croak);
use DBI;
use POSIX;
use Data::Dumper;


#use lib "/net/db/src/CPAN/Data-ShowTable-3.3a";
#use Data::ShowTableEWD;
use Data::ShowTable;

use SBEAMS::Connection::Settings;
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
    my %level_names = $self->selectTwoColumnHash("
	SELECT privilege_id,name FROM $TB_PRIVILEGE");

    my ($DB_TABLE_NAME) = $self->returnTableInfo($table_name,"DB_TABLE_NAME");
    #print "DB_TABLE_NAME = $DB_TABLE_NAME<BR>\n";
    #print "table_name = $table_name<BR>\n";


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
          FROM $DB_TABLE_NAME T
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

    $sth = $dbh->prepare("$log_query") or croak $dbh->errstr;
    $rv  = $sth->execute or croak $dbh->errstr;
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
# selectSeveralColumns
#
# Given a SQL statement which returns one or more columns, return an array
# of references to arrays of the results of each row of that query.
###############################################################################
sub selectSeveralColumns {
    my $self = shift || croak("parameter self not passed");
    my $sql_query = shift || croak("parameter sql_query not passed");

    my @rows;

    #### FIX ME replace with $dbh->selectall_arrayref ?????
    my $sth = $dbh->prepare("$sql_query") or croak $dbh->errstr;
    my $rv  = $sth->execute or croak $dbh->errstr;

    while (my @row = $sth->fetchrow_array) {
        push(@rows,\@row);
    }

    $sth->finish;

    return @rows;

}


###############################################################################
# selectHashArray
#
# Given a SQL statement which returns one or more columns, return an array
# of references to hashes of the results of each row of that query.
###############################################################################
sub selectHashArray {
    my $self = shift || croak("parameter self not passed");
    my $sql_query = shift || croak("parameter sql_query not passed");

    my @rows;

    my $sth = $dbh->prepare("$sql_query") or croak $dbh->errstr;
    my $rv  = $sth->execute or croak $dbh->errstr;

    while (my $columns = $sth->fetchrow_hashref) {
        push(@rows,$columns);
    }

    $sth->finish;

    return @rows;

}


###############################################################################
# selectTwoColumnHash
#
# Given a SQL statement which returns exactly two columns, return a hash
# containing the results of that query.
###############################################################################
sub selectTwoColumnHash {
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
# insert_update_row
###############################################################################
sub insert_update_row {
  my $self = shift || croak("parameter self not passed");
  my %args = @_;

  #### Decode the argument list
  my $table_name = $args{'table_name'} || die "ERROR: table_name not passed";
  my $rowdata_ref = $args{'rowdata_ref'} || die "ERROR: rowdata_ref not passed";
  my $database_name = $args{'database_name'} || "";
  my $return_PK = $args{'return_PK'} || 0;
  my $verbose = $args{'verbose'} || 0;
  my $testonly = $args{'testonly'} || 0;
  my $insert = $args{'insert'} || 0;
  my $update = $args{'update'} || 0;
  my $PK = $args{'PK'} || "";
  my $PK_value = $args{'PK_value'} || "";


  #### Make sure either INSERT or UPDATE was selected
  unless ( ($insert or $update) and (!($insert and $update)) ) {
    croak "ERROR: Need to specify either 'insert' or 'update'\n\n";
  }


  #### If this is an UPDATE operation, make sure that we got the PK and value
  if ($update) {
    unless ($PK and $PK_value) {
      croak "ERROR: Need both PK and PK_value if operation is UPDATE\n\n";
    }
  }


  #### Initialize some variables
  my ($column_list,$value_list,$columnvalue_list) = ("","","");
  my ($key,$value,$value_ref);


  #### Loops over each passed rowdata element, building the query
  while ( ($key,$value) = each %{$rowdata_ref} ) {

    #### If $value is a reference, assume it's a reference to a hash and
    #### extract the {value} key value.  This is because of Xerces.
    $value = $value->{value} if (ref($value));

    print "	$key = $value\n" if ($verbose > 0);

    #### Add the key as the column name
    $column_list .= "$key,";

    #### Enquote and add the value as the column value
    $value =~ s/'/''/g;
    if (uc($value) eq "CURRENT_TIMESTAMP") {
      $value_list .= "$value,";
      $columnvalue_list .= "$key = $value,\n";
    } else {
      $value_list .= "'$value',";
      $columnvalue_list .= "$key = '$value',\n";
    }

  }


  unless ($column_list) {
    print "ERROR: insert_row(): column_list is empty!\n";
    return;
  }


  #### Chop off the final commas
  chop $column_list;
  chop $value_list;
  chop $columnvalue_list;  # First the \n
  chop $columnvalue_list;  # Then the comma


  #### Build the SQL statement
  my $sql;
  if ($update) {
    $sql = "UPDATE $database_name$table_name SET $columnvalue_list WHERE $PK = '$PK_value'";
  } else {
    $sql = "INSERT INTO $database_name$table_name ( $column_list ) VALUES ( $value_list )";
  }
  print "$sql\n" if ($verbose > 0);


  #### Return if just testing
  return "1" if ($testonly);


  #### Execute the SQL
  $self->executeSQL($sql);


  #### If user didn't want PK, return with success
  return "1" unless ($return_PK);


  #### If user requested the resulting PK, return it
  if ($update) {
    return $PK_value;
  } else {
    return $self->getLastInsertedPK(table_name=>"$database_name$table_name",
      PK_column_name=>"$PK");
  }


}


###############################################################################
# executeSQL
#
# Execute the supplied SQL statement with no return value.
###############################################################################
sub executeSQL {
    my $self = shift || croak("parameter self not passed");
    my $sql_query = shift || croak("parameter sql_query not passed");

#    my $sth = $dbh->prepare("$sql_query") or croak $dbh->errstr;
#    my $rv  = $sth->execute or croak $dbh->errstr;

    my $rows = $dbh->do("$sql_query") or croak $dbh->errstr;

    return 0;

}



###############################################################################
# getLastInsertedPK
#
# Return the value of the AUTO GEN key for the last INSERTed row
###############################################################################
sub getLastInsertedPK {
    my $self = shift || croak("parameter self not passed");
    my %args = @_;
    my $subName = "getLastInsertedPK";


    #### Decode the argument list
    my $table_name = $args{'table_name'};
    my $PK_column_name = $args{'PK_column_name'};


    my $sql;
    my $DBType = $self->getDBType() || "";


    #### Method to determine last inserted PK depends on database server
    if ($DBType =~ /MS SQL Server/i) {
      $sql = "SELECT SCOPE_IDENTITY()";

    } elsif ($DBType =~ /MySQL/i) {
      $sql = "SELECT LAST_INSERT_ID()";

    } elsif ($DBType =~ /PostgreSQL/i) {
      croak "ERROR[$subName]: Both table_name and PK_column_name need to be " .
        "specified here for PostgreSQL since no automatic PK detection is " .
        "yet possible." unless ($table_name && $PK_column_name);

      #### YUCK! PostgreSQL 7.1 appears to truncate table name and PK name at
      #### 13 characters to form the automatic SEQUENCE.  Might be fix later?
      my $table_name_tmp = substr($table_name,0,13);
      my $PK_column_name_tmp = substr($PK_column_name,0,13);
 
      $sql = "SELECT currval('${table_name_tmp}_${PK_column_name_tmp}_seq')"

    } else {
      croak "ERROR[$subName]: Unable to determine DBType\n\n";
    }


    #### Get value and return it
    my ($returned_PK) = $self->selectOneColumn($sql);
    return $returned_PK;

}



###############################################################################
# parseConstraint2SQL
#
# Given human-entered constraint, convert it to a SQL "AND" clause which some
# suitable checking to make sure the user isn't trying to enter something
# bogus
###############################################################################
sub parseConstraint2SQL {
  my $self = shift || croak("parameter self not passed");
  my %args = @_;

  #### Decode the argument list
  my $constraint_column = $args{'constraint_column'}
   || die "ERROR: constraint_column not passed";
  my $constraint_type = $args{'constraint_type'}
   || die "ERROR: constraint_type not passed";
  my $constraint_name = $args{'constraint_name'}
   || die "ERROR: constraint_name not passed";
  my $constraint_value = $args{'constraint_value'};
  my $verbose = $args{'verbose'} || 0;


  #### Strip leading and trailing whitespace
  return unless (defined($constraint_value));
  $constraint_value =~ s/^\s+//;
  $constraint_value =~ s/\s+$//;


  #### If no value was provided, simply return an empty string
  #### Don't return is the value is "0" because that may be a value
  return if ($constraint_value eq "");


  #### Parse type int
  if ($constraint_type eq "int") {
    print "Parsing int $constraint_name<BR>\n" if ($verbose);
    if ($constraint_value =~ /^[\d]+$/) {
      return "   AND $constraint_column = $constraint_value";
    } else {
      print "<H4>Cannot parse $constraint_name constraint ".
        "'$constraint_value'!  Check syntax.</H4>\n\n";
      return -1;
    }
  }


  #### Parse type flexible_int
  if ($constraint_type eq "flexible_int") {
    print "Parsing flexible_int $constraint_name<BR>\n" if ($verbose);
    if ($constraint_value =~ /^[\d]+$/) {
      return "   AND $constraint_column = $constraint_value";
    } elsif ($constraint_value =~ /^between\s+[\d]+\s+and\s+[\d]+$/i) {
      return "   AND $constraint_column $constraint_value";
    } elsif ($constraint_value =~ /^([\d]+)\s*\+\-\s*([\d]+)$/i) {
      my $lower = $1 - $2;
      my $upper = $1 + $2;
      return "   AND $constraint_column BETWEEN $lower AND $upper";
    } elsif ($constraint_value =~ /^[><=][=]*\s*[\d]+$/) {
      return "   AND $constraint_column $constraint_value";
    } else {
      print "<H4>Cannot parse $constraint_name constraint ".
        "'$constraint_value'!  Check syntax.</H4>\n\n";
      return -1;
    }
  }


  #### Parse type flexible_float
  if ($constraint_type eq "flexible_float") {
    print "Parsing flexible_float $constraint_name<BR>\n" if ($verbose);
    if ($constraint_value =~ /^[\d\.]+$/) {
      return "   AND $constraint_column = $constraint_value";
    } elsif ($constraint_value =~ /^between\s+[\d\.]+\s+and\s+[\d\.]+$/i) {
      return "   AND $constraint_column $constraint_value";
    } elsif ($constraint_value =~ /^([\d\.]+)\s*\+\-\s*([\d\.]+)$/i) {
      my $lower = $1 - $2;
      my $upper = $1 + $2;
      return "   AND $constraint_column BETWEEN $lower AND $upper";
    } elsif ($constraint_value =~ /^[><=][=]*\s*[\d\.]+$/) {
      return "   AND $constraint_column $constraint_value";
    } else {
      print "<H4>Cannot parse $constraint_name constraint ".
        "'$constraint_value'!  Check syntax.</H4>\n\n";
      return -1;
    }
  }


  #### Parse type int_list: a list of integers like "+1, 2,-3"
  if ($constraint_type eq "int_list") {
    print "Parsing int_list $constraint_name<BR>\n" if ($verbose);
    if ($constraint_value =~ /^[\d,\s]+$/ ) {
      return "   AND $constraint_column IN ( $constraint_value )";
    } else {
      print "<H4>Cannot parse $constraint_name constraint ".
        "'$constraint_value'!  Check syntax.</H4>\n\n";
      return -1;
    }
  }


  #### Parse type plain_text: a plain, unquoted bit of text
  if ($constraint_type eq "plain_text") {
    print "Parsing plain_text $constraint_name<BR>\n" if ($verbose);

    #### Convert any ' marks to '' to appear okay within the strings
    $constraint_value =~ s/'/''/g;

    #### Bad word checking here has been disabled because the string will be
    #### quoted, so there shouldn't be a way to put in dangerous SQL...
    #if ($constraint_value =~ /SELECT|TRUNCATE|DROP|DELETE|FROM|GRANT/i) {}

    return "   AND $constraint_column LIKE '$constraint_value'";
  }




  die "ERROR: unrecognized constraint_type!";

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
    my $method_options = shift;
    my $selected_flag;

    my %selected_options;

    #### If we explicitly were called with an MULITOPIONLIST, separate
    #### a comma-delimited list into several elements
    my @tmp;
    if ($method_options =~ /MULTIOPTIONLIST/) {
      @tmp = split(",",$selected_option);
    } else {
      @tmp = ($selected_option);
    }

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
    my %args = @_;

    #### Process the arguments list
    my $sql_query = $args{'sql_query'} || croak "parameter sql_query missing";
    my $url_cols_ref = $args{'url_cols_ref'};
    my $hidden_cols_ref = $args{'hidden_cols_ref'};
    my $row_color_scheme_ref = $args{'row_color_scheme_ref'};
    my $printable_table = $args{'printable_table'};
    my $max_widths_ref = $args{'max_widths'};
    $resultset_ref = $args{'resultset_ref'};


    #### Execute the query
    $sth = $dbh->prepare("$sql_query") or croak $dbh->errstr;
    my $rv  = $sth->execute or croak $dbh->errstr;


    #print $sth->{NUM_OF_FIELDS},"<BR>\n";
    #print join ("|",@{ $sth->{TYPE} }),"<BR>\n";

    #### Define <TD> tags
    my @TDformats=('NOWRAP');


    #### If a row_color_scheme was not passed, create one:
    unless ($row_color_scheme_ref) {
      my %row_color_scheme;
      $row_color_scheme{change_n_rows} = 3;
      my @row_color_list = ("#E0E0E0","#C0D0C0");
      $row_color_scheme{color_list} = \@row_color_list;
      $row_color_scheme_ref = \%row_color_scheme;
    }


    #### Decode the type numbers into type strings
    my $types_ref = $self->decodeDataType($sth->{TYPE});


    #### Make some adjustments to the default column width settings
    my @precisions = @{$sth->{PRECISION}};
    my $i;
    for ($i = 0; $i <= $#precisions; $i++) {
      #### Set the width to negative (variable)
      $precisions[$i] = (-1) * $precisions[$i];

      #### Override the width if the user specified it
      $precisions[$i] = $max_widths_ref->{$sth->{NAME}->[$i]}
        if ($max_widths_ref->{$sth->{NAME}->[$i]});

      #### Set the precision to 20 for dates (2001-01-01 00:00:01)
      $precisions[$i] = 20 if ($types_ref->[$i] =~ /date/i);

      #### Print for debugging
      #print $sth->{NAME}->[$i],"(",$types_ref->[$i],"): ",
      #  $precisions[$i],"<BR>\n";
    }


    #### Prepare returned resultset
    my @resultsetdata;
    my %column_hash;
    my $element;
    $resultset_ref->{column_list_ref} = $sth->{NAME};
    $i = 0;
    foreach $element (@{$sth->{NAME}}) {
      $column_hash{$element} = $i;
      $i++;
    }
    $resultset_ref->{column_hash_ref} = \%column_hash;
    $resultset_ref->{data_ref} = \@resultsetdata;


    #### If a printable table was desired, use one format
    if ( $printable_table ) {

      ShowHTMLTable { titles=>$sth->{NAME},
	types=>$types_ref,
	widths=>$sth->{PRECISION},
	row_sub=>\&fetchNextRow,
        table_attrs=>'WIDTH=675 BORDER=1 CELLPADDING=2 CELLSPACING=2',
        title_formats=>['BOLD'],
        url_keys=>$url_cols_ref,
        hidden_cols=>$hidden_cols_ref,
        THformats=>['BGCOLOR=#C0C0C0'],
        TDformats=>['NOWRAP']
      };

    #### Otherwise, use the standard viewable format which doesn't print well
    } else {

      ShowHTMLTable { titles=>$sth->{NAME},
	types=>$types_ref,
	widths=>\@precisions,
	row_sub=>\&fetchNextRow,
        table_attrs=>'BORDER=0 CELLPADDING=2 CELLSPACING=2',
        title_formats=>['FONT COLOR=white,BOLD'],
        url_keys=>$url_cols_ref,
        hidden_cols=>$hidden_cols_ref,
        THformats=>['BGCOLOR=#0000A0'],
        TDformats=>\@TDformats,
        row_color_scheme=>$row_color_scheme_ref
      };

    }


    #### finish up
    print "\n";
    $sth->finish;

    return 1;


} # end displayQueryResult


###############################################################################
# fetchNextRow called by ShowTable
###############################################################################
sub fetchNextRow {
  my $flag = shift @_;
  #print "Entering fetchNextRow (flag = $flag)...<BR>\n";

  #### If flag == 1, just testing to see if this is rewindable
  if ($flag == 1) {
    #print "Test if rewindable: yes<BR>\n";
    return 1;
  }

  #### If flag > 1, then really do the rewind  
  if ($flag > 1) {
    #print "rewind...<BR>";
    $sth->execute;
    #print "and return.<BR>\n";
    return 1;
  }

  #### Else return the next row
  my @row = $sth->fetchrow_array;
  if (@row) {
    push(@{$resultset_ref->{data_ref}},\@row);
  }

  return @row;
}


###############################################################################
# fetchNextRow called by ShowHTMLTable
###############################################################################
sub fetchNextRowOld {
    my $flag = shift @_;
    if ($flag) {
      print "fetchNextRow: flag = $flag<BR>\n";
      return $sth->execute;
    }
    return $sth->fetchrow_array;
}


###############################################################################
# decodeDataType
###############################################################################
sub decodeDataType {
    my $self = shift;
    my $types_ref = shift || die "decodeDataType: insufficient paramaters\n";

    my %typelist = ( 1=>"varchar", 4=>"int", 2=>"numeric", 6=>"float",
      11=>"date",-1=>"text" );
    my ($i,$type,$newtype);
    my @types = @{$types_ref};
    my @newtypes;

    for ($i = 0; $i <= $#types; $i++) {
      $type = $types[$i];
      $newtype = $typelist{$type} || $type;
      push(@newtypes,$newtype);
      #print "$i: $type --> $newtype\n";
    }

    return \@newtypes;
}





#### A new way of doing things: having a resultset in memory



###############################################################################
# fetchResultSet
#
# Executes a query and loads the result into a resultset structure
###############################################################################
sub fetchResultSet {
    my $self = shift;
    my %args = @_;

    #### Process the arguments list
    my $sql_query = $args{'sql_query'} || croak "parameter sql_query missing";
    $resultset_ref = $args{'resultset_ref'};


    #### Execute the query
    $sth = $dbh->prepare("$sql_query") or croak $dbh->errstr;
    my $rv  = $sth->execute or croak $dbh->errstr;


    #### Decode the type numbers into type strings
    my $types_list_ref = $self->decodeDataType($sth->{TYPE});

    my @precisions = @{$sth->{PRECISION}};


    #### Prepare returned resultset
    my @resultsetdata;
    my %column_hash;
    my $element;
    $resultset_ref->{column_list_ref} = $sth->{NAME};
    my $i = 0;
    foreach $element (@{$sth->{NAME}}) {
      $column_hash{$element} = $i;
      $i++;
    }
    $resultset_ref->{column_hash_ref} = \%column_hash;
    $resultset_ref->{types_list_ref} = $types_list_ref;
    $resultset_ref->{precisions_list_ref} = \@precisions;
    $resultset_ref->{data_ref} = \@resultsetdata;
    $resultset_ref->{row_pointer} = 0;
    $resultset_ref->{row_counter} = 0;
    $resultset_ref->{page_size} = 100;


    #### Read the result set into memory
    while (fetchNextRow()) { 1; }


    #### finish up
    print "\n";
    $sth->finish;

    return 1;


} # end fetchResultSet


###############################################################################
# displayResultSet
#
# Displays a resultset in memory as an HTML table
###############################################################################
sub displayResultSet {
    my $self = shift;
    my %args = @_;

    #### Process the arguments list
    my $url_cols_ref = $args{'url_cols_ref'};
    my $hidden_cols_ref = $args{'hidden_cols_ref'};
    my $row_color_scheme_ref = $args{'row_color_scheme_ref'};
    my $printable_table = $args{'printable_table'};
    my $max_widths_ref = $args{'max_widths'};
    $resultset_ref = $args{'resultset_ref'};
    my $page_size = $args{'page_size'} || 100;
    my $page_number = $args{'page_number'} || 0;


    #### Set the display window of rows
    $resultset_ref->{row_pointer} = $page_size * $page_number;
    $resultset_ref->{row_counter} = 0;
    $resultset_ref->{page_size} = $page_size;


    #### Define <TD> tags
    my @TDformats=('NOWRAP');


    #### If a row_color_scheme was not passed, create one:
    unless ($row_color_scheme_ref) {
      my %row_color_scheme;
      $row_color_scheme{change_n_rows} = 3;
      my @row_color_list = ("#E0E0E0","#C0D0C0");
      $row_color_scheme{color_list} = \@row_color_list;
      $row_color_scheme_ref = \%row_color_scheme;
    }


    my $types_ref = $resultset_ref->{types_list_ref};


    #### Make some adjustments to the default column width settings
    my @precisions = @{$resultset_ref->{precisions_list_ref}};
    my $i;
    for ($i = 0; $i <= $#precisions; $i++) {
      #### Set the width to negative (variable)
      $precisions[$i] = (-1) * $precisions[$i];

      #### Override the width if the user specified it
      $precisions[$i] = $max_widths_ref->{$sth->{NAME}->[$i]}
        if ($max_widths_ref->{$sth->{NAME}->[$i]});

      #### Set the precision to 20 for dates (2001-01-01 00:00:01)
      $precisions[$i] = 20 if ($types_ref->[$i] =~ /date/i);

      #### Print for debugging
      #print $sth->{NAME}->[$i],"(",$types_ref->[$i],"): ",
      #  $precisions[$i],"<BR>\n";
    }


    #### If a printable table was desired, use one format
    if ( $printable_table ) {

      ShowHTMLTable { titles=>$resultset_ref->{column_list_ref},
	types=>$types_ref,
	widths=>\@precisions,
	row_sub=>\&returnNextRow,
        table_attrs=>'WIDTH=675 BORDER=1 CELLPADDING=2 CELLSPACING=2',
        title_formats=>['BOLD'],
        url_keys=>$url_cols_ref,
        hidden_cols=>$hidden_cols_ref,
        THformats=>['BGCOLOR=#C0C0C0'],
        TDformats=>['NOWRAP']
      };

    #### Otherwise, use the standard viewable format which doesn't print well
    } else {

      ShowHTMLTable { titles=>$resultset_ref->{column_list_ref},
	types=>$types_ref,
	widths=>\@precisions,
	row_sub=>\&returnNextRow,
        table_attrs=>'BORDER=0 CELLPADDING=2 CELLSPACING=2',
        title_formats=>['FONT COLOR=white,BOLD'],
        url_keys=>$url_cols_ref,
        hidden_cols=>$hidden_cols_ref,
        THformats=>['BGCOLOR=#0000A0'],
        TDformats=>\@TDformats,
        row_color_scheme=>$row_color_scheme_ref
      };

    }


    #### finish up
    print "\n";

    return 1;


} # end displayResultSet



###############################################################################
# displayResultSetControls
#
# Displays the links and form to control ResultSet display
###############################################################################
sub displayResultSetControls {
    my $self = shift;
    my %args = @_;

    my ($i,$element,$key,$value,$line,$result,$sql);

    #### Process the arguments list
    my $resultset_ref = $args{'resultset_ref'};
    my $rs_params_ref = $args{'rs_params_ref'};
    my $query_parameters_ref = $args{'query_parameters_ref'};
    my $base_url = $args{'base_url'};

    my %rs_params = %{$rs_params_ref};
    my %parameters = %{$query_parameters_ref};


    #### Start form
    print qq~
      <FORM METHOD="POST">
    ~;


    #### Display the row statistics and warn the user
    #### if they're not seeing all the data
    my $start_row = $rs_params{page_size} * $rs_params{page_number} + 1;
    my $nrows = scalar(@{$resultset_ref->{data_ref}});
    print "Displayed rows $start_row - $resultset_ref->{row_pointer} of ".
      "$nrows\n";

    if ( $parameters{row_limit} == scalar(@{$resultset_ref->{data_ref}}) ) {
      print "&nbsp;&nbsp;(<font color=red>WARNING: </font>Resultset ".
	"truncated at $parameters{row_limit} rows. ".
	"Increase row limit to see more.)\n";
    }


    #### Provide links to the other pages of the dataset
    print "<BR>Result Page \n";
    $i=0;
    my $nrowsminus = $nrows - 1 if ($nrows > 0);
    my $npages = int($nrowsminus / $rs_params{page_size}) + 1;
    for ($i=0; $i<$npages; $i++) {
      my $pg = $i+1;
      if ($i == $rs_params{page_number}) {
        print "[<font color=red>$pg</font>] \n";
      } else {
        print "<A HREF=\"$base_url?apply_action=VIEWRESULTSET&".
          "rs_set_name=$rs_params{set_name}&".
          "rs_page_size=$rs_params{page_size}&".
          "rs_page_number=$pg\">$pg</A> \n";
      }
    }
    print "of $npages<BR>\n";


    #### Print out a form to control some variable parameters
    my $this_page = $rs_params{page_number} + 1;
    print qq~
      <INPUT TYPE="hidden" NAME="rs_set_name" VALUE="$rs_params{set_name}">
      Page Size:
      <INPUT TYPE="text" NAME="rs_page_size" SIZE=4
        VALUE="$rs_params{page_size}">
      &nbsp;&nbsp;&nbsp;&nbsp;Page Number:
      <INPUT TYPE="text" NAME="rs_page_number" SIZE=4
        VALUE="$this_page">
      <INPUT TYPE="submit" NAME="apply_action" VALUE="VIEWRESULTSET">
    ~;


    #### Supply some additional links to the Result Set
    print qq~
      <BR>Download ResultSet in Format:
      <a href="$CGI_BASE_DIR/GetResultSet.cgi/$rs_params{set_name}.tsv?rs_set_name=$rs_params{set_name}&format=tsv">TSV</a>,
      <a href="$CGI_BASE_DIR/GetResultSet.cgi/$rs_params{set_name}.xls?rs_set_name=$rs_params{set_name}&format=excel">Excel</a>
      <BR>
    ~;


    #### Finish the form
    print qq~
      </FORM>
    ~;


    #### Print out some debugging information about the returned resultset:
    if (0 == 1) {
      print "<BR><BR>resultset_ref = $resultset_ref<BR>\n";
      while ( ($key,$value) = each %{$resultset_ref} ) {
        printf("%s = %s<BR>\n",$key,$value);
      }
      #print "columnlist = ",
      #  join(" , ",@{$resultset_ref->{column_list_ref}}),"<BR>\n";
      print "nrows = ",scalar(@{$resultset_ref->{data_ref}}),"<BR>\n";
      print "rs_set_name=",$rs_params{set_name},"<BR>\n";
    }


    return 1;


} # end displayResultSetControls


###############################################################################
# readResultSet
#
# Reads a resultset from a file
###############################################################################
sub readResultSet {
    my $self = shift;
    my %args = @_;

    #### Process the arguments list
    my $resultset_file = $args{'resultset_file'};
    $resultset_ref = $args{'resultset_ref'};
    my $query_parameters_ref = $args{'query_parameters_ref'};

    my $indata = "";


    #### Read in the query parameters
    my $infile = "../../tmp/queries/${resultset_file}.params";
    open(INFILE,"$infile") || die "Cannot open $infile\n";
    while (<INFILE>) { $indata .= $_; }
    close(INFILE);


    #### eval the dump
    my $VAR1;
    eval $indata;
    %{$query_parameters_ref} = %{$VAR1};


    #### Read in the resultset
    $indata = "";
    my $infile = "../../tmp/queries/${resultset_file}.resultset";
    open(INFILE,"$infile") || die "Cannot open $infile\n";
    while (<INFILE>) { $indata .= $_; }
    close(INFILE);

    #### eval the dump
    eval $indata;
    %{$resultset_ref} = %{$VAR1};


    return 1;


} # end readResultSet


###############################################################################
# writeResultSet
#
# Writes a resultset to a file
###############################################################################
sub writeResultSet {
    my $self = shift;
    my %args = @_;

    #### Process the arguments list
    my $resultset_file_ref = $args{'resultset_file_ref'};
    $resultset_ref = $args{'resultset_ref'};
    my $query_parameters_ref = $args{'query_parameters_ref'};


    #### If a filename was not provides, create one
    if ($$resultset_file_ref eq "SETME") {
      my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
      my $timestr = strftime("%Y%m%d-%H%M%S",$sec,$min,$hour,$mday,$mon,$year);
      $$resultset_file_ref = "query_" . $self->getCurrent_username() ."_" . 
	$timestr;
    }
    my $resultset_file = $$resultset_file_ref;


    #### Write out the query parameters
    my $outfile = "../../tmp/queries/${resultset_file}.params";
    open(OUTFILE,">$outfile") || die "Cannot open $outfile\n";
    printf OUTFILE Data::Dumper->Dump( [$query_parameters_ref] );
    close(OUTFILE);


    #### Write out the resultset
    my $outfile = "../../tmp/queries/${resultset_file}.resultset";
    open(OUTFILE,">$outfile") || die "Cannot open $outfile\n";
    printf OUTFILE Data::Dumper->Dump( [$resultset_ref] );
    close(OUTFILE);


    return 1;


} # end writeResultSet


###############################################################################
# returnNextRow called by ShowTable
###############################################################################
sub returnNextRow {
  my $flag = shift @_;
  #print "Entering returnNextRow (flag = $flag)...<BR>\n";

  #### If flag == 1, just testing to see if this is rewindable
  if ($flag == 1) {
    #print "Test if rewindable: yes<BR>\n";
    return 1;
  }

  #### If flag > 1, then really do the rewind  
  if ($flag > 1) {
    #print "rewind...<BR>";
    $resultset_ref->{row_pointer} = 0;
    #print "and return.<BR>\n";
    return 1;
  }

  #### Else return the next row
  my @row;
  my $irow = $resultset_ref->{row_pointer};
  my $nrows = scalar(@{$resultset_ref->{data_ref}});
  my $nrow = $resultset_ref->{row_counter};
  my $page_size = $resultset_ref->{page_size};
  if ($irow < $nrows && $nrow < $page_size) {
    (@row) = @{$resultset_ref->{data_ref}->[$irow]};
    $resultset_ref->{row_pointer}++;
    $resultset_ref->{row_counter}++;
  }

  return @row;
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
