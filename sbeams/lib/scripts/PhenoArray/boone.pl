#!/usr/local/bin/perl
##################################################
# Boone.pl version: 1/30/02
#             Rowan Christmas
#
# This program reads in Charlie Boone's Data set and creates substrains and
#  and substrain behaviours 


use strict;
use Getopt::Long;
use vars qw ($sbeams $sbeamsPH
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $current_contact_id $current_username %ref_id $DA $DS);

use lib qw (/net/db/lib/sbeams/lib/perl);

#### Set up SBEAMS package
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;


use SBEAMS::PhenoArray;
use SBEAMS::PhenoArray::Settings;
use SBEAMS::PhenoArray::Tables;
use SBEAMS::PhenoArray::TableInfo;
#require 'dumpvar.pl';
$sbeams = new SBEAMS::Connection;
$sbeamsPH = new SBEAMS::PhenoArray;
$sbeamsPH->setSBEAMS($sbeams);
$QUIET = 0;
my %plate_id;
my $cond_id_num;
$USAGE = "ssp_load.pl [master_plate_file.txt] [-a -s]\n       -a   delete all\n       -s delete SM and PL\n";
print "$#ARGV\n";
if ( $#ARGV < 0 ) {die $USAGE};


for ( my $i=1; $i <= $#ARGV; $i++) {

    if ( $ARGV[$i] =~ /^-a/) {$DA = 1; $i++;}
    if ( $ARGV[$i] =~ /^-s/) {$DS = 1; $i++;}
}



#### Print the header, do what the program does, and print footer
$| = 1;
$sbeams->printTextHeader() unless ($QUIET);
main();
$sbeams->printTextFooter() unless ($QUIET);

sub main {
   
    #### Define standard variables
    my ($i,$element,$key,$value,$line,$result,$sql,$infile);

    $DATABASE = $sbeams->getPHENOARRAY_DB();
    ####  Print out the header
    exit unless ($current_username =
		 $sbeams->Authenticate(work_group=>'Phenotype_user'));
    $sbeams->printUserContext(style=>'TEXT') unless ($QUIET);
    print "\n" unless ($QUIET);

    readSheet();

}


sub readSheet {
   
    my $DEBUG ;
   #deleteAll();
   #makePlateTable();
   #checkPlate();
    makeSubstrainTable();
    makeSMTable_and_makePlateLayoutTable();
    #makeNewCondRep();
    insertBehaviour();
    
}   

sub getRefStrains {
    
    my $sql = "SELECT strain_number, reference_strain_id FROM ${DATABASE}reference_strain ";
    %ref_id = $sbeams->selectTwoColumnHash($sql);
}


sub deleteAll {

    my $sql = "DELETE FROM ${DATABASE}plate_layout ".
	"WHERE plate_layout_id = plate_layout_id";
    $sbeams->executeSQL($sql);

    my $sql = "DELETE FROM ${DATABASE}sequence_modification ".
	"WHERE sequence_modification_id =  sequence_modification_id";
    $sbeams->executeSQL($sql);


    my $sql = "DELETE FROM ${DATABASE}substrain ".
	" WHERE substrain_id = substrain_id";
    $sbeams->executeSQL($sql);
  
    

}
sub makeSubstrainTable {
    my $lazy = 0;
    print "Inserting Substrains.....";
    open (IN3, "$ARGV[0]");
    # Now go back through, making substrains
    my $Insert = 0;
#Read in the biosequence table
    my $sql_bioseq = "SELECT biosequence_desc, biosequence_gene_name FROM ${DATABASE}biosequence WHERE biosequence_set_id = 3";
    my %bioSeq = $sbeams->selectTwoColumnHash($sql_bioseq);
    my %substrain;
    
    while (<IN3>) {


	#Read in the substrain table each time to check for new entries
	if ($Insert == 0 ) {
	    my $sql_substrain = "SELECT substrain_name, substrain_id FROM ${DATABASE}substrain";
	    %substrain =  $sbeams->selectTwoColumnHash($sql_substrain);
	    $Insert = 1;
	}
	next if ( /^\#/ || /num_rows/ || /none/ || /blank/);
	
	my @line = split("\t");
	my $parent = "BY4741";
	# TEst first KO
	chomp(@line);
	my $thing = uc $line[0]; #make upper case
	chomp($thing);
	my $KO1;
	if ( $thing =~ /Y[A-P][LR]\d\d\d[CW]/ ) {
	    #This is a systematic name
	    $KO1 = $thing;
	    # print "Systematic name found\n";# for $KO1 \n";
	    
       	} else {
	    #match the common name to the systematic name
	    $KO1 = $bioSeq{$thing};
	    #print "Common name matched $KO1 : $thing : $bioSeq{$thing}\n";
	    if (!$KO1 ) {
		print "Common name not found for $KO1 line @line\n";
		next;
	    }
	}
	my $name = "$parent"."."."$KO1";
	my $KO2;
	
	if ( $line[1] !~ /null/ ) {
	    my $thing2 = uc $line[1]; #make upper case
	   chomp($thing2);
	    if ( $thing2 =~ /Y[A-P]\d\d\d[CW]/ ) {
		#This is a systematic name
		$KO2 = $thing2;
	    } else {
		#match the common name to the systematic name
		$KO2 = $bioSeq{$thing2};
		if (!$KO2 ) {
		    print "Common name not found $KO2 @line\n";
		    next;
		}
	    }
	    $name = "$name"."."."$KO2";
	}



	#make a plasmid if necessary
	#if ($plasmid_num !~ /null/ ) {
	    
	   # print "FUCK $plasmid_num\n";
	 #   $name = "$name"."."."$plasmid_num";
	 #   makePlasmid($plasmid_num);
	 #}
    

	#if ( $line[6] =~ /wt/ ) {
	#    $name = $parent;
	#}

	#my $sql_plasmid = "SELECT plasmid_name, plasmid_id FROM ${DATABASE}plasmid ";

	#my %plas_id = $sbeams->selectTwoColumnHash($sql_plasmid);
	

	#test for substrain insertion
	my $exist = 0;

	#if ( $substrain{$name} =~ // ) { $exist = 1;} 
	
	foreach my $line (keys %substrain) {
	    if ( $line eq $name ) {
		$exist = 1; # This means that there is already an instance of this name, since it is unique we therefore skip it.
	    }
	}
	
	if ( $exist == 0 ) {
	    $lazy++;
	    $Insert = 0;
	    my %strain;
	    #if there is a plasmid :
	    #if ( $plasmid_num !~ /null/ ) {
	#	%strain = (
	#		   substrain_name => $name,
	#		   strain_id => 1,
	##		   plasmid1_id => $plas_id{$plasmid_num},
	#		   created_by_id => $sbeams->getCurrent_contact_id(),  
	#		   modified_by_id => $sbeams->getCurrent_contact_id(),
	#		 owner_group_id => $sbeams->getCurrent_work_group_id(),
	#		  record_status => 0,           
	#    ); 
	#} else {
	    #otherwise:
	    %strain = (
		       substrain_name => $name,
		       strain_id => 1,
		       created_by_id => $sbeams->getCurrent_contact_id(),      
		       modified_by_id => $sbeams->getCurrent_contact_id(),
		       owner_group_id => $sbeams->getCurrent_work_group_id(),
		       record_status => 0,           
		       comment => "$line[3]",
		       ); 
	
	    my $result;
	    my $result = $sbeams->insert_update_row(
						    insert => 1,                      
						    update => 0,                      
				     table_name => "${DATABASE}substrain",     
						rowdata_ref => \%strain,         
						    PK => "substrain_id",  
						    );  
	}
    }

    print "SUBSTRAINS SUCCESFULLY INSERTED\n";
    if ($lazy != 0) {
	print "New strains inserted $lazy\n";
    }
}

sub insertBehaviour {
    my $lazy = 0;
    print "Inserting Behaviours.....";
    open (IN3, "$ARGV[0]");
    # Now go back through, making substrains
    my $Insert = 0;
#Read in the biosequence table
    my $sql_bioseq = "SELECT biosequence_desc, biosequence_gene_name FROM ${DATABASE}biosequence WHERE biosequence_set_id = 3";
    my %bioSeq = $sbeams->selectTwoColumnHash($sql_bioseq);
    
    my $sql_cond = "SELECT condtion_name, condition_id FROM ${DATABASE}conditon";
    my %cond = $sbeams->selectTwoColumnHash($sql_bioseq);
    
    my %behave;
    
    my $sql_substrain = "SELECT substrain_name, substrain_id FROM ${DATABASE}substrain";
    my %substrain =  $sbeams->selectTwoColumnHash($sql_substrain);

    my $sql_cond = "SELECT condition_name, condition_id FROM ${DATABASE}condition";
    my %cond_id = $sbeams->selectTwoColumnHash($sql_cond);

    while (<IN3>) {


	#Read in the substrain table each time to check for new entries
	if ($Insert == 0 ) {
	    my $sql_behave = "SELECT substrain_id, substrain_behavior_id FROM ${DATABASE}substrain_behavior";
	    %behave =  $sbeams->selectTwoColumnHash($sql_substrain);
	    $Insert = 1;
	}
	next if ( /^\#/ || /num_rows/ || /none/ || /blank/);
	
	my @line = split("\t");
	my $parent = "BY4741";
	# TEst first KO
	chomp(@line);
	my $thing = uc $line[0]; #make upper case
	chomp($thing);
	my $KO1;
	if ( $thing =~ /Y[A-P][LR]\d\d\d[CW]/ ) {
	    #This is a systematic name
	    $KO1 = $thing;
	    # print "Systematic name found\n";# for $KO1 \n";
	    
       	} else {
	    #match the common name to the systematic name
	    $KO1 = $bioSeq{$thing};
	    #print "Common name matched $KO1 : $thing : $bioSeq{$thing}\n";
	    if (!$KO1 ) {
		print "Common name not found for $KO1 line @line\n";
		next;
	    }
	}
	my $name = "$parent"."."."$KO1";
	my $KO2;
	
	if ( $line[1] !~ /null/ ) {
	    my $thing2 = uc $line[1]; #make upper case
	   chomp($thing2);
	    if ( $thing2 =~ /Y[A-P]\d\d\d[CW]/ ) {
		#This is a systematic name
		$KO2 = $thing2;
	    } else {
		#match the common name to the systematic name
		$KO2 = $bioSeq{$thing2};
		if (!$KO2 ) {
		    print "Common name not found $KO2 @line\n";
		    next;
		}
	    }
	    $name = "$name"."."."$KO2";
	}



	#test for substrain insertion
	my $exist = 0;

	#if ( $substrain{$name} =~ // ) { $exist = 1;} 
	
	foreach my $line (keys %behave) {
	    if ( $line eq $substrain{$name} ) {
		$exist = 1; # This means that there is already an instance of this name, since it is unique we therefore skip it.
	    }
	}
	
	if ( $exist == 0 ) {
	    $lazy++;
	    $Insert = 0;
	  
	   
	   my  %strain = (
			  substrain_id => $substrain{$name},
			  condition_id => $cond_id{"YPD"},
			  growth => 0,
			  ); 
	
	    my $result;
	    my $result = $sbeams->insert_update_row(
						    insert => 1,                      
						    update => 0,                      
				     table_name => "${DATABASE}substrain_behavior",     
						rowdata_ref => \%strain,         
						    PK => "substrain_behavior_id",  
						    );  
	}
    }

    print "BEHAVIORS SUCCESFULLY INSERTED\n";
    if ($lazy != 0) {
	print "New behaviors inserted $lazy\n";
    }
}
sub makeNewCondRep {

# We will read through all repeats entered together to determine which 
# conditions are represented. For each condition a condition repeat will
# be generated, and the ID stored in %cond_rep_id acessed with the name of
# the condition
    print "Inserting Condition Repeat............\n";
    my $sql_cond = "SELECT condition_name, condition_id FROM ${DATABASE}condition";
    my %cond_id = $sbeams->selectTwoColumnHash($sql_cond);
   

    my $condA = "YPD";
	#print "$condA, $condB, $condC, $condD\n";
#Set the values for each cond to the condition ID
#%cond_id is of course the hash that has all conditions in it
    my %cond_rep_id;
    $cond_rep_id{$condA} = $cond_id{$condA};
	#$cond_rep_id{$condB} = $cond_id{$condB};
	#$cond_rep_id{$condC} = $cond_id{$condC};
	#$cond_rep_id{$condD} = $cond_id{$condD};


	#my %dappleDone = (
	#		
	#		record_status => 1,
	#		);
	#print "PK  $file : $quant_id{$file}\n";
	#my $result;
	#my $result = $sbeams->insert_update_row(
	#					insert => 0,
	#					update => 1,
	#			      table_name => "${DATABASE}array_quantitation",
	#					rowdata_ref => \%dappleDone,
	#					PK_value => $quant_id{$file},
	#					PK => "array_quantitation_id",
	#					);





    #}

    foreach my $thing (keys %cond_rep_id) {
	next if ($thing !~ /\w/); #check for non-empty
	print "$thing:\t\t$cond_rep_id{$thing}\n";
    }
    
#Now set the values for each cond to the condition REPEAT ID

    foreach my $cond (keys %cond_rep_id) {
	next if ($cond !~ /\w/); #check for non-empty
	print "COND $cond ID :: $cond_id{$cond}\n";
	my %cond_insert = (
			   protocol_id => 0,
			   condition_id => $cond_id{$cond},
			   created_by_id => $sbeams->getCurrent_contact_id(), 
			   comment => $cond,
			   modified_by_id => $sbeams->getCurrent_contact_id(),
			   owner_group_id => $sbeams->getCurrent_work_group_id(),
			   record_status => 0,           
			   ); 

	my $result;
	#Create this cond_rep returning the PK
	my $result = $sbeams->insert_update_row(
				   insert => 1,
				   update => 0,
				   return_PK => 1,
				   table_name => "${DATABASE}condition_repeat",
				   rowdata_ref => \%cond_insert,
				   PK => "condition_repeat_id",
						);
	#Now set the returned PK to %cond_rep_id
	$cond_id_num = $result;
    }
    print "done\n";
    
}



sub makeSMTable_and_makePlateLayoutTable {
    my $lazy == 0;
    print "INSERTING SM AND PL.....";

    # Read in what is already in the database then use the ID nums for the FKs
    #Read in the substrain table

    my $sql_substrain = "SELECT substrain_name, substrain_id FROM ${DATABASE}substrain";
    my %substrain_id =  $sbeams->selectTwoColumnHash($sql_substrain);

    #Read in the biosequence table
    my $sql_bioseq = "SELECT biosequence_gene_name, biosequence_id FROM ${DATABASE}biosequence WHERE biosequence_set_id = 3";
    my %bioSeq_id = $sbeams->selectTwoColumnHash($sql_bioseq);
  
    #Read in the biosequence name matching hash
    my $sql_bioseq = "SELECT biosequence_desc, biosequence_gene_name FROM ${DATABASE}biosequence WHERE biosequence_set_id = 3";
    my %bioSeqName = $sbeams->selectTwoColumnHash($sql_bioseq);


    
    #Read in the cassette table
    my $sql_kan = "SELECT biosequence_name, biosequence_id FROM ${DATABASE}biosequence WHERE biosequence_set_id = 2";
    my %kan_id = $sbeams->selectTwoColumnHash($sql_kan);

  

    open (OUT, ">bad_genes");
    open (IN2, "$ARGV[0]");
    # Now go back through, reading in the biosequences


    my $Insert = 0;
    my %bioM;
    while (<IN2>) {

	if ( $Insert == 0) { #read in bio_mods if changed
	    my $sql_bioM  = "SELECT substrain_id, sequence_modification_id FROM ${DATABASE}sequence_modification ";
	    %bioM = $sbeams->selectTwoColumnHash($sql_bioM);
	    $Insert == 1;
	}
	    
	next if ( /^\#/ || /num_rows/ || /none/ || /blank/);

	my @line = split("\t");
	chomp @line;
	my $parent = "BY4741";
	# TEst first KO
	my $thing = uc $line[0]; #make upper case
	chomp($thing);
	
	my $KO1;
	if ( $thing =~ /Y[A-P][LR]\d\d\d[CW]/ ) {
	    #This is a systematic name
	    $KO1 = $thing;
	    # print "Systematic name found\n";# for $KO1 \n";
	    
       	} else {
	    #match the common name to the systematic name
	    $KO1 = $bioSeqName{$thing};
	   # print "$KO1|n";
	    #print "Common name matched $KO1 : $thing : $bioSeq{$thing}\n";
	    if (!$KO1) {
		print "Common name not found for @line[0] line @line\n";
		next;
	    }
	}
	my $name = "$parent"."."."$KO1";
	my $KO2;
	
	if ( $line[1] !~ /null/ ) {
	    my $thing2 = uc $line[1]; #make upper case
	    chomp($thing2);   
	    if ( $thing2 =~ /Y[A-P]\d\d\d[CW]/ ) {
		#This is a systematic name
		$KO2 = $thing2;
	    } else {
		#match the common name to the systematic name
		$KO2 = $bioSeqName{$thing2};
		if (!$KO2)  {
		    print "Common name not found $KO2 @line\n";
		    next;
		}
	    }
	    $name = "$name"."."."$KO2";
	}

	
	#print "$name : $substrain_id{$name}, $orf : $bioSeq_id{$orf}, KanMX4 : $kan_id{KanMX4}, Plate : $plate : $plate_id{$plate}\n";


#############
# Insert sequence_modification 
#############
	#To change the replacement cassette change the id
	

	my $exist = 0;
	foreach my $mod (keys %bioM) {
	    #print "$mod vs $substrain_id{$name}\n";
	    if ($mod == $substrain_id{$name}) {
		$exist =1;
	    }
	}
	
	if ($exist == 0 ) {
	    $lazy++;
	    $Insert = 0;
	    if ( $bioSeq_id{$KO1} ) {
		my %bioMod = (
			  substrain_id => $substrain_id{$name},
			  affected_biosequence_id => $bioSeq_id{$KO1},
			  deletion_start => 0,
			  deletion_length => 100,
			  inserted_biosequence_id => 19962,
			  created_by_id => $sbeams->getCurrent_contact_id(),              
			  modified_by_id => $sbeams->getCurrent_contact_id(), 
			  owner_group_id => $sbeams->getCurrent_work_group_id(),
			  record_status => 0,           
			  ); 
		my $result;
		my $result = $sbeams->insert_update_row(
					 insert => 1,                      
					 update => 0,                      
			table_name => "${DATABASE}sequence_modification",
				    rowdata_ref => \%bioMod,         
				     PK => "sequence_modification_id",      
			       );         

	    } 

	    if ( $bioSeq_id{$KO2} ) {
		my %bioMod = (
			  substrain_id => $substrain_id{$name},
			  affected_biosequence_id => $bioSeq_id{$KO2},
			  deletion_start => 0,
			  deletion_length => 100,
			  inserted_biosequence_id => 19962,
			  created_by_id => $sbeams->getCurrent_contact_id(),              
			  modified_by_id => $sbeams->getCurrent_contact_id(), 
			  owner_group_id => $sbeams->getCurrent_work_group_id(),
			  record_status => 0,           
			  ); 
		my $result;
		my $result = $sbeams->insert_update_row(
					 insert => 1,                      
					 update => 0,                      
			table_name => "${DATABASE}sequence_modification",
				    rowdata_ref => \%bioMod,         
				     PK => "sequence_modification_id",      
			       );         

	    
	    } else {
		print OUT "ORF not in records:     $KO1   $KO2\n";
	    }
	    
	}
	
    }
    print "SEQUENCE MODS AND PLATE LAYOUTS SUCCESSFULLY INSERTED\n";
    if ($lazy != 0) {
	print "New things put in $lazy\n";
    }
}

sub makePlasmid {
   
    my $plasmid_num = shift;

    my $sql_plasmid = "SELECT plasmid_name, plasmid_id FROM ${DATABASE}plasmid ";

    my %plas_id = $sbeams->selectTwoColumnHash($sql_plasmid);
    
    my $exist = 0;
    foreach my $num (keys %plas_id) {
	if ( $num =~ $plasmid_num ) {
	    #print "
	    $exist = 1;
	}
    }

    if ($exist == 0 ) {
	print "making plasmid...\n";
	my %plasmid = (
		       plasmid_name => "$plasmid_num",
		       biosequence_id => 1,
		       created_by_id => $sbeams->getCurrent_contact_id(),      
		       modified_by_id => 7,         
		       record_status => 0,           
		       );  

	my $result = $sbeams->insert_update_row(
						insert => 1,                   
						update => 0,                   
						table_name => "$TBPH_PLASMID", 
						rowdata_ref => \%plasmid,      
						PK => "plasmid_id",    
						);         

	print "Plasmid Inserted\n";
    }
   
}


sub makePlateTable {
    print "Making plate hash....\n";
    open (IN, "$ARGV[0]");
    my %plates = checkPlate(); 
    while ( <IN>) {

	next if ( /^\#/ || /num_rows/ || /none/);
	my $DEBUG1;
	#my @line = parseLine($_);	
	my @line = split;
	my $orf = $line[0];
	#$orf =~ s/-/_/ ;
	my $p96p = $line[1];
	my $p96r = $line[2];
	my $p96c = $line[3];
	my $plate = $line[4];
	my $p384r = $line[5];
	my $p385c = $line[6];

	print "---------------------------------------\n\n$line[0], $line[1], 
        $line[2], $line[3], $line[4], $line[5], $line[6]\n" if ( $DEBUG );
	##########################################
	# Check to See if the plate is in already 
        ## If in, do nothing, else insert it 
	
	my $exist = 0;  
 	foreach my $inPlate (keys %plates) { 
	    print "$inPlate, $plates{$inPlate}, $plate\n"if ( $DEBUG1 ); 
	    if ( $plates{$inPlate} eq  $plate ) {  
		$exist = 1; 
		print "$plates{$inPlate} == $plate \n\nPlate Name already exists, 
                not entering\n"if ( $DEBUG1 );    #
		#$plate_id{$plate} = $inPlate; # Set plate name to id 
	    }
	}	if ( $exist == 0 ) { 
	    print "NEW PLATE FOUND, $plate\n"if ( $DEBUG1 ); 
	    my %rowdata = (  
			   plate_name => $plate,             
			   created_by_id => $sbeams->getCurrent_contact_id(), 
			   modified_by_id => $sbeams->getCurrent_contact_id(),
			   record_status => 0,               
			   );                                
	    my $result;                                    
	    my $result = $sbeams->insert_update_row(         
			   insert => 1,                      
			   update => 0,                      
			   table_name => "$TBPH_PLATE",      
			   rowdata_ref => \%rowdata,         
			   PK => "plate_id", 
			   )                           
	}                                                    
	# This will result in all plates being inserted, 
	# also %plate_id will have been initialized with keys
	# being plate name, values being the plate's PK

    }
    #return %plate_id;
    print "Plate hash made\n";
}
sub checkPlate {
    
    my $sql = "SELECT plate_name, plate_id FROM ${DATABASE}plate";
    #my %plate_names = $sbeams->selectTwoColumnHash($sql);
    #return  %plate_names;
    %plate_id = $sbeams->selectTwoColumnHash($sql);
    ###return $sbeams->selectTwoColumnHash($sql);
}






#sub checkPlate_Layout {
    #
#    my $sql = "SELECT plate_layout_id";
#}

#sub checkSubstrain {

#    my $sql = "SELECT substrain_id, substrain_name FROM ${DATABASE}substrain WHERE substrain_id ";
#}

