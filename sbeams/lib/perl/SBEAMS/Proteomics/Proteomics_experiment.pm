{package SBEAMS::Proteomics::Proteomics_experiment;
	
our $VERSION = '1.00';

####################################################
=head1 NAME

SBEAMS::Proteomics::Proteomics_experiment - Methods to find and dispaly proteomics_samples and experiments info


=head1 SYNOPSIS

 use SBEAMS::Proteomics::Proteomics_experiment;
 $prot_exp_obj = new SBEAMS::Proteomics::Proteomics_experiment();
 $prot_exp_obj->setSBEAMS($sbeams);
	

=head1 DESCRIPTION


=head2 EXPORT

None by default.


=head1 SEE ALSO


=head1 AUTHOR

Pat Moss, E<lt>pmoss@systemsbiology.org<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 by Pat Moss

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.3 or,
at your option, any later version of Perl 5 you may have available.


=cut
##############################################################
use strict;
use vars qw($sbeams $sbeamsMOD);		

use Carp;
use Data::Dumper;
use SBEAMS::Connection qw($log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TabMenu;

use base qw(SBEAMS::Proteomics);		
use SBEAMS::Proteomics;
use SBEAMS::Proteomics::Settings;
use SBEAMS::Proteomics::Tables;
use SBEAMS::Proteomics::TableInfo;


#$sbeamsMOD = new SBEAMS::Proteomics;


###############################################################################
# get_experiment_info
# Give: project_id
# Return: array of arrays results set
###############################################################################
sub get_experiment_info {
	my $method = 'get_experiment_info';
    my $self = shift;
    
    
   	my %args = @_;
    
    my $project_id = $args{project_id};
   	my $sbeams = $self->getSBEAMS();
     confess(__PACKAGE__ . "::$method Need to provide project_id \n") unless ($project_id =~ /^\d/);
    
  my @rows = ();
  #### Get all the experiments for this project
  if ($project_id > 0) {
    my $sql = qq~
	SELECT experiment_id,experiment_tag,experiment_name
	  FROM $TBPR_PROTEOMICS_EXPERIMENT PE
	 WHERE project_id = '$project_id'
	   AND PE.record_status != 'D'
	 ORDER BY experiment_tag
    ~;
    $log->debug("experiment info sql '$sql'");
    @rows = $sbeams->selectSeveralColumns($sql);
  } else {
    @rows = ();
  }

	return @rows;
}

###############################################################################
# get_experiment_tag
# Give: experiment_id
# Return: experiment_tag or null
###############################################################################
sub get_experiment_tag {
	my $method = 'get_experiment_tag';
    my $self = shift;
    
    
   	my %args = @_;
    
    my $experiment_id = $args{experiment_id};
    
    my $sbeams = $self->getSBEAMS();
    	
     confess(__PACKAGE__ . "::$method Need to provide experiment id you gave $experiment_id \n") unless ($experiment_id =~ /^\d/);
    
  my @rows = ();
  #### Get all the experiments for this project
  
    my $sql = qq~
	SELECT experiment_tag
	  FROM $TBPR_PROTEOMICS_EXPERIMENT PE
	  WHERE PE.experiment_id = $experiment_id
    ~;
    
   my @rows = $sbeams->selectOneColumn($sql);
   
   if (@rows){
   	return $rows[0];
   }else{
   	return;
   }
   
}

###############################################################################
# get_sample_tag
# Give: Proteomic sample_id
# Return: experiment_tag or null
###############################################################################
sub get_sample_tag {
	my $method = 'get_sample_tag';
    my $self = shift;
    
    
   	my %args = @_;
    
    my $proteomics_sample_id = $args{sample_id};
    
    my $sbeams = $self->getSBEAMS();
    	
     confess(__PACKAGE__ . "::$method Need to provide Sample id You gave '$proteomics_sample_id' \n") 
     unless ($proteomics_sample_id =~ /^\d/);
    
  my @rows = ();
  #### Get all the experiments for this project
  
    my $sql = qq~
	SELECT sample_tag
	  FROM $TBPR_PROTEOMICS_SAMPLE
	  WHERE proteomics_sample_id = $proteomics_sample_id
    ~;
    
   my @rows = $sbeams->selectOneColumn($sql);
   
   if (@rows){
   	return $rows[0];
   }else{
   	return;
   }
   
}

###############################################################################
# get_sample_info
# Give: project_id
# Return: array of arrays results set
###############################################################################
sub get_sample_info {
	my $method = 'get_sample_info';
    my $self = shift;
    
   	my %args = @_;
    my $project_id = $args{project_id};
   	
   	my $sbeams = $self->getSBEAMS();
    
    confess(__PACKAGE__ . "::$method Need to provide project_id \n") unless ($project_id =~ /^\d/);

#### Get information about all the samples for this project
  my $sql = qq~
	SELECT PS.proteomics_sample_id, sample_tag + ' (' + full_sample_name + ')'
	FROM $TBPR_PROTEOMICS_SAMPLE PS
	WHERE PS.record_status != 'D'
    AND PS.project_id = $project_id
    ORDER BY sample_tag,full_sample_name
	~;
	
	my @all_samples_results = $sbeams->selectSeveralColumns($sql);
	if (@all_samples_results){
		return @all_samples_results
	}else{
		return;
	}
}


###############################################################################
# get_all_sample_names
# Give: nothing
# Return: return array of arrays results set
###############################################################################
sub get_all_sample_names {
	my $method = 'get_all_sample_names';
    my $self = shift;
    
   	my %args = @_;
   
   	
   	my $sbeams = $self->getSBEAMS();
    
  
#### Get information about all the samples for this project
  	my $sql = qq~
		SELECT 
		PS.proteomics_sample_id, 
		sample_tag + ' (' + full_sample_name + ')',
		P.project_id,
		P.project_tag
		FROM $TBPR_PROTEOMICS_SAMPLE PS
		JOIN $TB_PROJECT P ON (P.project_id = PS.project_id)
		WHERE PS.record_status != 'D' AND
		P.record_status != 'D'
		
		
	    ORDER BY P.project_tag,sample_tag,full_sample_name
	~;
	$log->debug("$method '$sql'");
	my @all_samples_names = $sbeams->selectSeveralColumns($sql);
	if (@all_samples_names){
		return @all_samples_names
	}else{
		return;
	}
}

###############################################################################
# add_sample_to_experiments_samples_linker_table
# Give: sample_id, experiment_id
# Return: pk of the row just inserted or 0
###############################################################################
sub add_sample_to_experiments_samples_linker_table {
	my $method = 'add_sample_to_experiments_samples_linker_table';
	my $self = shift;
	my %args = @_;
	my $experiment_id = $args{experiment_id};
	my $proteomics_sample_id = $args{sample_id};
	
	confess(__PACKAGE__ . "::$method Need sample_id and experiment_id You Gave '$proteomics_sample_id'  and '$experiment_id'\n") unless 
	($proteomics_sample_id =~ /^\d/ && $experiment_id =~ /^\d/);
	
	my $sbeams = $self->getSBEAMS();
	
	
	my $rowdata_ref =   { 	
						 proteomics_sample_id   =>$proteomics_sample_id,
						 experiment_id 			=>$experiment_id,
						};   
			
	my $new_linker_id = $sbeams->updateOrInsertRow(
					table_name=>$TBPR_EXPERIMENTS_SAMPLES,
		   			rowdata_ref=>$rowdata_ref,
		   			return_PK=>1,
		   			verbose=>'',
		   			testonly=>'',
		   			insert=>1,
		   			PK=>'experiments_samples_id	',
		   		   	add_audit_parameters=>1,
				        );
				        
	
	 
	if($new_linker_id > 0 && $new_linker_id =~ /^\d/){
		#update the linker info within the experiment table
		$self->update_experiments_sample_linker_table(	proteomics_sample_id  	=> $proteomics_sample_id,
	 												    experiment_id 			=> $experiment_id);
		return $new_linker_id;
	}else{
		return 0;
	}   
				        

}
###############################################################################
# update_experiments_sample_linker_table
# Give: proteomics_sample_id
# Return: experiment_id of the row updated for sucess OR 0 (zero) for failure 
###############################################################################
sub update_experiments_sample_linker_table {
	my $method = 'update_experiments_sample_linker_table';
	my $self = shift;
	my %args = @_;
	my $experiment_id = $args{experiment_id};
	my $proteomics_sample_id = $args{proteomics_sample_id};
	my $sbeams = $self->getSBEAMS();
	
	confess(__PACKAGE__ . "::$method Need sample_id and experiment_id You Gave '$proteomics_sample_id'  and '$experiment_id'\n") unless 
	($proteomics_sample_id =~ /^\d/ && $experiment_id =~ /^\d/);
	
	
	my $current_liner_info = $self->get_experiment_linker_ids(experiment_id => $experiment_id);
	my @current_sample_ids = split /,/, $current_liner_info;
	
	#check to see if the sample id allready exists.  It really never should....
	if (grep $proteomics_sample_id == $_, @current_sample_ids){
		$log->debug("Proteomic sample ID '$proteomics_sample_id' already exists in the experiment table '$current_liner_info'");
	}
	
	push @current_sample_ids, $proteomics_sample_id;
	my $new_info = join ",", @current_sample_ids;
	
	my $rowdata_ref =   { 	
						 experiment_samples_ids   =>$new_info,
						};   
			
	
			
	my $returned_id = $sbeams->updateOrInsertRow(
				table_name=>$TBPR_PROTEOMICS_EXPERIMENT,
	   			rowdata_ref=>$rowdata_ref,
	   			return_PK=>1,
	   			verbose=>'',
	   			testonly=>'',
	   			update=>1,
	   			PK_name => 'experiment_id',
				PK_value=> $experiment_id,
	   		   	add_audit_parameters=>1,
			   );
			   
	$log->debug("UPDATED LINKER TABLE PK '$returned_id'");
	
	if ($returned_id){
		return $returned_id;
	}else{
		return 0;
	}
	
}

###############################################################################
# get_experiment_linker_ids
# Give: experiment_id
# Return: return the proteomic sample_ids in the field '' or null if nothing exists
###############################################################################
sub get_experiment_linker_ids {
	my $method = 'get_experiment_linker_ids';
	my $self = shift;
	my %args = @_;
	my $experiment_id = $args{experiment_id};
	my $sbeams = $self->getSBEAMS();
	
	confess(__PACKAGE__ . "::$method Need  experiment_id You Gave '$experiment_id'\n") unless 
	( $experiment_id =~ /^\d/);
	
	my $sql = qq~ SELECT experiment_samples_ids
				  FROM $TBPR_PROTEOMICS_EXPERIMENT
				  WHERE experiment_id = $experiment_id
			  ~;
	my @rows = $sbeams->selectOneColumn($sql);
	
	if (@rows){
		return $rows[0];
	}else{
		return 0;
	}
	
}


###############################################################################
# format_option_list
# Give: results set aref.  Must be array of arryas.  
#  Column 0 is the pk, 
#  Column 1 is human readable information, 
#  Column 2 is the project_id
#  Column 3 is the project_tag
# Return: html code for JUST the option tags for a select list.  User needs to wrap the list in a select tag.
###############################################################################
sub format_option_list {
	my $method = 'format_option_list';
	my $self = shift;
	my %args = @_;

	my $results_set_aref =  $args{results_set_ref};
	my $make_blank_flag  =  $args{make_blank}; #if true return an option list that just has the tags
	my @rows = @{$results_set_aref};
	
	my @html = ();
	
 ##Make blank option tags.  Need for some of the java script
 	if ($make_blank_flag){
 		foreach my $row (@rows){
 			push @html, "<OPTION></OPTION>";
 		}
 	}elsif($results_set_aref->[0][3]){ #project_info present
	
	
	#Want to seperate the data by projects in the drop down list
	
		$log->debug("I SEE THE PROJECT INFO");
		
		
		my $current_project_id = '';
		foreach my $row (@rows){
			my $project_id = $row->[2];
			
			my $pk_id 		= $row->[0];
			my $print_info 	= $row->[1];
			
			if ($current_project_id == $project_id){
					
				push @html, "<OPTION VALUE='$pk_id'>$print_info</OPTION>";
				$current_project_id = $project_id;
			}else{##New project
				my $project_tag = $row->[3];
				my $option_list_div = "##### $project_tag ###### ";
				push @html, "<optgroup label='$option_list_div'>";
				push @html, "<OPTION VALUE='$pk_id'>$print_info</OPTION>";
				$current_project_id = $project_id;
				
			}
		}
	
	
	}else{ #output just a regular option list
		$log->debug("OUT PUT REGULAR OPTION LIST");
		foreach my $row (@rows){
			my $pk_id 		= $row->[0];
			my $print_info 	= $row->[1];
			push @html, "<OPTION VALUE='$pk_id'>$print_info</OPTION>";
			
		}
	}
	
	my $html = join " ", @html;
	$log->debug($html);
	return $html;
}

}#Close end of package

1;

