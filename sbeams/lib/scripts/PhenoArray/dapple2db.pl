#!/usr/local/bin/perl

###############################################################################
# Program     : dapple2db.pl
# Author      : Rowan Christmas <xmas@systemsbiology.org>
# $Id$
#
# Description : This script loads a Quantitation file into PhenoArray
#
###############################################################################


###############################################################################
# Generic SBEAMS script setup
###############################################################################
use strict;
use vars qw ($sbeams $sbeamsPH
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $current_contact_id $current_username %plate_id %cond_id %cond_rep_id 
	     %subset_id %quant_id %quant_loc %notin);
use lib qw (/net/db/lib/sbeams/lib/perl);

use POSIX;
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;
use SBEAMS::PhenoArray;
use SBEAMS::PhenoArray::Settings;
use SBEAMS::PhenoArray::Tables;
use SBEAMS::PhenoArray::TableInfo;

$sbeams = new SBEAMS::Connection;
$sbeamsPH = new SBEAMS::PhenoArray;
$sbeamsPH->setSBEAMS($sbeams);
$| = 1;
$QUIET = 0;
#### Do the SBEAMS authentication and exit if a username is not returned
exit unless ($current_username =
    $sbeams->Authenticate(work_group=>'Phenotype_user'));

#### Print the header, do what the program does, and print footer
$sbeams->printTextHeader();
main();
$sbeams->printTextFooter();

exit 0;


###############################################################################
# Main part of the script
###############################################################################
sub main { 

    $sbeams->printUserContext(style=>'TEXT');
    print "\n";


    #### Define standard variables
    my ($i,$element,$key,$value,$line,$result,$sql,$infile);

    $DATABASE = $sbeams->getPHENOARRAY_DB();
    ####  Print out the header
    exit unless ($current_username =
		 $sbeams->Authenticate(work_group=>'Phenotype_user'));
   

    #### Define program and usage
    #my $USAGE = "Usage:  dapple2DB.pl (Quantitation_Files) (......)\n";
    
    #if ( $#ARGV < 0 ) { die $USAGE; }   

    #my @dappleFiles = @ARGV; 
    my @dappleFiles;
    print "DAPPLE FILES: @dappleFiles\n";
    ########################
    #Order of Program

#1. Read into hashes names and public keys from:
#     -Condition, Plate, Array_Quantitation

#2. Make Condition Repeats, one for each type of condition
#This means that when this program only repeats can be run together

#3. Make array_quantitation_subsets, one per 384-well plate

#4. Insert Spot data

    #Step 1
    readCondAndPlateIDandArrayQuant();
    #checkHashes();

    #Step2
    #send a list of all dapple files
    @dappleFiles = displayDappleFiles();
    makeNewCondRep(@dappleFiles);

    #Step3
    #Run through the files, sending one each time:
    foreach my $file (@dappleFiles) {
	makeNewArrayQuantitationSubset($file);
    }

    #Step4
    #Run through each of the files again, utilizing the subset info
    #this is the only time we will actually open a file
    foreach my $file (@dappleFiles) {
	insertSpotQuantitation($file);
    }


}


###############################################################################
# bail_out() subroutine - print error code and string, then exit
###############################################################################
sub bail_out {
    my ($message) = shift;
    $PROG_NAME = "Quantitation File Parser"; 
    print scalar localtime," [$PROG_NAME] $message\n";
    die "Error $DBI::err ($DBI::errstr)\n";
}

##################################################
##################################################
##################################################
# Rowan Stuff Below Here
##################################################
##################################################
##################################################


