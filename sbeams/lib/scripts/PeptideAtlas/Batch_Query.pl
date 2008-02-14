#!/usr/local/bin/perl  -w

###############################################################################
# Program     : Batch_Query.pl
#
#
# Description : Prints summary of a given peptide given selection
#               atlas build, and peptide name or sequence.
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


###############################################################################
# Set up all needed modules and objects
###############################################################################

use strict;
use Getopt::Long;
use FindBin;

use POSIX qw(ceil);

use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS);
##use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TabMenu;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::PeptideAtlas::ConsensusSpectrum;
use SBEAMS::PeptideAtlas::ModificationHelper;
use SBEAMS::PeptideAtlas::PeptideOverview;

use SBEAMS::Proteomics::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

my $modification_helper = new ModificationHelper();




###############################################################################
# Set Global Variables and execute main()
###############################################################################
main();
exit(0);


###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
###############################################################################
sub main {

    #### Do the SBEAMS authentication and exit if a username is not returned
    exit unless ($current_username = $sbeams->Authenticate(
        permitted_work_groups_ref=>['PeptideAtlas_user','PeptideAtlas_admin',
        'PeptideAtlas_readonly'],
        #connect_read_only=>1,
        allow_anonymous_access=>1,

     ));
     
      handle_request();
} # end main


###############################################################################
# Handle Request
###############################################################################
sub handle_request {



    ### Default Page headers Nav Bar and Footer
    my ($static_header,$footer)=getStaticHeaderFooter() ;
    my $vocab=vocabHTML();
    
       #### Define some generic variables
    my ($sql);
    
    ##### Default Path for saving output files
    my $file_path="/net/dblocal/wwwspecial/peptideatlas/peptides";

    ###### Definfing the constants URL to build dynamic links
    my $base_url= "http://db.systemsbiology.net/sbeams/cgi/PeptideAtlas";
    my $build_link= "/buildDetails?atlas_build_id=";
    my $pep_link1="/GetPeptide?atlas_build_id=";
    my $pep_link2="&searchWithinThis=Peptide+Sequence&searchForThis=";
    my $pep_link3="&action=QUERY";


    ### Default



    # Get list of accessible projects  PASSING ON EXPLICITLY CONTACT_ID = 107 WHICH IS BY DEFAULT GUEST CONTACT ID
    my @accessible_project_ids = $sbeams->getAccessibleProjects(contact_id => 107);
    my $project_string = join( ",", @accessible_project_ids ) || '0';
    return unless $project_string;  # Sanity check
    my $atlas_project_clause = "AND AB.project_id IN ( $project_string )";

    ### AND P.peptide_sequence LIKE 'GL%'  sequence constraint being removed now building pages for each peptide in public build

    #### Define the SQL statement

    $sql = qq~

      SELECT  distinct P.peptide_accession,P.peptide_sequence, P.SSRCalc_relative_hydrophobicity,
      P.molecular_weight, P.peptide_isoelectric_point, PI.n_observations, PI.atlas_build_id,
      AB.atlas_build_name, OZ.organism_name
      FROM $TBAT_PEPTIDE_INSTANCE PI
      INNER JOIN $TBAT_PEPTIDE P
      ON ( PI.peptide_id = P.peptide_id )
      INNER JOIN $TBAT_ATLAS_BUILD AB
      ON (PI.atlas_build_id = AB.atlas_build_id)
      INNER JOIN $TBAT_BIOSEQUENCE_SET BS
      ON (AB.biosequence_set_id = BS.biosequence_set_id)
      INNER JOIN $TB_ORGANISM OZ
      ON (BS.organism_id= OZ.organism_id)
      WHERE 1 = 1
      $atlas_project_clause
      ORDER BY P.peptide_sequence, OZ.organism_name, PI.n_observations DESC,AB.atlas_build_name

       ~;

my ($tmp_peptide,@peptide_info, @builds, $counter);

$counter=0;



while (my $row = $sbeams->selectSeveralColumnsRow(sql=>$sql)) {


  my ($peptide_acc,$peptide_seq,$ssr_calc,$mol_wt,$pi,$n_obs,$build_id,$build_name,$org_name)= @{$row};


    #### Case when one peptide occurs in many builds
    
    if(  ($peptide_seq eq $tmp_peptide ) || (!$tmp_peptide)  ) {


        @peptide_info = ($peptide_acc,$peptide_seq,$mol_wt,$pi,$ssr_calc);
        
        ####### Building the link for No of observations
        my $peptide_url=qq~$base_url$pep_link1$build_id$pep_link2$peptide_seq$pep_link3~;
        my $peptide_html_link=qq~<A HREF ="$peptide_url" target="_blank">$n_obs</A>~;


        ##### Building the link for the Atlas Builds
        my $build_url=qq~ $base_url$build_link$build_id ~;
        my $build_html_link=qq~<A HREF="$build_url" target="_blank">$build_name</A>~;

        my @temp_array=($org_name,$peptide_html_link,$build_html_link);

        ##### Passing by reference to the @builds array as per the requirement of the EncodesectionTable Method
        push (@builds, \@temp_array);
        

        }

else

     {

     
       my ($dyn_content, $dynamic_header_top);
       
      ($dynamic_header_top,$dyn_content) = DisplayPeptide(view1=>\@peptide_info,
                                                      view2=>\@builds);

      #### Creating the name of the Static HTML Page eg GXEAYIFPR.html
      my $file_ext=".html";
      my $file_name=$peptide_info[1].$file_ext;
      #### Creating a new static HTML page for each peptide

      open(FH , ">$file_path/$file_name") ||  die " Unable to open the file" ;

      my $full_header=$dynamic_header_top.$static_header;

      print (FH $full_header.$dyn_content.$vocab.$footer);

      close (FH) || die " Cant close the file handle ";

      $counter ++;
      print " \nPrinted the file $counter $peptide_info[1].html\n";
      

      
      
      @peptide_info=();
      @builds=();

      @peptide_info = ($peptide_acc,$peptide_seq,$mol_wt,$pi,$ssr_calc);
      my $peptide_url=qq~$base_url$pep_link1$build_id$pep_link2$peptide_seq$pep_link3~;
      my $peptide_html_link=qq~<A HREF ="$peptide_url" target="_blank">$n_obs</A>~;

      ##### Building the link for the Atlas Builds
      my $build_url=qq~ $base_url$build_link$build_id ~;
      my $build_html_link=qq~<A HREF="$build_url" target="_blank">$build_name</A>~;

      my @temp_array=($org_name,$peptide_html_link,$build_html_link);

      ##### Passing by reference to the @builds array as per the requirement of the EncodesectionTable Method
      push (@builds, \@temp_array);


      }


$tmp_peptide=$peptide_seq;

  } ## END WHILE LOOP

} ### END Handle Request






