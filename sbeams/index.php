<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<HTML>

<HEAD>
  <TITLE>SBEAMS Home Page</TITLE>

<?php
  include("$DOCUMENT_ROOT/includes/style.inc.php");
?>


<?php
  include("$DOCUMENT_ROOT/includes/header.inc.php");
?>


<td align="center"><H1>SBEAMS Home Page</H1></td>
</tr>


<?php
  include("$DOCUMENT_ROOT/includes/navbar.inc.php");
?>




<!-- --------------------------- Main Page Content ------------------------ -->

<table border=0 width="100%" bgcolor="#ffffff" cellpadding=10>
<tr><td>



<hr noshade size="3" width="35%" align="left">
<H3>Welcome to the Systems Biology Experiment Analysis System (SBEAMS)</H3>

The Systems Biology Experiment Analysis System provides a customizable
framework to meet the
needs of modern systems biology research.  It is composed of a unified
state-of-the-art relational database management system (RDBMS)
back end, a collection
tools to store, manage, and query experiment information and results
in the RDBMS, a web front end for querying the database and providing integrated
access to remote data sources, and an interface to existing programs for
clustering and other analysis.<P>

A username and password is required to enter the system and begin using it.
SBEAMS normally uses unix authentication, so please use your unix username and
password.  Note that not everyone has an account by default.  If your
account has not yet been enabled please contact <B>edeutsch</B> 
or <B>bmarzolf</B>.


<BR>
<BR>

<UL>
<LI><A HREF="cgi/main.cgi">Login to SBEAMS</A>
<P>
<LI><A HREF="cgi/MicroArrayMain.cgi">Login to SBEAMS - Microarray</A>
<LI><A HREF="http://www.systemsbiology.org/forum/microarrays">Microarray Discussion Forum</A>
<LI><A HREF="doc/array_request_instructions.txt">Instructions for Submitting a Microarray Request</A>
<P>
<LI><A HREF="cgi/Proteomics/main.cgi">Login to SBEAMS - Proteomics</A>
<P>
<LI><A HREF="cgi/Inkjet/main.cgi">Login to SBEAMS - Inkjet</A>
</UL>

<BR>
<BR>
<BR>



<?php
  include("$DOCUMENT_ROOT/includes/footer.inc.php");
?>

