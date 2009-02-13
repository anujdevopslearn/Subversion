###############################################################################
# Program     : SBEAMS::SolexaTrans::SolexaUtilities
# Author      : Denise Mauldin <dmauldin@systemsbiology.org>
#
# Description : Object representation of single Solexa run
# 
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
#
###############################################################################


{package SBEAMS::SolexaTrans::SolexaUtilities;

our $VERSION = '1.00';

=head1 NAME

SBEAMS::SolexaTrans::SolexaUtilities - Utility package for helper methods



=head1 SYNOPSIS

Contains methods to check for database entries and perform other utility functions.


=head1 DESCRIPTION

Contains methods to check for database entries and perform other utility functions.

=head2 EXPORT

None by default.

=head1 SEE ALSO

lib/scripts/SolexaTrans/load_solexatrans.pl

=head1 AUTHOR

Denise Mauldin<lt>dmauldin@systemsbiology.org<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 by Pat Moss

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.3 or,
at your option, any later version of Perl 5 you may have available.


=cut

use warnings;
use strict;
use vars qw($sbeams);

use Data::Dumper;

use SBEAMS::Connection::Tables;
use SBEAMS::Connection qw( $log );
use SBEAMS::SolexaTrans::Tables;

use base qw(SBEAMS::SolexaTrans);		#declare superclass
use Carp;

#@ISA = qw(SBEAMS::SolexaTrans);     



#######################################################
# Constructor
#######################################################
sub new {
	my $class = shift;
	
	my $self = {};
	
	bless $self, $class;
	
	return $self;
}
	
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

###############################################################################
# Get/Set the directory to start searching in
#
#the Base directory holding the Solexa files.
###############################################################################
sub base_dir {
        my $self = shift;

        if (@_){
                #it's a setter
                $self->{BASE_DIR} = $_[0];
        }else{
                #it's a getter
                $self->{BASE_DIR};
        }
}

###############################################################################
# Get/Set the file extension names to start searching for to make a valid group
#
#Return an array of the file extensions
###############################################################################
sub file_extension_names {
        my $either = shift;

        my $class = ref($either) ||$either;

        if (@_){
                #it's a setter
                $either->{FILE_EXTENSION_A_REF} = \@_;
        }else{
                #it's a getter
                @{$either->{FILE_EXTENSION_A_REF}};
        }
}

###############################################################################
# Get/Set the VERBOSE status
#
#
###############################################################################
sub verbose {
        my $self = shift;

        if (@_){
                #it's a setter
                $self->{_VERBOSE} = $_[0];
        }else{
                #it's a getter
                $self->{_VERBOSE};
        }
}

###############################################################################
# Get/Set the DEBUG status
#
#
###############################################################################
sub debug {
        my $self = shift;

        if (@_){
                #it's a setter
                $self->{_DEBUG} = $_[0];
        }else{
                #it's a getter
                $self->{_DEBUG};
        }
}

###############################################################################
# Get/Set the TESTONLY status
#
#
###############################################################################
sub testonly {
        my $self = shift;

        if (@_){
                #it's a setter
                $self->{_TESTONLY} = $_[0];
        }else{
                #it's a getter
                $self->{_TESTONLY};
        }
}


###############################################################################################################
### CHECK FUNCTIONS - check for something in the SBEAMS database
###############################################################################################################

###############################################################################
# check_sbeams_project
# Requires Project Tag and Project Name
# Returns SBEAMS project ID or 0
###############################################################################
sub check_sbeams_project {
	my $method = 'check_sbeams_project';
	my $self = shift;
	my %args = @_;
	my $name = $args{"name"};
	my $tag = $args{"tag"};

	unless ($name && $tag) {
	  confess(__PACKAGE__."::$method needs 'name' and 'tag' to look up a project in SBEAMS\n");
	}

        my $sql = qq~
		SELECT PROJECT_ID
		FROM $TB_PROJECT
		WHERE project_tag LIKE '$tag'
		  AND RECORD_STATUS != 'D'
		OR name LIKE '$name'
		  AND RECORD_STATUS != 'D'
	~;

	my @rows = $sbeams->selectOneColumn($sql);

	if ($rows[0]) {
	  return $rows[0];
	} else {
	  return 0;
	}
}

###############################################################################
# check_sbeams_user
# Requires first name and last name of user
# Returns SBEAMS user ID or 0
###############################################################################
sub check_sbeams_user {
	my $method = 'check_sbeams_user';
	my $self = shift;
	my %args = @_;
	my $first_name = $args{"first_name"};
	my $last_name = $args{"last_name"};

	unless ($first_name && $last_name) {
	  confess(__PACKAGE__."::$method needs 'first_name' and 'last_name' to look up a user in SBEAMS\n");
	}

        my $sql = qq~
		SELECT contact_id
		FROM $TB_CONTACT
		WHERE first_name = '$first_name'
		AND last_name = '$last_name'
		AND RECORD_STATUS != 'D'
	~;

	my @rows = $sbeams->selectOneColumn($sql);

	if ($rows[0]) {
	  return $rows[0];
	} else {
	  return 0;
	}
}

###############################################################################
# check_sbeams_organization
# Requires name of organization
# Returns SBEAMS organization ID or 0
###############################################################################
sub check_sbeams_organization {
	my $method = 'check_sbeams_organization';
	my $self = shift;
	my %args = @_;
	my $name = $args{"name"};

	unless ($name) {
	  confess(__PACKAGE__."::$method needs 'name' to look up an organization in SBEAMS\n");
	}

        my $sql = qq~
		SELECT organization_id
		FROM $TB_ORGANIZATION
		WHERE organization like '$name'
		AND RECORD_STATUS != 'D'
	~;

	my @rows = $sbeams->selectOneColumn($sql);

	if ($rows[0]) {
	  return $rows[0];
	} else {
	  return 0;
	}
}

###############################################################################
# check_sbeams_work_group
# Requires name of work_group
# Returns SBEAMS work_group ID or 0
###############################################################################
sub check_sbeams_work_group {
	my $method = 'check_sbeams_work_group';
	my $self = shift;
	my %args = @_;
	my $name = $args{"name"};

	unless ($name) {
	  confess(__PACKAGE__."::$method needs 'name' to look up an work_group in SBEAMS\n");
	}

        my $sql = qq~
		SELECT work_group_id
		FROM $TB_WORK_GROUP
		WHERE work_group_name like '$name'
		AND RECORD_STATUS != 'D'
	~;

	my @rows = $sbeams->selectOneColumn($sql);

	if ($rows[0]) {
	  return $rows[0];
	} else {
	  return 0;
	}
}

###############################################################################
# check_sbeams_group_project_permission
# Requires work_group_id and project_id
# Returns SBEAMS group_project_permission ID or 0
###############################################################################
sub check_sbeams_group_project_permission {
	my $method = 'check_sbeams_group_project_permission';
	my $self = shift;
	my %args = @_;
        my $work_group_id = $args{"work_group_id"};
        my $project_id = $args{"project_id"};

	unless ($args{"work_group_id"} && $args{"project_id"}) {
	  confess(__PACKAGE__."::$method needs 'work_group_id' and 'project_id' to look up an group_project_permission in SBEAMS\n");
	}

        my $sql = qq~
		SELECT group_project_permission_id
		FROM $TB_GROUP_PROJECT_PERMISSION
		WHERE work_group_id = '$work_group_id'
                AND project_id = '$project_id'
		AND RECORD_STATUS != 'D'
	~;

	my @rows = $sbeams->selectOneColumn($sql);

	if ($rows[0]) {
	  return $rows[0];
	} else {
	  return 0;
	}
}

###############################################################################
# check_sbeams_sample
# Requires slimseq sample id of sample and sample description
# Returns SBEAMS sample ID or 0
###############################################################################
sub check_sbeams_sample {
	my $method = 'check_sbeams_sample';
	my $self = shift;
	my %args = @_;
	my $sid = $args{"slimseq_id"};
	my $desc = $args{"desc"};

	unless ($sid && $desc) {
	  confess(__PACKAGE__."::$method needs 'sid' and 'desc' to look up an sample in SBEAMS\n");
	}

        my $sql = qq~
		SELECT solexa_sample_id
		FROM $TBST_SOLEXA_SAMPLE
		WHERE full_sample_name like '$desc'
		  AND RECORD_STATUS != 'D'
		AND slimseq_sample_id = '$sid'
		  AND RECORD_STATUS != 'D'
	~;

	my @rows = $sbeams->selectOneColumn($sql);

	if ($rows[0]) {
	  return $rows[0];
	} else {
	  return 0;
	}
}

###############################################################################
# check_sbeams_organism
# Requires organism name
# Returns SBEAMS organism ID or 0
###############################################################################
sub check_sbeams_organism {
	my $method = 'check_sbeams_organism';
	my $self = shift;
	my %args = @_;
	my $name = $args{"name"};

	unless ($name) {
	  confess(__PACKAGE__."::$method needs 'name' to look up an organism in SBEAMS\n");
	}

        my $sql = qq~
		SELECT organism_id
		FROM $TB_ORGANISM
		WHERE organism_name like '$name'
		  AND RECORD_STATUS != 'D'
		OR common_name like '$name'
		  AND RECORD_STATUS != 'D'
	~;

	my @rows = $sbeams->selectOneColumn($sql);

	if ($rows[0]) {
	  return $rows[0];
	} else {
	  return 0;
	}
}

###############################################################################
# check_sbeams_sample_prep_kit
# Requires slimseq_sample_prep_kit_id
# Returns SBEAMS sample_prep_kit ID or 0
###############################################################################
sub check_sbeams_sample_prep_kit {
	my $method = 'check_sbeams_sample_prep_kit';
	my $self = shift;
	my %args = @_;
	my $id = $args{"slimseq_sample_prep_kit_id"};

	unless ($id) {
	  confess(__PACKAGE__."::$method needs 'slimseq_sample_prep_kit_id' to look up a sample_prep_kit in SBEAMS\n");
	}

        my $sql = qq~
		SELECT solexa_sample_prep_kit_id
		FROM $TBST_SOLEXA_SAMPLE_PREP_KIT
		WHERE slimseq_sample_prep_kit_id = '$id'
		  AND RECORD_STATUS != 'D'
	~;

	my @rows = $sbeams->selectOneColumn($sql);

	if ($rows[0]) {
	  return $rows[0];
	} else {
	  return 0;
	}
}

###############################################################################
# check_sbeams_reference_genome
# Requires reference_genome name and sbeams organism_id
# Returns SBEAMS reference_genome ID or 0
###############################################################################
sub check_sbeams_reference_genome {
	my $method = 'check_sbeams_reference_genome';
	my $self = shift;
	my %args = @_;
	my $name = $args{"name"};
	my $org_id = $args{"org_id"};

	unless ($args{"name"} && $args{"org_id"}) {
	  confess(__PACKAGE__."::$method needs 'name' and 'org_id' to look up a reference_genome in SBEAMS\n");
	}

        my $sql = qq~
		SELECT solexa_reference_genome_id
		FROM $TBST_SOLEXA_REFERENCE_GENOME
		WHERE name like '$name'
                  AND organism_id = $org_id
		  AND RECORD_STATUS != 'D'
	~;

	my @rows = $sbeams->selectOneColumn($sql);

	if ($rows[0]) {
	  return $rows[0];
	} else {
	  return 0;
	}
}

###############################################################################
# check_sbeams_flow_cell_lane
# Requires flow_cell_lane slimseq id
# Returns SBEAMS flow_cell_lane ID or 0
###############################################################################
sub check_sbeams_flow_cell_lane {
	my $method = 'check_sbeams_flow_cell_lane';
	my $self = shift;
	my %args = @_;
	my $slimseq_fcl_id = $args{"slimseq_fcl_id"};

	unless ($args{"slimseq_fcl_id"}) {
	  confess(__PACKAGE__."::$method needs 'slimseq_fcl_id' to look up a flow_cell_lane in SBEAMS\n");
	}

        my $sql = qq~
		SELECT flow_cell_lane_id
		FROM $TBST_SOLEXA_FLOW_CELL_LANE
		WHERE slimseq_flow_cell_lane_id = '$slimseq_fcl_id'
		  AND RECORD_STATUS != 'D'
	~;

	my @rows = $sbeams->selectOneColumn($sql);

	if ($rows[0]) {
	  return $rows[0];
	} else {
	  return 0;
	}
}

###############################################################################
# check_sbeams_flow_cell
# Requires flow_cell slimseq id
# Returns SBEAMS flow_cell ID or 0
###############################################################################
sub check_sbeams_flow_cell {
	my $method = 'check_sbeams_flow_cell';
	my $self = shift;
	my %args = @_;
	my $slimseq_fc_id = $args{"slimseq_fc_id"};

	unless ($args{"slimseq_fc_id"}) {
	  confess(__PACKAGE__."::$method needs 'slimseq_fc_id' to look up a flow_cell in SBEAMS\n");
	}

        my $sql = qq~
		SELECT flow_cell_id
		FROM $TBST_SOLEXA_FLOW_CELL
		WHERE slimseq_flow_cell_id = '$slimseq_fc_id'
		  AND RECORD_STATUS != 'D'
	~;

	my @rows = $sbeams->selectOneColumn($sql);

	if ($rows[0]) {
	  return $rows[0];
	} else {
	  return 0;
	}
}

###############################################################################
# check_sbeams_instrument
# Requires instrument slimseq id
# Returns SBEAMS instrument ID or 0
###############################################################################
sub check_sbeams_instrument {
	my $method = 'check_sbeams_instrument';
	my $self = shift;
	my %args = @_;
	my $slimseq_instrument_id = $args{"slimseq_instrument_id"};

	unless ($args{"slimseq_instrument_id"}) {
	  confess(__PACKAGE__."::$method needs 'slimseq_instrument_id' to look up a instrument in SBEAMS\n");
	}

        my $sql = qq~
		SELECT solexa_instrument_id
		FROM $TBST_SOLEXA_INSTRUMENT
		WHERE slimseq_instrument_id = '$slimseq_instrument_id'
		  AND RECORD_STATUS != 'D'
	~;

	my @rows = $sbeams->selectOneColumn($sql);

	if ($rows[0]) {
	  return $rows[0];
	} else {
	  return 0;
	}
}

###############################################################################
# check_sbeams_solexa_run
# Requires solexa_run slimseq id
# Returns SBEAMS solexa_run ID or 0
###############################################################################
sub check_sbeams_solexa_run {
	my $method = 'check_sbeams_solexa_run';
	my $self = shift;
	my %args = @_;
	my $sbeams_fc_id = $args{"sbeams_fc_id"};
	my $sbeams_instrument_id = $args{"sbeams_instrument_id"};

	unless ($args{"sbeams_fc_id"} && $args{"sbeams_instrument_id"}) {
	  confess(__PACKAGE__."::$method needs 'sbeams_fc_id' and 'sbeams_instrument_id' to look up a solexa_run in SBEAMS\n");
	}

        my $sql = qq~
		SELECT solexa_run_id
		FROM $TBST_SOLEXA_RUN
		WHERE flow_cell_id = '$sbeams_fc_id'
                  AND solexa_instrument_id = '$sbeams_instrument_id'
		  AND RECORD_STATUS != 'D'
	~;

	my @rows = $sbeams->selectOneColumn($sql);

	if ($rows[0]) {
	  return $rows[0];
	} else {
	  return 0;
	}
}

###############################################################################
# check_sbeams_flow_cell_lane_to_sample
# Requires sbeams_fcl_id and sbeams_sample_id
# Returns SBEAMS solexa_sample_id and flow_cell_lane id from solexa_flow_cell_lane_samples linker table or 0
###############################################################################
sub check_sbeams_flow_cell_lane_to_sample {
	my $method = 'check_sbeams_flow_cell_lane_to_sample';
	my $self = shift;
	my %args = @_;
	my $sbeams_fcl_id = $args{"sbeams_fcl_id"};
	my $sbeams_sample_id = $args{"sbeams_sample_id"};

	unless ($args{"sbeams_fcl_id"} && $args{"sbeams_sample_id"}) {
	  confess(__PACKAGE__."::$method needs 'slimseq_fcl_id' and 'sbeams_sample_id' to look up a flow_cell_lane_to_sample in SBEAMS\n");
	}

	my $sql = qq~
		SELECT solexa_sample_id, flow_cell_lane_id
		FROM $TBST_SOLEXA_FLOW_CELL_LANE_SAMPLES
		WHERE flow_cell_lane_id = '$sbeams_fcl_id'
		  AND solexa_sample_id = '$sbeams_sample_id'
		  AND RECORD_STATUS != 'D'
	~;

	my @rows = $sbeams->selectSeveralColumns($sql);

	if ($rows[0] && $rows[1]) {
	  return ($rows[0], $rows[1]);
	} else {
	  return (0,0);
	}
}

###############################################################################
# check_sbeams_file_path
# Requires file_path
# Returns SBEAMS file_path ID or 0
###############################################################################
sub check_sbeams_file_path {
	my $method = 'check_sbeams_file_path';
	my $self = shift;
	my %args = @_;
	my $file_path = $args{"file_path"};

	unless ($args{"file_path"}) {
	  confess(__PACKAGE__."::$method needs 'file_path' to look up a file_path in SBEAMS\n");
	}

        my $sql = qq~
		SELECT file_path_id
		FROM $TBST_FILE_PATH
		WHERE file_path = '$file_path'
		  AND RECORD_STATUS != 'D'
	~;

	my @rows = $sbeams->selectOneColumn($sql);

	if ($rows[0]) {
	  return $rows[0];
	} else {
	  return 0;
	}
}

###############################################################################
# check_sbeams_server
# Requires server_name
# Returns SBEAMS server ID or 0
###############################################################################
sub check_sbeams_server {
	my $method = 'check_sbeams_server';
	my $self = shift;
	my %args = @_;
	my $server_name = $args{"server_name"};

	unless ($args{"server_name"}) {
	  confess(__PACKAGE__."::$method needs 'server_name' to look up a server in SBEAMS\n");
	}

        my $sql = qq~
		SELECT server_id
		FROM $TBST_SERVER
		WHERE server_name = '$server_name'
		  AND RECORD_STATUS != 'D'
	~;

	my @rows = $sbeams->selectOneColumn($sql);

	if ($rows[0]) {
	  return $rows[0];
	} else {
	  return 0;
	}
}



###############################################################################
# check_sbeams_pipeline_results
# Requires flow cell lane id, eland output file, summary file, raw data path
# Returns SBEAMS pipeline_results ID or 0
###############################################################################
sub check_sbeams_pipeline_results {
	my $method = 'check_sbeams_pipeline_results';
	my $self = shift;
	my %args = @_;
	my $sbeams_fcl_id = $args{"sbeams_fcl_id"};
	my $eland_output_id = $args{"eland_output_file_id"};
        my $summary_file_id = $args{"summary_file_id"};
        my $raw_data_path_id = $args{"raw_data_path_id"};

	unless ($args{"sbeams_fcl_id"} && $args{"eland_output_file_id"} && $args{"summary_file_id"} && $args{"raw_data_path_id"}) {
	  confess(__PACKAGE__."::$method needs 'sbeams_fcl_id', 'eland_output_file_id', 'summary_file_id' and 'raw_data_path_id' to look up a pipeline_results in SBEAMS\n");
	}

        my $sql = qq~
		SELECT solexa_pipeline_results_id
		FROM $TBST_SOLEXA_PIPELINE_RESULTS
		WHERE flow_cell_lane_id = '$sbeams_fcl_id'
                  AND eland_output_file_id = '$eland_output_id'
                  AND summary_file_id = '$summary_file_id'
                  AND raw_data_path_id = '$raw_data_path_id'
		  AND RECORD_STATUS != 'D'
	~;

	my @rows = $sbeams->selectOneColumn($sql);

	if ($rows[0]) {
	  return $rows[0];
	} else {
	  return 0;
	}
}





###############################################################################################################
### GET FUNCTIONS - retrieve values from the SBEAMS database
###############################################################################################################

###############################################################################
# get_sbeams_restriction_enzyme_motif
# Requires enzyme (name)
# Returns SBEAMS restriction enzyme motif or undef
###############################################################################
sub get_sbeams_restriction_enzyme_motif {
	my $method = 'get_sbeams_restriction_enzyme_motif';
	my $self = shift;
	my %args = @_;
	my $enzyme = $args{"enzyme"};
print "enzyme in get_sbeams_restriction_enzyme_motif $enzyme\n";
	unless ($args{"enzyme"}) {
	  confess(__PACKAGE__."::$method needs 'enzyme' to look up a restriction_enzyme_motif in SBEAMS\n");
	}

        my $sql = qq~
		SELECT motif
		FROM $TBST_RESTRICTION_ENZYME
		WHERE name like '$enzyme'
		  AND RECORD_STATUS != 'D'
	~;

	my @rows = $sbeams->selectOneColumn($sql);

	if ($rows[0]) {
	  return $rows[0];
	} else {
	  return undef;
	}
}



###############################################################################################################
### INSERT FUNCTIONS - insert something into the SBEAMS database
###############################################################################################################

###############################################################################
# insert_project
# Requires Project Tag and Project Name and contact_id
# Returns SBEAMS project ID or error message (string)
###############################################################################
sub insert_project {
  my $method = 'insert_project';
  my $self = shift;
  my %args = @_;

  my $project_tag = $args{"tag"};
  my $project_name = $args{"name"};
  my $contact_id = $args{"contact_id"};

  unless ($project_name && $project_tag && $contact_id) {
    confess(__PACKAGE__."::$method needs 'name', 'tag', and 'contact_id' to insert a project in SBEAMS\n");
  }

  my $rowdata_ref = {
        name => $project_name,
        project_tag => $project_tag,
        PI_contact_id => $contact_id,
        description => 'TBD',
        budget => 'NA',
        comment => 'This record was automatically created based on a SLIMseq record by LoadSolexa.'
  };

  if ($self->debug) {
        print "SQL DATA FOR PROJECT INSERT\n";
        print Dumper($rowdata_ref);
  }

  my $project_id = $sbeams->updateOrInsertRow(
        table_name=>$TB_PROJECT,
        rowdata_ref => $rowdata_ref,
        PK=>'project_id',
        return_PK=>1,
        insert=>1,
        verbose=>$self->verbose,
        testonly=>$self->testonly,
        add_audit_parameters=>1,
  );

  unless ($project_id) {
        return "ERROR: COULD NOT ENTER PROJECT FOR PROJECT NAME '".$project_name."'\n";
  }

  return $project_id;
}

###############################################################################
# insert_sample_prep_kit
# Requires name and restriction_enzyme
# Returns SBEAMS sample_prep_kit ID or error message (string)
###############################################################################
sub insert_sample_prep_kit {
  my $method = 'insert_sample_prep_kit';
  my $self = shift;
  my %args = @_;

  my $slimseq_spk_id = $args{"slimseq_spk_id"};
  my $sample_prep_kit_name = $args{"name"};
  my $restriction_enzyme = $args{"restriction_enzyme"};
  $restriction_enzyme = 'NULL' if !$restriction_enzyme;

  unless ($sample_prep_kit_name && $slimseq_spk_id) {
    confess(__PACKAGE__."::$method needs 'slimseq_spk_id' and 'name' to insert a sample_prep_kit in SBEAMS\n");
  }

  my $motif = $self->get_sbeams_restriction_enzyme_motif("enzyme" => $restriction_enzyme) if $restriction_enzyme ne 'NULL'; 
  if (!$motif) { $motif = 'NULL'; }

  my $rowdata_ref = {
	slimseq_sample_prep_kit_id => $slimseq_spk_id,
        name => $sample_prep_kit_name,
        restriction_enzyme => $restriction_enzyme,
        restriction_enzyme_motif => $motif
  };

  if ($self->debug) {
        print "SQL DATA FOR SAMPLE PREP KIT INSERT\n";
        print Dumper($rowdata_ref);
  }

  my $sample_prep_kit_id = $sbeams->updateOrInsertRow(
        table_name=>$TBST_SOLEXA_SAMPLE_PREP_KIT,
        rowdata_ref => $rowdata_ref,
        PK=>'solexa_sample_prep_kit_id',
        return_PK=>1,
        insert=>1,
        verbose=>$self->verbose,
        testonly=>$self->testonly,
        add_audit_parameters=>1,
  );

  unless ($sample_prep_kit_id) {
        return "ERROR: COULD NOT ENTER SAMPLE PREP KIT FOR KIT NAMED '".$sample_prep_kit_name."'\n";
  }

  return $sample_prep_kit_id;
}

###############################################################################
# insert_reference_genome
# Requires name and restriction_enzyme
# Returns SBEAMS reference_genome ID or error message (string)
###############################################################################
sub insert_reference_genome {
  my $method = 'insert_reference_genome';
  my $self = shift;
  my %args = @_;

  my $name = $args{"name"};
  my $sbeams_org_id = $args{"org_id"};

  unless ($args{"name"} && $args{"org_id"}) {
    confess(__PACKAGE__."::$method needs 'org_id' and 'name' to insert a reference_genome in SBEAMS\n");
  }

  my $rowdata_ref = {
	organism_id => $sbeams_org_id,
        name => $name,
  };

  if ($self->debug) {
        print "SQL DATA FOR REFERENCE GENOME INSERT\n";
        print Dumper($rowdata_ref);
  }

  my $reference_genome_id = $sbeams->updateOrInsertRow(
        table_name=>$TBST_SOLEXA_REFERENCE_GENOME,
        rowdata_ref => $rowdata_ref,
        PK=>'solexa_reference_genome_id',
        return_PK=>1,
        insert=>1,
        verbose=>$self->verbose,
        testonly=>$self->testonly,
        add_audit_parameters=>1,
  );

  unless ($reference_genome_id) {
        return "ERROR: COULD NOT ENTER REFERENCE GENOME FOR GENOME NAMED '".$name."'\n";
  }

  return $reference_genome_id;
}



###############################################################################
# insert_sample
# Requires Sample Tag and Sample Name and contact_id
# Returns SBEAMS sample ID or error message (string)
###############################################################################
sub insert_sample {
  my $method = 'insert_sample';
  my $self = shift;
  my %args = @_;
  print "SAMPLE IN INSERT SAMPLE\n";
  print Dumper \%args;

  #unless ($sample_name && $sample_tag && $contact_id) {
  #  confess(__PACKAGE__."::$method needs 'name', 'tag', and 'contact_id' to insert a sample in SBEAMS\n");
  #}

  my $rowdata_ref = {
	slimseq_sample_id		=> $args{"id"},
	slimseq_project_id		=> $args{"slimseq_project_id"},
	project_id			=> $args{"sbeams_project_id"},
	sample_tag			=> $args{"name_on_tube"},
	full_sample_name		=> $args{"sample_description"},
	organism_id			=> $args{"sbeams_organism_id"},
	solexa_sample_prep_kit_id	=> $args{"solexa_spk_id"},
	solexa_reference_genome_id	=> $args{"solexa_reference_genome_id"},
	sample_preparation_date		=> $args{"submission_date"},
	insert_size			=> $args{"insert_size"},
	alignment_start_position	=> $args{"alignment_start_position"},
	alignment_end_position		=> $args{"alignment_end_position"},
        comment => 'This record was automatically created based on a SLIMseq record by LoadSolexa.'
  };

  if ($self->debug) {
        print "SQL DATA FOR SAMPLE INSERT\n";
        print Dumper($rowdata_ref);
  }

  my $sample_id = $sbeams->updateOrInsertRow(
        table_name=>$TBST_SOLEXA_SAMPLE,
        rowdata_ref => $rowdata_ref,
        PK=>'sample_id',
        return_PK=>1,
        insert=>1,
        verbose=>$self->verbose,
        testonly=>$self->testonly,
        add_audit_parameters=>1,
  );

  unless ($sample_id) {
        return "ERROR: COULD NOT ENTER SAMPLE FOR SAMPLE NAME '".$args{"id"}."'\n";
  }

  return $sample_id;
}

###############################################################################
# insert_flow_cell
# Requires slimseq_flow_cell_id, name, date_generated
# Returns SBEAMS flow_cell ID or error message (string)
###############################################################################
sub insert_flow_cell {
  my $method = 'insert_flow_cell';
  my $self = shift;
  my %args = @_;

  my $name = $args{"name"};
  my $date_generated = $args{"date_generated"};
  my $slimseq_flow_cell_id = $args{"id"};

  unless ($args{"name"} && $args{"date_generated"} && $args{"id"}) {
    confess(__PACKAGE__."::$method needs 'date_generated', 'id', and 'name' to insert a flow_cell in SBEAMS\n");
  }

  my $rowdata_ref = {
	slimseq_flow_cell_id => $slimseq_flow_cell_id,
        name => $name,
	date_generated => $date_generated
  };

  if ($self->debug) {
        print "SQL DATA FOR FLOW CELL INSERT\n";
        print Dumper($rowdata_ref);
  }

  my $flow_cell_id = $sbeams->updateOrInsertRow(
        table_name=>$TBST_SOLEXA_FLOW_CELL,
        rowdata_ref => $rowdata_ref,
        PK=>'flow_cell_id',
        return_PK=>1,
        insert=>1,
        verbose=>$self->verbose,
        testonly=>$self->testonly,
        add_audit_parameters=>1,
  );

  unless ($flow_cell_id) {
        return "ERROR: COULD NOT ENTER SOLEXA FLOW CELL FOR FLOW CELL NAMED '".$name."' with id $slimseq_flow_cell_id\n";
  }

  return $flow_cell_id;
}


###############################################################################
# insert_instrument
# Requires name
# Returns SBEAMS instrument ID or error message (string)
###############################################################################
sub insert_instrument {
  my $method = 'insert_instrument';
  my $self = shift;
  my %args = @_;

  my $name = $args{"name"};
  my $instrument_version = $args{"instrument_version"};
  my $serial_number = $args{"serial_number"};
  my $slimseq_instrument_id = $args{"id"};

  unless ($args{"name"} && $args{"instrument_version"} && $args{"serial_number"} && $args{"id"}) {
    confess(__PACKAGE__."::$method needs 'instrument_version', 'serial_number', 'id', and 'name' to insert a instrument in SBEAMS\n");
  }

  my $rowdata_ref = {
	slimseq_instrument_id => $slimseq_instrument_id,
	instrument_version => $instrument_version,
        name => $name,
	serial_number => $serial_number
  };

  if ($self->debug) {
        print "SQL DATA FOR INSTRUMENT INSERT\n";
        print Dumper($rowdata_ref);
  }

  my $instrument_id = $sbeams->updateOrInsertRow(
        table_name=>$TBST_SOLEXA_INSTRUMENT,
        rowdata_ref => $rowdata_ref,
        PK=>'solexa_instrument_id',
        return_PK=>1,
        insert=>1,
        verbose=>$self->verbose,
        testonly=>$self->testonly,
        add_audit_parameters=>1,
  );

  unless ($instrument_id) {
        return "ERROR: COULD NOT ENTER SOLEXA INSTRUMENT FOR INSTRUMENT NAMED '".$name."' with id $slimseq_instrument_id\n";
  }

  return $instrument_id;
}

###############################################################################
# insert_solexa_run
# Requires sbeams_flow_cell_id and sbeams_instrument_id
# Returns SBEAMS solexa_run ID or error message (string)
###############################################################################
sub insert_solexa_run {
  my $method = 'insert_solexa_run';
  my $self = shift;
  my %args = @_;

  my $sbeams_flow_cell_id = $args{"sbeams_fc_id"};
  my $sbeams_instrument_id = $args{"sbeams_instrument_id"};

  unless ($args{"sbeams_fc_id"} && $args{"sbeams_instrument_id"}) {
    confess(__PACKAGE__."::$method needs 'sbeams_instrument_id' and 'sbeams_fc_id' to insert a solexa_run in SBEAMS\n");
  }

  my $rowdata_ref = {
        flow_cell_id => $sbeams_flow_cell_id,
	solexa_instrument_id => $sbeams_instrument_id
  };

  if ($self->debug) {
        print "SQL DATA FOR SOLEXA RUN INSERT\n";
        print Dumper($rowdata_ref);
  }

  my $solexa_run_id = $sbeams->updateOrInsertRow(
        table_name=>$TBST_SOLEXA_RUN,
        rowdata_ref => $rowdata_ref,
        PK=>'solexa_run_id',
        return_PK=>1,
        insert=>1,
        verbose=>$self->verbose,
        testonly=>$self->testonly,
        add_audit_parameters=>1,
  );

  unless ($solexa_run_id) {
        return "ERROR: COULD NOT ENTER SOLEXA RUN WITH FLOW CELL ID ".$sbeams_flow_cell_id."' AND INSTRUMENT ID $sbeams_instrument_id\n";
  }

  return $solexa_run_id;
}

###############################################################################
# insert_flow_cell_lane
# Requires sbeams_fc_id, id (goes to slimseq_flow_cell_lane_id), lane number,
#     starting concentration, loaded concentration and status
# Returns SBEAMS flow_cell_lane ID or error message (string)
###############################################################################
sub insert_flow_cell_lane {
  my $method = 'insert_flow_cell_lane';
  my $self = shift;
  my %args = @_;

  my $slimseq_flow_cell_lane_id = $args{"id"};
  my $sbeams_fc_id = $args{"sbeams_fc_id"};
  my $lane_number = $args{"lane_number"};
  my $start_conc = $args{"starting_concentration"};
  my $loaded_conc = $args{"loaded_concentration"};
  my $status = $args{"status"};

  my $err;
  for my $param ( qw( status loaded_concentration starting_concentration lane_number sbeams_fc_id id) ) {
    unless ( defined $args{$param} ) {
      $err = ( $err ) ? $err . ', '.$param : "Missing required param(s) $param";
    }
  }
  confess(__PACKAGE__."::$method ".$err."\n") if $err;

  my $rowdata_ref = {
	slimseq_flow_cell_lane_id => $slimseq_flow_cell_lane_id,
	flow_cell_id => $sbeams_fc_id,
	lane_number => $lane_number,
	starting_concentration => $start_conc,
	loaded_concentration => $loaded_conc,
	status => $status
  };

  if ($self->debug) {
        print "SQL DATA FOR FLOW CELL LANE INSERT\n";
        print Dumper($rowdata_ref);
  }

  my $flow_cell_lane_id = $sbeams->updateOrInsertRow(
        table_name=>$TBST_SOLEXA_FLOW_CELL_LANE,
        rowdata_ref => $rowdata_ref,
        PK=>'flow_cell_lane_id',
        return_PK=>1,
        insert=>1,
        verbose=>$self->verbose,
        testonly=>$self->testonly,
        add_audit_parameters=>1,
  );

  unless ($flow_cell_lane_id) {
        return "ERROR: COULD NOT ENTER SOLEXA FLOW CELL LANE FOR FLOW CELL LANE WITH SLIMSEQ ID $slimseq_flow_cell_lane_id\n";
  }

  return $flow_cell_lane_id;
}

###############################################################################
# insert_flow_cell_lane_to_sample
# Requires sbeams_fc_id, id (goes to slimseq_flow_cell_lane_to_sample_id), lane number,
#     starting concentration, loaded concentration and status
# Returns SBEAMS flow_cell_lane_to_sample ID or error message (string)
###############################################################################
sub insert_flow_cell_lane_to_sample {
  my $method = 'insert_flow_cell_lane_to_sample';
  my $self = shift;
  my %args = @_;

  my $sbeams_fcl_id = $args{"sbeams_fcl_id"};
  my $sbeams_sample_id = $args{"sbeams_sample_id"};

  unless ($args{"sbeams_fcl_id"} && $args{"sbeams_sample_id"}) {
    confess(__PACKAGE__."::$method needs 'sbeams_sample_id' and 'sbeams_fcl_id' to create a solexa_flow_cell_lane_samples entry in SBEAMS\n");
  }

  my $rowdata_ref = {
	solexa_sample_id => $sbeams_sample_id,
	flow_cell_lane_id => $sbeams_fcl_id
  };

  if ($self->debug) {
        print "SQL DATA FOR FLOW CELL LANE SAMPLES INSERT\n";
        print Dumper($rowdata_ref);
  }

  my $success = $sbeams->updateOrInsertRow(
        table_name=>$TBST_SOLEXA_FLOW_CELL_LANE_SAMPLES,
        rowdata_ref => $rowdata_ref,
        insert=>1,
        verbose=>$self->verbose,
        testonly=>$self->testonly,
        add_audit_parameters=>1,
  );

  unless ($success) {
        return "ERROR: ADDING ENTRY TO SOLEXA_FLOW_CELL_LANE_SAMPLES FAILED - $success\n";
  }

  return ($sbeams_sample_id, $sbeams_fcl_id);
}

###############################################################################
# insert_file_path
# Requires server_id, file_path_name, fie_path_desc, file_path 
# Returns SBEAMS file_path ID or error message (string)
###############################################################################
sub insert_file_path {
  my $method = 'insert_file_path';
  my $self = shift;
  my %args = @_;

  my $file_path = $args{"file_path"};
  my $name = $args{"file_path_name"};
  my $desc = $args{"file_path_desc"};
  my $server_id = $args{"server_id"};

  my $err;
  for my $param ( qw( file_path file_path_name file_path_desc server_id) ) {
    unless ( defined $args{$param} ) {
      $err = ( $err ) ? $err . ', '.$param : "Missing required param(s) $param";
    }
  }
  confess(__PACKAGE__."::$method ".$err."\n") if $err;

  my $rowdata_ref = {
	"file_path" => $file_path,
	"file_path_name" => $name,
	"file_path_desc" => $desc,
	"server_id" => $server_id
  };

  if ($self->debug) {
        print "SQL DATA FOR FILE_PATH INSERT\n";
        print Dumper($rowdata_ref);
  }

  my $file_path_id = $sbeams->updateOrInsertRow(
        table_name=>$TBST_FILE_PATH,
        rowdata_ref => $rowdata_ref,
        PK=>'file_path_id',
        return_PK=>1,
        insert=>1,
        verbose=>$self->verbose,
        testonly=>$self->testonly,
        add_audit_parameters=>1,
  );

  unless ($file_path_id) {
        return "ERROR: COULD NOT ENTER FILE_PATH FOR FILE PATH $file_path NAMED $name LOCATED ON SERVER $server_id\n";
  }

  return $file_path_id;
}

###############################################################################
# insert_pipeline_results
# Requires server_id, pipeline_results_name, fie_path_desc, pipeline_results 
# Returns SBEAMS pipeline_results ID or error message (string)
###############################################################################
sub insert_pipeline_results {
  my $method = 'insert_pipeline_results';
  my $self = shift;
  my %args = @_;

  my $sbeams_fcl_id = $args{"sbeams_fcl_id"};
  my $eland_output_id = $args{"eland_output_file_id"};
  my $summary_file_id = $args{"summary_file_id"};
  my $raw_data_path_id = $args{"raw_data_path_id"};
  my $slimseq_updated_at = $args{"slimseq_updated_at"};
  my $slimseq_status = $args{"slimseq_status"};

  unless ($args{"sbeams_fcl_id"} && $args{"eland_output_file_id"} && $args{"summary_file_id"} && $args{"raw_data_path_id"} && $args{"slimseq_updated_at"} && $args{"slimseq_status"}) {
    confess(__PACKAGE__."::$method needs 'sbeams_fcl_id', 'eland_output_file_id', 'summary_file_id', 'raw_data_path_id', 'slimseq_updated_at', and 'slimseq_status' to insert a pipeline_results in SBEAMS\n");
  }

  my $rowdata_ref = {
	"flow_cell_lane_id"    => $sbeams_fcl_id,
	"summary_file_id"      => $summary_file_id,
	"eland_output_file_id" => $eland_output_id,
	"raw_data_path_id"     => $raw_data_path_id,
	"slimseq_updated_at"   => $slimseq_updated_at,
	"slimseq_status"   => $slimseq_status
  };

  if ($self->debug) {
        print "SQL DATA FOR PIPELINE RESULTS INSERT\n";
        print Dumper($rowdata_ref);
  }

  my $pipeline_results_id = $sbeams->updateOrInsertRow(
        table_name=>$TBST_SOLEXA_PIPELINE_RESULTS,
        rowdata_ref => $rowdata_ref,
        PK=>'solexa_pipeline_results_id',
        return_PK=>1,
        insert=>1,
        verbose=>$self->verbose,
        testonly=>$self->testonly,
        add_audit_parameters=>1,
  );

  unless ($pipeline_results_id) {
        return "ERROR: COULD NOT ENTER SOLEXA PIPELINE RESULTS FOR FLOW CELL LANE $sbeams_fcl_id WITH SUMMARY FILE ID $summary_file_id ELAND OUTPUT FILE ID $eland_output_id AND RAW DATA PATH ID $raw_data_path_id\n";
  }

  return $pipeline_results_id;
}




}#Close of package bracket 
1;




