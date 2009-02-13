###############################################################################
# Program     : SBEAMS::SolexaTrans::Solexa
# Author      : Denise Mauldin <dmauldin@systemsbiology.org>
#
# Description : Object representation of single Solexa run
# 
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
#
###############################################################################


{package SBEAMS::SolexaTrans::Solexa;

our $VERSION = '1.00';

=head1 NAME

SBEAMS::SolexaTrans::Solexa- Class to contain information about Solexa runs



=head1 SYNOPSIS

  $sbeams_solexa = new SBEAMS::SolexaTrans::Solexa;		#make an instance of a Solexa obj to use for finding all the objects to be made
  
 #make more $solexa_o to hold data describing a single run/sample pair
 
 foreach my $solexa_o ($sbeams_solexa->registered) {
 	#read data from the solexa_o and use the information some how
}
 	

=head1 DESCRIPTION

Instances of this class are used to hold information about a single run (one per flow cell) and sample pair.  As the script load_solexatrans.pl is finding groups of solexa files that belong together it will create new Solexa objects to hold the data needed to upload into the SBEAMS database.  For example the objects will store the project_id, user_id, root_file names, sample_name and so on.
The class contains a plethora of simple getter and setters for entering and reading data.  Most method names are created by having the prefix <set or get><database table_name symbol><table column name>.  Therefore most of the data these objects hold are database id's ie PK and FK.


=head2 EXPORT

None by default.

=head1 SEE ALSO

SBEAMS::SolexaTrans::Solexa_file_groups;
lib/scripts/SolexaTrans/load_solexatrans.pl

=head1 AUTHOR

Denise Mauldin<lt>dmauldin@systemsbiology.org<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 by Pat Moss

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.3 or,
at your option, any later version of Perl 5 you may have available.


=cut

use strict;
use vars qw(%REGISTRY $sbeams);

use SBEAMS::Connection::Tables;
use SBEAMS::Connection qw( $log );
use SBEAMS::SolexaTrans::Tables;
use SBEAMS::BioLink::Tables;

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
	
	$REGISTRY{$self} = $self;	#also returns $self
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
#######################################################
# registered
# Make a list of all the instances made and return a sorted list by the root_name
#######################################################
sub registered{
	my $either = shift;

	#not interested in collecting the keys since they are just stringifed object refs.  
	#Values returns a list (key, value) but grep is only 
	#accepting one value which should be the last value in the list
	my @all_solexa_objects = grep {ref()} values %REGISTRY;		
	
	return _sorted_solexa_objects(@all_solexa_objects);;

}

#######################################################
# _sorted_solexa_objects
# private method to sort the instances by their root_name
#######################################################
sub _sorted_solexa_objects{
  no warnings; # Turn off warnings for this block...
	my @objects = @_;
	 
	my @sorted_objects =  map { $_->[0]}
									#element [0] should be the object
				sort {	my $a_date      = $$a[1];	#should be the YYYYMMDD
					my $a_scan_numb = $$a[2];	#should be the scan number
					
					my $b_date      = $$b[1];
					my $b_scan_numb = $$b[2];
				 
				 	$a_date	<=> $b_date
						||
					$a_scan_numb <=> $b_scan_numb
						||
					$$a[0] cmp $$b[0]	
				 
				 }
				 
				map { [$_, (split /_/, $_->get_sr_file_root) ]} @objects;	# example root file name '20040609_03_LPS1-60'
		
	return @sorted_objects;

}


###################################################################################################
#Here comes the getter and setters    

##################################################################################################
#set get pair:sr_user_id
#######################################################
# set_sr_user_id
# user id associated with a group of solexa runs usually taken from the MAGE XML 
#######################################################
sub set_sr_user_id { 
	my $method = 'set_user_name';
	
	my $self = shift;
	my $name = shift;
	confess(__PACKAGE__ . "::$method No user id provided '$name'\n") unless ($name =~ /^\d/);
	
	return $self->{USER_ID} = $name;
}

#######################################################
# get_sr_user_id
# user name associated with a group of solexa run files usually taken from the MAGE XML 
#######################################################
	
sub get_sr_user_id {
	my $self = shift;
	return $self->{USER_ID};
}	

#######################################################
# set_solexa_id
# solexa_id 
#######################################################
sub set_solexa_id { 
	my $method = 'set_solexa_id';
	
	my $self = shift;
	my $name = shift;
	confess(__PACKAGE__ . "::$method No solexa_id provided '$name'\n") unless ($name =~ /^\d/);
	
	return $self->{SOLEXA_ID} = $name;
}

#######################################################
# get_solexa_id
# solexa_id
#######################################################
	
sub get_solexa_id {
	my $self = shift;
	return $self->{SOLEXA_ID};
}



##################################################################################################
#set get pair:ss_sample_group_name
#######################################################
# set_ss_sample_group_name
# Sample Group Name taken from the MAGE XML file 
#######################################################
sub set_ss_sample_group_name {
	my $method = 'set_ss_sample_group_name';
	
	my $self = shift;
	my $name = shift;
	confess(__PACKAGE__ . "::$method No sample name provided '$name'\n") unless ($name =~ /^[\w+-]/);
	
	return $self->{SAMPLE_GROUP_NAME} = $name;
}

#######################################################
# get_ss_sample_group_name
# Sample Group Name taken from the MAGE XML file 
#######################################################
	
sub get_ss_sample_group_name {
	my $self = shift;
	return $self->{SAMPLE_GROUP_NAME};
}	

##################################################################################################
#set get pair:ss_sample_tag
#######################################################
# set_ss_sample_tag
# Sample Tag taken from the root file name
#######################################################
sub set_ss_sample_tag {
	my $method = 'set_ss_sample_tag';
	
	my $self = shift;
	my $name = shift;
	confess(__PACKAGE__ . "::$method No sample name provided '$name'\n") unless ($name =~ /^[\w+-]/);
	
	return $self->{SAMPLE_TAG} = $name;
}

#######################################################
# get_ss_sample_tag
# Sample Tag taken from the root file name
#######################################################
	
sub get_ss_sample_tag {
	my $self = shift;
	return $self->{SAMPLE_TAG};
}

##################################################################################################
#set get pair:ss_solexa_sample_id
#######################################################
# set_ss_solexa_sample_id
# Solexa sample id
#######################################################
sub set_ss_solexa_sample_id {
	my $method = 'set_ss_solexa_sample_id';
	
	my $self = shift;
	my $name = shift;
	confess(__PACKAGE__ . "::$method No solexa sample id provided '$name'\n") unless ($name =~ /^\d/);
	
	return $self->{SAMPLE_ID} = $name;
}

#######################################################
# get_ss_solexa_sample_id
# Solexa sample id
#######################################################
	
sub get_ss_solexa_sample_id {
	my $self = shift;
	return $self->{SAMPLE_ID};
}


##################################################################################################
#set get pair:ss_project_id
#######################################################
# set_ss_project_id
#Project id associated with a group of solexa runs usually taken from the MAGE XML 
#######################################################
sub set_ss_project_id {
	my $method = 'set_ss_project_id';
	
	my $self = shift;
	my $name = shift;
	confess(__PACKAGE__ . "::$method No project id provided '$name'\n") unless ($name =~ /^\d/);
	
	return $self->{PROJECT_ID} = $name;
}

#######################################################
# get_ss_project_id
# project_id associated with a group of solexa runs usually taken from the MAGE XML 
#######################################################
	
sub get_ss_project_id {
	my $self = shift;
	return $self->{PROJECT_ID};
}

##################################################################################################
#set get pair:ss_project
#######################################################
# set_ss_project
# SolexaProject object
#######################################################
sub set_ss_project {
	my $method = 'set_ss_project';
	
	my $self = shift;
	my $name = shift;
	confess(__PACKAGE__ . "::$method No project provided '$name'\n") unless ($name =~ /^\d/);
	
	return $self->{PROJECT} = $name;
}

#######################################################
# get_ss_project
# SolexaProjec object
#######################################################
	
sub get_ss_project {
	my $self = shift;
	return $self->{PROJECT};
}

##################################################################################################
#set get pair:ss_organism_id
#######################################################
# set_ss_organism_id
# organism_id for a sample applied to a solexa run
#######################################################
sub set_ss_organism_id {
	my $method = 'set_ss_organism_id';
	
	my $self = shift;
	my $name = shift;
	confess(__PACKAGE__ . "::$method No Organism id provided '$name'\n") unless ($name =~ /^\w/);
	
	return $self->{ORGANISM_ID} = $name;
}

#######################################################
# get_ss_organism_id 
#  return the organism_id for a sample applied to a solexa run
#######################################################
	
sub get_ss_organism_id {
	my $self = shift;
	return $self->{ORGANISM_ID};
}	

##################################################################################################
#set get pair:organism
#######################################################
# set_organism
# organism for a sample applied to an array 
#######################################################
sub set_organism { 
	my $method = 'set_organism';
	
	my $self = shift;
	my $name = shift;
	confess(__PACKAGE__ . "::$method No Organism name provided '$name'\n") unless ($name =~ /^\w/);
	
	return $self->{ORGANISM_NAME} = $name;
}

#######################################################
# get_ss_organism
#  return the organism for a sample applied to an array 
#######################################################
	
sub get_organism {
	my $self = shift;
	return $self->{ORGANISM_NAME};
}


##################################################################################################
#set get pair:sr_file_root
#######################################################
# set_sr_file_root
# file_root name for a solexa run
#######################################################
sub set_sr_file_root { 
	my $method = 'set_sr_file_root';
	
	my $self = shift;
	my $name = shift;
	#confess(__PACKAGE__ . "::$method No file_root name provided '$name'\n") unless ($name =~ /^\w/);
	confess(__PACKAGE__ . "::$method No file_root name provided '$name'\n") unless ($name =~ /\w/);
	
	return $self->{ROOT_NAME} = $name;
}

#######################################################
# root_name
#  return the root file name for a solexa run
#######################################################
	
sub get_sr_file_root {
	my $self = shift;
	return $self->{ROOT_NAME} || '';
}	


##################################################################################################
#set get pair:sr_processed_date 
#######################################################
# set_sr_processed_date
# Set the file_date taken mainly from the MAGE XML file for the date of the run
#######################################################
sub set_sr_processed_date { 
	my $method = 'set_sr_processed_date';
	
	my $self = shift;
	my $name = shift;
	confess(__PACKAGE__ . "::$method No file date given '$name'\n") unless ($name =~ /^\w/);
	
	return $self->{FILE_DATE} = $name;
}

#######################################################
# get_sr_processed_date
#  Get the file_date taken mainly from the MAGE XML file for the date of the run
#######################################################
	
sub get_sr_processed_date {
	my $self = shift;
	return $self->{FILE_DATE};
}


##################################################################################################
#set get pair:sr_file_path_id
#######################################################
# set_sr_file_path_id
# Set the file_base_path which is every thing up to the root_file_name
#######################################################
sub set_sr_file_path_id { 
	my $method = 'set_sr_file_path_id';
	
	my $self = shift;
	my $name = shift;
	
	confess(__PACKAGE__ . "::$method No file path id given '$name'\n") unless ($name =~ /^\w/);
	
	return $self->{FILE_BASE_PATH} = $name;
}

#######################################################
# get_sr_file_path_id
#  Get the file_base_path which is every thing Upto the root_file_name
#######################################################
	
sub get_sr_file_path_id {
	my $self = shift;
	return $self->{FILE_BASE_PATH};
}

##################################################################################################
#set get pair:sr_solexa_run_protocol
#######################################################
# set_sr_solexa_run_protocol
# the solexa protocol which covers 
#######################################################
sub set_sr_solexa_run_protocol { 
	my $method = 'set_sr_solexa_run_protocol';
	
	my $self = shift;
	my $name = shift;
	
	confess(__PACKAGE__ . "::$method No run protocol '$name'\n") unless ($name =~ /^\w/);
	
	$self->append_protocol_id(value 		=> $name,
				  append_to_method 	=> 'sr_solexa_protocol_ids',
				  );
				  
	return $self->{SR_SOLEXA_RUN_PROTOCOL} = $name;
}

#######################################################
# get_sr_solexa_run_protocol
#  the solexa protocol which covers
#######################################################
sub get_sr_solexa_run_protocol {
	my $self = shift;
	return $self->{SR_SOLEXA_RUN_PROTOCOL};
}

##################################################################################################
#set get pair:sr_solexa_run_protocol_ids
#######################################################
# set_sr_solexa_run_protocol_ids
# Hold comma delimited list of ALL protocols used on a solexa run
#######################################################
sub set_sr_solexa_run_protocol_ids { 
	my $method = 'set_sr_solexa_run_protocol_ids';
	
	my $self = shift;
	my $name = shift;
	
	confess(__PACKAGE__ . "::$method No base solexa protocols given '$name'\n") unless ($name =~ /^\w/);
	
	return $self->{SR_SOLEXA_RUN_PROTOCOL_IDS} = $name;
}

#######################################################
# get_sr_solexa_run_protocol_ids
# Hold comma delimited list of protocols used on a solexa run
#######################################################
	
sub get_sr_solexa_run_protocol_ids {
	my $self = shift;
	return $self->{SR_SOLEXA_RUN_PROTOCOL_IDS};
}


##################################################################################################
#set get pair:ss_solexa_sample_protocol_ids
#######################################################
# set_ss_solexa_sample_protocol_ids
# Hold comma delimited list of ALL protocols used on solexa run samples
#######################################################
sub set_ss_solexa_sample_protocol_ids { 
	my $method = 'set_ss_solexa_sample_protocol_ids';
	
	my $self = shift;
	my $name = shift;
	
	confess(__PACKAGE__ . "::$method No protocol ids given '$name'\n") unless ($name =~ /^\w/);
	
	return $self->{SS_SOLEXA_SAMPLE_PROTOCOL_IDS} = $name;
}

#######################################################
# get_ss_solexa_sample_protocol_ids
# Hold comma delimited list of protocols used on a solexa run samples
#######################################################
	
sub get_ss_solexa_sample_protocol_ids {
	my $self = shift;
	return $self->{SS_SOLEXA_SAMPLE_PROTOCOL_IDS};
}

##################################################################################################
#set get pair:sr_comment
#######################################################
# set_sr_comment
# solexa run comment
#######################################################
sub set_sr_comment { 
	my $method = 'set_sr_comment';
	
	my $self = shift;
	my $name = shift;	
	return $self->{SR_COMMENT} = $name;
}

#######################################################
# get_sr_comment
# solexa run comment
#######################################################
	
sub get_sr_comment {
	my $self = shift;
	return $self->{SR_COMMENT};
}

#################################################################################################
#set get pair:sr_full_sample_name
#######################################################
# set_sr_full_sample_name
#######################################################
sub set_sr_full_sample_name { 
	my $self = shift;
	my $name = shift;
	return $self->{SR_FULL_SAMPLE_NAME} = $name;
}
#######################################################
# get_sr_full_sample_name
#######################################################	
sub get_sr_full_sample_name {
	my $self = shift;
	return $self->{SR_FULL_SAMPLE_NAME};
}

##################################################################################################
#set get pair:ss_strain_or_line
#######################################################
# set_ss_strain_or_line
#######################################################
sub set_ss_strain_or_line { 
	my $self = shift;
	my $name = shift;
	return $self->{SS_STRAIN_OR_LINE} = $name;
}
#######################################################
# get_ss_strain_or_line
#######################################################	
sub get_ss_strain_or_line {
	my $self = shift;
	return $self->{SS_STRAIN_OR_LINE};
}

##################################################################################################
#set get pair:individual
#######################################################
# set_ss_individual
#######################################################
sub set_ss_individual { 
	my $self = shift;
	my $name = shift;
	return $self->{SS_INDIVIDUAL} = $name;
}
#######################################################
# get_ss_individual
#######################################################	
sub get_ss_individual {
	my $self = shift;
	return $self->{SS_INDIVIDUAL};
}

##################################################################################################
#set get pair:ss_sex_ontology_term_id
#######################################################
# set_ss_sex_ontology_term_id
#######################################################
sub set_ss_sex_ontology_term_id { 
	my $self = shift;
	my $name = shift;
  return undef if !$name;
  if ( ! $self->{MGED_sex_terms} ) {
    $self->{MGED_sex_terms} = {};
    my $sql =<<"    END";
    SELECT MOT2.MGED_ontology_term_id, MOT2.name
    FROM $TBBL_MGED_ONTOLOGY_RELATIONSHIP MOR
    INNER JOIN $TBBL_MGED_ONTOLOGY_TERM MOT2 ON
          ( MOR.subject_term_id = MOT2.MGED_ontology_term_id )
    WHERE MOR.object_term_id in
    ( SELECT MGED_ontology_term_id FROM $TBBL_MGED_ONTOLOGY_TERM
      WHERE name = 'Sex' )
    AND MOT2.name IN ('male', 'female')
    ORDER BY MOT2.name
    END
    my @results = $sbeams->selectSeveralColumns( $sql );
    for my $result ( @results ) {
      my $sex = ucfirst( $result->[1] );
      $self->{MGED_sex_terms}->{$sex} = $result->[0];
    }
  }
  $name = ucfirst( $name );
  my $term_id = $self->{MGED_sex_terms}->{$name};
	$self->{SS_SEX} = $term_id;
  return $term_id;
}
#######################################################
# get_ss_sex_ontology_term_id
#######################################################	
sub get_ss_sex_ontology_term_id {
	my $self = shift;
	return $self->{SS_SEX};
}
##################################################################################################
#set get pair:ss_age
#######################################################
# set_ss_age
#######################################################
sub set_ss_age { 
	my $self = shift;
	my $name = shift;
	return $self->{SS_AGE} = $name;
}
#######################################################
# get_ss_age
#######################################################	
sub get_ss_age {
	my $self = shift;
	return $self->{SS_AGE};
}


#######################################################
#set/get pair:ss_organism_part
#######################################################
# set_ss_organism_part
#######################################################
sub set_ss_organism_part { 
  my $self = shift;
  my $name = shift;
  return $self->{SS_ORGANISM_PART} = $name;
}
#######################################################
# get_ss_organism_part
#######################################################	
sub get_ss_organism_part {
  my $self = shift;
  return $self->{SS_ORGANISM_PART};
}

##################################################################################################
#set get pair:ss_cell_line
#######################################################
# set_ss_cell_line
#######################################################
sub set_ss_cell_line { 
	my $self = shift;
	my $name = shift;
	return $self->{SS_CELL_LINE} = $name;
}
#######################################################
# get_ss_cell_line
#######################################################	
sub get_ss_cell_line {
	my $self = shift;
	return $self->{SS_CELL_LINE};
}

##################################################################################################
#set get pair:ss_cell_type
#######################################################
# set_ss_cell_type
#######################################################
sub set_ss_cell_type { 
	my $self = shift;
	my $name = shift;
	return $self->{SS_CELL_TYPE} = $name;
}
#######################################################
# get_ss_cell_type
#######################################################	
sub get_ss_cell_type {
	my $self = shift;
	return $self->{SS_CELL_TYPE};
}
##################################################################################################
#set get pair:ss_disease_state
#######################################################
# set_ss_disease_state
#######################################################
sub set_ss_disease_state { 
	my $self = shift;
	my $name = shift;
	return $self->{SS_DISEASE_STATE} = $name;
}
#######################################################
# get_ss_disease_state
#######################################################	
sub get_ss_disease_state {
	my $self = shift;
	return $self->{SS_DISEASE_STATE};
}

##################################################################################################
#set get pair:ss_protocol_deviations
#######################################################
# set_ss_protocol_deviations
#######################################################
sub set_ss_protocol_deviations { 
	my $self = shift;
	my $name = shift;
	return $self->{SS_SAMPLE_PROTOCOL_DEVIATIONS} = $name;
}
#######################################################
# get_ss_protocol_deviations
#######################################################	
sub get_ss_protocol_deviations {
	my $self = shift;
	return $self->{SS_SAMPLE_PROTOCOL_DEVIATIONS};
}

##################################################################################################
#set get pair:ss_sample_description
#######################################################
# set_ss_sample_description
#######################################################
sub set_ss_sample_description { 
	my $self = shift;
	my $name = shift;
	return $self->{SS_SAMPLE_DESCRIPTION} = $name;
}
#######################################################
# get_ss_sample_description
#######################################################	
sub get_ss_sample_description {
	my $self = shift;
	return $self->{SS_SAMPLE_DESCRIPTION};
}

#######################################################
#set get pair:ss_treatment_description
#######################################################
# set_ss_treatment_description
#######################################################
sub set_ss_treatment_description { 
	my $self = shift;
	my $name = shift;
	return $self->{SS_TREATMENT_DESCRIPTION} = $name;
}
#######################################################
# get_ss_treatment_description
#######################################################	
sub get_ss_treatment_description {
	my $self = shift;
	return $self->{SS_TREATMENT_DESCRIPTION};
}

#######################################################
#set get pair:sr_replicate_tag
#######################################################
# set_sr_replicate_tag
#######################################################
sub set_sr_replicate_tag { 
	my $self = shift;
	my $name = shift || '';
	return $self->{SR_REPLICATE_TAG} = $name;
}
#######################################################
# get_sr_replicate_tag
#######################################################	
sub get_sr_replicate_tag {
	my $self = shift;
	return $self->{SR_REPLICATE_TAG};
}

#######################################################
#set get pair:ss_data_flag
#######################################################
# set_ss_data_flag
#######################################################
sub set_ss_data_flag { 
	my $self = shift;
	my $name = shift || 'OK';
	return $self->{SS_DATA_FLAG} = $name;
}
#######################################################
# get_ss_data_flag
#######################################################	
sub get_ss_data_flag {
	my $self = shift;
	return $self->{SS_DATA_FLAG};
}

#######################################################
#set get pair:treatment_values
#######################################################
# set_treatment_values
#######################################################
sub set_treatment_values { 
	my $self = shift;
	my $values = shift;
  $self->{TREATMENT} ||= [];

  # Maps the XML fields to the field names
  my %field_map = ( 'Stimulus 1 Modifier' => 'modifier', 
                    'Time 1'              => 'time',
                    'Stimulus 1'          => 'treatment_name', 
                    'Stimulus 1 Type'     => 'treatment_mode', 
                    'Stimulus 2 Modifier' => 'modifier', 
                    'Time 2'              => 'time',
                    'Stimulus 2'          => 'treatment_name', 
                    'Stimulus 2 Type'     => 'treatment_mode' 
                  ); 

  my @stim_num = ( 1,2 );
  for my $stim_num ( @stim_num ) {
    my $skip = 1;
    my %treatment;
    for my $key_templ ( 'Stimulus NUM Modifier', 'Time NUM', 
                  'Stimulus NUM', 'Stimulus NUM Type' ) {
      my $key = $key_templ;
      $key =~ s/NUM/$stim_num/;
      $treatment{$field_map{$key}} = $values->{$key};
      if ( defined $values->{$key} && $values->{$key} ne '' ) {
        $skip = 0;
      }
    }
    next if $skip; # Don't add record unless at least one of the params is set
    $treatment{treatment_name} ||= 'unspecified';
    $treatment{treatment_agent} ||= $treatment{treatment_name};
    # Fixme - add defaults to config file?
    $treatment{time_units} ||= 'minutes';
    $treatment{treatment_agent} ||= 'chemical agent';
    $treatment{sort_order} ||= 200;
#    for my $t ( keys( %treatment ) ) { print "TREAT SAYS $t => $treatment{$t}\n"; }
    push @{$self->{TREATMENT}}, \%treatment;
  }
#  print  'Total of ' . scalar( @{$self->{TREATMENT}} ) . ' treatments seen' . "\n";
}
#######################################################
# get_treatment_values
#######################################################	
sub get_treatment_values {
	my $self = shift;
#  print "Returning treatments: " . scalar( @{$self->{TREATMENT}} ) . "\n";
	return $self->{TREATMENT};
}

##################################################################################################
#set get pair:ss_comment
#######################################################
# set_ss_sample_comment
#######################################################
sub set_ss_comment { 
	my $self = shift;
	my $name = shift;
	return $self->{SS_SAMPLE_COMMENT} = $name;
}
#######################################################
# get_ss_comment
#######################################################	
sub get_ss_comment {
	my $self = shift;
	return $self->{SS_SAMPLE_COMMENT};
}

##################################################################################################
#set get pair:ss_sample_preparation_date
#######################################################
# set_ss_sample_preparation_date
#######################################################
sub set_ss_sample_preparation_date { 
	my $self = shift;
	my $name = shift;
	return $self->{SS_SAMPLE_PREP_DATE} = $name;
}
#######################################################
# get_ss_sample_preparation_date
#######################################################	
sub get_ss_sample_preparation_date {
	my $self = shift;
	return $self->{SS_SAMPLE_PREP_DATE};
}
#######################################################
# append_protocol_id
# Append a new protocol id to previous ones all values will be entered in a comma delimited fashion
#######################################################
sub append_protocol_id { 
	my $method = '_append_protocol_id';
	
	my $self = shift;
	my %args = @_;
	
	my $value = $args{value};
	my $append_to_method =  $args{append_to_method};
	
	
	unless ($append_to_method && $value){
		confess(__PACKAGE__ . "::$method Must give values for append_to_method and value, your gave '$value' '$append_to_method' \n") 
	}
	
	my $getter = "get_$append_to_method";
	my $setter = "set_$append_to_method";
	
	my $current_val = $self->$getter();			#grab the current values in the solexa_o object
	
	if ($current_val){
		$self->$setter("$current_val,$value");		#append on the new value comma delimited
	}else{	
		$self->$setter($value);				#append on the first protocol		
	}
	
	return 1;
}

###############################################################################
#find_organism_id
#Given a organism_name
#return organism_id
###############################################################################
sub find_organism_id {
	my $method = 'find_organism_id';
    my $self = shift;
	
	my %args = @_;
	my $organism_name= $args{organism_name};
	my $do_not_die_flag = $args{do_not_die};	#simple flag to use the die statement here or let the caller take care of seeing if the value is good or not
	
	confess(__PACKAGE__ . "::$method Need to provide key value pair 'organism_name'") unless ($organism_name =~ /^\w/);
	
	my $sql =  qq~ 	SELECT organism_id
			FROM $TB_ORGANISM
			WHERE organism_name like '$organism_name'
		~;
	my @rows = $sbeams->selectOneColumn($sql);
	
	if ($rows[0] =~ /^\d/ || $do_not_die_flag){
		return $rows[0];
	}else{
		die "ORGANISM NAME '$organism_name' DOES NOT MATCH ANY OGANISM NAMES, PLEASE GO ADD IT\n";
	}
	
}
###############################################################################
#find_user_login_id
#Given a username
#return userid
###############################################################################
sub find_user_login_id {
	my $method = 'find_user_login_id';
    my $self = shift;
	
	my %args = @_;
	my $user_name= $args{username};
	my $do_not_die_flag = $args{do_not_die};	#simple flag to use the die statement here or let the caller take care of seeing if the value is good or not
	
	confess(__PACKAGE__ . "::$method Need to provide key value pair 'username'") unless ($user_name =~ /^\w/);
	
	my $sql =  qq~ 	SELECT user_login_id
			FROM $TB_USER_LOGIN
			WHERE username like '$user_name'
		~;
	my @rows = $sbeams->selectOneColumn($sql);
	
	if ($rows[0] =~ /^\d/ || $do_not_die_flag){
		return $rows[0];
	}else{
		die "USER NAME '$user_name' DOES NOT MATCH ANY USER NAMES, PLEASE GO ADD IT\n";
	}
	
}

###############################################################################
#find_user_login_id_from_contact
#Given a first name and last name
#return userid
###############################################################################
sub find_user_login_id_from_contact {
	my $method = 'find_user_login_id_from_contact';
    my $self = shift;
	
	my %args = @_;
	my $first_name= $args{first_name};
	my $last_name= $args{last_name};
	my $do_not_die_flag = $args{do_not_die};	#simple flag to use the die statement here or let the caller take care of seeing if the value is good or not
	
	confess(__PACKAGE__ . "::$method Need to provide key value pair 'first_name'") unless ($first_name =~ /^\w/);
	confess(__PACKAGE__ . "::$method Need to provide key value pair 'last_name'") unless ($last_name =~ /^\w/);
	
	my $sql =  qq~ 	SELECT ul.user_login_id
			FROM $TB_USER_LOGIN ul
			INNER JOIN $TB_CONTACT c on c.contact_id = ul.contact_id
			WHERE c.first_name like '$first_name'
			AND c.last_name like '$last_name'
		~;
	my @rows = $sbeams->selectOneColumn($sql);
	
	if ($rows[0] =~ /^\d/ || $do_not_die_flag){
		return $rows[0];
	}else{
		die "DID NOT FIND A USER WITH FIRST NAME  '$first_name' AND LAST NAME '$last_name' IN CONTACT, PLEASE GO ADD IT\n";
	}
	
}



###############################################################################
#find_ontology_id
#Given a term
#return return ontology_id .. #Currently the database is located in the Biolink database
###############################################################################
sub find_ontology_id {
	my $method = 'find_ontology_id';
    my $self = shift;
	
	my %args = @_;
	my $ontology_term= $args{ontology_term};
	my $do_not_die_flag = $args{do_not_die};	#simple flag to use the die statement here or let the caller take care of seeing if the value is good or not
	
	return if (!$ontology_term && $do_not_die_flag >0);
	confess(__PACKAGE__ . "::$method Need to provide key value pair 'ontology_term' VALUE '$ontology_term'") unless ($ontology_term =~ /^\w/);
	
	my $sql =  qq~ 	SELECT MGED_ontology_term_id 
			FROM $TBBL_MGED_ONTOLOGY_TERM
			WHERE name like '$ontology_term'
		~;
	my @rows = $sbeams->selectOneColumn($sql);
	
	if ($rows[0] =~ /^\d/ || $do_not_die_flag){
		return $rows[0];
	}else{
		die "ONTOLOGY NAME '$ontology_term' DOES NOT MATCH ANY ONTOLOGY NAMES, PLEASE GO ADD IT\n";
	}
	
}

}#Close of package bracket 
1;




