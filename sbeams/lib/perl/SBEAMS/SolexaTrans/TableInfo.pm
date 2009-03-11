package SBEAMS::SolexaTrans::TableInfo;

###############################################################################
# Program     : SBEAMS::SolexaTrans::TableInfo
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id: TableInfo.pm 4504 2006-03-07 23:49:03Z edeutsch $
#
# Description : This is part of the SBEAMS::SolexaTrans module which returns
#               information about various tables.
#
###############################################################################

use strict;
use CGI::Carp qw( croak);

use SBEAMS::SolexaTrans::Settings;
use SBEAMS::SolexaTrans::Tables;
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
#    my @ids = $self->getSBEAMS()->getAccessibleProjects();
#    my $project_string = join(",", @ids) || 0;
    my $project_string = $self->getSBEAMS()->getCurrent_project_id();

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
###############################################################################
#    elsif (uc($table_name) eq 'ST_SOLEXA_SAMPLE') {
#      if ($info_key eq "BASICQuery") {
#        return( <<"	END_QUERY");
#	  SELECT * 
#            FROM $TBST_SOLEXA_SAMPLE
#            WHERE project_id in ( $project_string )
#            AND record_status != 'D'
#	END_QUERY
#       }

#      if ($info_key eq "projPermSQL") {
#        my %projSQL;
#        $projSQL{dbsql} = <<"          END";
#          SELECT project_id
#          FROM $TBST_SOLEXA_SAMPLE
#          WHERE solexa_sample_id IN (KEYVAL)
#          END
#        $projSQL{fsql} = '';

#        return \%projSQL;
#      }
#    }


###############################################################################

    #### Obtain main SBEAMS object and fall back to its TableInfo handler
    my $sbeams = $self->getSBEAMS();
    my @temp_result = $sbeams->returnTableInfo($table_name,$info_key);
    return @temp_result;

}




###############################################################################
# getParentProject
#
# Return the parent project of a record in a table which might govern
# whether the proposed INSERT or UPDATE function may proceed.
###############################################################################
sub getParentProject {
  my $self = shift;
  my %args = @_;
  my $SUB_NAME = "getParentProject";

  #### Decode the argument list
  my $table_name = $args{'table_name'}
    || die("ERROR: $SUB_NAME: Parameter table_name not passed");
  my $action = $args{'action'}
    || die("ERROR: $SUB_NAME: Parameter action not passed");
  my $parameters_ref = $args{'parameters_ref'}
    || die("ERROR: $SUB_NAME: Parameter parameters_ref not passed");

  #### Make sure action is one of INSERT,UPDATE,DELETE
  unless ($action =~ /^INSERT$|^UPDATE$|^DELETE$/) {
    die("ERROR: $SUB_NAME: action must be one of INSERT,UPDATE,DELETE");
  }

  #### Get sbeams object, needed for Core tables and SQL queries
  my $sbeams = $self->getSBEAMS();

  #### Define the project_id, starting as undef, it gets filled if there is one
  my $project_id;

  #### Check to see if this is a Core table that has project control
  $project_id = $sbeams->getParentProject(
    table_name => $table_name,
    action => $action,
    parameters_ref => $parameters_ref,
  );
  return($project_id) if ($project_id);

  # Fetch SQL to retrieve project_id from table_name, if it is available.
#  my $sqlref = $self->returnTableInfo( $table_name, 'projPermSQL' );

  # If we don't have it
#  unless ( ref( $sqlref ) && $sqlref->{dbsql} ) {
#    print STDERR "dbsql not defined for $table_name\n";
#    return undef;
#  }


  #############################################################################
  #### Process actions for individual tables

  #### If table is xxxx
  if ($table_name eq "xxxx") {

    #### If the user wants to INSERT, determine how it fits into project
    if ($action eq 'INSERT') {

    #### Else for an UPDATE or DELETE, determine how it fits into project
    } elsif ($action eq 'UPDATE' || $action eq 'DELETE') {

    }

    return($project_id) if ($project_id);
#  } elsif ($table_name eq 'ST_SOLEXA_SAMPLE') {
#    if ($action eq 'INSERT') {
#      return undef;
#    }

#    elsif ($action eq 'UPDATE' || $action eq 'DELETE') {
#      if ($parameters_ref->{solexa_sample_id}) {
#        $sqlref->{dbsql} =~ s/KEYVAL/$parameters_ref->{solexa_sample_id}/;
#        ($project_id) = $sbeams->selectOneColumn( $sqlref->{dbsql} );
#      }
#    }
#    return($project_id ? $project_id : undef);
  }


  #### No information for this table so return undef
  return;

}



###############################################################################
1;

__END__
###############################################################################
###############################################################################
###############################################################################
