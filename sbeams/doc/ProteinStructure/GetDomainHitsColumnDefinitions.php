<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<HTML>
<?php
  /* $Id$ */
  $TITLE="GetDomainHits Column Definitions";

  include("../share/style.inc.php");

  include("../share/header.inc.php");

  include("../share/navbar.inc.php");
?>



<!-- --------------------------- Main Page Content ------------------------ -->

<table border=0 width="100%" bgcolor="#ffffff" cellpadding=10>
<tr><td align="top">


<!-- BEGIN_CONTENT -->

<H2>Column Definitions for GetDomainHits query resultset</H2>

<P>Revised: 2004-03-23</P>

<P>Each row of the table corresponds to a single hit to an annotation source for a given protein. 
If a protein has multiple domains or multiple weak hits (or redundant strong hits) for a given 
domain that protein will have multiple rows in the table. Each column is described below, columns 
are occupied only when applicable.</P>

<TABLE>
<TR>
<TH ALIGN="LEFT" BGCOLOR="#0000A0"><FONT COLOR="white"><BOLD>Column Name</BOLD></FONT></TH>
<TH ALIGN="LEFT" BGCOLOR="#0000A0"><FONT COLOR="white"><BOLD>Definition</BOLD></FONT></TH>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">Biosequence Set Name</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">name of organism or sequence set</TD></TR>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">Biosequence Name</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">gene/sequence name</TD></TR>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">Accession</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">gene/sequence accession</TD></TR>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">Gene Symbol</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0"></TD></TR>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">Full gene name</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0"></TD></TR>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">Protein EC number</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">EC number corresponding to</TD></TR>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">TMR Class</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">Results of TMHMM. 0 == soluble protein, TM == transmembrane protein</TD></TR>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">Number of TMRs</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">number of TM regions</TD></TR>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">pI</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">isoelectric point</TD></TR>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">Match Source</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">program used to derive/detect match. “Pfam” indicates that HMMER was used to find the match to Pfam. “pdbblast” indicates that PSI-BLAST was used to detect a match to a given PDB sequence. “mamSum” indicates that the match is the result of a Rosetta prediction.</TD></TR>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">Domain Index</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">If protein is a multi-domain protein, as detected by ginzu, domains are labeled as domain 0-domainN.</TD></TR>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">Overall-P</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">Probability that one of the top five rosetta predictions is the correct fold</TD></TR>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">BH</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">Best Hit, “Y” if this is the Rosetta model for this protein with the highest Z-score to match to the PDB.</TD></TR>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">Cluster</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">Rosetta model number. Cluster00 is the center of the largest cluster and thus the top Rosetta model prior to considering the Z-score of each models best match to the PDB.</TD></TR>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">Query start (stop)</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">Start and stop of hit with reference to the query protein(domain)</TD></TR>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">Query length</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">length of protein in case of single protein, length of domain if query is a single domain from Ginzu.</TD></TR>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">Match start(end)</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">start and stop of match with reference to domain matched in external database (eg. PDB, Pfam, etc.)</TD></TR>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">Match length</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0"></TD></TR>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">Match Type</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">possible types are “pdbblast”, “pfam” and “PDB”</TD></TR>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">Match name</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">ID in external database (PDB id, Pfam domain)</TD></TR>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">Domain EC numbers</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">EC number if hit/match has a corresponding EC number.</TD></TR>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">Prob</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">Probability of individual Rosetta prediction being correct.</TD></TR>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">E value</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">confidence of corresponding method</TD></TR>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">Score</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">confidence of corresponding method</TD></TR>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">Z-score</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">strength of match between Rosetta predicted structure and the PDB, expressed as a Z-score.</TD></TR>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">Second Reference</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">CATH id of matched PDB.</TD></TR>

<TR><TD ALIGN="LEFT" NOWRAP BGCOLOR="#E0E0E0">Match Annotation</TD>
    <TD ALIGN="LEFT"        BGCOLOR="#E0E0E0">Additional annotation information associated with this match in the match source</TD></TR>

</TABLE>



<!-- END_CONTENT -->

<?php
  include("../share/footer.inc.php");
?>

