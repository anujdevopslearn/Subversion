#!/usr/local/bin/perl -w

###############################################################################
# Program     : update_buildpage.pl
# Author      : Zhi Sun
#
# Description : update http://www.peptideatlas.org/builds/
#
###############################################################################


###############################################################################
   # Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Data::Dumper;
use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams $sbeamsMOD $q $current_username 
             $ATLAS_BUILD_ID 
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TEST
            );


#### Set up SBEAMS core module
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::Proteomics::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::Proteomics::Tables;

$sbeams = new SBEAMS::Connection;
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);
my $atlas = new SBEAMS::PeptideAtlas;
$atlas->setSBEAMS($sbeams);

###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:
  --verbose n            Set verbosity level.  default is 0
  --quiet                Set flag to print nothing at all except errors
  --debug n              Set debug flag
  --test                 Test only, don't write records
  --atlas_build_id       
  --organism_specialized      'plasma' 
                              'N-Glycosite'
                              'Pancreas'
                              'Liver'
                              'Urine'
  --xml_file
  --sql_file

e.g.: ./$PROG_NAME --atlas_build_id \'73\'  --organism_specialized 'plasma' 

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","test",
        "atlas_build_id:i","organism_specialized:s","xml_file:s",
        "sql_file:s",
    )) {

    die "\n$USAGE";

}


$VERBOSE = $OPTIONS{"verbose"} || 0;

$QUIET = $OPTIONS{"quiet"} || 0;

$DEBUG = $OPTIONS{"debug"} || 0;

$TEST = $OPTIONS{"test"} || 0;

my $current_build_page = "/net/dblocal/wwwspecial/peptideatlas/builds/index.php"; 
my $page = qq~
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<script type="text/javascript" src="/includes/TipWidget.js"> </script>
    <STYLE>
  div#tooltipID { background-color:#F0F0F0;
                  border:2px
                  solid #FF8C00;
                  padding:4px;
                  line-height:1.5;
                  width:200px;
                  font-family: Helvetica, Arial, sans-serif;
                  font-size:12px;
                  font-weight: normal;
                  position:absolute;
                  visibility:hidden; left:0; top:0;
                }
  </STYLE>
  <script type="text/javascript">
  function my_alert( foo, bar ) {
    alert( foo );
    alert( bar );
  }
  </script>

<HTML>
<?php
  \$DOCUMENT_ROOT = \$_SERVER['DOCUMENT_ROOT'];
  /* \$Id\$ */
  \$TITLE="Peptide Atlas";
  include("\$DOCUMENT_ROOT/includes/style.inc.php");
  include("\$DOCUMENT_ROOT/includes/header.inc.php");
  include("\$DOCUMENT_ROOT/includes/navbar.inc.php");

~;

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
  exit unless (
      $current_username = $sbeams->Authenticate(work_group=>'PeptideAtlas_admin')
  );


  $sbeams->printPageHeader() unless ($QUIET);

  handleRequest();

  $sbeams->printPageFooter() unless ($QUIET);

} # end main


###############################################################################
# handleRequest
###############################################################################
sub handleRequest {

  my %args = @_;


  my $atlas_build_id = $OPTIONS{"atlas_build_id"} || '';
  my $organism_specialized = $OPTIONS{"organism_specialized"} || '';

  #### Verify required parameters
  unless ($atlas_build_id) {
    print "\n$USAGE\n";
    print "\nERROR: You must specify an --atlas_build_id\n\n";
    exit;
  }

  writeRecords( atlas_build_id=>$atlas_build_id, organism_specialized=>$organism_specialized);

} # end handleRequest