#######################################################################################
##############Display Peptide
#######################################################################################


sub DisplayPeptide {

#### This subroutine will print the first two tables of the HTML page.

#
my %args =@_;

##
unless( $args{view1} && $args{view2}  ) {

    $log->error( "No information passed to display" );
    return;
  }
  

### Defining global symbols and values here
 my ($table1, $table2 );

my $view1 = $args{view1};
my $view2 = $args{view2};
my @view2=  @{$view2};


my ($pa,$seq,$mw,$pi,$ssr_calc) = @{$view1};

my $peptide_accession = $pa;
my $peptide_sequence= $seq;
my $SSR_Calc = sprintf("%0.2f",$ssr_calc);
my $mol_wt= sprintf( "%0.2f", $mw);
my $Pi = sprintf( "%0.1f", $pi );




$table1 = "<BR><TABLE WIDTH=600>\n";

$table1.=$sbeamsMOD->encodeSectionHeader(
                                        text => "$peptide_accession",

                                                    bold => 1,
                                                    width => 900
                                            );
#Substituting the path generated from encodeSectionHeader to match with peptideatlas.org for displaying oragne header
$table1 =~ s/\/devAP\/sbeams//gm;

  $table1 .= $sbeamsMOD->encodeSectionItem( key   => 'Peptide Accession',
                                          value => $peptide_accession,
                                          key_width => '20%'
                                         );
  $table1.= $sbeamsMOD->encodeSectionItem( key   => 'Peptide Sequence',
                                          value => $peptide_sequence
                                         );
   $table1 .= $sbeamsMOD->encodeSectionItem( key   => 'Avg Molecular Weight',
                                           value => "$mol_wt"
                                         ) if $mol_wt;
  $table1 .= $sbeamsMOD->encodeSectionItem( key   => 'pI (approx)',
                                           value => "$Pi"
                                         ) if $Pi;
 $table1.= $sbeamsMOD->encodeSectionItem( key   => 'SSRCalc Relative Hydrophobicity',
                                          value => "$SSR_Calc"
                                         );

 $table1 .= '</TABLE>';



$table2 = "<BR><TABLE WIDTH=600>";


my @headings = (   'Organism Name',
                   'No. of Observations',
                   'Build Names in which Peptide is found',
                );



$table2 .= $sbeamsMOD->encodeSectionHeader(
      text => 'Peptide Found in these builds',
      width => 900
  );

#Substituting the path generated from encodeSectionHeader to match with peptideatlas.org for displaying oragne header
$table2 =~ s/\/devAP\/sbeams//gm;

########### In the row argument of encodeSectionTable we need to pass referenced arrays

$table2 .= $sbeamsMOD->encodeSectionTable(rows => [ \@headings, @view2 ],
                                        header => 1,
                                        nowrap => [1..scalar(@headings)],
                                        align => [ qw(left left left) ],
                                        bg_color => '#EAEAEA',
                                        sortable => 1,
                                        set_download=>0);
$table2 .= '</TABLE>';

########################################################################
########## Generating the Dynamic Header for each Static Page
########################################################################

my $doc_type =qq ~<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">\n~;
my $title = qq~ <HTML><head><title>$peptide_sequence</title>\n~;
my $meta_tag1=qq~<meta name="DESCRIPTION" content="Summary of Information in PeptideAtlas for Peptide $peptide_sequence" >\n~;
my $meta_tag2=qq~<meta name="KEYWORDS" content="$peptide_sequence" >\n~;
my $meta_tag3=qq~<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">\n\n~;

##### Generating a single scalar containing the dynamic header
my $dynamic_header_top=$doc_type.$title.$meta_tag1.$meta_tag2.$meta_tag3;

###### Generating a single scalar for each peptide information to be displayed
my $peptide_info_html = $table1.$table2;

return($dynamic_header_top,$peptide_info_html);


 }  #### End of Display Peptide


