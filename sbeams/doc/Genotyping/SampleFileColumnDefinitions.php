<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<HTML>
<?php
  /* $Id$ */
  $TITLE="Sample File Column Definitions";

  include("../../includes/style.inc.php");

  include("../../includes/header.inc.php");

  include("../../includes/navbar.inc.php");
?>



<!-- --------------------------- Main Page Content ------------------------ -->

<table border=0 width="100%" bgcolor="#ffffff" cellpadding=10>
<tr><td align="top">


<!-- BEGIN_CONTENT -->

<H2>Column Definitions for Genotyping Sample File</H2>

<P>Revised: 2004-05-03</P>

<P>Each row of the file corresponds to a single sample. The file should be in tab-delimited form.  If the file is created as an Excel file, just save as in TSV format for uploading.  <B>All fields are required!</B>  Please take note of the assumed units (e.g. ng/&#181;l), but do not include the units in your file.</P>

<TABLE>
<TR>
<TH ALIGN="LEFT" BGCOLOR="#0000A0"><FONT COLOR="white"><BOLD>Column Name</BOLD></FONT></TH>
<TH ALIGN="LEFT" BGCOLOR="#0000A0"><FONT COLOR="white"><BOLD>Example</BOLD></FONT></TH>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">Plate Code</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">PlateA</TD></TR>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">Well Position</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">A05</TD></TR>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">Sample ID</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">S1</TD></TR>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">Concentration, in ng/&#181;l</TD>
<TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">10</TD></TR>

    <TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">Well Volume, in ng/&#181;l</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">80</TD></TR>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">Stock DNA Solvent</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">TE</TD></TR>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">DNA Dilution Solvent</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">ddH<SUB>2</SUB>O</TD></TR>

</TABLE>

<BR>

<H2>Column Definitions for Genotyping Assay File</H2>

<P>Revised: 2004-05-04</P>

<P>Each row of the file corresponds to a single assay. The file should be in tab-delimited form.  If the file is created as an Excel file, just save as in TSV format for uploading.  <B>Both fields are required!</B></P>

<TABLE>
<TR>
<TH ALIGN="LEFT" BGCOLOR="#0000A0"><FONT COLOR="white"><BOLD>Column Name</BOLD></FONT></TH>
<TH ALIGN="LEFT" BGCOLOR="#0000A0"><FONT COLOR="white"><BOLD>Example</BOLD></FONT></TH>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">Assay Name</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">rs12345</TD></TR>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">Assay Sequence</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">ATATA[C/T]AATAT</TD></TR>

</TABLE>

<!-- END_CONTENT -->

<?php
  include("../../includes/footer.inc.php");
?>

