###############################################################################
# Program     : SBEAMS::Microarray::Affy_Analysis
# Author      : Pat Moss <pmoss@systemsbiology.org>
# $Id$
#
# Description :  Module which implements methods for parsing Affymetrix
# annotation files.
# 
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
#
###############################################################################

{package SBEAMS::Microarray::Affy_Annotation;
	
our $VERSION = '1.00';


##############################################################
use strict;
use vars qw($sbeams $self);		#HACK within the read_dir method had to set self to global: read below for more info

use File::Basename;
use File::Find;
use Data::Dumper;
use Carp;
use FindBin;

use SBEAMS::Connection qw($log);
use SBEAMS::Connection::Tables;
use SBEAMS::Microarray::Tables;

use base qw(SBEAMS::Microarray::Affy);		#declare superclass




#######################################################
# Constructor
#######################################################
sub new {
	my $class = shift;
	
	my @all_records =();
	my $self = {ALL_RECORDS =>\@all_records};
	
	bless $self, $class;
	
	
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
###############################################################################
# Get/Set the DATABASE status
#
#
###############################################################################
sub database {
	my $self = shift;
	if (@_){
		#it's a setter
		$self->{_DATABASE} = $_[0];
	}else{
		#it's a getter
		$self->{_DATABASE};
	}
}

###############################################################################
# Get/Set the run_mode status
#
#
###############################################################################
sub run_mode {
	my $self = shift;
	if (@_){
		#it's a setter
		$self->{_RUN_MODE} = $_[0];
	}else{
		#it's a getter
		$self->{_RUN_MODE};
	}
}


###############################################################################
#Set Record
#
###############################################################################
sub set_record {
    my $method = 'set_record';
    my $self = shift;
    my $record = shift;
    confess(__PACKAGE__ . "::$method Need to provide a record ") unless ($record);
    push @ { $self->{ALL_RECORDS}} , $record;

}
###############################################################################
#Get Record
#
###############################################################################
sub get_record {
    my $method = 'get_record';
    my $self = shift;
   
  return  pop @{ $self->{ALL_RECORDS}} 

}

###############################################################################
#set_annotation_set_id
#Set the annotation set id.  Will first go grab the slide type id then check to see
# if this annotation set has been loaded.  If so the user will have to choose to delete the previous
#version.
###############################################################################
sub set_annotation_set_id {
    	my $method = 'set_annotation_set_id';
    	my $self = shift;
	   
	my %args = @_;
	
	my $annotation_date = $args{anno_date};
	my $genome_version  = $args{genome_version};
	my $file_name	 = $args{file_name};
	
	confess(__PACKAGE__ . "::$method Need to provide key value pair 'anno_date', 'genome_version', 'file_name'") unless (%args);
	
  	my $slide_type_id = $self->find_slide_type_id(slide_name => $file_name);
	
	my $id = $self->check_previous_annotation_set(	slide_type_id   => $slide_type_id,
							genome_version  => $genome_version,
							annotation_date => $annotation_date,
					     	     );
	
	$self->{ANNO_SET_ID} = $id		#set the ANNOTATION SET ID into the annotation object

}

###############################################################################
#get_annotation_set_id
#Return the annotation_set_id
###############################################################################
sub get_annotation_set_id {
    	my $method = 'get_annotation_set_id';
    	my $self = shift;
	return $self->{ANNO_SET_ID}
}

###############################################################################
#get_record_count
#Return the number of records
###############################################################################
sub get_record_count {
    	my $method = 'get_record_count';
    	my $self = shift;
	return scalar @ { $self->{ALL_RECORDS}};
}
###############################################################################
# parse_data_file
#
# Simple parse of the data file foreach row of the data file make a record hash keys will be the data column names and the value will be the piece of data from the particular row column intersection
#sets all the data into little objects, basically an array of hashes
###############################################################################
sub parse_data_file {
	my $self = shift;
	my $file_name = shift;
	
	open DATA, $file_name or 
		die "CANNOT OPEN ANNOTATION FILE '$!' \n";
	
	my @col_names = ();
	my $count = 0;
	while(<DATA>){
		chomp;
		s/^"//;					#remove the first quote from the line
		s/"$//;
		my @line_parts = split /","/, $_;  	#split on the quotes and comma.  Commas do exists in some of the data fields
	
	
		if ($count == 0){			#grab the column names	
			@col_names = @line_parts;
			if ($self->verbose() > 0){
				print "@col_names\n";
			}
			$count ++;
			next;	
		}
	
		if($count == 1){
			# find Annotation Date and Genome Version columns
 		  my $annotation_date_column;
			my $genome_version_column;
		  for(my $i=0;$i<$#col_names;$i++) {
				if($col_names[$i] =~ /Annotation\ Date/i) {
						$annotation_date_column = $i;
				}
				elsif($col_names[$i] =~ /Genome\ Version/i) {
						$genome_version_column = $i;
				}
		  }
			my ($annotation_date, $genome_version) = @line_parts[$annotation_date_column, $genome_version_column];
			my $file_base_name = basename($file_name);		#will use the file name to find the slide_type_id
			
			
			
			unless ($file_base_name =~ s/_anno.*//){		#all files should contain _anno.csv 
				die "THE FILE NAME '$file_base_name' DOES NOT LOOK GOOD\n",
				     "All file names must have '<name>_anno.csv' AND the name must be in entered into MA_slide_type.name column\n";
			}
			
			
			if ( $self->verbose() > 0 ){
				print "ANNO FILE ROOT NAME '$file_base_name'\n";
			}
			
			$self->set_annotation_set_id(
							anno_date 	  => $annotation_date,
							genome_version    => $genome_version,
							file_name	  => $file_base_name,
							);
		}
		
		
		my %record_h = ();
		for (my $i = 0; $i <= $#line_parts; $i ++){
		
			my $name = ();
			if ($name = $col_names[$i]){
			}else{
				$self->anno_error(error => "LINE $count FIELD '$i' DOES NOT HAVE A COLUMN NAME");
			}
			
			if ($self->verbose() > 3 ) {
				print  "_${i}__ $name => $line_parts[$i]\n";
			}
			$record_h{$name} = $line_parts[$i];
			
		}
		
		$self->set_record( \%record_h);
		$count ++;
	}		
	
}


###############################################################################
#add_record_to_annotation_table
#Given a record hash_ref take the columns needed and upload into Affy annotation table
#Return the PK
###############################################################################
sub add_record_to_annotation_table {
    	my $method = 'add_record_to_annotation_table';
    	my $self = shift;
	
	my %args = @_;
	
	my $record_href = $args{record};
	my %record_h= %{$record_href};
							
							
							
							#setup the rowdata_ref need to insert the record
							#table_column_name => value : The keys for the record_h are taken from the Affy annotation file
	
	confess(__PACKAGE__ . "::$method Need to provide reference to a record hash ") unless (ref($record_href));
	
	my %rowdata_h = ( 	
				affy_annotation_set_id	 => $self->get_annotation_set_id(),
				probe_set_id	 	 => $record_h{'Probe Set ID'},
			  	sequence_type		 => $record_h{'Sequence Type'},
				sequence_source		 => $record_h{'Sequence Source'},
				transcript_id		 => $record_h{'Transcript ID'},
				
				target_description_feature => $record_h{'Target Description'}   =~ m!FEA=(.+?)/! ? $1: undef ,
				target_description	   => $record_h{'Target Description'}   =~ m!DEF=(.+?)/! ? $1: undef ,
				target_description_note	   => $record_h{'Target Description'}   =~ m!NOTE=(.+?)/!? $1: undef ,
				
				representative_public_id => $record_h{'Representative Public ID'},
				archival_unigene_cluster => $record_h{'Archival UniGene Cluster'},
				
				gene_title	 	 => $record_h{'Gene Title'},
				gene_symbol		 => $record_h{'Gene Symbol'},
				chromosomal_location	 => $record_h{'Chromosomal Location'},
				
				pathway			 		=> $record_h{'Pathway'},
				qtl			 			=> $record_h{'QTL'},
				annotation_description  => $record_h{'Annotation Description'},
				transcript_assignment   => $record_h{'Transcript Assignments'},
				annotation_transcript_cluster => $record_h{'Annotation Transcript Cluster'},
				annotation_notes  		=> $record_h{'Annotation Notes'},
			  
			  );

	%rowdata_h = $self->truncate_data(record_href => \%rowdata_h); #some of the data will need to truncated to make it easy to put all data in varchar 255 or less
	
	my $rowdata_ref = \%rowdata_h;
	
	my $affy_annotation_set_id = $sbeams->updateOrInsertRow(				
							table_name=>$TBMA_AFFY_ANNOTATION,
				   			rowdata_ref=>$rowdata_ref,
				   			return_PK=>1,
				   			verbose=>$self->verbose(),
				   			testonly=>$self->testonly(),
				   			insert=>1,
				   			PK=>'affy_annotation_id',
				   		   );
	return $affy_annotation_set_id
}

###############################################################################
#parse_alignment
#Given the data from the aligment field 
#FORMAT:chromosome // start-end // strand // percentage identity"
#Example: "chr9:109422168-109422413 (-) // 100"
#Add the data to the current record
###############################################################################
sub parse_alignment_OLD {
    	my $method = 'parse_alignment';
    	my $self = shift;
	
	
	my %record_h = @_;
	
	my $alignemt = $record_h{'Alignments'};
	
	confess(__PACKAGE__ . "::$method Need to provide a record hash ") unless (%record_h);
	
	if ($alignemt =~ m!:(\d+)-(\d+)\s 	#find the genomic bp Start Stop Example chr6:109422168-109422413
			  \((\+|-)\)\s+ 	#pull out the strand orientaion Example (+) Escape the first parenthesis
		          //\s(.+?)\s		#pull out the percent Identity 
			!x){
			
		$record_h{gene_start} = $1;
		$record_h{gene_stop}   = $2;
		$record_h{gene_orientation} = $3;
	        $record_h{percent_identity} = $4;
		
		
		if ($self->verbose() > 0) {
			print "PARSED ALIGNMENT '$alignemt'\n";
			print "\t'$record_h{gene_start}' '$record_h{gene_stop}' '$record_h{gene_orientation}' '$record_h{percent_identity}'\n";
		}
		return %record_h;
	}else{
		
		if ( $alignemt && $alignemt ne '---'){
			$self->anno_error(error => "ERROR: ALIGNMENT NOT PARSED '$alignemt'");
			
		}
	}

	return %record_h;			#return the same hash

}
			
	


###############################################################################
#add_record_to_affy_db_links
#Given a record hash_ref take the columns needed and upload into Affy annotation table
#Return the PK
###############################################################################
sub add_record_to_affy_db_links {
    	my $method = 'add_record_to_affy_db_links';
    	my $self = shift;
	
	my %args = @_;
	
	my $record_href = $args{record};
	my $affy_anno_pk = $args{affy_annotation_pk};
	
	confess(__PACKAGE__ . "::$method Need to provide  'record' and 'affy_annotation_pk' ") unless ($record_href && $affy_anno_pk);
	
	my %record_h= %{$record_href};
	
			#dbxref.dbxref_tag	#value from Affy annotation file
	my %external_links = ( 	LocusLink => $record_h{'LocusLink'},
				SwissProt => $record_h{'SwissProt'},
				FlyBase   => $record_h{'FlyBase'},
				WormProt  => $record_h{'WormBase'},
				EC 	  => $record_h{'EC'},
				NCBIProt  => $record_h{'RefSeq Protein ID'},	
			    	ENSEMBL	  => $record_h{'Ensembl'},
				OMIM	  => $record_h{'OMIM'},
			    	MGI	  => $record_h{'MGI Name'},
			        RGD	  => $record_h{'RGD Name'},
			   
			    );
				###NEED TO ADD TO DBXREF TABLE 
				#UNKNOWN => $record_h{'AGI'}	
				
				


	foreach my $db_ref_tag (keys %external_links){				#loop through all the fields to upload
		my $db_id = $external_links{$db_ref_tag};			#actual accession number for external database
		
		my $dbxref_id = $self->get_xref_id($db_ref_tag);

                if ( !defined $db_id || $db_id =~ /---/ ) { #skip uploading blank data
		  next; 
                }
		
		my @parts = split "///", $db_id;		#each field could hold multiple ids
		
		foreach my $val (@parts){
			
			$val =~ s/\s//g;			#remove any white space
			
			$val =~ s/^EC://;			#remove the EC tag from the EC accession number it is not needed
				
			if ( $self->debug ){
				print "EXTERNAL DBID '$val'\n";
			}
			
			my $rowdata_ref = { 	
				affy_annotation_id	=> $affy_anno_pk,
				db_id			=> $val,
				dbxref_id		=> $dbxref_id,
				};
			 $sbeams->updateOrInsertRow(				
							table_name=>$TBMA_AFFY_DB_LINKS,
				   			rowdata_ref=>$rowdata_ref,
				   			return_PK=>1,
				   			verbose=>$self->verbose(),
				   			testonly=>$self->testonly(),
				   			insert=>1,
				   			PK=>'affy_links_id',
				   		   );
		}
	}
				

}

###############################################################################
#add_data_child_tables
#Take data from a record_h parse and add to child tables of the affy_annotation table.  All the sub tables will hold a FK to the affy_annotaion_table
#Will load data into a bunch of tables
###############################################################################
sub add_data_child_tables {
    	my $method = 'add_data_child_tables';
    	my $self = shift;
	my %args = @_;
	
	my $record_href = $args{record};
	my $affy_anno_pk = $args{affy_annotation_pk};
	
	my %record_h = %{$record_href};
	
	
	
	confess(__PACKAGE__ . "::$method Need to provide  'record' and 'affy_annotation_pk' ") unless (%record_h && $affy_anno_pk);
	
	my %ontology_column_id	= $self->get_gene_ontolgy_types();			#maps the affy_column heads to a db id
	

####################
			#A column from the affy annotation .csv file will be parsed and added to a child table.  The hash below will be used to 
			#pull the data from the record hash, parse the data and supply all the data data need to insert the record into the child tables 
			
###Example hash		
			
#Data_column name <From Affy annocolun header> => {	REG_EXP used to parse affy annotation line. regular expression will be used with the 'x' flag so white space will be ignored
#							MULTI_RECORDS < NO> if the piece of data has a /// it means there are multiple records that do not need to be split apart, the default is to split records into individual chunks
#							TABLE_NAME   <$TABLE_VAR> Name of the table to insert data into
#							PK           <Primary key name>  Name of the primary key column of the table to insert into
#							COLUMN_NAMES <Annon hash> Foreach piece of data to capture have a column name as the value for each numeric ID.  The number ID's is the order of the data being captured by the REG_EXP 
#							RUN_METHOD  <method name> Some inserts will need to gather data from various other tables this can be done by using a method.						
#}

	my $ontlogy_reg_exp = qr!(\d+)\s+//   #grab the ID 
				\s+(\w.+?)\s//	#grab the gene_ontology_description
				\s+(\w.*)	#grab the gene_ontology_evidence 
				!x;
	my %child_tables = (	
			
		
			### Ontology Suff ###	
			
			"Gene Ontology Biological Process"=>{
								REG_EXP => $ontlogy_reg_exp,
								
								COLUMN_NAMES => { 	1 => 'affy_gene_ontology_id',
											2 => 'gene_ontology_description',
											3 => 'gene_ontology_evidence',
										},
								
								
								TABLE_NAME => $TBMA_GENE_ONTOLOGY,
								PK	   => 'gene_ontology_type_id',
							   	RUN_METHOD => 'add_affy_db_links',
							},
							
			"Gene Ontology Cellular Component"=>{
								REG_EXP => $ontlogy_reg_exp,
								
								COLUMN_NAMES => { 	1 => 'affy_gene_ontology_id',
											2 => 'gene_ontology_description',
											3 => 'gene_ontology_evidence',
										},
								
								
								TABLE_NAME => $TBMA_GENE_ONTOLOGY,
								PK	   => 'gene_ontology_type_id',
							   	RUN_METHOD => 'add_affy_db_links',
							},
			"Gene Ontology Molecular Function"=>{
								REG_EXP => $ontlogy_reg_exp,
								
								COLUMN_NAMES => { 	1 => 'affy_gene_ontology_id',
											2 => 'gene_ontology_description',
											3 => 'gene_ontology_evidence',
										},
								
								
								TABLE_NAME => $TBMA_GENE_ONTOLOGY,
								PK	   => 'gene_ontology_type_id',
							   	RUN_METHOD => 'add_affy_db_links',
							},
			### End of Ontology ##
			
			
				Alignments	      =>{
								REG_EXP =>     qr!\s?(.+?):		#pull the Chromsome Information Example 'chr16:'
										(\d+)-(\d+)\s 		#find the genomic bp Start Stop Example chr6:109422168-109422413
			  						 	\((\+|-)\)\s+ 		#pull out the strand orientaion Example (+) Escape the first parenthesis
		          							//\s(.+?)\s!x,		#pull out the percent Identity
								
								COLUMN_NAMES => { 	1 => 'match_chromosome',
											2 => 'gene_start',
											3 => 'gene_stop',
											4 => 'gene_orientation',
											5 => 'percent_identity',
										},
								
								TABLE_NAME => $TBMA_ALIGNMENT,
								PK	   => 'alignment_id',
							   	
							 },
				"Trans Membrane_NOT_USED"       =>{### THIS IS WOULD PARSE WHAT THE AFFY PROBE SET DATA IN TABULAR FORMAT DESCRIBES, BUT THE FILE IT SELF HAS A MUCH DIFFERNT FORMAT
								REG_EXP =>     qr!numtm:(\d+); 		#grab the number of transmemebrane domains
										  Nin-prob:(\w+);	#grab the the probability the the N term is interior					
										  Type:(\w+);		#grab the type values :SIGNAL, ANCHOR, empty ""		
										!x,
								
								COLUMN_NAMES => { 	1 => 'number_of_domains',
											2 => 'nin_prob',
											3 => 'type',
										},
								
								TABLE_NAME => $TBMA_TRANS_MEMBRANE,
								PK	   => 'trans_membrane_id',
							 	
								#sub table info
								ST_REG_EXP => qr!TM from (\d+) to (\d+): #grab the start and stop of the TM domain
										 Eval:(\d\.\d+)		 #grab the e-val for the TM domain prediction		
										!x,
								ST_COLUMN_NAMES =>   {  1 => 'tm_protein_start',
											2 => 'tm_protein_end',
											3 => 'tm_e_value',
										      },	
							 	ST_TABLE_NAME	=>$TBMA_TRANS_MEMBRANE_DOMAIN,
								ST_PK		=>'trans_membrane_domain_id',
							 	ST_FK		=>'trans_membrane_id',
							 },
				
				"Trans Membrane"      		=>{					#Example 'NP_054700.1 // span:417-439 // numtm:1'
								REG_EXP =>     qr!(\w.+?)\s.*numtm:(\d+)!x,	#grab the number of predicted domains.  This format just repeats the same information over and over for each predicted TM domain	
										
								
								COLUMN_NAMES => { 	1 => 'protein_accession_numb',
													2 => 'number_of_domains',
											
										},
								
								TABLE_NAME => $TBMA_TRANS_MEMBRANE,
								PK	   => 'trans_membrane_id',	
								#MULTIPLE_RECORDS => 'NO',
								
								},
				"Overlapping Transcripts"      =>{					#Example 'NM_173599 // hypothetical protein FLJ40126 // chr12:38306286-38588369 (+)'
								REG_EXP =>     qr!(\w+)\s//		#grab the accession number
										 \s(.+?)\s//		#grab the title
										 \s(.+?):		#pull the Chromsome Information Example 'chr16:'
										 (\d+)-(\d+)\s 		#find the genomic bp Start Stop Example chr6:109422168-109422413
			  						 	\((\+|-)\) 		#pull out the strand orientaion Example (+) Escape the first parenthesis
										 !x,		
										
								
								COLUMN_NAMES => { 	1 => 'accession_number',
											2 => 'title',
											3 => 'overlapping_choromosome',
											4 => 'overlapping_gene_start',
											5 => 'overlapping_gene_end',
											6 => 'gene_orientation',
										},
								
								TABLE_NAME => $TBMA_OVERLAPPING_TRANSCRIPT,
								PK	   => 'overlapping_transcript_id',	
								},
				"Protein Families"      	=>{					
													#Example 'ec // ACRO_HUMAN // ACRO_HUMAN EC:3.4.21.10:ACROSIN PRECURSOR (EC 3.4.21.10). // ---'
								REG_EXP =>     qr!(EC):(\d.+?):		#grab the database_type  AND grab the EC number
										  (\w.+?)\s//		#grab the description
										 !ix,		
										 			#Example 'Hanks // ECK // KECK_HUMAN (ECK) KINASES:5.2.1 | PTK Group B membrane spanning protein tyrosine kinases.PTK XI Eph/Elk/Eck orphan receptor family .ECK // ---'
								REG_EXP_2 => 	qr!(Hanks)\s//		#grab the database type
										  \s(\w.+?)\s//		#grab the HANK accession number
										  \s(\w.+?)//		#grab the description
										  !x,	
								
													#Example 'P450 // Q62397 // CYP2B-10 Cyt P450: Animalia.CYP2B-10.mou // ---'
								REG_EXP_3 => 	qr!(P450)\s//		#grab the database type
										  \s(\w.+?)\s//		#grab the P450 accession number
										  \s(\w.+?)//		#grab the description
										  !x,
										 	
								COLUMN_NAMES => { 	
											1 => 'database_type',
											2 => 'accession_number',
											3 => 'description',
											#4 => 'e_value', 	#turned off None of the inital annotation files had field
										},
								
								TABLE_NAME => $TBMA_PROTEIN_FAMILIES,
								PK	   => 'protein_families_id',	
								RUN_METHOD => '$self->add_affy_db_links(accession_number 	=>$accession_number,
												  	affy_anno_id		=>$affy_anno_pk,
												  	dbxref_tag		=>$database_type,
												 	)',
										
								},
							
				InterPro      			=>{					
													#Example 'IPR003309 // Transcriptional regulator SCAN /// IPR007087 // Zn-finger, C2H2 type'
								REG_EXP =>     qr!(IPR\d+)\s//		#grab the Accession number
										  \s(\w.*)(?:\s+//|$)		#grab the description
										 !x,		
										
								COLUMN_NAMES => { 	1 => 'accession_number',
											2 => 'interpro_description',
											
										},
								
								TABLE_NAME => $TBMA_INTERPRO,
								PK	   => 'interpro_id',	
								RUN_METHOD => '$self->add_affy_db_links(accession_number 	=>$accession_number,
												 	affy_anno_id		=>$affy_anno_pk,
												 	dbxref_tag		=> "InterPro"
												 	)',
									       
								},
				"Protein Domains"      		=>{					
													#OLD Example 'scop // d1bupa1 // d1bupa1 SCOP:c.55.1.1:| Heat shock protein 70kDa, ATPase fragment // --- /// scop // d1dkza_ // d1dkza_ SCOP:e.20.1.1:'
#				REG_EXP =>     qr!(scop)\s//		#grab the Database
#										  \s(\w.+?)\s//   	#grab the Accession number
#										  .+?\s(\w.*)\s// 	#grab the description
#										 !x,		
													#example ' pfam // IL4 // Interleukin 4 // 6.5E-97'
								REG_EXP_2 =>    qr!(pfam)\s//		#grab and Accession number 
										   \s(\w.+?)\s// 	#grab the Database type 
										  .+?\s(\w.*)\s//\s	#grab the description
										  (.*)			#grab the e-value
										 !x,
                 # New scop example 'scop // a.4.1.Paired domain // All alpha proteins; DNA/RNA-binding 3-helical bundle; Homeodomain-like; Paired domain'
								REG_EXP =>     qr!(scop)\s//		#grab the Database
										  \s(\w(?:\.\d)+).+?\s//   	#grab the Accession number
										  .+?\s(\w.*)\s// 	#grab the description
										 !x,		
								
										
								COLUMN_NAMES => { 	1 => 'database_type',
											2 => 'accession_number',
											3 => 'protein_domain_description',
											4 => 'protein_domain_e_value',
										},
								
								TABLE_NAME => $TBMA_PROTEIN_DOMAIN,
								PK	   => 'protein_domanin_id',	
								RUN_METHOD => '$self->add_affy_db_links(accession_number 	=>$accession_number,
												 	affy_anno_id		=>$affy_anno_pk,
												 	dbxref_tag		=>$database_type,
												 	)',
									       

								},

			);
			
	foreach my $record_key (keys %child_tables){			#start looping through child_tables keys
	
		#next unless $record_key =~ 'Gene Ontology ';		#DEBUG ONLY 
	
		my $full_record_value = $record_h{$record_key};		#pull the piece of data from the record hash
					 
		if ($self->verbose() > 0){
			print "RECORD_KEY '$record_key' VALUE '$full_record_value'\n";
		}
		
		
		my @all_reg_exp = grep {/^REG_EXP/} keys % {$child_tables{$record_key} };	#pull all the reg exp keys that might be needed most will only have one...
		
		my $rowdata_ref = {};
		my @multi_records = ();

                # Set a default
                $child_tables{$record_key}{MULTIPLE_RECORDS} ||= 'NO';

		if ( $child_tables{$record_key}{MULTIPLE_RECORDS} eq 'NO'){
		 	push @multi_records, $full_record_value;			 	
		}else{
			@multi_records = split /\/\/\//,$full_record_value;		#split on the /// to make individual records
		}
		@multi_records = $self->truncate_data(data_aref => \@multi_records);
		
		RECORD_VAL:foreach my $record_value (@multi_records) {
		
			next if $record_value && $record_value eq '---';					#skip the blank fields
			if ($self->verbose() > 0){
				print "RECORD PART '$record_value'\n";
			} 
			
			for( my $i = 0; $i<=$#all_reg_exp; $i++) {			#loop through the regular expression 
				my $reg_exp_key = $all_reg_exp[$i];
				my $reg_exp = $child_tables{$record_key}{$reg_exp_key};	
				
				if ($record_value && $record_value =~ /$reg_exp/){			#run the regular expression
					for (my $i = 1; $i <= $#+; $i ++){		# @+ = LAST_MATCH_END perl internal variable, array holds the offsets of the ends of the last successful sub matches, which can be use to find out how many matches where made
					
						my $column_name = $child_tables{$record_key}{COLUMN_NAMES}{$i};
					
						no strict 'refs';
						$$rowdata_ref{$column_name} = ${$i};		#add the data found to the hash-ref. ${$i} = to $1.... from the data the reg_exp found
						if ($self->verbose() > 0){
							print "REG EXP FOUND POSITION $i '${$i}' INSERT INTO '$column_name'\n";
						} 
					}
					last;
				}else{
						
					if ($i == $#all_reg_exp){
                                                $record_value = '' if !defined $record_value;
						$self->anno_error(error => "ERROR: Cannot MATCH VAL '$record_value'\n\tREG_EXP '$reg_exp'");
						next RECORD_VAL ;	#if no more regular expression are in the @all_reg_exp array move on to the next record since there is not data to insert for this particular chunk	
					}
				}
			}
####################################################################
### Specific for Gene Ontology columns only .....
			
			if ($record_key =~ /Gene Ontology/){					#Need to convert the affy GO accession to a real GO accession number then add a record to the DBREF table
				
				my $affy_go_accession_numb = $$rowdata_ref{affy_gene_ontology_id};
				
				
				my $pad = '0' x (7 - length($affy_go_accession_numb));
				my $go_accession_numb = "GO:" . $pad  . $affy_go_accession_numb;#GO accession numbers are 7 digit long, need to pad affy accession numbers to the correct format
												#example Affy 1234 -> GO:0001234
					
						
				my $affy_db_linds_id = $self->add_affy_db_links(accession_number =>$go_accession_numb,
										affy_anno_id		=>$affy_anno_pk,
										dbxref_tag		=> 'GO',
										);
				$$rowdata_ref{affy_db_links_id} = $affy_db_linds_id;
			
				my $ontology_type_id = $ontology_column_id{$record_key};	#pull the ontology_type_id 
				$$rowdata_ref{gene_ontology_type_id} = $ontology_type_id;
			
				if ($self->verbose() >0 ){
					print "ADDING ONTOLOGY INFO RECORD_TYPE '$record_key' AFFY_DB_LINK_ID '$affy_db_linds_id' GO ACCESSION '$go_accession_numb'\n ONTOLOGY_TYPE_ID '$ontology_type_id'\n";
				}
			} elsif ( $record_key =~ /^Alignments$/) {
        if ( length( $rowdata_ref->{match_chromosome} ) > 25 ) {
          $log->warn( "Truncating match_chromosome: $rowdata_ref->{match_chromosome}" );
			  	$$rowdata_ref{match_chromosome} = substr( $$rowdata_ref{match_chromosome}, 0, 25 );
        }
      }

###################################################################			
### Add in link to Affy_Db_links table if needed

			if ( defined $record_key && 
                             defined $child_tables{$record_key}{RUN_METHOD} && 
                             $child_tables{$record_key}{RUN_METHOD} =~ /add_affy_db_links/ 
                             && $record_key !~ /Gene Ontology/ ) {
				my $accession_number = $$rowdata_ref{accession_number};
				delete($$rowdata_ref{accession_number});			#need to delete the key since the data will be kept in the affy_db_links table
				
				my $database_type = $$rowdata_ref{database_type};		#need to delete this key too
				delete($$rowdata_ref{database_type});				# only the "Protein Familiy" record keys should have this field			
				
				my $method = $child_tables{$record_key}{RUN_METHOD};
				
				if  ($accession_number && $accession_number !~ /NULL/i ){	#some of the data does not have a valid accession number in the file so Affymetrix puts in NULL 
				
					my $affy_db_linds_id = eval $method;
					die "EVAL ERROR '$@'\n"if $@;
					$$rowdata_ref{affy_db_links_id} = $affy_db_linds_id;
				
					if ($self->verbose() >0 ){
						print "ADDING AFFY_DB_ID INTO '$record_key' AFFY_DB_LINK_ID '$affy_db_linds_id'\n";
					}
				}
			}

###################################################################			
### Add the data to the database

			my $table_name  = $child_tables{$record_key}{TABLE_NAME};
			my $PK		= $child_tables{$record_key}{PK};
		
			$$rowdata_ref{affy_annotation_id} = $affy_anno_pk;			#add the affy_annotation_id FK column
		
			my $inserted_PK = $sbeams->updateOrInsertRow(				# insert the data in to the first child table, most record_values will only be parse into one table but some will have two tables that will need to be dealt with				
						table_name=>$table_name,
				   		rowdata_ref=>$rowdata_ref,
				   		return_PK=>1,
				   		verbose=>$self->verbose(),
				   		testonly=>$self->testonly(),
				   		insert=>1,
				   		PK=>$PK,
				   	  );
		
			if ($self->verbose() > 0) {
				print "INSERTED DATA IN TO PRIMARAY CHILD TABLE '$table_name' PK '$inserted_PK'\n\n";
			}
			
####################################################################
### Add the sub table data if present  #basically built to upload the TM information
			
			if (my $sub_table = $child_tables{$record_key}{ST_TABLE_NAME}){
				if ($self->verbose() >0) {
					print "ADDING SUB TABLE INFO FOR '$sub_table'\n";
				}	 
				my $PK = $child_tables{$record_key}{ST_PK};
				my $FK_column = $child_tables{$record_key}{ST_FK};			#subtable foregin key
				
				my $st_reg_exp = $child_tables{$record_key}{ST_REG_EXP};
				my %column_names_h = %{$child_tables{$record_key}{ST_COLUMN_NAMES} };	#key is the order which the reg exp will find the data, value is the column to put the data into
				my @column_name_keys   = sort keys %column_names_h;
				
				
				my $rowdata_ref = {};
				$$rowdata_ref{$FK_column} = $inserted_PK;				
				
				if (my @all_hits = ($record_value =~ /$st_reg_exp/)) {			#gather all the hits
					
					while (@all_hits){
						
					foreach my $key (@column_name_keys){				#loop the array of column keys, which are just numbers
							my $column_name = $column_names_h{$key};	#convert to a column name
							my $value = shift @all_hits;			#get a value from things that where found
							$$rowdata_ref{$column_name} = $value;	
							
							if ($self->verbose() > 0){
								print "SUB TABLE HIT VALUE '$value' INSERT INTO COL '$column_name'\n";
							}
						}
					
					
						my $st_inserted_PK = $sbeams->updateOrInsertRow(	# insert the data 			
										table_name=>$sub_table,
				   						rowdata_ref=>$rowdata_ref,
				   						return_PK=>1,
				   						verbose=>$self->verbose(),
				   						testonly=>$self->testonly(),
				   						insert=>1,
				   						PK=>$PK,
				   	  					);
					}
				}else{
					$self->anno_error(error => "ERROR:SUB TABLE REGEXP '$st_reg_exp' DID NOT MATCH\n\tRECORD_VAL'$record_value'\n");
				}
					
				
			}		
		}
	}
						
}
###############################################################################
#get_gene_ontolgy_types
#
#retrun hash of with keys of the differnt gene ontology types and the value equal to the PK for the row in the db
###############################################################################

