<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<HTML>
<?php
  /* $Id$ */
  $TITLE="SBEAMS Documentation";

  include("../share/style.inc.php");

  include("../share/header.inc.php");

  include("../share/navbar.inc.php");
?>



<!-- --------------------------- Main Page Content ------------------------ -->

<table border=0 width="100%" bgcolor="#ffffff" cellpadding=10>
<tr><td align="top">



<H2>File Type Descriptions</H2>

<P>Revised: 2003-06-29</P>

<UL>

 <LI><B>File ends in '.plan' or '.planFile':</B><BR>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;This is a text file that is generated from the webinterface ProcessProject.cgi (Data Pipeline Interface).  The contents specify which files to process, as well as the order and parameters to use. <A HREF="PlanFile.php">[Read More...]</A><BR>&nbsp;

 <LI><B>File ends in '.log': </B><BR>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;This is a text file that records information as data is passed through the data processing pipeline.  This information provides technical information on the status of each processing script. <A HREF="LogFile.php">[Read More...]</A><BR>&nbsp;


 <LI><B>File ends in '.map' or '.key':</B><BR>
 &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;This file links a feature (a coordinate on an array) to the biological information of the reporter (the sequence on the feature).  For example, it will link a feature with a gene name and an accession number. <A HREF="MapFile.php">[Read More...]</A><BR>&nbsp;

 <LI><B>File ends in '.csv':</B><BR>
 &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;This is the output from the AnalyzerDG spotfinding program.  This file links a feature (a coordinate on an array) to intensity quantitation information. This a quantitation file and is usually stored in /net/arrays/Quantitation/.<A HREF="CSVFile.php">[Read More...]</A><BR>&nbsp;


 <LI><B>File ends in '.dapple' or '.dapplefmt':</B><BR>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Dapple is a spotfinding program and performs the same basic function as AnalyzerDG.  Its output is the initial input in the data processing pipeline.  '.dapple' files are files that were produced by Dapple.  '.dapplefmt' files are those created by another spotfinding program, but altered to mimic the format of '.dapple' .<A HREF="DappleFile.php">[Read More...]</A><BR>&nbsp;
 

 <LI><B>File ends in '.rep' or '.rep.ps':</B><BR>
 &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;The output of 'preprocess' is a '.rep' file.  Preprocess integrates feature/reporter annotation with feature/reporter quantitation.  This file contains gene names combined with background subtracted/normalized data.<A HREF="RepFile.php">[Read More...]</A><BR>&nbsp;


 <LI><B>File ends in '.merge':</B><BR>
 &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;This file places the data from replicate spots (from one or more arrays) onto a single line.  This is created by the script 'mergeReps'.<A HREF="MergeFile.php">[Read More...]</A><BR>&nbsp;


 <LI><B>File ends in '.ft':</B><BR>
 &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'ft' stands for "file table," and is used by mergeReps to determine the relatively direction of each slide being merged (i.e. Cy3/Cy5 or Cy5/Cy3).<A HREF="FTFile.php">[Read More...]</A><BR>&nbsp;


 <LI><B>File ends in '.model':</B><BR>
 &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;A 'model' file is the output of VERA-- one of the two programs developed to determine differentially expressed genes.  This file contains the parameters used to describe the error model that best fits the data.  This file is used by SAM to identify differentially expressed genes.<A HREF="ModelFile.php">[Read More...]</A><BR>&nbsp;


 <LI><B>File ends in '.sig':</B><BR>
 &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;A 'sig' file is the output of SAM-- the second of two programs developed to determine differentially expressed genes.  This file contains the same information as a '.merge' file, but also has extra information appended.  The most important of these data is the 'lambda' value, the significance of the change in expression.<A HREF="SigFile.php">[Read More...]</A><BR>&nbsp;


 <LI><B>File ends in '.clone':</B><BR>
 &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Clone files are either '.merge' files or '.sig' files with extra annotation from the '.map' files appended to it.  The pipeline does not use much of the information from the '.map' file, and this extra information is not passed through the pipeline. <A HREF="CloneFile.php">[Read More...]</A><BR>&nbsp;


 <LI><B>File is named 'matrix_output':</B><BR>
 &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Matrix files are summaries of multiple '.sig files'.  These files contain gene names, average log ratio, and lambda for each condition in a matrix format. <A HREF="MatrixFile.php">[Read More...]</A><BR>&nbsp;

</UL>


<?php
  include("../share/footer.inc.php");
?>

