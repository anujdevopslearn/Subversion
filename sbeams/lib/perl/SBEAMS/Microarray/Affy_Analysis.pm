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
use Data::Dumper;
use Carp;
use FindBin;

use base qw(SBEAMS::Microarray::Affy);		
use SBEAMS::Connection::Tables;
use SBEAMS::Microarray::Tables;


my $R_program = '/tools/bin/R';
my $R_library = '/net/arrays/Affymetrix/bioconductor/library';


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
    
   	
	
	my $R_temp_dir = "../../../tmp/Microarray/R_CHP_RUNS/${file_name}_R_CHP";	#temp out dir for storing R and shell scripts	
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
output.file.name <- c("$out_R_CHP_file")
data <- ReadAffy(filenames =  cel.file.name)

eset <- mas5(data,sc=250)
PACalls <- mas5calls(data)

Matrix <- exprs(eset)
output <- cbind(row.names(Matrix),Matrix,exprs(PACalls),se.exprs(PACalls))
headings <- c("Probesets","MAS5_Signal","MAS5_Detection_calls", "MAS5_Detection_p-value")
write.table(output,file=output.file.name,sep="\\t",col.names = headings,row.names=FALSE)



jpeg("$out_chip_image", width=1000, height=1000)
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
		or "Cannot open '$out_shell_script'\n";
		
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
	my $method = 'log_R_run';
 
	my $self = shift;
	
	my $info = shift;
	
	
	open OUT, ">>../../../tmp/Microarray/AFFY_R_CHP_RUNS.log" or
		die "CANNOT OPEN R_CHP RUN LOG $!\n";
		
	my $date = `date`;
	chomp $date;
	
	my $line = "$date $info\n";
	
	print OUT $line;
	close OUT;
} 



###############################################################################
# get_annotation_set_id
#Given a string of comma seperarted affy_array_ids find the most recent annotation set ids
#Return the most resent annotation_set_id as a comma delimited string. 
###############################################################################
sub get_annotation_set_id_OLD {
	my $method = 'get_annotation_set_id';
	my $self = shift;
	
	my %args = @_;
	
	my $arrays = $args{affy_array_ids};

	
	my $sql = qq~ SELECT DISTINCT anno_set.slide_type_id , anno_set.affy_annotation_set_id
			FROM $TBMA_AFFY_ANNOTATION_SET anno_set
			JOIN $TBMA_AFFY_ARRAY afa  ON (anno_set.slide_type_id =  afa.array_type_id)
			WHERE afa.affy_array_id IN ($arrays)
		    ~;	 
	print "ANNO SET SQL '$sql'<br>";
	my @rows = $sbeams->selectSeveralColumns($sql);
	
							#Need to pull out the greatest annotation set id for each of the different slide types
	my %all_slide_types = ();
	foreach my $record (@rows){
		my ($slide_type_id, $anno_set_id) = @{$record};
		if ( exists $all_slide_types{$slide_type_id}){
			if ($all_slide_types{$slide_type_id} > $anno_set_id){
				$all_slide_types{$slide_type_id} = $anno_set_id;
			}
		}else{
			$all_slide_types{$slide_type_id} = $anno_set_id;
		}
	}
	
	my $all_annotation_set_ids = join ",", values  %all_slide_types ;
	
	
	
	print "ANNO ID '$all_annotation_set_ids<br>";
	return $all_annotation_set_ids;	#CHANGED 9.8.04 from "$rows[0]"
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

###############################################################################
# find_chips_with_data
#given a project_id find all the affy_array ids that have data
#return array of affy_array_ids
###############################################################################
sub find_chips_with_data {
	my $method = 'find_chips_with_data';
	my $slef= shift;
	my %args = @_;
	
	my $project_id = $args{project_id};
	
	confess(__PACKAGE__ . "::$method Need to provide arugments 'project_id'\n") unless ($project_id =~ /^\d/);
    

	my $sql = qq~ 	SELECT distinct (gi.affy_array_id) 
			FROM $TBMA_AFFY_GENE_INTENSITY gi
			JOIN $TBMA_AFFY_ARRAY afa ON (afa.affy_array_id = gi.affy_array_id)
			JOIN $TBMA_AFFY_ARRAY_SAMPLE afs ON (afs.affy_array_sample_id = afa.affy_array_sample_id)
			WHERE afs.project_id = $project_id 
		
		   ~;
	
#	print "SQL '$sql'";	
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
	
	my $affy_array_ids = $args{affy_array_ids};
	my $annotation_display = $args{annotation_display};
	my @all_constriants = @ {$args{constriants}};
	
	my $R_protocol_id     = $args{r_chp_protocol};
	my $annotation_set_id = $args{annotation_id};
	
	confess(__PACKAGE__ . "::$method Need to provide arugments 'affy_array_ids' you gave '$affy_array_ids'\n") unless ($affy_array_ids);
    
	my $add_affy_db_link_table = '';
	
	
	for (my $i; $i<=$#all_constriants; $i++){ 
		my $constraint = $all_constriants[$i];
		
		if ($constraint =~ /link\.db_id/){			#only add the affy_db_links table if we have a constriant for it 
			$add_affy_db_link_table = "JOIN $TBMA_AFFY_DB_LINKS link ON (anno.affy_annotation_id = link.affy_annotation_id)";
		
		}elsif($constraint =~ /anno\.gene_name (LIKE.*)/){	#the gene name constrain needs to search two fields
			my $search_term = $1;
			my $new_constriant = "AND (anno.gene_symbol $search_term OR anno.gene_title $search_term) ";
			$all_constriants[$i] = $new_constriant;
		}else{
		}
	}
		
		
	
	
	my $constriants = join " ", @all_constriants;
	
	my $sql = qq~ SELECT top 10000( gi.probe_set_id), afa.file_root, gi.affy_array_id, gi.signal, gi.detection_call, anno.gene_symbol, anno.gene_title, gi.protocol_id
			FROM $TBMA_AFFY_GENE_INTENSITY gi 
			JOIN $TBMA_AFFY_ARRAY afa ON (gi.affy_array_id = afa.affy_array_id)
			JOIN $TBMA_AFFY_ANNOTATION anno ON (anno.probe_set_id = gi.probe_set_id)
			JOIN $TBMA_AFFY_ANNOTATION_SET anno_s ON (anno.affy_annotation_set_id = anno_s.affy_annotation_set_id) $add_affy_db_link_table
			WHERE anno_s.affy_annotation_set_id = $annotation_set_id AND 
			gi.protocol_id = $R_protocol_id AND
			gi.affy_array_id IN ($affy_array_ids) 
			$constriants
			order BY gi.probe_set_id
			 ~;
	
	return $sql;


}



}#closing bracket for the package

1;