sub get_gene_ontolgy_types {
	my $self = shift;
	my $sql = qq~ SELECT gene_ontology_name_type, gene_ontology_type_id
			FROM $TBMA_GENE_ONTOLOGY_TYPE
		  qq~;
	return $sbeams->selectTwoColumnHash($sql)
}

###############################################################################
#add_affy_db_links
#Given a dbref_tag turn it into a PK 
#retrun the PK from $TBMA_AFFY_DB_LINKS
###############################################################################
sub add_affy_db_links {
    	my $method = 'add_affy_db_links';
    	my $self = shift;

	my %args = @_;
	my $db_id       = $args{accession_number};
	my $affy_anno_id = $args{affy_anno_id};
	my $dbxref_tag   = $args{dbxref_tag};
	
	my $dbxref_id = $self->get_xref_id($dbxref_tag);
	
confess(__PACKAGE__ . "::$method Need to provide  'accession_number' & 'affy_anno_id' & 'dbxref_tag") unless ($db_id =~ /^\w/ && $affy_anno_id && $dbxref_tag);
	
	my $rowdata_ref = {affy_annotation_id	=> $affy_anno_id,
			   dbxref_id		=> $dbxref_id,
       			   db_id		=> $db_id,
			 };
	
	my $inserted_pk = $sbeams->updateOrInsertRow(		# insert the data 			
							table_name=>$TBMA_AFFY_DB_LINKS,
				   			rowdata_ref=>$rowdata_ref,
				   			return_PK=>1,
				   			verbose=>$self->verbose(),
				   			testonly=>$self->testonly(),
				   			insert=>1,
				   			PK=>'affy_db_links_id',
				   	  		);
	if ($self->verbose() > 0){
		print "INSERTED AFFY_DB_LINK FOR '$dbxref_tag' DB_ID '$db_id' PK '$inserted_pk'\n";
	}
	return $inserted_pk;

}
###############################################################################
#get_xref_id
#Given a dbref_tag turn it into a PK 
#retrun the PK from $TB_DBXREF
###############################################################################
sub get_xref_id {
    	my $method = 'get_xref_id';
    	my $self = shift;
	
	my $dbxref_tag = shift;
	
	if (exists $self->{$dbxref_tag}){			#if we have already seen this dbxref tag before send back the PK 
		return $self->{$dbxref_tag};
	}
	
	confess(__PACKAGE__ . "::$method Need to provide  'dbxref_tag' =>  YOU GAVE '$dbxref_tag'") unless ($dbxref_tag =~ /^\w/);
	
	my $sql = qq~ SELECT dbxref_id
			FROM $TB_DBXREF
			WHERE dbxref_tag = '$dbxref_tag'
		  ~;
	
	
	my @rows = $sbeams->selectOneColumn($sql);
	
	die "*** CANNOT FIND DBXREF_ID FOR '$dbxref_tag' '$sql' ***\n" unless ($rows[0] =~ /^\d/);
	
	$self->{$dbxref_tag} = $rows[0];			#add the data into a hash for future lookups
	return $rows[0];
}


