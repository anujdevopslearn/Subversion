<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<HTML>
<?php
  /* $Id$ */
  $TITLE="SBEAMS Documentation";

  include("../includes/style.inc.php");

  include("../includes/header.inc.php");

  include("../includes/navbar.inc.php");
?>



<!-- --------------------------- Main Page Content ------------------------ -->

<table border=0 width="100%" bgcolor="#ffffff" cellpadding=10>
<tr><td align="top">



<H2>Submitting a Inkjet Request</H2>

<P>Revised: 2002-07-22</P>

<P>Go to: <A HREF="http://db.systemsbiology.net/">http://db.systemsbiology.net/</A> and click on "[ SBEAMS ]" at the top.<BR>
Or go directly to: <A HREF="http://db.systemsbiology.net/sbeams/">http://db.systemsbiology.net/sbeams/</A>


<P>Log in with your UNIX username and password.  If you don't know
your UNIX password, see the UNIX systems administrators.  If you know
your UNIX password, but the login fails, contact bmarzolf or edeutsch
to resolve access problems.

<P>Go to the SBEAMS - Inkjet module by clicking on
"SBEAMS - Inkjet".</P>

<P>Verify that your Project (including budget, etc.) is up to date:<BR>
<LI>Click "Manage Projects" on left navigation bar
<LI>If you need to adda  new project, click "Add Project"
<LI>To check on your existing project, scroll down to find the list of
projects and click on your Project ID Number
</P>


<P>Create the request for a set of microarrays:<BR>
<LI>Click "Array Requests" on left navigation bar
<LI>Click "Add Array Request" option
<LI>Fill in appropriate fields
<LI>If your Project is not listed, add your Project as described above
<LI>After filling in number of slides and samples per slide, click REFRESH
<LI>Fill in the data table<BR>
  &nbsp;&nbsp;&nbsp;- Use unique names for all different samples, but use
    the same name for
    different tubes containing the same sample (e.g. the control)<BR>
  &nbsp;&nbsp;&nbsp;- When possible, place control (ratio denominator)
    in second column
    at least for the first repeat<BR>
<LI>Click REFRESH
<LI>Verify all information you have typed in to be sure it is all correct
<LI>If you make any adjustments, click REFRESH
<P>
<LI>When everything is correct, click INSERT to submit your request
<P>
<LI>If your submission was claimed to be successful, click on the PRINTABLE
    VIEW.  It would probably be a good idea to print out the submission for
    your own records, although it will remain in the database.

<LI>If you are giving sample tubes to the Array Group for labeling, please
    mark the tubes with the Sample IDs that were assigned by the database.
</P>


<P>To check on the status of your request:
<LI>Click "Project Status" on left navigation bar
<LI>Select your project from the option box and press QUERY
</P>


<BR>
<BR>
<BR>

<P>If you have difficulties with the process, please contact:
<LI>Bruz Marzolf  (bmarzolf@systemsbiology.org)
<LI>Eric Deutsch  (edeutsch@systemsbiology.org)
</P>



<BR>
<BR>
<BR>



<?php
  include("../includes/footer.inc.php");
?>

