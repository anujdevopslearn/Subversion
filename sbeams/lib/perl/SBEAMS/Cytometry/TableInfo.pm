package SBEAMS::Cytometry::TableInfo;

###############################################################################
# Program     : SBEAMS::Cytometry::TableInfo
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Cytometry module which returns
#               information about various tables.
#
###############################################################################

use strict;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Cytometry::Settings;
use SBEAMS::Cytometry::Tables;
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
    
    if (uc($table_name) eq 'CY_FCS_RUN') {
      if ( $info_key eq "projPermSQL" ) { 
        my %projectSQL;

        $projectSQL{fsql} = '';

        $projectSQL{dbsql} =<<"        END";
        SELECT project_id FROM $TBCY_FCS_RUN WHERE fcs_run_id = KEYVAL
        END

        return \%projectSQL
      }
    }
    
     if (uc($table_name) eq 'CY_CYTOMETRY_SAMPLE') {
      if ( $info_key eq "projPermSQL" ) { 
        my %projectSQL;

        $projectSQL{fsql} = '';

        $projectSQL{dbsql} =<<"        END";
        SELECT project_id FROM $TBCY_CYTOMETRY_SAMPLE WHERE fcs_run_id = KEYVAL
        END

        return \%projectSQL
      }
    }
    
   
     elsif (uc($table_name) eq 'CY_SORT_ENTITY') {
      if ( $info_key eq "projPermSQL" ) { 
        my %projectSQL;

        $projectSQL{fsql} ='';      

       $projectSQL{dbsql} =<<"        END";
        SELECT project_id FROM $TBCY_SORT_ENTITY
         where sort_entity_id =  KEYVAL
        END

        return \%projectSQL
      }
    }
        
   
           
      elsif (uc($table_name) eq 'CY_TISSUE_TYPE') {
      if ( $info_key eq "projPermSQL" ) { 
        my %projectSQL;

        $projectSQL{fsql} =   '';
        $projectSQL{dbsql} =<<"        END";
        SELECT project_id FROM $TBCY_TISSUE_TYPE 
        where tissue_type_id =  KEYVAL
        END

        return \%projectSQL
      }
    }
    
       elsif (uc($table_name) eq 'CY_MEASURED_PARAMETERS') {
      if ( $info_key eq "projPermSQL" ) { 
        my %projectSQL;

        $projectSQL{fsql} =   '';
        $projectSQL{dbsql} =<<"        END";
        SELECT project_id FROM $TBCY_MEASURED_PARAMETERS 
        where measured_parameters_id  =  KEYVAL
        END

        return \%projectSQL
      }
    }
    
    
    

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

  
    # We may well have this cached
  return $parameters_ref->{project_id} if $parameters_ref->{project_id};

  # Fetch SQL to retrieve project_id from table_name, if it is available.
  my $sqlref = $self->returnTableInfo( $table_name, 'projPermSQL' );

  # If we don't have it 
  unless ( ref( $sqlref ) && $sqlref->{dbsql} ) {
    print STDERR "dbsql not defined for $table_name\n";
    return undef;
  }

  #############################################################################
  #### Process actions for individual tables

  #### If table is xxxx
  if (uc($table_name) eq "CY_FCS_RUN") {

    #### If the user wants to INSERT, determine how it fits into project
    if ($action eq 'INSERT') {
      return undef;

    #### Else for an UPDATE or DELETE, determine how it fits into project
    } elsif ($action eq 'UPDATE' || $action eq 'DELETE') {
      if ($parameters_ref->{fcs_run_id})
      {
        $sqlref->{dbsql} =~ s/KEYVAL/$parameters_ref->{fcs_run_id}/;
        ( $project_id ) = $sbeams->selectOneColumn( $sqlref->{dbsql} );
   
      }
    }
    return($project_id) if ($project_id);
  }
    elsif (uc($table_name) eq "CY_CYTOMETRY_SAMPLE") {        
        if ($action eq 'INSERT') {
            return undef;
        }
        
       #### Else for an UPDATE or DELETE, determine how it fits into project
    elsif ($action eq 'UPDATE' || $action eq 'DELETE') {
      if ($parameters_ref->{cytometry_sample_id})
      {
        $sqlref->{dbsql} =~ s/KEYVAL/$parameters_ref->{cytometry_sample_id}/;
        ( $project_id ) = $sbeams->selectOneColumn( $sqlref->{dbsql} );
   
      }
    }
    return($project_id) if ($project_id);
  }
     
    elsif (uc($table_name) eq "CY_SORT_ENTITY") {

    #### If the user wants to INSERT, determine how it fits into project
    if ($action eq 'INSERT') {
      return undef;

    #### Else for an UPDATE or DELETE, determine how it fits into project
    } elsif ($action eq 'UPDATE' || $action eq 'DELETE') {
      if ($parameters_ref->{sort_entity_id})
      {
        $sqlref->{dbsql} =~ s/KEYVAL/$parameters_ref->{sort_entity_id}/;
        ( $project_id ) = $sbeams->selectOneColumn( $sqlref->{dbsql} );
           
      }
    }
       return($project_id) if ($project_id);
  }
  
 
   elsif (uc($table_name) eq "CY_TISSUE_TYPE") {

    #### If the user wants to INSERT, determine how it fits into project
    if ($action eq 'INSERT') {
      return undef;

    #### Else for an UPDATE or DELETE, determine how it fits into project
    } elsif ($action eq 'UPDATE' || $action eq 'DELETE') {
      if ($parameters_ref->{tissue_type_id})
      {
        $sqlref->{dbsql} =~ s/KEYVAL/$parameters_ref->{tissue_type_id}/;
        ( $project_id ) = $sbeams->selectOneColumn( $sqlref->{dbsql} );
           
      }
    }
       return($project_id) if ($project_id);
   
  }
  
  elsif (uc($table_name) eq "CY_MEASURED_PARAMETERS") {

    #### If the user wants to INSERT, determine how it fits into project
    if ($action eq 'INSERT') {
      return undef;

    #### Else for an UPDATE or DELETE, determine how it fits into project
    } elsif ($action eq 'UPDATE' || $action eq 'DELETE') {
      if ($parameters_ref->{tissue_type_id})
      {
        $sqlref->{dbsql} =~ s/KEYVAL/$parameters_ref->{measured_parameters_id}/;
        ( $project_id ) = $sbeams->selectOneColumn( $sqlref->{dbsql} );
           
      }
    }
       return($project_id) if ($project_id);
   
  }
  elsif ($table_name eq "xxxx") {

    #### If the user wants to INSERT, determine how it fits into project
    if ($action eq 'INSERT') {

    #### Else for an UPDATE or DELETE, determine how it fits into project
    } elsif ($action eq 'UPDATE' || $action eq 'DELETE') {

    }

    return ( $project_id ) ? $project_id : undef;
  }

  #### No information for this table so return undef
  return undef;

}



###############################################################################
1;

__END__
###############################################################################
###############################################################################
###############################################################################