###############################################################################
#truncate_data
#used to truncate any long fields.  Will truncate everything in a hash or a single value to 254 char.  Also will
#write out to the error log if any extra fields are truncated
###############################################################################
sub truncate_data {
	my $self = shift;
  my %args = @_;
  my $method = 'truncate_data';

  unless ( $args{record_href} || $args{data_aref} ) {
    $log->error( "$method requires either record or data ref" );
    return undef;
  }
  unless ( ref($args{record_href}) eq 'HASH' || ref($args{data_aref}) eq 'ARRAY' ) {
    $log->error( "Invalid reference type in $method" );
    return undef;
  }
  
  if ($args{record_href}){ # Cleaned up 6/06 DSC
    my %record_h = %{$args{record_href}};
	
    my %fieldsize = ( gene_symbol => 50,
              chromosomal_location => 50,
          archival_unigene_cluster => 50,
                               qtl => 100 );
    
    # Trim values to match data type 
    foreach my $key ( keys %record_h){
      next unless defined $key;	

      $fieldsize{$key} ||= 255;
      my $orig_len = length( $record_h{$key} );
      if ( $record_h{$key} && $fieldsize{$key} && $orig_len > $fieldsize{$key} ){
        my $trunc = substr($record_h{$key}, 0, $fieldsize{$key} );
        my $trunc_len = length( $trunc );
        $self->anno_error( error => "Hash value truncated from $orig_len to $trunc_len ($record_h{$key})");
        $record_h{$key} = $trunc;
      }
    }
		return %record_h;

  } elsif($args{data_aref}){ # left alone for now
		my @data = @{$args{data_aref}};
		
		for(my $i=0; $i<=$#data; $i++){
			if ( $data[$i] && length $data[$i] > 255){
				my $big_val = $data[$i];
		
				my $truncated_val = substr($data[$i], 0, 254);
			
				$self->anno_error(error => "Warning DATA Val truncated\n,ORIGINAL VAL SIZE:". length($big_val). "'$big_val'\nNEW VAL SIZE:" . length($truncated_val) . "'$truncated_val'");
				#print "VAL '$record_h{$key}'\n"
				$data[$i] = $truncated_val;
			}
		}
		return @data;
	}
}


