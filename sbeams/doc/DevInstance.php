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



<H2>Using Your Dev Instance</H2>

<P>If you wish to do your own development on an SBEAMS module in
parallel with other developers or a production instance, your SBEAMS
Administrator can assign you a "dev instance".  This is a separate
copy of all the SBEAMS code that may or may not point to the
production databases.  You can work on this code without fear of
affecting other users.  When it is debugged and ready, it can be
checked into CVS and rolled out to the production instance.</P>

<P>You will typically been assigned a DevXX area where XX are your
first and last initials or a devN number like dev4 as your SBEAMS
development instance.  Assuming dev4, here's how to use your
instance.</P>


<P>Once the administrator has created the your dev4 instance, you can
check out your code and later resync your code tree with:</P>

<PRE>
setenv CVSROOT /net/db/cvsroot
cd /net/dblocal/www/html/dev4
cvs checkout -P sbeams
</PRE>


<P>If the module you are working on is MODULE, you will find important
files in:</P>

<PRE>
/net/dblocal/www/html/dev4/sbeams/cgi/MODULE/
/net/dblocal/www/html/dev4/sbeams/doc/MODULE/
/net/dblocal/www/html/dev4/sbeams/lib/conf/MODULE/
/net/dblocal/www/html/dev4/sbeams/lib/perl/SBEAMS/MODULE/
/net/dblocal/www/html/dev4/sbeams/lib/scripts/MODULE/
/net/dblocal/www/html/dev4/sbeams/lib/sql/MODULE/
</PRE>


<P>You can access your site from the web at:</P>

<PRE>
<A HREF="http://db.systemsbiology.net/dev4/sbeams/">http://db.systemsbiology.net/dev4/sbeams/</A>
</PRE>

<P>which mirrors the normal production code at:</P>

<PRE>
<A HREF="http://db.systemsbiology.net/sbeams/">http://db.systemsbiology.net/sbeams/</A>
</PRE>


<P>Once you have edited and debugged your code in your dev instance,
check in the new code in the current directory (and below) into CVS
with:</P>

<PRE>
cvs commit filename.ext      (just one file)
cvs commit                   (all files in this and subdirectories)
</PRE>

<P>Add new files with:</P>

<PRE>
cvs add newfilename.ext
cvs commit newfilename.ext
</PRE>

<P>The cgi/MODULE directory contains the actual web programs that the user
executes.</P>

<P>The lib/perl/SBEAMS/MODULE directory contains perl modules that contain:</P>
<PRE>
  HTMLPrinter - Methods that controls the HTML style and interface
  Tables      - Definition of table names
  DBInterface - Methods for the database interface
  Settings    - Module specific settings
  TableInfo   - Some special definitions for how tables can be edited
</PRE>

<P>Other files of relevance:</P>
<UL>

<LI>Table property and column definition tables (table_property and
table_column) define the columns for each table and parameters for
each query.  The contents of these tables are imported from the TSV
files in lib/conf/MODULE using the script
lib/scripts/Core/update_driver_tables.pl

<P>

<LI> Files with the CREATE TABLE statements to create and sometimes
provide an initial population of rows in the database are found in the
lib/sql/MODULE directory.

</UL>


<BR>
<BR>
<BR>



<?php
  include("includes/footer.inc.php");
?>