#Show all dapple files that have a record_status of 0
sub displayDappleFiles {
    my $sql = "SELECT array_quantitation_id, quant_file_name FROM ${DATABASE}array_quantitation WHERE record_status = '0'";
    my %notIn = $sbeams->selectTwoColumnHash($sql);

    my $sql = "SELECT array_quantitation_id, quant_file_path FROM ${DATABASE}array_quantitation WHERE record_status = '0'";
    %notin = $sbeams->selectTwoColumnHash($sql);


    my @files = keys %notIn;
    if ($#files < 0 ) {
	print "\n------------------\nNo dapple files to process.\n\n    please press enter";
    } else {
	print "Please select dapple files that were done together by typing\nthe numbers of all the files(underneath).\n then press return.\n";
    }

    print "\n\n";
    foreach my$i (keys %notIn) {
	print "$notIn{$i}\n|||||||||||||||||||\n>>> $i\n-------------------\n";
    }

    my $which = <STDIN>;
    my @line = split(" ",$which);
    my @ret;
    foreach my $id (@line) {
	#print "$notIn{$id}\n";
	push(@ret, $notin{$id});
    }
    print "@ret\n";
    return @ret;



}




sub checkHashes {
    print "-----------Conditions------------\n";
    foreach my $thing (keys %cond_id) {
	print "$thing \t:\t\t$cond_id{$thing}\n";
    }
    print "-----------Plates------------\n";
    foreach my $thing (keys %plate_id) {
	print "$thing \t:\t\t$plate_id{$thing}\n";
    }
    print "-----------Dapple------------\n";
    foreach my $thing (keys %quant_id) {
	print "$thing \t:\t\t$quant_id{$thing}\n";
    }
    print "-----------------------\n";

}

sub readCondAndPlateIDandArrayQuant {
#Read in the name and PK's for plate, condition, and array_quantitation
   #read in the name and path for array_quantitation
    my $sql_plate = "SELECT plate_name, plate_id FROM ${DATABASE}plate";
    %plate_id = $sbeams->selectTwoColumnHash($sql_plate);
   
    my $sql_cond = "SELECT condition_name, condition_id FROM ${DATABASE}condition";
    %cond_id = $sbeams->selectTwoColumnHash($sql_cond);

    my $sql_quant = "SELECT quant_file_path, array_quantitation_id FROM ${DATABASE}array_quantitation";
    %quant_id = $sbeams->selectTwoColumnHash($sql_quant);

    my $sql_loc = "SELECT quant_file_path, quant_file_path FROM ${DATABASE}array_quantitation";
    %quant_loc = $sbeams->selectTwoColumnHash($sql_loc);
}


sub makeNewCondRep {

# We will read through all repeats entered together to determine which 
# conditions are represented. For each condition a condition repeat will
# be generated, and the ID stored in %cond_rep_id acessed with the name of
# the condition
    print "Inserting Condition Repeats............\n";

    #my @dapple_files = shift; 
    #Read through each file name
    foreach my $file (@_) {
	
	my @line = split(":", $file);
	chomp(@line);	
	my $date_quantitated = $line[0];
	my $plateA = $line[1];
	my $condA = $line[2];
	my $plateB = $line[3];
	my $condB = $line[4];
	my $plateC = $line[5];
	my $condC = $line[6];
	my $plateD = $line[7];
	my $condD = $line[8];
	$condD =~ s/.dapple//;
	print "$condA, $condB, $condC, $condD\n";
#Set the values for each cond to the condition ID
#%cond_id is of course the hash that has all conditions in it
	
	$cond_rep_id{$condA} = $cond_id{$condA};
	$cond_rep_id{$condB} = $cond_id{$condB};
	$cond_rep_id{$condC} = $cond_id{$condC};
	$cond_rep_id{$condD} = $cond_id{$condD};


	my %dappleDone = (
			
			record_status => 1,
			);
	print "PK  $file : $quant_id{$file}\n";
	my $result;
	my $result = $sbeams->insert_update_row(
						insert => 0,
						update => 1,
				      table_name => "${DATABASE}array_quantitation",
						rowdata_ref => \%dappleDone,
						PK_value => $quant_id{$file},
						PK => "array_quantitation_id",
						);





    }

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
	$cond_rep_id{$cond} = $result;
    }
    print "done\n";
}