###############################################################################
#check_previous_annotation_set
#Check to see if annotation set already exists in the db 
#if not upload a record into affy_annotation_set and return the PK
#if yes delete old data if user wants too  REQUIRES USER INPUT
###############################################################################
sub check_previous_annotation_set {
    	my $method = 'check_previous_annotation_set';
    	my $self = shift;
	
	my %args = @_;
	
	
	my $slide_type_id   = $args{slide_type_id};  
	my $genome_version  = $args{genome_version}; 
	my $annotation_date = $args{annotation_date}; 
	
	my $sql = qq~ SELECT affy_annotation_set_id
			FROM $TBMA_AFFY_ANNOTATION_SET
			WHERE annotation_date = '$annotation_date' AND
			slide_type_id = $slide_type_id
		  ~;
	my @rows = $sbeams->selectOneColumn($sql);	  
		 
	
	if ( scalar(@rows) && $rows[0] =~ /^\d/ ) { 		#Record exists so ask the user if previous data should be deleted

                # if they say they wanna delete, accept the default since they can still bail.

                my $answer = ( $self->run_mode() =~ /delete/i ) ? 'Y' : '';	

		QUESTION:{
                unless ( $answer ) {
		  print "\n\n\n********* WARNING THIS AFFYMETRIX ANNOTATION FILE HAS ALREADY BEEN UPLOADED*****\n" .
		        "re-uploading it will delete the previous version, are you sure you want to delete the annotation for\n" .
		       "'$genome_version - $annotation_date', annotation_set_id  '$rows[0]'\n" .
                       "Enter Y or [N]:";
		  $answer = <STDIN>;
                  chomp $answer;

                  # Did they just hit enter (default)?
                  $answer = 'N' if $answer eq '';
                }
		

		if ($answer =~ /^[nN]/){
			print "OK I WILL NOT DELETE ANYTHING\n";
			die "Data already exists in the database and you do not want to updated it so there is nothing to do\n";
			
		}elsif($answer =~ /^[Yy]/) {
			print "OK I WILL DELETE ALL THE ANNOTATION IN 5 secs... LAST CHANCE push crtl-c TO ABORT....\n";
			sleep 5;
		
			if ($self->verbose() > 0){
				print "AFFY ANNOTATION ID '$rows[0]'\n";
			}
			$self->delete_affy_annotation_data(affy_annotation_set_id => $rows[0]);																						
		
		}else{
			print "Sorry I do not understand your answer, Type Y or N\n";
                        $answer = '';
			QUESTION:redo;
		}
		}
		
		if ($self->run_mode() =~ /delete/i){	#if we are in delete mode return the annotation_set_id
			print "RETRUN ANNOTATION SET ID FROM '$method' ID = '$rows[0]'\n" if ( $self->verbose() );
			return $rows[0];
		}
		
		$self->check_previous_annotation_set(	slide_type_id   => $slide_type_id,		#Now that the old date is gone redo the method which will insert a new record
							genome_version  => $genome_version,
							annotation_date => $annotation_date,
					     	     );
	}else{
									#record does not exists need to insert new annotation_set record
		
			
		
		
		my $rowdata_ref = { 	annotation_date => $annotation_date,
					slide_type_id	=> $slide_type_id,
				  	genome_version	=> $genome_version,
				  }; 
	
		
		
		my $affy_annotation_set_id = $sbeams->updateOrInsertRow(				
							table_name=>$TBMA_AFFY_ANNOTATION_SET,
				   			rowdata_ref=>$rowdata_ref,
				   			return_PK=>1,
				   			verbose=>$self->verbose(),
				   			testonly=>$self->testonly(),
				   			insert=>1,
				   			PK=>'affy_annotation_set_id',
				   		   	add_audit_parameters=>1,
						   );

	
		##DEBUG
		print "ADDING ANNOTATION RECORD '$affy_annotation_set_id'\n";
		
		return $affy_annotation_set_id
		
	}
}

	
###############################################################################
#delete_affy_annotation_data
#give annotation set id 
#delete all the annotation from all the annotation tables
###############################################################################
sub delete_affy_annotation_data {
    	
	
	my $method = 'delete_affy_annotation_data';
	my $self = shift;
	
	my %args = @_;
	my $affy_annotation_set_id = $args{affy_annotation_set_id};
	
	print "ID '$affy_annotation_set_id'\n";
	confess(__PACKAGE__ . "::$method Need to provide key value pair 'affy_annotation_set_id' =>  YOU GAVE '$affy_annotation_set_id'") unless ($affy_annotation_set_id =~ /^\d/);
	

	my %table_child_relationship = ();
	my $table_name = '';
	

	%table_child_relationship = (						#table relationship needed by deleteRecordsAndChildren
      				
      				affy_annotation_set => 'affy_annotation(C)',	#Below it will utilize this hash to delete the affy_array rows then loop back and take out the sample rows
										#add more PKLC tables here
				affy_annotation => "protein_domain(PKLC),interpro(PKLC),protein_families(PKLC),gene_ontology(PKLC),alignment(PKLC),trans_membrane(PKLC),overlapping_transcript(PKLC),affy_db_links(PKLC)",	 
						  		
				trans_membrane => ("trans_membrane_domain(C)"),
				);

		
		
										#DELETE THE annotation_set record and delete all the childern in affy_annotation and it's PKLC childeren
				
		if ($self->verbose() > 0){
			print "Affy annotation set ID TO DELETE'$affy_annotation_set_id'\n";
		}
				
					
		print "Starting to delete Old data\n";
		
		my $result = $sbeams->deleteRecordsAndChildren(
         							table_name 	=> "affy_annotation_set",
         							table_child_relationship => \%table_child_relationship,
         							delete_PKs 	=> [ $affy_annotation_set_id ],
         							delete_batch 	=> 1000,
         							database 	=> $self->database(),
         							verbose 	=> $self->verbose(),
         							testonly 	=> $self->testonly(),
								);
			
					
		
		print "Done deleting old records\n";


}

