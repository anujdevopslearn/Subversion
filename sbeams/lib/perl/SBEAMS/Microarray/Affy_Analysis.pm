###############################################################################
# Program     : SBEAMS::Microarray::Affy_Analysis
# Author      : Pat Moss <pmoss@systemsbiology.org>
# $Id$
#
# Description :  Module which implements various methods for the analysis of
# Affymetrix array files.
# 
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
#
###############################################################################



{package SBEAMS::Microarray::Affy_Analysis;
	
our $VERSION = '1.00';

####################################################
=head1 NAME

SBEAMS::Microarray::Affy_Analysis - Methods to analize a group of affymetrix files
SBEAMS::Microarray

=head1 SYNOPSIS

 use SBEAMS::Connection::Tables;
 use SBEAMS::Microarray::Tables;
 
 use SBEAMS::Microarray::Affy;
 use SBEAMS::Microarray::Affy_file_groups;

 my $sbeams_affy_groups = new SBEAMS::Microarray::Affy_file_groups;

$sbeams_affy_groups->setSBEAMS($sbeams);		#set the sbeams object into the sbeams_affy_groups


=head1 DESCRIPTION


=head2 EXPORT

None by default.



=head1 SEE ALSO

SBEAMS::Microarray::Affy;
lib/scripts/Microarray/load_affy_array_files.pl

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
use vars qw($sbeams);		

use File::Basename;
use File::Find;
use File::Path;
use Data::Dumper;
use Carp;
use FindBin;

use SBEAMS::Connection qw($log);

use base qw(SBEAMS::Microarray::Affy);		
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::Settings qw( $PHYSICAL_BASE_DIR );
use SBEAMS::Microarray::Tables;
use SBEAMS::Microarray::Analysis_Data;
use SBEAMS::Microarray::Settings qw( $AFFY_TMP_DIR );

my $R_program = SBEAMS::Microarray::Settings->get_local_R_exe_path( 'obj_placeholder' );
my $R_library = SBEAMS::Microarray::Settings->get_local_R_lib_path( 'obj_placeholder' );

#our $PHYSICAL_BASE_DIR;

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
# make_R_CHP_file
#make an R CHP file by making an R script and shell script 
#Using the shell script to facilitate making graphics.
#Give file_name and full path to cel_file
#will make a R script file, shell script, run the shell script and log results
#returns the results of running the shell script if there is a problem running R or 1 if no errors detected  
###############################################################################
sub make_R_CHP_file {
	my $method = 'make_R_CHP_file';
    	my $self = shift;
    
   	my %args = @_;
    
    	my $file_name = $args{file_name};
    	my $cel_file = $args{cel_file};
    
    
    	confess(__PACKAGE__ . "::$method Need to provide arugments 'cel_file' & 'file_name \n") unless ($file_name =~ /^\w/ && $cel_file =~ /CEL$/);
    
   	
  # temp dir for storing R/shell scripts, use config value or fall back
	my $R_temp_dir = ( $AFFY_TMP_DIR ) ? "${AFFY_TMP_DIR}/R_CHP_RUNS/${file_name}_R_CHP" : 
                           "$PHYSICAL_BASE_DIR/tmp/Microarray/R_CHP_RUNS/${file_name}_R_CHP";

        my $out_shell_script = "${file_name}_shell.sh";
	my $out_R_script = "${file_name}_R_script.R";					#these paths will be relative to where the shell script will be running, they all should be in the same directory
	my $out_error_log = "${file_name}_error.txt";
	
	
	my $base_dir = dirname($cel_file);
	my $out_R_CHP_file = "$base_dir/${file_name}.R_CHP";		#Write the R_CHP file to the same directory the CEL file was found
	my $out_chip_image = "$base_dir/${file_name}.JPEG";
	
##############################################################################################
### Make and Write out the R script	
	my  $R_script = <<END;
.libPaths("$R_library")
library(affy)

# Make sure R is reasonably modern
v_minor = R.version\$minor;
v_major = R.version\$major;

if ( v_major < 2 ) {
  print( "Must run R version 2.2.0 or above" );
  quit();
} 

cel.file.name    <- c("$cel_file")
output.file.name <- c("$out_R_CHP_file")
data <- ReadAffy(filenames =  cel.file.name)

eset <- mas5(data,sc=250)
PACalls <- mas5calls(data,alpha1=0.05,alpha2=0.065)

Matrix <- exprs(eset)
headings <- c("Probesets","MAS5_Signal","MAS5_Detection_calls", "MAS5_Detection_p-value")

if  ( as.integer(v_minor) > 4.0 ) {
  output <- cbind(row.names(Matrix),Matrix,exprs(PACalls), assayData(PACalls)\$se.exprs )
  write.table(output, file=output.file.name, sep="\t", col.names=headings, row.names=FALSE)
} else {
  output <- cbind(row.names(Matrix),Matrix,exprs(PACalls),se.exprs(PACalls))
  write.table(output, file=output.file.name, sep="\t", col.names=headings, row.names=FALSE)
} 

bitmap(file="$out_chip_image",  res=72*4, pointsize = 12 )
	image( data[,1] )
dev.off()

END


	
	if (-d $R_temp_dir){
		my $command_line = "rm -r $R_temp_dir";
		my $results = `$command_line`;
		print "REMOVED OLD R TEMP DIR EXIT STATUS '$results'\n";
		
	}

	mkdir $R_temp_dir;
		
	open OUT,  ">$R_temp_dir/$out_R_script" or 
		die "Cannot open R temp dir '$out_R_script' $!\n";
	
	print OUT $R_script;
	close OUT;
	
################################################################################################
### Make shell script 
	my $shell_script = <<END;
#!/bin/sh

R_LIBS=$R_library
$R_program --no-save  < $out_R_script 2>$out_error_log

STATUS=\$?

if [ \$STATUS == 0 ]

	then
		echo "R Exit Status 0"
		chgrp affydata $out_R_CHP_file $out_chip_image
	
	else
		echo "ERROR: R Exit Status \$STATUS";
fi

END

	open OUT, ">$R_temp_dir/$out_shell_script"
		or die "Cannot open '/$R_temp_dir/$out_shell_script'\n";
		
	print OUT $shell_script;
	close OUT;
	sleep 1;
	die "DID NOT CHMOD \n" unless (chmod 0777, "$R_temp_dir/$out_shell_script");
	
################################################################################################
### actually run the shell script 

	my $command_line = "cd $R_temp_dir; ./$out_shell_script";
	
	print "Starting R Job for $file_name\n";
	my $results = `$command_line`;
	
	if ($results =~ /ERROR: R Exit Status/){
		$self->log_R_run("\tERROR: R EXITED WITH ERROR CODE\t$file_name");
		return $results;
	}else{
		$self->log_R_run("\tRUN COMPLETED\t$file_name");
		$self->R_CHP_file_name($out_R_CHP_file);
		return 1;
	}
	

}

###############################################################################
# make_chip_jpeg_file
#make a jpeg image of chip by making an R script and shell script 
#Using the shell script to facilitate making graphics.
#Give file_name and full path to cel_file
#will make a R script file, shell script, run the shell script and log results
#returns the results of running the shell script if there is a problem running R or 1 if no errors detected  
###############################################################################
sub make_chip_jpeg_file {
	my $method = 'make_chip_jpeg_file';
    	my $self = shift;
    
   	my %args = @_;
    
    	my $file_name = $args{file_name};
    	my $cel_file = $args{cel_file};
    
    
    	confess(__PACKAGE__ . "::$method Need to provide arugments 'cel_file' & 'file_name \n") unless ($file_name =~ /^\w/ && $cel_file =~ /CEL$/);
    
   	
  # temp dir for storing R/shell scripts, use config value or fall back
	my $R_temp_dir = ( $AFFY_TMP_DIR ) ? "${AFFY_TMP_DIR}/R_CHP_RUNS/${file_name}_R_CHP" : 
                           "$PHYSICAL_BASE_DIR/tmp/Microarray/R_CHP_RUNS/${file_name}_R_CHP";

        my $out_shell_script = "${file_name}_shell.sh";
	my $out_R_script = "${file_name}_R_script.R";					#these paths will be relative to where the shell script will be running, they all should be in the same directory
	my $out_error_log = "${file_name}_error.txt";
	
	
	my $base_dir = dirname($cel_file);
	my $out_R_CHP_file = "$base_dir/${file_name}.R_CHP";		#Write the R_CHP file to the same directory the CEL file was found
	my $out_chip_image = "$base_dir/${file_name}.JPEG";
	
##############################################################################################
### Make and Write out the R script	
	my  $R_script = <<END;
.libPaths("$R_library")
library(affy)
cel.file.name    <- c("$cel_file")
data <- ReadAffy(filenames =  cel.file.name)

bitmap(file="$out_chip_image",  res=72*4, pointsize = 12 )
	image( data[,1] )
dev.off()

#jpeg("$out_chip_image", width=1000, height=1000)
#image( data[,1] )
#dev.off()
END


	
	if (-d $R_temp_dir){
		my $command_line = "rm -r $R_temp_dir";
		my $results = `$command_line`;
		print "REMOVED OLD R TEMP DIR EXIT STATUS '$results'\n";
		
	}

	mkdir $R_temp_dir;
		
	open OUT,  ">$R_temp_dir/$out_R_script" or 
		die "Cannot open R temp dir '$out_R_script' $!\n";
	
	print OUT $R_script;
	close OUT;
	
################################################################################################
### Make shell script 
	my $shell_script = <<END;
#!/bin/sh

R_LIBS=$R_library
$R_program --no-save  < $out_R_script 2>$out_error_log

STATUS=\$?

if [ \$STATUS == 0 ]

	then
		echo "R Exit Status 0"
		chgrp affydata $out_chip_image
	
	else
		echo "ERROR: R Exit Status \$STATUS";
fi

END

	open OUT, ">$R_temp_dir/$out_shell_script"
		or die "Cannot open '/$R_temp_dir/$out_shell_script'\n";
		
	print OUT $shell_script;
	close OUT;
	sleep 1;
	die "DID NOT CHMOD \n" unless (chmod 0777, "$R_temp_dir/$out_shell_script");
	
################################################################################################
### actually run the shell script 

	my $command_line = "cd $R_temp_dir; ./$out_shell_script";
	
	print "Starting R Job for $file_name\n";
	my $results = `$command_line`;
	
	if ($results =~ /ERROR: R Exit Status/){
		$self->log_R_run("\tERROR: R EXITED WITH ERROR CODE\t$file_name");
		return $results;
	}else{
		$self->log_R_run("\tRUN COMPLETED\t$file_name");
		$self->R_CHP_file_name($out_R_CHP_file);
		return 1;
	}
	

}

###############################################################################
# parse_R_CHP_file
#Get/Set full path to R_CHP file
#
###############################################################################
sub parse_R_CHP_file {
	my $method = 'parse_R_CHP_file';
	my $self = shift;
	
	my %args = @_;
	
	my $VERBOSE = $args{verbose};
	my $TESTONLY = $args{testonly};
	my $DEBUG = $args{debug};
	my $update_flag  = $args{update};
	
	my $r_chp_protocol_name = $self->get_affy_r_chp_protocol();
	$self->set_R_CHP_protocol_id($r_chp_protocol_name);
	
	
	my $r_chp_file = $self->R_CHP_file_name();
	
	open R_CHP, $r_chp_file or 
		die "CANNOT OPEN R_CHP File '$r_chp_file' $!\n";
	
	my @column_names = ();
	
	while (my $line = <R_CHP>){			#grab the column names to make sure the file looks ok.
		next if $line =~ /^#/;			#skip comment lines
		$line =~ s/^"|"\s+$//g;			#remove the starting quote
		@column_names = split /"\t"/, $line;
		last;
	}
	close R_CHP;
	
	my %ref_columns = (	1 =>  "Probesets",			#these columns must be present in this order in the data file to be vaild
				2 =>  "MAS5_Signal", 
				3 =>  "MAS5_Detection_calls",
				4 =>  "MAS5_Detection_p-value",
			 );
			 
	
	for (my $i= 0; $i <= $#column_names; $i ++){
	
		unless ($column_names[$i] eq $ref_columns{($i+1)}){
			die "FILE DATA COLUMN $i '$column_names[$i]' DOES NOT MATCH 'REF COLUMN '". $ref_columns{($i+1)}. "PLEASE FIX THE PROBLEM AND TRY AGAIN'\n"
		}
	
	}
	
	my %column_map = (	0 	=>  "probe_set_id",
				1 	=>  "signal",
				2 	=>  "detection_call",
				3	=>  "detection_p_value",
				1000 	=>  "affy_array_id", 
				1001	=>  "protocol_id",
			 );
	
	
	#### For tricky mappings,
	#### use an absurdly high column number.  This will not work,if
	#### there are 1000 columns in the file
	my %transform_map = (
				'1000'=> sub{return $self->get_affy_array_id ;},
				'1001'=> sub{return $self->get_R_CHP_protocol_id},
   			     );
			     
	my %update_keys = ( probe_set_id   => 0,
			    affy_array_id  => 1000,
			    protocol_id	   => 1001,
			  );

	 print "\nTransferring $r_chp_file -> affy_gene_intensity" if ($VERBOSE >0);
 	
	 
	 
	 $sbeams->transferTable(
		 source_file=>$r_chp_file,
		 delimiter=>"\t",
		 skip_lines=>'2',
		 dest_PK_name=>'affy_gene_intensity_id',
		 dest_conn=>$sbeams,
		 column_map_ref=>\%column_map,
		 transform_map_ref=>\%transform_map,
		 table_name=>$TBMA_AFFY_GENE_INTENSITY,
		 update=>$update_flag,
		 update_keys_ref=>\%update_keys,
		 verbose=>$VERBOSE,
		 testonly=>$TESTONLY,
		 );


}

###############################################################################
#
#Tag the R_CHP file with the protocol name used to make the file
#
###############################################################################
sub tag_R_CHP_file {
	my $method = 'tag_R_CHP_file';
	my $self = shift;
	confess(__PACKAGE__ . "::$method self not passed \n") unless ($self);
    
	my $R_CHP_path = $self->R_CHP_file_name();
	
	open DATA, $R_CHP_path or 
		die "CANNOT OPEN R_CHP DATA FOR TAGGING '$R_CHP_path' $!\n";
	my $data = '';
	while(<DATA>){
		$data .= $_;
	}
	close DATA;
	my$r_chp_protocol_name = $self->get_affy_r_chp_protocol();
	my $date = `date`;
	chomp $date;
	my $tag_line = "$r_chp_protocol_name $date\n";
	
	open OUT, ">$R_CHP_path" or 
		die "CANNOT OPEN OUT FILE FOR TAGGING '$R_CHP_path' $!\n";
		
	print OUT "# $tag_line";
	print OUT "$data";
	close OUT;
	
	
	return 1;
}

	

###############################################################################
# R_CHP_file_name
#Get/Set full path to R_CHP file
#
###############################################################################
sub R_CHP_file_name {
	my $method = 'R_CHP_file_name';
	my $self = shift;
	my $file_path = shift;
	
	if ($file_path){ 		#its a setter
		return $self->{R_CHP_FILE} = $file_path;
	}else{
		return $self->{R_CHP_FILE};
	}
}
	
###############################################################################
# set_R_CHP_protocol_id
#given a protocol name fetch then set the protocol_id
#die if protocol name does not exists in the database
###############################################################################
sub set_R_CHP_protocol_id {
	my $method = 'set_R_CHP_protocol_id';
	
	my $self= shift;
	my $protocol_name = shift;
	
	my $sql = qq~ select protocol_id
			from $TB_PROTOCOL
			WHERE name = '$protocol_name'
			AND record_status != 'D'
		    ~;
		    
	#print "$method SQL '$sql' \n" ;
	
	my @rows = $sbeams->selectOneColumn($sql);
	
	#print "PROTOCOL ID '$rows[0]'\n";
	if ($rows[0] =~ /^\d/){
		$self->{R_CHP_PROTOCOL} = $rows[0];
	}else{
		
		confess(__PACKAGE__ . "::$method ERROR:Could not find protocol name '$protocol_name' in DB \n");
	}
}
###############################################################################
# get_R_CHP_protocol_id
#return the R_CHP protocol id
###############################################################################
sub get_R_CHP_protocol_id {
    my $self = shift;
    return $self->{R_CHP_PROTOCOL};
}

###############################################################################
# log_R_run
#make an R CHP file by making an R script and shell script 
#Using the shell script to facilitate making graphics.  
###############################################################################
sub log_R_run {
  my $self = shift;
  my $info = shift;

  my $logdir = $self->get_affy_log_dir();
	
  open OUT, ">>$logdir/AFFY_R_CHP_RUNS.log" || die "Can't open R_CHP log dir $!\n";
		
  my $date = `date`;
  chomp $date;
	
  my $line = "$date $info\n";
	
  print OUT $line;
  close OUT;
} 




###############################################################################
# get_annotation_set_id
#Given a string of comma seperarted affy_array_ids OR a project id (will use the array_ids as defualt) find the most recent annotation set ids
#Should work even with groups of arrays utilizing differnt chips
#Return the most recent annotation_set_id as a comma delimited string. 
###############################################################################
sub get_annotation_set_id {
	my $method = 'get_annotation_set_id';
	my $self = shift;
	
	my %args = @_;
	
	my $arrays = $args{affy_array_ids};
	
	my $project_id = $args{project_id};
	
	unless ( ($project_id =~ /^\d/ || $arrays =~ /^\d/) ){
		
		confess(__PACKAGE__ . "::$method Need to provide arugments 'affy_array_ids' or 'project_id'h\n") 
    	}
	
	my $constriant = '';
	
	if ($arrays){							#if we just have array_ids make the constriant.  This will always be the defualt 
		$constriant = qq~ WHERE  afa.affy_array_id IN ($arrays)
				~;
	}else{								#if we have a project id join on the affy sample table and constrian to the project table
		$constriant = qq~ JOIN $TBMA_AFFY_ARRAY_SAMPLE afs ON (afa.affy_array_sample_id = afs.affy_array_sample_id)
				  WHERE  afs.project_id IN ($project_id)
				~;
	}
	
	
	#note that two columns are comming back but selectOneColumn will only return the values in the first column which is what we want need the second column to group by
	my $sql = qq~ 	SELECT MAX(affy_annotation_set_id) AS annotation_set_id, afa.array_type_id
			FROM $TBMA_AFFY_ARRAY afa JOIN $TBMA_AFFY_ANNOTATION_SET anno_set
			ON afa.array_type_id = anno_set.slide_type_id
			$constriant
			GROUP BY afa.array_type_id
		~;
		
	#$sbeams->display_sql(sql=>$sql);
	my @rows = $sbeams->selectOneColumn($sql);
	
	return (join ",", @rows);
}	
	
###############################################################################
# get_r_chp_protocol
#Given a string of comma seperarted affy_array_ids find the most common R_CHP protocol
#Return the R_CHP protocol.  
#Warning not setup to indicate if a group of array_ids have utilized a differnt set of R_CHP protocols
###############################################################################
sub get_r_chp_protocol {
	my $method = 'get_r_chp_protocol';
	my $self = shift;
	my %args = @_;
	my $arrays = $args{affy_array_ids};
	
	my $sql = qq~   SELECT distinct (protocol_id)
			FROM $TBMA_AFFY_GENE_INTENSITY gi
			WHERE gi.affy_array_id IN ($arrays)
		~;
		
	 my @rows = $sbeams->selectOneColumn($sql);
	
	
	return $rows[0];
}

##############################################################################
# find_slide_type_name
#Given an array ref of file names
#Method will strip the .CEL suffix, and make a comma seperated list of values
#Return only ONE slide_type.name or confess there is a problem
###############################################################################
sub find_slide_type_name {
	my $method = 'find_slide_type_name';
	my $self = shift;
	my %args = @_;
	my @file_names  = @{ $args{file_names} };
	unless ( @file_names ){
		confess(__PACKAGE__ . "::$method No affy CEL file Names were provided\n") 
    }
	
	
##Clean up the file names and make a comma seperated string
	my @clean_file_names = ();
	foreach (@file_names){
		s/\.CEL$//;
		push @clean_file_names, "'$_'";
	}
	my $search_term = join ",", @clean_file_names;
		
	my $sql = qq~   SELECT distinct st.name 
					FROM $TBMA_AFFY_ARRAY afa 
					JOIN $TBMA_SLIDE_TYPE st ON (afa.array_type_id = st.slide_type_id)
					WHERE afa.file_root IN ( $search_term)
		~;
		
	 my @rows = $sbeams->selectOneColumn($sql);
	unless ( @rows == 1){
		confess(__PACKAGE__ . "::$method Found incorrect number of array type names '@rows' Should only be one\n") 
    }
	
	return $rows[0];
}


###############################################################################
# find_chips_with_R_CHP_data
#given a project_id find all the affy_array ids that have data
#return array of affy_array_ids
###############################################################################
sub find_chips_with_R_CHP_data {
	my $method = 'find_chips_with_R_CHP_data';
	my $slef= shift;
	my %args = @_;
	
	my $project_id = $args{project_id};
	
	confess(__PACKAGE__ . "::$method Need to provide arugments 'project_id'\n") unless ($project_id =~ /^\d/);
    

	my $sql = qq~ 	SELECT distinct (gi.affy_array_id) 
			FROM $TBMA_AFFY_GENE_INTENSITY gi
			JOIN $TBMA_AFFY_ARRAY afa ON (afa.affy_array_id = gi.affy_array_id)
			JOIN $TBMA_AFFY_ARRAY_SAMPLE afs ON (afs.affy_array_sample_id = afa.affy_array_sample_id)
			WHERE afs.project_id IN ($project_id) 
		
		   ~;
	
#$sbeams->display_sql(sql=>$sql);
	return my @rows = $sbeams->selectOneColumn($sql);

}
###############################################################################
# find_chips_with_data
#given a project_id return all affy array ids
#return array of affy_array_ids
###############################################################################
sub find_chips_with_data {
	my $method = 'find_chips_with_data';
	my $slef= shift;
	my %args = @_;
	
	my $project_id = $args{project_id};
	
	confess(__PACKAGE__ . "::$method Need to provide arugments 'project_id'\n") unless ($project_id =~ /^\d/);
    

	my $sql = qq~ 	SELECT afa.affy_array_id 
			FROM $TBMA_AFFY_ARRAY afa
			JOIN $TBMA_AFFY_ARRAY_SAMPLE afs ON (afs.affy_array_sample_id = afa.affy_array_sample_id)
			WHERE afs.project_id IN ($project_id) 
		
		   ~;
	
#$sbeams->display_sql(sql=>$sql);
	return my @rows = $sbeams->selectOneColumn($sql);

}

###############################################################################
# get_affy_intensity_data_sql
#Given some array_id, some optional constriants, and annotation display type make a sql query to display the gene intensity values
#return a sql query
###############################################################################
sub get_affy_intensity_data_sql {
	my $method = 'get_affy_intensity_data_sql';
	my $self = shift;
	my %args = @_;
#  $log->printStack( 'debug' );
	
	my $affy_array_ids = $args{affy_array_ids};
	my $annotation_display = $args{annotation_display};
	my @all_constraints = @{$args{constraints}};
	
	my $R_protocol_id     = $args{r_chp_protocol};
	my $annotation_set_id = $args{annotation_id};
	
	confess(__PACKAGE__ . "::$method Need to provide arugments 'affy_array_ids' you gave '$affy_array_ids'\n") unless ($affy_array_ids);
    
	my $add_affy_db_link_table = '';
	
	
	for (my $i; $i<=$#all_constraints; $i++){ 
		my $constraint = $all_constraints[$i];
		
		if ($constraint =~ /link\.db_id/){			#only add the affy_db_links table if we have a constraints for it 
			$add_affy_db_link_table = "JOIN $TBMA_AFFY_DB_LINKS link ON (anno.affy_annotation_id = link.affy_annotation_id)";
		
		} elsif( $constraint =~ /anno\.gene_name/ ) {	
      my @subclauses = split / OR /, $constraint;
			my $new_constraint = 'AND ( ';
# = "AND (anno.gene_symbol $search_term OR anno.gene_title $search_term) ";

      my $sep = '';
      for my $sc ( @subclauses ) {
        chomp $sc;
        ( my $term ) = $sc =~ /anno\.gene_name LIKE(.*)/;
        $new_constraint .=  "$sep anno.gene_symbol LIKE $term OR anno.gene_title LIKE $term \n";
        $sep = ' OR ';
      }
			$new_constraint .= ' )'; 
			$all_constraints[$i] = $new_constraint;
		}else{
		}
	}
		
	my $constraints = join " ", @all_constraints;
  my $limit = $sbeams->buildLimitClause( row_limit => 10000 );	
  my $sql = qq~
      SELECT $limit->{top_clause} gi.probe_set_id, 
			afa.file_root, 
			gi.affy_array_id, 
			gi.signal, 
			gi.detection_call, 
			anno.gene_symbol, 
			anno.gene_title, 
			gi.protocol_id,
      sample_group_name
			FROM $TBMA_AFFY_GENE_INTENSITY gi 
			JOIN $TBMA_AFFY_ARRAY afa ON (gi.affy_array_id = afa.affy_array_id)
			JOIN $TBMA_AFFY_ARRAY_SAMPLE afas ON (afa.affy_array_sample_id = afas.affy_array_sample_id)
			JOIN $TBMA_AFFY_ANNOTATION anno ON (anno.probe_set_id = gi.probe_set_id)
			JOIN $TBMA_AFFY_ANNOTATION_SET anno_s ON (anno.affy_annotation_set_id = anno_s.affy_annotation_set_id) $add_affy_db_link_table
			WHERE anno_s.affy_annotation_set_id = $annotation_set_id AND 
			gi.protocol_id = $R_protocol_id AND
			gi.affy_array_id IN ($affy_array_ids) 
			$constraints
			order BY anno.gene_symbol, gi.probe_set_id
      $limit->{trailing_limit_clause}
			 ~;
	
	return $sql;


}

###############################################################################
# get_user_id_from_user_name
# Give user_name
#Return user_id
###############################################################################
sub get_user_id_from_user_name {
	my $method = 'get_user_id_from_user_name';
	my $self = shift;
	my $user_name = shift;
	
	unless ($user_name =~ /^\w/ ) {
		confess( __PACKAGE__ . "::$method Need to provide a user name \n");
	}
	my $sql = qq~SELECT user_login_id
				 FROM $TB_USER_LOGIN
				 WHERE username like '$user_name'
				~;
			
	my @user_id = $sbeams->selectOneColumn($sql);
	
	if (@user_id) {
		return $user_id[0];
	}else{
		return 0;
	}
}
##############################################################################
# delete_analysis_session
# Turn a record from N to D
# Provide an affy analysis id
###############################################################################
sub delete_analysis_session {
	my $method = 'delete_analysis_session';
	my $self = shift;
	my %args = @_;
	
	my $analysis_id = $args{analysis_id};
	my $rowdata_ref = {record_status => 'D'};
	
	my $returned_id = $sbeams->updateOrInsertRow(
							table_name=>$TBMA_AFFY_ANALYSIS,
				   			rowdata_ref=>$rowdata_ref,
				   			return_PK=>1,
				   			verbose=>'',
				   			testonly=>'',
				   			update=>1,
				   			PK_name => 'affy_analysis_id',
							PK_value=> $analysis_id,
				   		   	add_audit_parameters=>1,
						   );

	if ($returned_id){
		return $returned_id;
	}else{
		return 0;
	}
}

##############################################################################
# delete_analysis_folder
# delete an analysis recorded from disk
# Provide a full path to the analysis folder
###############################################################################
sub delete_analysis_folder {
	my $method = 'delete_analysis_folder';
	my $self = shift;
	my %args = @_;
	my $analysis_folder = $args{analysis_folder};
	
	my $base_folder_path = $self->affy_bioconductor_delivery_path();
	$log->debug("OUT MAIN FOLDER '$base_folder_path'");
	
	unless ($analysis_folder){
		die "ANALYSIS FOLDER NOT GIVEN '$method'";
	}
	unless ($analysis_folder =~ /[^a-zA-A0-9\-]/){
		die"STRANGE CHAR SEEN '$analysis_folder' THIS IS NOT GOOD";
		
	}
	my $folder_path = "$base_folder_path/$analysis_folder";
	$log->debug("METHOD '$method' ABOUT TO DELETE FOLDER '$folder_path'");
	if (-d $folder_path){
		
		rmtree($folder_path,1,1);#folder_path, print msg about each file deleted, print msg about files that cannot be deleted
		
		#terrible hack.....
		#Since the web user apache and arraybot were both writing into the analysis folder the
		#permissions were set in such a way to prevent the web user from coming back through and
		#deleting the files.  So this will move the folder which can then be deleted by a admin type user
		#as a bonus if the folder was accidentally remove it can be recovered....
		my $command_line = "mv $folder_path $base_folder_path/deleted/";
		$log->debug("MOVE COMMAND LINE '$command_line'");
		
		my $results = system($command_line);
	}
	
	
	
}

###############################################################################
# add_analysis_session
# Add information to SBEAMS to register a type of analysis session
#Retrun affy_analysis_id for success 0 if it did not work
###############################################################################
sub add_analysis_session {
	my $method = 'add_analysis_session';
	my $self = shift;
	my %args = @_;
	
	my $rowdata_ref = $args{rowdata_ref};

	my $inserted_pk = $sbeams->updateOrInsertRow(		# insert the data 			
							table_name=>$TBMA_AFFY_ANALYSIS,
				   			rowdata_ref=>$rowdata_ref,
				   			return_PK=>1,
				   			verbose=>'',
				   			testonly=>'',
				   			insert=>1,
				   			PK=>'affy_analysis_id',
				   	  		);

	if ($inserted_pk){
		return $inserted_pk;
	}else{
		return 0;
	}
}


###############################################################################
# find_analysis_type_id
# Find the analysis type id from the analysis type name
#Give Analysis type name
#Return analysis type id or 0 if nothing is found
###############################################################################
sub find_analysis_type_id {
	my $method = 'find_analysis_type_id';
	my $self = shift;
	my $analysis_name_type = shift;
	
	unless ($analysis_name_type =~ /^\w/ ) {
		confess( __PACKAGE__ . "::$method Need to provide a analysis name type \n");
	}
	my $sql = qq~ SELECT affy_analysis_type_id
				  FROM $TBMA_AFFY_ANALYSIS_TYPE
				  WHERE affy_analysis_name like '$analysis_name_type'
				~;
	
	#$sbeams->display_sql(sql=>$sql);
				
	my @affy_analysis_ids = $sbeams->selectOneColumn($sql);
	
	
	if (@affy_analysis_ids) {
		return $affy_analysis_ids[0];
	}else{
		return 0;
	}
}

###############################################################################
# find_analysis_folder_name
# Find the folder name
#Give Analysis id
#Return analysis folder name or 0 if nothing is found
###############################################################################
sub find_analysis_folder_name {
	my $method = 'find_analysis_folder_name';
	my $self = shift;
	my $analysis_id = shift;
	
	unless ($analysis_id =~ /^\d/ ) {
		confess( __PACKAGE__ . "::$method Need to provide a analysis id \n");
	}
	my $sql = qq~ SELECT folder_name
				  FROM $TBMA_AFFY_ANALYSIS
				  WHERE affy_analysis_id = $analysis_id
				~;
	
	#$sbeams->display_sql(sql=>$sql);
				
	my @affy_folder_names = $sbeams->selectOneColumn($sql);
	
	
	if (@affy_folder_names) {
		return $affy_folder_names[0];
	}else{
		return 0;
	}
}

##############################################################################
# find_child_analysis_runs
# Find if a an analysis id has any children. 
#give an analysis id
#Return new instance of the Analysis_Data class or 0 if no data exists\
#return undef if no analysis id was given
###############################################################################
sub find_child_analysis_runs {
	my $method = 'find_child_analysis_runs';
	my $self = shift;
	my $parent_analysis_id = shift;
	
	return unless $parent_analysis_id;
	
	if  ($parent_analysis_id =~ /[a-zA-Z]/ ) {
		confess( __PACKAGE__ . "::$method Need to provide a parent analysis id\n");
	}
	my $sql = qq~ SELECT aa.affy_analysis_id, 
				 aa.folder_name,
				 aa.user_description, 
				 aa.analysis_description,
				 aa.parent_analysis_id, 
				 aat.affy_analysis_name, 
				 aa.date_created,
				 ul.username
				 FROM $TBMA_AFFY_ANALYSIS aa
				 JOIN 	$TBMA_AFFY_ANALYSIS_TYPE aat ON (aa.affy_analysis_type_id = aat.affy_analysis_type_id)
      			 JOIN $TB_USER_LOGIN ul ON (aa.user_id = ul.user_login_id)
      			 WHERE aa.parent_analysis_id = $parent_analysis_id
      			 AND aa.record_status NOT LIKE 'D'
				~;
					
	#$sbeams->display_sql(sql=>$sql);
				
	my @data = $sbeams->selectHashArray($sql);
	
	if ($data[0]){
		
		my $analysis_data_o = new SBEAMS::Microarray::Analysis_Data(data=>\@data);
		#print Dumper ($analysis_data_o);
		return $analysis_data_o;
	}else{
		return 0;
	}
}

###############################################################################
# find_analysis_project_id
# Find the project_id given a token name (folder name containing some analysis files)
#Give token
#Return project id or 0 if name is not in the database
###############################################################################
sub find_analysis_project_id {
	my $method = 'find_analysis_project_id';
	my $self = shift;
	my $token = shift;
	
	unless ($token =~ /^\w/ ) {
		confess( __PACKAGE__ . "::$method Need to provide a token\n");
	}
	my $sql = qq~ SELECT project_id
				  FROM $TBMA_AFFY_ANALYSIS
				  WHERE folder_name like '$token'
				~;
	
	#$sbeams->display_sql(sql=>$sql);
				
	my @affy_project_id = $sbeams->selectOneColumn($sql);
	
	
	if (@affy_project_id) {
		return $affy_project_id[0];
	}else{
		return 0;
	}
}



###############################################################################
# check_for_analysis_data
# Find if an project has any analysis data
#Give Project Id
#Return new instance of the Analysis_Data class or 0 if no data exists
###############################################################################
sub check_for_analysis_data {
	my $method = 'check_for_analysis_data';
	my $self = shift;
	my %args = @_;
	
	my $project_id = $args{project_id};
	#my $analysis_name_type = $args{analysis_name_type};
	
	unless ($project_id =~ /^\d/ ) {
		confess( __PACKAGE__ . "::$method Need to provide a project_id\n");
	}
		
	my $sql = qq~ SELECT aa.affy_analysis_id, 
				 aa.folder_name,
				 aa.user_description, 
				 aa.analysis_description,
				 aa.parent_analysis_id, 
				 aat.affy_analysis_name, 
				 aa.date_created,
				 ul.username
				 FROM $TBMA_AFFY_ANALYSIS aa
				 JOIN 	$TBMA_AFFY_ANALYSIS_TYPE aat ON (aa.affy_analysis_type_id = aat.affy_analysis_type_id)
      			 JOIN $TB_USER_LOGIN ul ON (aa.user_id = ul.user_login_id)
      			 WHERE aa.project_id = $project_id
      			 AND aa.record_status NOT LIKE 'D'
      			 
				~;
				
	#$sbeams->display_sql(sql=>$sql);
	my @data = $sbeams->selectHashArray($sql);
	
	if ($data[0]){
		
		my $analysis_data_o = new SBEAMS::Microarray::Analysis_Data(data=>\@data);
		#print Dumper ($analysis_data_o);
		return $analysis_data_o;
	}else{
		return 0;
	}

}
###############################################################################
# return_analysis_description
# Give a folder name
#return the analysis_field info or 0 if not found or no data exists
###############################################################################
sub return_analysis_description {
	my $method = 'return_analysis_description';
	
	my $self = shift;
	my %args = @_;
	my $folder_name = $args{folder_name};
	unless ($folder_name =~ /^\w/ ) {
		confess( __PACKAGE__ . "::$method Need to provide a folder $folder_name does not look good\n");
	}
	my $sql = qq~
				SELECT analysis_description 
				FROM $TBMA_AFFY_ANALYSIS 
				WHERE folder_name = '$folder_name'
			  ~;
	my ($info) = $sbeams->selectOneColumn($sql);
#The automated inforamtion collection should return a string with the name File Names at the start
#unless you have changed it.......
	
	if ($info =~ /File Names/){

		return $info;
	}else{
		$log->debug("REG EXP MISSED FINDING THE FILE INFO IN THE ANALYSIS INFO METHOD => $method");		
		return 0;
	}
}

###############################################################################
# getAnalysisInfoFromFolderName
# Given a folder name, return the analysis_id
###############################################################################
sub getAnalysisInfoFromFolderName {
	my $self = shift;
	my %args = @_;
	my $folder_name = $args{folder_name};
	unless ($folder_name =~ /^\w/ ) {
    $log->error( "Missing required parameter folder_name" );
    return undef;
	}
	my $sql = "SELECT * FROM $TBMA_AFFY_ANALYSIS WHERE folder_name = '$folder_name'";
  my $row = $sbeams->getDBHandle()->selectrow_hashref( $sbeams->evalSQL( $sql ) );
  return $row;
}


###############################################################################
# parse_file_names_from_analysis_description
# Give a string containing a comma delimited string of cel file names
#File Names =>20041213_07_1_SJL.CEL, 20041213_08_2_SJL_2.CEL
#Return a list of clean file names or 0 if nothing is found
###############################################################################
sub parse_file_names_from_analysis_description {
	my $method = 'parse_file_names_from_analysis_description';
	
	my $self = shift;
	my %args = @_;
	my $info = $args{analysis_description};
	
	unless ($info){
		return 0;
	}
	my @file_names = ();
	if ($info =~ /File Names =>(.+?)\/\//){
		
		my $file_info_string = $1;
		$log->debug("FOUND FILE NAMES '$file_info_string'");
	#first split on the commas in the string then remove the .CEL file extensions
		@file_names = grep {s/\.CEL//} split /,/,$file_info_string;
		$log->debug("CLEAN FILE NAME '@file_names'");
		return @file_names;
	}else{
		$log->debug("MISSED THE FILE NAMES METHOD '$method'");
		return 0;
	}
	
}

###############################################################################
# find_organism_id_from_file_root
# Give a list of cel file names
# Return a list of unique species id's or UNDEF if no data exists, don't return 0 since it might 
#be an organisim ID
###############################################################################
sub find_organism_id_from_file_root {
	my $method = 'find_organism_id_from_file_root';
	
	my $self = shift;
	my %args = @_;
	my @file_names = @{ $args{file_names_aref} };
	
	unless (@file_names){
		return 0;	
	}
#join together all the file names and make sure the
#quotes are correct for the sql query
	my $search_string = join "' , '", @file_names;
	$search_string = "'$search_string'";
	$log->debug("SEARCH STRING '$search_string'");
	
	
	my %unique_org_ids = ();
	
	my $sql = qq~
		SELECT afs.organism_id 
		FROM $TBMA_AFFY_ARRAY afa 
		JOIN $TBMA_AFFY_ARRAY_SAMPLE afs ON (afa.affy_array_sample_id = afs.affy_array_sample_id) 
		WHERE afa.file_root IN ($search_string)
		~;
			
	
	my @all_org_ids = $sbeams->selectOneColumn($sql);
	foreach my $org_id (@all_org_ids){
		$unique_org_ids{$org_id} = 1;
	}
	if( scalar (keys %unique_org_ids) > 0){
		$log->debug("FOUND ORG IDS keys '" . keys %unique_org_ids );
		return keys %unique_org_ids;
		
	}else{
		$log->debug("MISSED FINDING ORG IDS ");
		return undef;
	}
}


###############################################################################
# find_organism_name_form_ids
# Give a list of organism_name_id(s)
# Return the common name for example Human or Mouse 
#Return 0 for no hits
###############################################################################
sub find_organism_name_form_ids {
	my $method = 'find_organism_name_form_ids';
	
	my $self = shift;
	my %args = @_;
	my @org_ids= @{ $args{organism_id_aref} };
	
	unless ($org_ids[0] =~ /^\d+$/ ) {
		confess( __PACKAGE__ . "::$method Need to provide a Integer for the Organism ID you gave '$org_ids[0]'\n");
	}
	
	#join together all the file names and make sure the
	#quotes are correct for the sql query
	
	my $search_string = join "' , '", @org_ids;
 	$search_string = "'$search_string'";
	$log->debug("SEARCH STRING '$search_string'");
	
	
	my $sql = qq~ 
					SELECT organism_name 
					FROM $TB_ORGANISM
					WHERE  organism_id IN ($search_string)
				~;
	my @organism_names = $sbeams->selectOneColumn($sql);		
	if (@organism_names){
		return @organism_names;
	}else{
		return 0;
	}
	
				
}


###############################################################################
# find_sample_group_names
# Give a list of cel file names
# Return a list of sample group names
###############################################################################
sub find_sample_group_names {
	my $method = 'find_sample_group_names';
	
	my $self = shift;
	my %args = @_;
	my @file_names = @ {$args{cel_file_names} };
	my @all_sample_group_names  = ();
	foreach my $file_name (@file_names){
		unless ($file_name =~ /\.CEL$/){
			print "<h2>WARNING File Name '$file_name' DOES NOT APPEAR TO BE A CEL FILE AND WILL NOT BE USED FOR ANALYSIS <h2>";
			next;
		}
		my $clean_file_name = $file_name;
		$clean_file_name =~ s/.CEL$//;
		
		my $sql = qq~ SELECT sample_group_name
					  FROM $TBMA_AFFY_ARRAY_SAMPLE afs
					  JOIN $TBMA_AFFY_ARRAY afa ON (afa.affy_array_sample_id = afs.affy_array_sample_id)
					  WHERE afa.file_root = '$clean_file_name'
					~;
		my @sample_group_names = $sbeams->selectOneColumn($sql);
	
	 	if ($sample_group_names[0] =~ /^\w/){
		
	 		push @all_sample_group_names, $sample_group_names[0];
	 		
	 	}else{
	 		print "ERROR:Cannot Find Sample group name for FILE '$file_name'<br>";
	 	}
		
	}
	return @all_sample_group_names;
}
	
###############################################################################
# conditions_organism_info
# Give a list of condition_names
# Return an array of hashes of the distinct organism info
###############################################################################
sub conditions_organism_info {
	my $method = 'conditions_organism_info';
	
	my $self = shift;
	my %args = @_;
	my @condition_names  = @ {$args{condition_names_aref} };
	
	#join together all the condition names and make sure the
	#quotes are correct for the sql query
	
	my $search_string = join "' , '", @condition_names;
 	$search_string = "'$search_string'";
	$log->debug("SEARCH STRING '$search_string'");
	
	my $sql = qq~
		SELECT DISTINCT O.organism_name, O.genus, O.species
		FROM $TBMA_COMPARISON_CONDITION C 
		JOIN $TB_ORGANISM O ON (C.organism_id = O.organism_id)
		WHERE C.condition_name IN ($search_string)
	~;
	
	#$log->debug("SQL '$sql'");
	my @organism_info = $sbeams->selectHashArray($sql);
	
	return @organism_info;
	
	
}
	
}#closing bracket for the package

1;