sub makeNewArrayQuantitationSubset {
#This will read through each array and make an array_quantitation_subset for 
#each 384-well-plate in the file

#A hash of hashes structured as
#
# %subset_id-->file--->A
#                  |-->B
#                  |-->C
#                  |-->D
# 
#will be created so that when each spot record is inserted we know
#which subset it belongs to
    my $file = shift;
    my @line = split(":", $file);
    chomp(@line);	
    my $date_quantitated = $line[0];
    my $plateA = $line[1];
    my $condA = $line[2];
    my $plateB = $line[3];
    my $condB = $line[4];
    my $plateC = $line[5];
    my $condC = $line[6];
    my $plateD = $line[7];
    my $condD = $line[8];
    $condD =~ s/.dapple//;

    print "FILE: $file , ID: $quant_id{$file}\n";
    
    #Now we will insert a seperate array_quant_subset
    ##############################
    #A
    my $resultA;
    if ($plateA =~ /\w/) {
	print "PLATEA $plateA : $plate_id{$plateA}\n";
	my %subsetA = (
		   array_quantitation_id => $quant_id{$file},
		   set_row => 0,
		   set_column => 0,
		   condition_repeat_id => $cond_rep_id{$condA},
		   plate_id => $plate_id{$plateA},
		   quality_flag => 0,
		   );


   
	$resultA = $sbeams->insert_update_row(
					  insert => 1,
					  update => 0,
					  return_PK => 1,
			    table_name => "${DATABASE}array_quantitation_subset",
					  rowdata_ref => \%subsetA,
					  PK => "array_quantitation_subset_id",
					  );
    } 
    ##############################
    #B
    my $resultB;
    if ($plateB =~ /\w/) {
	print "PLATEB $plateB : $plate_id{$plateB}\n";
	my %subsetB = (
		       array_quantitation_id => $quant_id{$file},
		       set_row => 0,
		       set_column => 1,
		       condition_repeat_id => $cond_rep_id{$condB},
		       plate_id => $plate_id{$plateB},
		       quality_flag => 0,
		       );


   
   
	$resultB = $sbeams->insert_update_row(
					      insert => 1,
					      update => 0,
					      return_PK => 1,
			    table_name => "${DATABASE}array_quantitation_subset",
					      rowdata_ref => \%subsetB,
					      PK => "array_quantitation_subset_id",
					      );
    }
    ############################
    #C
    my $resultC;
    if ($plateC =~ /\w/) {
    print "PLATEC $plateC : $plate_id{$plateC}\n";
    my %subsetC = (
		   array_quantitation_id => $quant_id{$file},
		   set_row => 1,
		   set_column => 0,
		   condition_repeat_id => $cond_rep_id{$condC},
		   plate_id => $plate_id{$plateC},
		   quality_flag => 0,
		   );


   
    $resultC = $sbeams->insert_update_row(
					  insert => 1,
					  update => 0,
					  return_PK => 1,
			    table_name => "${DATABASE}array_quantitation_subset",
					  rowdata_ref => \%subsetC,
					  PK => "array_quantitation_subset_id",
					  );
    }
    #########################
    #D
    my $resultD;
    if ($plateD =~ /\w/) {
	print "PLATED $plateD : $plate_id{$plateD}\n";
	my %subsetD = (
		       array_quantitation_id => $quant_id{$file},
		       set_row => 1,
		       set_column => 1,
		       condition_repeat_id => $cond_rep_id{$condD},
		       plate_id => $plate_id{$plateD},
		       quality_flag => 0,
		       );

   
	$resultD = $sbeams->insert_update_row(
					      insert => 1,
					      update => 0,
					      return_PK => 1,
			    table_name => "${DATABASE}array_quantitation_subset",
					      rowdata_ref => \%subsetD,
					      PK => "array_quantitation_subset_id",
					      );
    
    }
    #Now store each PK into the hash
    $subset_id{$file}->{A} = $resultA;
    $subset_id{$file}->{B} = $resultB;
    $subset_id{$file}->{C} = $resultC;
    $subset_id{$file}->{D} = $resultD;

}