###############################################################################
#find_annotation_ids
#Given a FK to affy_annotation_set collect all the annotation_id 
#Return array of PK from affy_annotation
###############################################################################
sub find_annotation_ids {
    	my $method = 'find_annotation_ids';
    	my $self = shift;
	
	my %args = @_;
	my $FK = $args{affy_annotation_set_id};	
	
	confess(__PACKAGE__ . "::$method Need to provide key value pair 'error'") unless ($FK);
	
	my $sql = qq~   SELECT affy_annotation_id
			FROM $TBMA_AFFY_ANNOTATION
			WHERE affy_annotation_set_id = $FK
		~;
		
	my @rows = $sbeams->selectOneColumn($sql);
	if ($self->verbose() > 0){
		print "ANNOTATION KEYS '@rows'\n";
	}
	
	return @rows;
	
}
###############################################################################
#get_annotation_sql
#Given an affy_probe_set_id and an annotation_set_id get a sql statment to pull out all the information we know
#about this particular probe
#Return a sql string
###############################################################################
sub get_annotation_sql {

	my $self = shift;
	my %args = @_;
 
	
	my $sql = qq~	SELECT
			anno_set.genome_version  AS "Genome_Version",
          		anno_set.annotation_date AS "Annotation_Date",
            		st.name                  AS "Affy_Chip",
			anno.affy_annotation_id,           
			anno.probe_set_id       AS "probe_set_id",
           		anno.gene_title         AS "gene_title",
           		anno.gene_symbol        AS "gene_symbol",
           		anno.sequence_type,
			anno.sequence_source,
			anno.transcript_id,
			anno.target_description_feature,
			anno.target_description,
			anno.target_description_note,
			anno.representative_public_id,
			anno.archival_unigene_cluster,
			anno.chromosomal_location,
			anno.pathway,
			anno.qtl,
			anno.annotation_description,
			anno.transcript_assignment,
			anno.annotation_transcript_cluster,
			anno.annotation_notes
           		FROM $TBMA_AFFY_ANNOTATION anno 
            		JOIN $TBMA_AFFY_ANNOTATION_SET anno_set 
                		ON (anno.affy_annotation_set_id = anno_set.affy_annotation_set_id)	
            		JOIN $TBMA_SLIDE_TYPE st 
                		ON (st.slide_type_id = anno_set.slide_type_id)
			WHERE 1=1
          		
		~;
	
	return $sql;

}
	
