<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<HTML>
<?php
  /* $Id$ */
  $TITLE="SBEAMS Home Page";

  include("$DOCUMENT_ROOT/includes/style.inc.php");

  include("$DOCUMENT_ROOT/includes/header.inc.php");

  include("$DOCUMENT_ROOT/includes/navbar.inc.php");
?>



<!-- --------------------------- Main Page Content ------------------------ -->

<table border=0 width="100%" bgcolor="#ffffff" cellpadding=10>
<tr><td align="top">



<hr noshade size="3" width="35%" align="left">
<H3>Welcome to the Systems Biology Experiment Analysis System (SBEAMS)</H3>

The Systems Biology Experiment Analysis System provides a customizable
framework to meet the needs of modern systems biology research.  It is
composed of a unified state-of-the-art relational database management
system (RDBMS) back end, a collection tools to store, manage, and query
experiment information and results in the RDBMS, a web front end for
querying the database and providing integrated access to remote data
sources, and an interface to existing programs for clustering and other
analysis.<P>

You are required to enter your username and password to use the system.
SBEAMS normally uses UNIX authentication, so please use your UNIX username
and password.  Note that not everyone has an account by default.  If your
account has not yet been enabled please contact your local SBEAMS
administrators.


<BR>
<BR>

<UL>
<LI><A HREF="cgi/main.cgi">Login to SBEAMS</A>
</UL>

<BR>
<BR>
<BR>



<?php
  include("$DOCUMENT_ROOT/includes/footer.inc.php");
?>

