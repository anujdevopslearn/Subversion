<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<HTML>
<?php
  /* $Id$ */
  $TITLE="SBEAMS Documentation";

  include("includes/style.inc.php");

  include("includes/header.inc.php");

  include("includes/navbar.inc.php");
?>



<!-- --------------------------- Main Page Content ------------------------ -->

<table border=0 width="100%" bgcolor="#ffffff" cellpadding=10>
<tr><td align="top">



<H2>SBEAMS Documentation</H2>

<P>The Systems Biology Experiment Analysis System (SBEAMS) provides a
customizable software and database framework to meet the needs of
modern systems biology research.  Documenation for this system is
provided below first for the user and then for a developer.</P>


<BR>
<hr noshade size="3" width="35%" align="left">
<H3>User Documentation</H3>

<UL>
<LI><A HREF="Microarray/HOWTO_SubmitArrayRequest.php">Instructions for Submitting a Microarray Request</A>
<LI><A HREF="SBEAMSOutline.php">General Outline of the State of SBEAMS</A>
<LI><A HREF="/projects/sbeams/">Longer Concept Overview of SBEAMS</A>
<LI><A HREF="SecurityLayout.php">Description of Security Layout</A>
</UL>


<BR>
<BR>
<hr noshade size="3" width="35%" align="left">
<H3>Developer Documentation</H3>

<UL>
<LI><A HREF="DevInstance.php">Notes on using an SBEAMS "dev instance"</A>
<LI><A HREF="Proteomics/ProcPipeline.doc">General Proposal and Documenation for the Proteomics Data Pipeline (Word .doc)</A>
<P>
<LI><A HREF="Core/Core_Schema.gif">Core database schema</A>
<LI><A HREF="Microarray/Microarray_Schema.gif">Microarray database schema</A>
<LI><A HREF="PhenoArray/PhenoArray_Schema.gif">PhenoArray database schema</A>
<LI><A HREF="Proteomics/Proteomics_Schema.gif">Proteomics database schema</A>
<LI><A HREF="SNP/SNP_Schema.gif">SNP database schema</A>
</UL>



<BR>
<BR>
<hr noshade size="3" width="35%" align="left">
<H3>API Documentation</H3>

<UL>
<LI><A HREF="/dev2/sbeams/doc/POD/SBEAMS/Connection.html">SBEAMS::Connection</A>
<LI><A HREF="/dev2/sbeams/doc/POD/SBEAMS/Connection/Authenticator.html">SBEAMS::Connection::Authenticator</A>
<LI><A HREF="/dev2/sbeams/doc/POD/SBEAMS/Connection/DBConnector.html">SBEAMS::Connection::DBConnector</A>
<LI><A HREF="/dev2/sbeams/doc/POD/SBEAMS/Connection/DBInterface.html">SBEAMS::Connection::DBInterface</A>
<LI><A HREF="/dev2/sbeams/doc/POD/SBEAMS/Connection/ErrorHandler.html">SBEAMS::Connection::ErrorHandler</A>
<LI><A HREF="/dev2/sbeams/doc/POD/SBEAMS/Connection/HTMLPrinter.html">SBEAMS::Connection::HTMLPrinter</A>
<LI><A HREF="/dev2/sbeams/doc/POD/SBEAMS/Connection/Permissions.html">SBEAMS::Connection::Permissions</A>
<LI><A HREF="/dev2/sbeams/doc/POD/SBEAMS/Connection/PubMedFetcher.html">SBEAMS::Connection::PubMedFetcher</A>
<LI><A HREF="/dev2/sbeams/doc/POD/SBEAMS/Connection/Settings.html">SBEAMS::Connection::Settings</A>
<LI><A HREF="/dev2/sbeams/doc/POD/SBEAMS/Connection/TableInfo.html">SBEAMS::Connection::TableInfo</A>
<LI><A HREF="/dev2/sbeams/doc/POD/SBEAMS/Connection/Tables.html">SBEAMS::Connection::Tables</A>
<LI><A HREF="/dev2/sbeams/doc/POD/SBEAMS/Connection/Utilities.html">SBEAMS::Connection::Utilities</A>
</UL>



<BR>
<BR>
<hr noshade size="3" width="35%" align="left">
<H3>Miscellaneous Documentation</H3>

<UL>
<LI><A HREF="Microarray/keymapfiles.notes">Misc notes about .key and .map files</A>
</UL>








<BR>
<BR>
<BR>



<?php
  include("includes/footer.inc.php");
?>