###############################################################################
#get_dbxref_accessor_urls
#Give nothing
#return results as a hash example  16 => LocusLink__http://www.ncbi.nlm.nih.gov/LocusLink/ 
#dbxref_PK dbref_tag 2 underscores __ accessor url
###############################################################################
sub get_dbxref_accessor_urls {
	my $self = shift;
	return $sbeams->selectTwoColumnHash( <<"  END" );
  SELECT dbxref_id , dbxref_tag || '__' || accessor
	FROM $TB_DBXREF
  END
}
###############################################################################
#get_protein_family_info
#Give affy_annotation_id
#return results as an array of hrefs
###############################################################################
sub get_protein_family_info {
	my $self = shift;
	my $affy_annotation_id = shift;
	my $sql = qq~ 
				    SELECT  pf.description, pf.e_value, db.dbxref_id, db.db_id
					FROM  $TBMA_PROTEIN_FAMILIES pf
					JOIN $TBMA_AFFY_DB_LINKS db ON (pf.affy_db_links_id = db.affy_db_links_id)
					WHERE pf.affy_annotation_id = $affy_annotation_id
				~; 
	#$sbeams->display_sql(sql=>$sql);
	
	return $sbeams->selectHashArray($sql)

}

###############################################################################
#get_protein_domain_info
#Give affy_annotation_id
#return results as an array of hrefs
###############################################################################
sub get_protein_domain_info {
	my $self = shift;
	my $affy_annotation_id = shift;
	my $sql = qq~ 
				    SELECT  pd.protein_domain_description, db.dbxref_id, db.db_id
					FROM  $TBMA_PROTEIN_DOMAIN pd
					JOIN $TBMA_AFFY_DB_LINKS db ON (pd.affy_db_links_id = db.affy_db_links_id)
					WHERE pd.affy_annotation_id = $affy_annotation_id
				~; 
	#$sbeams->display_sql(sql=>$sql);
	
	return $sbeams->selectHashArray($sql)

}
###############################################################################
#get_interpro_info
#Give affy_annotation_id
#return results as an array of hrefs
###############################################################################
sub get_interpro_info {
	my $self = shift;
	my $affy_annotation_id = shift;
	my $sql = qq~ 
				    SELECT  ip.interpro_description, db.dbxref_id, db.db_id
					FROM  $TBMA_INTERPRO ip
					JOIN $TBMA_AFFY_DB_LINKS db ON (ip.affy_db_links_id = db.affy_db_links_id)
					WHERE ip.affy_annotation_id = $affy_annotation_id
				~; 
	#$sbeams->display_sql(sql=>$sql);
	
	return $sbeams->selectHashArray($sql)

}
###############################################################################
#get_transmembrane_info
#
#Give a affy_annotaion_id
#Return number of transmembrane domains
###############################################################################
sub get_transmembrane_info {
	my $self = shift;
	my $anno_id = shift;
	my $sql = qq~SELECT number_of_domains, protein_accession_numb
				FROM $TBMA_TRANS_MEMBRANE WHERE
				affy_annotation_id = $anno_id
				~;
	
	return $sbeams->selectHashArray($sql)
	
}
###############################################################################
#get_alignment_info
#
#Give a affy_annotaion_id
#Return all the alignment info as an array of hrefs
###############################################################################
sub get_alignment_info {
	my $self = shift;
	my $anno_id = shift;
	my $sql = qq~  SELECT a.gene_start, a.gene_stop,  a.percent_identity, a.gene_orientation,a.match_chromosome 
				   FROM $TBMA_ALIGNMENT a 
				   WHERE a.affy_annotation_id = $anno_id
			    ~;
	return $sbeams->selectHashArray($sql);
}
###############################################################################
#get_go_info
#
#Give a affy_annotaion_id
#Return all the go info as an array of hrefs
###############################################################################
sub get_go_info {
	my $self = shift;
	my $anno_id = shift;
	my $sql = qq~SELECT gt.gene_ontology_name_type, 
				 go.gene_ontology_description, 
				 go.gene_ontology_evidence, 
				 db.dbxref_id, 
				 db.db_id
 				 FROM $TBMA_GENE_ONTOLOGY go
				 JOIN $TBMA_GENE_ONTOLOGY_TYPE gt ON (go.gene_ontology_type_id = gt.gene_ontology_type_id)
				 JOIN  $TBMA_AFFY_DB_LINKS db ON(go.affy_db_links_id = db.affy_db_links_id) 
				 WHERE
				 go.affy_annotation_id = $anno_id
				 ORDER BY gt.gene_ontology_type_id
				~;
	#print STDERR ($sql);
	return $sbeams->selectHashArray($sql);
}