sub insertSpotQuantitation {
#This will take a dapple file and using the subset_id 
#generated PKs in this program will insert each spot

    #Read in file
    my $file = shift;
    my @line = split(":", $file);
    chomp(@line);	
    my $date_quantitated = $line[0];
    my $plateA = $line[1];
    my $condA = $line[2];
    my $plateB = $line[3];
    my $condB = $line[4];
    my $plateC = $line[5];
    my $condC = $line[6];
    my $plateD = $line[7];
    my $condD = $line[8];
    $condD =~ s/.dapple//;
    print "Inserting spots for $file....\n";
    open (DAPPLE, "$quant_loc{$file}");
    #Read through dapple file inserting a spot on each line
    while (<DAPPLE>) {
	next if ( /^\#/ || /^1536/);
	
	my @entry = split;
	my $set_row = $entry[0];
	my $set_col = $entry[1];
	my $rel_row = $entry[2];
	my $rel_col = $entry[3];
	my $size = $entry[4];
	my $flag = $entry[5];
	my $intensity = $entry[6];
	my $bgnd = $entry[7];
	my $bgnd_stdev = $entry[8];
	#print "SPOT:: $set_row $set_col\n";
	my %spot;	
        #Depending on which plate load the corresponding subset_id
        ####################
        #A
	my $Insert = 0;
	if ( $set_row == 0 && $set_col == 0 && $plateA =~ /\w/) {
	    $Insert = 1;
	    %spot = (
		     array_quantitation_subset_id => $subset_id{$file}->{A},
		     set_row => $set_row,
		     set_column => $set_col,
		     rel_row => $rel_row,
		     rel_column => $rel_col,
		     ch1_flag => $flag,
		     ch1_intensity => $intensity,
		     ch1_bkg => $bgnd,
		     ch1_bkg_stdev => $bgnd_stdev,
		     ch1_size => $size,
		     );
        ######################
	#B
	} elsif ( $set_row == 0 && $set_col == 1 && $plateB =~ /\w/) {
	    $Insert = 1;
	    %spot = (
			array_quantitation_subset_id => $subset_id{$file}->{B},
			set_row => $set_row,
			set_column => $set_col,
			rel_row => $rel_row,
			rel_column => $rel_col,
			ch1_flag => $flag,
			ch1_intensity => $intensity,
			ch1_bkg => $bgnd,
			ch1_bkg_stdev => $bgnd_stdev,
			ch1_size => $size,
			);
        ########################
	#C
	} elsif ( $set_row == 1 && $set_col == 0 && $plateC =~ /\w/) {
	    $Insert = 1;
	    %spot = (
			array_quantitation_subset_id => $subset_id{$file}->{C},
			set_row => $set_row,
			set_column => $set_col,
			rel_row => $rel_row,
			rel_column => $rel_col,
			ch1_flag => $flag,
			ch1_intensity => $intensity,
			ch1_bkg => $bgnd,
			ch1_bkg_stdev => $bgnd_stdev,
			ch1_size => $size,
			);
        #########################
	#D
	} elsif ( $set_row == 1 && $set_col == 1 && $plateD =~ /\w/) {
	    $Insert = 1;
	    %spot = (
			array_quantitation_subset_id => $subset_id{$file}->{D},
			set_row => $set_row,
			set_column => $set_col,
			rel_row => $rel_row,
			rel_column => $rel_col,
			ch1_flag => $flag,
			ch1_intensity => $intensity,
			ch1_bkg => $bgnd,
			ch1_bkg_stdev => $bgnd_stdev,
			ch1_size => $size,
			);

	} 
	#foreach my $thing (keys %spot) {
	#    print "THING $thing\n";
	#}
	if ($Insert == 1) {
	    my $result;
	    my $result = $sbeams->insert_update_row(
						    insert => 1,
						    update => 0,
					     table_name => "${DATABASE}spot_quantitation",
						    rowdata_ref => \%spot,
						    PK => "spot_quantitation_id",
						    );
	}
    }
    print "Spots successfully inserted\n";
}
