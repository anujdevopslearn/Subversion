<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<HTML>
<?php
  /* $Id$ */
  $TITLE="SBEAMS Documentation";

  include("../includes/style.inc.php");

  include("../includes/header.inc.php");

  include("../includes/navbar.inc.php");
?>


<!-- ------------------------ Start Main Page Content ------------------------ -->

<TABLE BORDER=0 WIDTH="500" BGCOLOR="#ffffff" CELLPADDING="5">

<TR>
  <TD ALIGN="top">
   <CENTER><FONT COLOR="red" SIZE="+2"><B>Developer Documentation</B></FONT></CENTER>
  </TD> 
</TR>


<!-- ------------------------ Table of Contents Table ------------------------ -->
<TR>
  <TD>

  <TABLE>

  <TR VALIGN="top">

<!-- ------------------------ Overview Links ------------------------ -->
    <TD>
    <CENTER><B>SBEAMS Overview</B></CENTER><BR>
    <UL>
     <LI><A HREF="SBEAMSOutline.php">General Outline of the State of SBEAMS</A>
     <LI><A HREF="http://www.sbeams.org/project_description.php">Longer Concept Overview of SBEAMS</A>
     <LI><A HREF="SecurityLayout.php">Description of Security Layout</A>
     <LI><A HREF="Proteomics/ProcPipeline.doc">General Proposal and Documentation for the Proteomics Data Pipeline (Word .doc)</A>
     <LI><A HREF="Microarray/keymapfiles.notes">Misc notes about .key and .map files</A>
     <LI><A HREF="misc/Sbeams_directory_layout.txt">Over View of Sbeams Directory Structure</A>
     <P>
     <LI><A HREF="/mantis/">Mantis SBEAMS bugs database</A>
    </UL>
    </TD>
  </TR>


<!-- ------------------------ Recipe Links ------------------------ -->
  <TR VALIGN="top">
    <TD>
    <CENTER><B>Recipes</B></CENTER><BR>
    <UL>
     <LI><A HREF="Microarray/HOWTO_SubmitArrayRequest.php">Instructions for Submitting a Microarray Request</A>
     <LI><A HREF="DevInstance.php">Notes on using an SBEAMS "dev instance"</A>
    </UL>
    </TD>
  </TR>

  <TR>
    <TD>
     <BR>
    </TD>
  </TR>


<!-- ------------------------ API Links ------------------------ -->
  <TR VALIGN="top">
   <TD>
    <CENTER><B>API</B></CENTER><BR>
    <UL>
     <LI><A HREF="POD/SBEAMS/Client.html">SBEAMS::Client</A>
     <P>
     <LI><A HREF="POD/SBEAMS/Connection.html">SBEAMS::Connection</A>
     <LI><A HREF="POD/SBEAMS/Connection/Authenticator.html">SBEAMS::Connection::Authenticator</A>
     <LI><A HREF="POD/SBEAMS/Connection/DBConnector.html">SBEAMS::Connection::DBConnector</A>
     <LI><A HREF="POD/SBEAMS/Connection/DBInterface.html">SBEAMS::Connection::DBInterface</A>
     <LI><A HREF="POD/SBEAMS/Connection/ErrorHandler.html">SBEAMS::Connection::ErrorHandler</A>
     <LI><A HREF="POD/SBEAMS/Connection/HTMLPrinter.html">SBEAMS::Connection::HTMLPrinter</A>
     <LI><A HREF="POD/SBEAMS/Connection/Permissions.html">SBEAMS::Connection::Permissions</A>
     <LI><A HREF="POD/SBEAMS/Connection/PubMedFetcher.html">SBEAMS::Connection::PubMedFetcher</A>
     <LI><A HREF="POD/SBEAMS/Connection/Settings.html">SBEAMS::Connection::Settings</A>
     <LI><A HREF="POD/SBEAMS/Connection/TableInfo.html">SBEAMS::Connection::TableInfo</A>
     <LI><A HREF="POD/SBEAMS/Connection/Tables.html">SBEAMS::Connection::Tables</A>
     <LI><A HREF="POD/SBEAMS/Connection/Utilities.html">SBEAMS::Connection::Utilities</A>
    </UL>
    </TD>
  </TR>

<!-- ------------------------ Schema Links ------------------------ -->
  <TR VALIGN="top">
    <TD>
    <CENTER><B>Schema</B></CENTER><BR>
    <UL>
     <LI><A HREF="Core/Core_Schema.gif">SBEAMS Core schema</A>
     <P>
     <LI><A HREF="Cytometry/Cytometry.gif">Cytometry module schema</A>
     <P>
     <LI><A HREF="Immunostain/Immunostain.gif">Immunostain module schema</A>
     <P>
     <LI><A HREF="PeptideAtlas/PeptideAtlas.gif">PeptideAtlas module schema</A>
     <P>
     <LI><A HREF="PhenoArray/PhenoArray_Schema.gif">PhenoArray module schema</A>
     <P>
     <LI><A HREF="Microarray/Microarray_Schema.gif">Microarray module schema</A>
     <LI><A HREF="Microarray/Microarray_Affy_Schema.gif">Microarray module (Affymetrix component) schema</A>
     <P>
     <LI><A HREF="ProteinStructure/ProteinStructure.gif">ProteinStructure module schema</A>
     <P>
     <LI><A HREF="Proteomics/Proteomics_main.gif">Proteomics module schema - main component</A>
     <LI><A HREF="Proteomics/Proteomics_ProteinProphet.gif">Proteomics module schema - ProteinProphet component</A>
     <LI><A HREF="Proteomics/Proteomics_APD.gif">Proteomics module schema - APD component</A>
     <LI><A HREF="Proteomics/Proteomics_request.gif">Proteomics module schema - request mgmt component</A>
     <P>
     <LI><A HREF="SNP/SNP_Schema.gif">SNP module schema</A>
    </UL>
    </TD>

  </TR>
  </TABLE>  

  </TD>
</TR>


</TABLE>


<!-- ------------------------ End Main Page Content ------------------------ -->
<?php
  include("../includes/footer.inc.php");
?>