########################################
#### Get Header and Footer
########################################


sub getStaticHeaderFooter{

####this is responsible for fetching the header .. navbar and footer.  First 4 lines of the header are scrapped and generated
#### dynamically for each peptide

  my $self = shift;
  use LWP::UserAgent;
  use HTTP::Request;
  my $ua = LWP::UserAgent->new();
  my $skinLink = 'http://www.peptideatlas.org';
  my $response = $ua->request( HTTP::Request->new( GET => "$skinLink/.index.dbbrowse.php" ) );
  my @page = split( "\n", $response->content() );
  my $skin = '';
  my $cnt=0;
  for ( @page[4..$#page] ) {

    $cnt++;
    last if $_ =~ /--- Main Page Content ---/;
    $skin .= $_;
  }

  ### No need to change the path when running on the peptideatlas.org
  ##$skin =~ s/\/images\//\/sbeams\/images\//gm;

  my $static_header_navbar=$skin;

  #### As 4 header lines have been skipped adding +4 to the counter explcitly
  #### to mantain the count number for extracting the footer
  $cnt=$cnt+4;
  
  my $footer =join("\n", @page[$cnt..$#page]);

  return ($static_header_navbar,$footer);

}  #### END GET STATIC HEADER FOOTER INFO


######################################################################################
########### HTML Static text for each page
######################################################################################



sub vocabHTML {

###### This subroutine displays the Vocab section on the HTML Page

my ($table3);

my $pi_desc='Isoelectric point of the peptide';
my $ssrcalc_desc='Sequence Specific Retention Factor provides a hydrophobicity measure for each peptide using the algorithm of Krohkin et al. Version 3.0';
my $org_desc='Organism in which this peptide is observed';
my $n_obs_desc='Number of MS/MS spectra that are identified to this peptide in each build. The hyperlink will take you to the peptide page that will display all the relevant information about this peptide contained in the listed PeptideAtlas build';
my $build_names_desc='Public build in which this peptide is found. The hyperlink will take you to a build specific page summarizing all the relevant information about the build.';

$table3 ='<BR><BR><BR><BR><BR><BR><BR><BR><BR><BR><TABLE WIDTH=600>';

$table3 .= $sbeamsMOD->encodeSectionHeader( text => 'Vocabulary',
                                            width => 900
                                            );

#Substituting the path generated from encodeSectionHeader to match with peptideatlas.org for displaying oragne header
$table3 =~ s/\/devAP\/sbeams//gm;

$table3 .= $sbeamsMOD->encodeSectionItem( key   => 'pI',
                                          value => $pi_desc,
                                          key_width => '20%'
                                         );
$table3.= $sbeamsMOD->encodeSectionItem( key   => 'SSRCalc',
                                          value =>$ssrcalc_desc
                                         );
$table3.= $sbeamsMOD->encodeSectionItem( key   => 'Organism Name',
                                          value =>$org_desc
                                         );
                                         
$table3.= $sbeamsMOD->encodeSectionItem( key   => 'Number of observations ',
                                          value =>$n_obs_desc
                                         );

$table3.= $sbeamsMOD->encodeSectionItem( key   => 'Build Names in which Peptide is found',
                                          value =>$build_names_desc
                                         );
$table3 .= '</TABLE>';


}