###############################################################################
# writeRecords -- write build page
# 
###############################################################################
sub writeRecords 
{
    my %args = @_;

    my $build_id = $args{'atlas_build_id'} or die
        " need atlas_build_id ($!)";
 
    my $org_spec = $args{'organism_specialized'} || '';


    my @build_info = get_build_overview ( $build_id);
    my ($multi_pep_count_cnt, 
        $multi_pep_count_obs, 
        $smpl_count, 
        $build_date, 
        $prob, 
        $db, 
        $organism_id) = @build_info;

    $build_date =~ s/\-//;
    $build_date =~ s/\-.*//;
    $prob = sprintf("%.1f", $prob);

    my %mon = ( '01'   =>  'Jan',
                '02'   =>  'Feb',
                '03'   =>  'Mar',
                '04'   =>  'Apr',
                '05'   =>  'May',
                '06'   =>  'June',
                '07'   =>  'July',
                '08'   =>  'Aug',
                '09'   =>  'Sep',
                '10'   =>  'Oct',
                '11'   =>  'Nov',
                '12'   =>  'Dec',
        );
   
    my @organism_info = get_organism_info();
    my %abbrev_organism;
    my %organism_abbrev;
    my $InputBuildOrg;
    my $InputBuildOrgAbr;
    my $InputBuildOrgFullName;

    foreach my $row (@organism_info)
    {
        my ($org, $abr, $org_id, $fullname) = @{$row};
        $organism_abbrev{$org} = lc($abr);
        $abbrev_organism{lc($abr)} = $org;

        if($org_id eq $organism_id){
          $InputBuildOrg = $org;
          $InputBuildOrgAbr = lc($abr);

         if($org_spec){
            if(lc($org_spec) eq 'plasma'){ $org_spec = 'pls';}
            $InputBuildOrgAbr =  $InputBuildOrgAbr."_".$org_spec;
         }  
          $InputBuildOrgFullName = $fullname;
        }
 
        $abr = lc($abr).'_pls';
        $abbrev_organism{$abr} = $org." plasma";

    }
 
    #print Dumper(\%organism_abbrev );

    open(IN, "<$current_build_page") or die "cannot open $current_build_page\n";
    
    my @lines = <IN> ;
    close IN;
    
    my (%build_info, %showbuild, %builds);
    my ($abr, $ind, $pre, $flag);
    LOOP:foreach my $line (@lines){
     next if ($line =~ /^\s*\#/); 
     next if($line =~ /^$/); 
     if($line =~ /^\s+\$(\w+)\s*=\s*array\s*\(/){
         if($line =~ /curr/) { print "$line"; last LOOP;}

         $pre = $abr;
         $abr = $1;
         $ind = 1;
         $build_info{$abr} = "\t# ".$abbrev_organism{$abr}." builds\n$line";
         if($pre && $pre eq $InputBuildOrgAbr){
          
           $build_date =~ /(\d{4})(\d{2})/;
           $build_date = $1.$2;
           next if (defined $builds{$pre}{$build_date});
           my $str = "               '".$build_date."' => array ('show' => TRUE, 'name' => '".
                     $InputBuildOrg." ".$org_spec."', 'date' => '".$mon{$2}." ".$1.
                     "', 'samples' => ".$smpl_count.", 'fdr' => '', 'peptides' => ".
                     $multi_pep_count_cnt.", 'spectra' => '". 
                     $multi_pep_count_obs."', 'db' => '".$db."', 'special' => '' ),\n";

           $flag =1;
           $build_info{$pre} =~ s/$pre = array\(\n/$pre = array\(\n$str/;
           $showbuild{$pre}='$'.$pre."['".$build_date."'],\n";
           $ind=1;
        }
         
     }
     elsif($line =~ /show/){
       $build_info{$abr} .= $line;
       if($line =~ /\'show\' => TRUE/){
         $line =~ /\s+'(\d+)'\s+=>\s+array/;
         my $time = $1;         
         my $tag = $abr;
         $builds{$tag}{$time}=1;
         if(defined $showbuild{$tag}){
           $tag=~ /(\d*)$/;
           if($1){
             $ind = $1;
           }
           $tag = $tag.++$ind;
           if($tag eq 'hs_pls2'){
             $showbuild{$tag}='$'.$abr."['".$time."'],\n";
           }
         }
         else{
           $showbuild{$tag}='$'.$abr."['".$time."'],\n";
         }
       }
     
     }
     elsif($line =~ /^\s+\);\s+$/){
       $build_info{$abr} .= "$line\n";
     }

   } 

   if(! $flag){
      $build_info{$InputBuildOrgAbr} = "\t# ".$abbrev_organism{$InputBuildOrgAbr}." builds\n";
      $build_info{$InputBuildOrgAbr} .="\t". '$'.$InputBuildOrgAbr." = array(\n";

      $build_date =~ /(\d{4})(\d{2})/;
      my $str ="\t\t\t\t'". $build_date."' => array ('show' => TRUE, 'name' => '".
                     $InputBuildOrg." ".$org_spec."','date' => '".$mon{$2}." ".$1.
                     "', 'samples' => ".$smpl_count.", 'fdr' => '', 'peptides' => ".
                     $multi_pep_count_cnt.", 'spectra' => '".
                     $multi_pep_count_obs."', 'db' => '".
                     $db."' , 'special' => '' ),\n\t\t);\n\n";

     $showbuild{$InputBuildOrgAbr}='$'.$InputBuildOrgAbr."['".$build_date."'],\n";
     $build_info{$InputBuildOrgAbr} .= $str;

   } 

   print Dumper(\%showbuild );
   foreach my $org (keys %build_info)
   {
     $page .=$build_info{$org};
   }
   $page .= '  $curr = array ('."\n";

   my $build_key_array;
   foreach my $k (sort keys %showbuild){
     $page .=sprintf("%20s", "'".$k)."' => ".$showbuild{$k};
     $build_key_array .= "'$k',";
   }
   
   $page .="                );\n";

   my $body_content;
   my $start=0;
   foreach my $line (@lines){
     if($line =~ /\?>/){
       $start=1;
     }
     if($start){
       if($line =~ /\s+\$build_keys = array\(/){
         $build_key_array =~ s/,$//;
         $body_content .="        \$build_keys = array(".$build_key_array.");\n";
       }
       elsif(! $flag && $line =~ /<\!-- End Content-->/){
         my $str = NewAddition($InputBuildOrgAbr, 
                               $InputBuildOrg, 
                               $InputBuildOrgFullName,
                               $org_spec,
                               $build_date);
         $body_content .=$str."\n   <!-- End Content-->\n";
       }
       else{
         $body_content .=$line;
       }
     }
   }
   $page .=$body_content;
   open(OUT, ">test.php");
   print OUT $page;
   close OUT;
   NewAddition($InputBuildOrgAbr,
               $InputBuildOrg,
               $InputBuildOrgFullName,
               $org_spec,
               $build_date);

}

###############################################################
# New addition of organism to the build page
###############################################################

sub NewAddition {

  my $abr = shift;
  my $org = shift;
  my $fullname = shift;
  my $spec = shift;
  my $buildDate = shift;
   
  my $dirname = $org;
  my $xml_file = $OPTIONS{"xml_file"} || '';
  my $sql_file = $OPTIONS{"sql_file"} || '';
  
  $dirname =~ s/\s+//g;
  $dirname =~ s/\.//g;
  $dirname = lc($dirname);

  my $str =<<EOM;

<hr width="100%" size="1" color="black" />
       <h4>$org $spec($fullname)</h4>

   <p class="text">
       $fullname     <?php echo(\$curr[\'$abr\']['date']) ?> build contains
   <?php echo(\$curr[\'$abr\']['peptides']) ?> distinct non-singleton peptides above P\&ge;0.9 from <?php echo(\$curr[\'$abr\']['samples']) ?> samples<?php echo(\$curr[\'$abr\']['fdr']) ?>.
   </P>

   <p class="text">Available Builds:<br/>

   <?php foreach( \$$abr as \$build ) {
   if ( \$build['show'] ) {
     echo( '<img src="/images/yellow-arrow.gif" border="0"><img src="../images/clear.gif" border="0" height="1" width="1">' );
      echo( "\$build[name] \$build[date] Build \$build[special] <BR>\\n" );
     }
   }
   ?>
   <a href="$dirname/$spec/index.php" class="textlink">[DOWNLOAD]</a><br>
EOM
  
   my $subdirname;
   my $build_path = $current_build_page;
   $build_path =~ s/(.*)\/.*/$1/;
   
   if($spec){
     $dirname = "$dirname/$spec";
     $subdirname = "$buildDate";
     `mkdir $build_path/$dirname`;
     `mkdir $build_path/$dirname/$subdirname`;
     `mv $xml_file  $build_path/$dirname/$subdirname/`;
     `mv $sql_file  $build_path/$dirname/$subdirname/`;
   }
   else{
     $subdirname = "$buildDate";
     `mkdir $build_path/$dirname`;
     `mkdir $build_path/$dirname/$subdirname`;
     `mv $xml_file  $build_path/$dirname/$subdirname`;
     `mv $sql_file  $build_path/$dirname/$subdirname`;

   }
   undate_individual_page(organism => $org,
                      spec => $spec,
                      build_path => $build_path,
                      dirpath  => $dirname,
                      subdir   => $subdirname,
                      build_date => $buildDate,                     
                      );

   return $str;

}

###############################################################
# update build page for each organism
###############################################################
sub undate_individual_page {

    my %args = @_;

    my $organism = $args{'organism'} or die " need organism ($!)";
    my $build_path = $args{'build_path'} or die " need build_path ($!)";
    my $dir_path = $args{'dirpath'} or die " dirpath ($!)";
    my $build_id = $args{'subdir'} or die " need subdir ($!)";
    my $build_date = $args{'subdir'} or die " need builddate ($!)";
    my $spec      = $args{'spec'};
    my $xml_file = $OPTIONS{"xml_file"} || '';
    my $sql_file = $OPTIONS{"sql_file"} || '';
    
    $xml_file =~ /.*(atlas_build_.*)/;
    $xml_file = $1;
    $sql_file =~ /.*(atlas_build_.*)/;
    $sql_file = $1;
    my $fasta_file;
    my $Data_files = get_build_path();
    $fasta_file =`ls $Data_files/APD_*_all.fasta`;
    chomp $fasta_file;

    if( -e $fasta_file){
      `ln -s $fasta_file $build_path/$dir_path/$build_date`;
      $fasta_file =~ /.*\/(.*)/;
      $fasta_file = $1;
    }
    if( -e "$Data_files/APD_ensembl_hits.tsv"){
      `ln -s $Data_files/APD_ensembl_hits.tsv $build_path/$dir_path/$build_date`;
    }
    if( -e "$Data_files/APD_ensembl_hits.tsv"){
      `ln -s $Data_files/coordinate_mapping.txt $build_path/$dir_path/$build_date`;
    }

  my $str =<<EOM;
   <tr><td><span class="sub_header">CURRENT BUILD: $organism $spec $build_date</span></td></tr>
   <tr><td background="/images/bg_Nav.gif" height="1"><img src="/images/clear.gif" width="1" height="1" border="0"></td></tr>
   <tr><td height="5"><img src="/images/clear.gif" width="1" height="1" border="0"></td></tr>


   <tr><td>
   <P>
   <img src="/images/yellow-arrow.gif" border="0">
   <img src="/images/clear.gif" width="1" height="1" border="0">
   Peptide sequences in FASTA format: 
   <a href="/docs/format_help.php#fasta"><IMG SRC="/images/description.jpg" BORDER=0></A>
   <BR>
   <A HREF="$build_date/$fasta_file"
   class="text_link">
   P >= 0.9
   </A> 
   </nobr>
   </P>

   <P>
   <img src="/images/yellow-arrow.gif" border="0"><img src="/images/clear.gif" width="1" height="1" border="0">
   Peptide CDS coordinates: 
   <a href="/docs/format_help.php#cds"><IMG SRC="/images/description.jpg" BORDER=0></A>
   <BR>
   <A HREF="$build_date/APD_ensembl_hits.tsv" 
   class="text_link">
   P >= 0.9
   </A> 
   </nobr>
   </P>
   
   <P>
   <img src="/images/yellow-arrow.gif" border="0"><img src="/images/clear.gif" width="1" height="1" border="0">
   Database tables exported as an XML file:
   <a href="/docs/format_help.php#cds"><IMG SRC="/images/description.jpg" BORDER=0></A>
   <BR>
   <A HREF="$build_date/$xml_file" class="text_link">P >= 0.9</A>
   </nobr>
   </P>
   <P>
   <img src="/images/yellow-arrow.gif" border="0"><img src="/images/clear.gif" width="1" height="1" border="0">
   Database tables exported as mysql dump file:
   <a href="/docs/format_help.php#cds"><IMG SRC="/images/description.jpg" BORDER=0></A>
   <BR>
   <A HREF="$build_date/$sql_file" class="text_link">P >= 0.9</A>
   </nobr>
   </P>
   <P>
   <img src="/images/yellow-arrow.gif" border="0">
   <img src="/images/clear.gif" width="1" height="1" border="0">
   Peptide CDS and chromosomal coordinates: 
   <a href="/docs/format_help.php#chrom"><IMG SRC="/images/description.jpg" BORDER=0></A>
   <BR>
   <A HREF="$build_date/coordinate_mapping.txt"
   class="text_link">
   P >= 0.9
   </A> 
   </nobr>
   </P>
   <tr><td height="30"><img src="/images/clear.gif" width="1" height="1" border="0"></td></tr>
   </td></tr>
   
EOM
  
    my $newpage = "$build_path/$dir_path/index$build_date.php";
    
    open (OUT , ">$newpage");
    if( -e "$build_path/$dir_path/index.php"){
       open(IN, "<$build_path/$dir_path/index.php") or die "cannot open index file";
       foreach (<IN>){
         if(/>CURRENT BUILD/){
           print OUT "$str\n"; 
           s/CURRENT BUILD/OLD BUILDS/;
           print OUT $_;
         }
         else {
          print OUT $_;
         }
       }
    }
    else{
      my $file = "$build_path/streptococcus/index.php";
      open(IN, "<$file") or die "cannot open index file";
      LOOP:foreach (<IN>){
        
         if(/>CURRENT BUILD/){
           print OUT "$str\n";
           last LOOP;
         }
         elsif(/Streptococcus/){
           s/Streptococcus/$organism/;
           print OUT $_;
         }
         else {
          print OUT $_;
         }
       }
      print OUT "<tr><td>\n<?php\n  include(\"\$DOCUMENT_ROOT/includes/footer.inc.php\");\n?>\n";  
    }
   close IN;
   close OUT;
  
   if( -e "$build_path/$dir_path/index.php"){ 
     `mv $build_path/$dir_path/index.php $build_path/$dir_path/index.php-$build_date`;
   }
   `mv $build_path/$dir_path/index$build_date.php $build_path/$dir_path/index.php`; 
      
}


###############################################################
# Organism info
###############################################################
  
sub get_organism_info{

  my @organism_info  = $sbeams->selectSeveralColumns( <<"  ORG" );
  SELECT organism_name, abbreviation, organism_id, full_name
  FROM $TB_ORGANISM
  ORG
  return  @organism_info ;
}

###############################################################
# General build info, date, name, organism, specialty, default
###############################################################

sub get_build_overview {

  my $build_id = shift;
  my @build_info;
  
  # Get a list of accessible project_ids
  my @project_ids = $sbeams->getAccessibleProjects();
  my $project_ids = join( ",", @project_ids ) || '0';

  my $build_info = $sbeams->selectrow_hashref( <<"  BUILD" );
  SELECT atlas_build_name, probability_threshold, atlas_build_description, 
  build_date, set_name, organism_id
  FROM $TBAT_ATLAS_BUILD AB JOIN $TBAT_BIOSEQUENCE_SET BS 
  ON AB.biosequence_set_id = BS.biosequence_set_id
  WHERE atlas_build_id = $build_id 
  AND AB.record_status <> 'D'
  BUILD

  my $multi_pep_count = $sbeams->selectrow_hashref( <<"  MPEP" );
  SELECT COUNT(*) cnt, SUM(n_observations) obs
  FROM $TBAT_PEPTIDE_INSTANCE  
  WHERE atlas_build_id = $build_id 
  AND n_observations > 1 
  MPEP

  my $smpl_count = $sbeams->selectrow_hashref( <<"  SMPL" );
  SELECT COUNT(*) cnt FROM $TBAT_ATLAS_BUILD_SAMPLE 
  WHERE atlas_build_id = $build_id
  SMPL
  push (@build_info , $multi_pep_count->{cnt});
  push (@build_info, $multi_pep_count->{obs});
  push (@build_info, $smpl_count->{cnt});
  push (@build_info, $build_info->{build_date});
  push (@build_info, $build_info->{probability_threshold});
  push (@build_info, $build_info->{set_name});
  push (@build_info, $build_info->{organism_id});
  return @build_info;
}


sub get_build_path {
  my $build_id = $OPTIONS{'atlas_build_id'} or die
        " need atlas_build_id ($!)";
  my $path = $atlas->getAtlasBuildDirectory( atlas_build_id => $build_id );
  print "$path\n";
  return $path;
}
