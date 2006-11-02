#!/usr/local/bin/perl -w

#####################################################################
# Program	: SQLTest.t
# Author	: Jeff Howbert <peak.list@verizon.net>
# $Id: $
#
# Description	: This script passes prototypical SQL statements to
#		  the current database instance.  It is intended to
#		  be exercised against multiple database instances,
#                 to confirm the syntax of the SQL statements is valid
#                 in each instance.
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public
# License (GPL) version 2 as published by the Free Software
# Foundation.  It is provided WITHOUT ANY WARRANTY.  See the full
# description of GPL terms in the LICENSE file distributed with this
# software.
#####################################################################

use strict;
use FindBin qw ( $Bin );
use lib( "$Bin/../.." );         # path to $SBEAMS/lib/perl directory
use Test::More;


###############################################################################
# BEGIN
###############################################################################
BEGIN {
    plan tests => 10;
    use_ok( 'SBEAMS::Connection' );
    use_ok( 'SBEAMS::Connection::Settings' );
    use_ok( 'SBEAMS::Connection::Tables' );
} # end BEGIN


###############################################################################
# END
###############################################################################
END {
    breakdown();
} # end END


###############################################################################
# MAIN
###############################################################################
use vars qw ( $sbeams );   # Main SBEAMS Connection object

ok($sbeams = SBEAMS::Connection->new(),"create main SBEAMS object");

#### Authenticate the current user
my $current_username;
ok($current_username = $sbeams->Authenticate(
			 permitted_work_groups_ref=>['Admin'],
			 #connect_read_only=>1,
			),"Authenticate current user");


#######################################################
# Test individal methods here
#######################################################

ok(testSimpleStringColumnConcat(),"Simple varchar column concatenation");
ok(testStringColumnConcat(),"Varchar column concatenation");
ok(testANSIConcat(),"Varchar concatenation with ANSI concat operator ||");
ok(testANSIStringConcat(),"String concatenation with ANSI concat operator ||");
ok(testSTRFunction(),"Test STR usage with translate SQL");

###############################################################################
# testSimpleStringColumnConcat
###############################################################################
sub testSimpleStringColumnConcat {

  my $sql = qq~
SELECT first_name+' '+last_name
  FROM $TB_CONTACT
  ~;

  my @contacts = $sbeams->selectOneColumn($sql);

  if ( scalar(@contacts)>1 &&
      grep(/SBEAMS Administrator/,@contacts) ) {
    diag("Returned ".scalar(@contacts)." rows");
    return(1);
  }

  return(0);
}

###############################################################################
# testSTRfunction
###############################################################################
sub testSTRFunction {

  my @sql = ( "SELECT STR(32.313, 7, 3) AS str_col, contact_id FROM $TB_CONTACT ",
              "SELECT\n STR(32.313, 7, 3) AS str_col, contact_id FROM $TB_CONTACT ",
              "SELECT STR(32.313,7,3) AS str_col, contact_id FROM $TB_CONTACT ",
              "SELECT STR(32.313,7,3)  AS str_col, contact_id FROM $TB_CONTACT ",
              "SELECT STR( 32.313,7,3)  AS str_col, contact_id FROM $TB_CONTACT ",
              "SELECT STR( 32.313,7,3), contact_id FROM $TB_CONTACT ",
              "SELECT STR(32.313,7,3 )  AS str_col, contact_id FROM $TB_CONTACT ",
              "SELECT\nSTR(32.313,7,3) AS str_col, contact_id FROM $TB_CONTACT ",
              "SELECT STR(  32.313 ,  7 , 3  ) AS str_col, contact_id FROM $TB_CONTACT ",
              "SELECT STR(  32.313 ,\n7\n, 3  ) AS str_col, contact_id FROM $TB_CONTACT " );

  my $dbh = $sbeams->getDBHandle();
  $dbh->{RaiseError} = 0;
  eval {
    for my $sql ( @sql ) {
      my $tsql = $sbeams->translateSQL( sql => $sbeams->evalSQL( $sql ) );
      my $sth = $dbh->prepare( $tsql );
      $sth->execute();
    }
  };
  if ( $@ ) {
    return 0;
  }
  return 1;
  }



###############################################################################
# testStringColumnConcat
###############################################################################
sub testStringColumnConcat {

  my $sql = qq~
SELECT contact_id, 
       first_name + ' ' + last_name
  FROM $TB_CONTACT
  ~;

  my @contacts = $sbeams->selectSeveralColumns($sql);

  if ( scalar(@contacts) ) {
    my $first = $contacts[0];
    return( $first->[1] );
  }

  return(0);
}

###############################################################################
# testANSIConcat
###############################################################################
sub testANSIConcat {

  my $sql = qq~
SELECT first_name, 
       first_name || last_name AS full_name
  FROM $TB_CONTACT
  ~;

  my @contacts;
  eval {
    @contacts = $sbeams->selectSeveralColumns($sql);
  };


  if ( scalar(@contacts) ) {
    my $first = $contacts[0];
    return( $first->[1] );
  }

  return(0);
}

###############################################################################
# testANSIStringConcat
###############################################################################
sub testANSIStringConcat {

  my $sql = qq~
  SELECT 'first' || '_' || 'last_name'
  FROM $TB_CONTACT
  ~;

  my @contacts;
  eval {
    @contacts = $sbeams->selectOneColumn($sql);
  };

  if ( scalar(@contacts) && grep /first_last/, @contacts ) {
    return(1);
  }
}


###############################################################################
# breakdown
###############################################################################
sub breakdown {
#    print "After the script, there was ... END\n\n";
}



################################################################################

1;

__END__

################################################################################
################################################################################
################################################################################

=head1  SQLTest.t

=head2  DESCRIPTION

This script passes prototypical SQL statements to the current database instance.
It is intended to be exercised against multiple database instances, to confirm
the syntax of the SQL statements is valid in each instance.

Executable currently located in sbeams/lib/perl/t/Core.

=head2  USAGE


=head2  KNOWN BUGS AND LIMITATIONS


=head2  AUTHOR

Jeff Howbert <peak.list@verizon.net>

=cut