###############################################################################
#get_db_acc_numbers
#
#Give a affy_annotaion_id
#retrun all ids as a hash of db_id => dbxref_id Example 12345 => 16
###############################################################################
sub get_db_acc_numbers {
	my $self = shift;
	my $anno_id = shift;
	return $sbeams->selectTwoColumnHash("	SELECT db_id, dbxref_id
						FROM $TBMA_AFFY_DB_LINKS WHERE
					     	affy_annotation_id = $anno_id"
				           );
}
	

###############################################################################
# anno_error
###############################################################################
sub  anno_error {
	my $method = 'anno_error';
	my $self = shift;
	
	my %args = @_;
	
	if (exists $args{error} ){
		if ($self->verbose() > 0){
			print "$args{error}\n";
		}
		return $self-> {ERROR} .= "\n$args{error}";	#might be more then one error so append on new errors
		
	}else{
		$self->{ERROR};
	
	}
}

#+
# Affy annotations can have multiple id's in the same field seperated with ///
# Truncate string to first value and return.
#-
sub clean_id{
  my $self = shift;
	my $val = shift;
	$val =~ s!///.*!!;
	return $val;
}

#+
# Logic for turning affy annotation values into gene_expression canonical_name
#-
sub getCanonicalName {
  my $self = shift;
  my %args = @_;

  my $canonical = 'undefined';

  # Refseq Prot Id should start with N/X . P_ddddd
  if ( $args{refseq} && $args{refseq} =~ /^\s*[NX]P_\d+/ ) { 
     $canonical = $args{refseq};
     $canonical =~ s/^\s*(.*)\.\d+\s*$/$1/;
  } elsif ( $args{gene_id} && $args{gene_id} =~ /^\s*\d+\s*$/ ) {
     $canonical = $args{gene_id};
	} elsif ( $args{public} ) {
     $canonical = $args{public};
  }
  return $canonical;     
}

}#closing bracket for the package

1;
