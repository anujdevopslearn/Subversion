#!/usr/local/bin/perl
##################################################
# ssp_load.pl version: 1/10/02
#             Rowan Christmas
#
# This program reads in a 


use strict;
use Getopt::Long;
use vars qw ($sbeams $sbeamsPH
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $current_contact_id $current_username %ref_id $DA $DS $DP);

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
$USAGE = "ssp_load.pl [master_plate_file.txt] [-a -s]\n-a   delete all\n-s delete SM\n-p   delete PL";
print "$#ARGV\n";
if ( $#ARGV < 0 ) {die $USAGE};


for ( my $i=1; $i <= $#ARGV; $i++) {

    if ( $ARGV[$i] =~ /^-a/) {$DA = 1; $i++;}
    if ( $ARGV[$i] =~ /^-s/) {$DS = 1; $i++;}
    if ( $ARGV[$i] =~ /^-p/) {$DP = 1; $i++;}
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
    deleteAll();
    #makePlateTable();
    checkPlate();
    makeSubstrainTable();
    makeSMTable_and_makePlateLayoutTable();
    
}   

sub getRefStrains {
    
    my $sql = "SELECT strain_number, reference_strain_id FROM ${DATABASE}reference_strain ";
    %ref_id = $sbeams->selectTwoColumnHash($sql);
}


sub deleteAll {

    if ($DA == 1 || $DP == 1) {
	print "Deleting ALL plate layouts\n";
	<STDIN>;
	my $sql = "DELETE FROM ${DATABASE}plate_layout ".
	    "WHERE plate_layout_id = plate_layout_id";
	$sbeams->executeSQL($sql);
    }

    if ($DA == 1 || $DS == 1) {
	print "Deleting ALL sequence_modification\n";
	<STDIN>;
	my $sql = "DELETE FROM ${DATABASE}sequence_modification ".
	    "WHERE sequence_modification_id =  sequence_modification_id";
	$sbeams->executeSQL($sql);
    }

    if ($DA == 1) {
	print "Deleting ALL substrains\n";
	<STDIN>;
	my $sql = "DELETE FROM ${DATABASE}substrain ".
	    " WHERE substrain_id = substrain_id";
	$sbeams->executeSQL($sql);
    }
    

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

	#print ".";
	#Read in the substrain table each time to check for new entries
	if ($Insert == 0 ) {
	    my $sql_substrain = "SELECT substrain_name, substrain_id FROM ${DATABASE}substrain";
	    %substrain =  $sbeams->selectTwoColumnHash($sql_substrain);
	    $Insert = 1;
	}
	next if ( /^\#/ || /num_rows/ || /none/ || /blank/);
	
	my @line = split("\t");
	#next if ( $#line < 10 );
	my $p96p = $line[0];
	my $p96r = $line[1];
	my $p96c = $line[2];
	my $plate = $line[3];
	my $p384r = $line[4];
	my $p385c = $line[5];
	my $parent = $line[8];
	my $plasmid_num = $line[9];
	my $plasmid_name = $line[10];
	my $plasmid_ori = $line[11];


	# TEst first KO
	my $thing = uc $line[6]; #make upper case
	my $KO1;
	if ( $thing =~ /Y[A-P][LR]\d\d\d[CW]/ ) {
	    #This is a systematic name
	    $KO1 = $thing;
	    # print "Systematic name found\n";# for $KO1 \n";
	    
       	} elsif ($thing =~ /WT/ || $thing =~ /WILDTYPE/   ) {
	    $KO1 = $parent;

	} else {
	    #match the common name to the systematic name
	    $KO1 = $bioSeq{$thing};
	    #print "Common name matched $KO1 : $thing : $bioSeq{$thing}\n";
	    if (!$KO1) {
		print "\nCommon name not found for $KO1 line @line";
		next;
	    }
	}
	my $name = "$parent"."."."$KO1";
	my $KO2;
	
	if ( $line[7] !~ /null/ ) {
	    my $thing2 = uc $line[7]; #make upper case
	    
	    if ( $thing2 =~ /Y[A-P]\d\d\d[CW]/ ) {
		#This is a systematic name
		$KO2 = $thing2;
	    } else {
		#match the common name to the systematic name
		$KO2 = $bioSeq{$thing2};
		if (!$KO2) {
		    print "\nCommon name not found $KO2 @line";
		    next;
		}
	    }
	    $name = "$name"."."."$KO2";
	}



	#make a plasmid if necessary
	if ($plasmid_num !~ /null/ ) {
	    
	   # print "FUCK $plasmid_num\n";
	    $name = "$name"."."."$plasmid_num";
	    makePlasmid($plasmid_num);
	 }
    

	if ( $line[6] =~ /wt/ ) {
	    $name = $parent;
	}

	my $sql_plasmid = "SELECT plasmid_name, plasmid_id FROM ${DATABASE}plasmid ";

	my %plas_id = $sbeams->selectTwoColumnHash($sql_plasmid);
	

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
	    if ( $plasmid_num !~ /null/ ) {
		%strain = (
			   substrain_name => $name,
			   strain_id => 1,
			   plasmid1_id => $plas_id{$plasmid_num},
			   created_by_id => $sbeams->getCurrent_contact_id(),  
			   modified_by_id => $sbeams->getCurrent_contact_id(),
			 owner_group_id => $sbeams->getCurrent_work_group_id(),
			  record_status => 0,           
			  ); 
	} else {
	    #otherwise:
	    %strain = (
		       substrain_name => $name,
		       strain_id => 1,
		       created_by_id => $sbeams->getCurrent_contact_id(),      
		       modified_by_id => $sbeams->getCurrent_contact_id(),
		       owner_group_id => $sbeams->getCurrent_work_group_id(),
		       record_status => 0,           
		       ); 
	}
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

    print "\nSUBSTRAINS SUCCESFULLY INSERTED\n$lazy strains inserted\n";
   
}

sub makeSMTable_and_makePlateLayoutTable {
    my $SM = 0;
    my $PL = 0;
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


    my $InsertSM = 0;
    my $InsertPL = 0;
    my %bioM;
    my %pLid;
    my %pLplate;
    while (<IN2>) {

	if ( $InsertSM == 0) { #read in bio_mods if changed
	    my $sql_bioM  = "SELECT substrain_id, sequence_modification_id FROM ${DATABASE}sequence_modification ";
	    %bioM = $sbeams->selectTwoColumnHash($sql_bioM);
	    $InsertSM = 1;
	}

	if ( $InsertPL == 0) { #read in plate layouts if changed
	    my $sql_pl = "SELECT plate_layout_id, substrain_id FROM ${DATABASE}plate_layout";
	    %pLid = $sbeams->selectTwoColumnHash($sql_pl);
	    my $sql_pla = "SELECT plate_layout_id, w384_plate_id FROM ${DATABASE}plate_layout";
	    %pLplate = $sbeams->selectTwoColumnHash($sql_pla);
	    $InsertPL =1;
	}
	
	next if ( /^\#/ || /num_rows/ || /none/ || /blank/);
	#print ".";
	my @line = split("\t");
#	next if ( $#line < 10 );
	my $p96p = $line[0];
	my $p96r = $line[1];
	my $p96c = $line[2];
	my $plate = $line[3];
	my $p384r = $line[4];
	my $p385c = $line[5];
	my $parent = $line[8];
	my $plasmid_num = $line[9];
	my $plasmid_name = $line[10];
	my $plasmid_ori = $line[11];
	
	# TEst first KO
	my $thing = uc $line[6]; #make upper case
	my $KO1;
	if ( $thing =~ /Y[A-P][LR]\d\d\d[CW]/ ) {
	    #This is a systematic name
	    $KO1 = $thing;
	    # print "Systematic name found\n";# for $KO1 \n";
	    
       	} elsif ($thing =~ /WT/ || $thing =~ /WILDTYPE/   ) {
	    $KO1 = $parent;

	} else {
	    #match the common name to the systematic name
	    $KO1 = $bioSeqName{$thing};
	    #print "Common name matched $KO1 : $thing : $bioSeq{$thing}\n";
	    if (!$KO1) {
		print "\nCommon name not found for $KO1 line @line";
		next;
	    }
	}
	my $name = "$parent"."."."$KO1";
	my $KO2;
	
	if ( $line[7] !~ /null/ ) {
	    my $thing2 = uc $line[7]; #make upper case
	    
	    if ( $thing2 =~ /Y[A-P]\d\d\d[CW]/ ) {
		#This is a systematic name
		$KO2 = $thing2;
	    } else {
		#match the common name to the systematic name
		$KO2 = $bioSeqName{$thing2};
		if (!$KO2) {
		    print "\nCommon name not found $KO2 @line";
		    next;
		}
	    }
	    $name = "$name"."."."$KO2";
	}

	if ($plasmid_num !~ /null/ ) {
	    $name = "$name"."."."$plasmid_num";
	   # makePlasmid($plasmid_num);
	}
    

	if ( $line[6] =~ /wt/ ) {
	    $name = $parent;
	}
	
#############
# Insert sequence_modification 
#############
       
	
	#Test for already inserted
	my $exist = 0;
	foreach my $mod (keys %bioM) {
	    
	    if ($mod == $substrain_id{$name}) {
		$exist =1;
	    }
	}
	
	if ($exist == 0 ) {
	   
	    $InsertSM = 0;
	    if ( $bioSeq_id{$KO1} ) {
		
		my %bioMod;
		if ($thing !~ /WT/ || $thing !~ /WILDTYPE/) {
		#Insert two mods
		    if ( $line[7] !~ /null/ ) {
		
			my %bioMod2 = (
				   substrain_id => $substrain_id{$name},
				   affected_biosequence_id => $bioSeq_id{$KO2},
				   modification_index => 1,
				   deletion_start => 0,
				   deletion_length => 100,
				   inserted_biosequence_id => 19962,
				   created_by_id => 7,
				   modified_by_id => 7, 
				   record_status => 0, 
				   ); 

			my $result;
			$SM++;
			my $result = $sbeams->insert_update_row(
				      insert => 1,                      
				      update => 0,                      
			table_name => "${DATABASE}sequence_modification",
				    rowdata_ref => \%bioMod2,         
				     PK => "sequence_modification_id",      
			       );       


		    } 

		     %bioMod = (
				substrain_id => $substrain_id{$name},
				affected_biosequence_id => $bioSeq_id{$KO1},
				modification_index => 0,
				deletion_start => 0,
				deletion_length => 100,
				inserted_biosequence_id => 19962,
				created_by_id => 7,
				modified_by_id => 7, 
				record_status => 0, 
				); 

		} else {
		    %bioMod = (
			  substrain_id => $substrain_id{$name},
			  created_by_id => 7,              
			  modified_by_id => 7,         
			  record_status => 0,           
			  ); 
		} 
		my $result;
		$SM++;
		my $result = $sbeams->insert_update_row(
				      insert => 1,                      
				      update => 0,                      
			table_name => "${DATABASE}sequence_modification",
				    rowdata_ref => \%bioMod,         
				     PK => "sequence_modification_id",      
			       );         
	    }
	}

####################
# Insert plate_layout table
####################
	my $exist2 = 0;
	foreach my $id (keys %pLid) {
	    if ( $pLid{$id} == $substrain_id{$name} && $pLplate{$id} == $plate_id{$plate} ) {
		$exist2 =1;
	    }
	}

	if ($exist2 ==0 ) {#&& $name != "BY4741.YJL038C" ) {
	    $PL++;
	    #print "$plate_id{$plate} is the ID for $plate\n";
	    my %layout = (
			  substrain_id => $substrain_id{$name},
			  w384_plate_id => $plate_id{$plate},
			  w384_row => $p384r,
			  w384_column => $p385c,
			  w96_plate => $p96p,
			  w96_row => $p96r,
			  w96_column => $p96c,
			  );

		my $result = $sbeams->insert_update_row(
					     insert => 1,                      
					     update => 0,     
				       table_name => "${DATABASE}plate_layout",
					     rowdata_ref => \%layout,
					     PK => "plate_layout_id",
					     );

	 

	    } else {
		print OUT "ORF not in records:     $KO1\n";
	    }
	    
	
	
    }
    print "\nSEQUENCE MODS AND PLATE LAYOUTS SUCCESSFULLY INSERTED\n$PL plate_layouts & $SM modifications\n";
   
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

