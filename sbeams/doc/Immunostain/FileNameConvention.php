<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<HTML>
<?php
  /* $Id$ */
  $TITLE="Immunostain Filename Conventions";

  include("../includes/style.inc.php");

  include("../includes/header.inc.php");

  include("../includes/navbar.inc.php");
?>



<!-- --------------------------- Main Page Content ------------------------ -->

<table border=0 width="100%" bgcolor="#ffffff" cellpadding=10>
<tr><td align="top">



<H2>Immunostain Image Filename Convention</H2>

Immunostain image files will be named according to the following convention
for consistency, with 6 items separated by spaces:

<PRE>
CD90 02-002A 1  HP a 100.jpg
 |      |  | |  |  |  |
 |      |  | |  |  |  +--------- <font color=red>Total image magnification</font> (20,40,100,200,400,...)
 |      |  | |  |  |
 |      |  | |  |  +------------ <font color=red>Image Label</font> (lowercase letter for the image, followed be a second lower case image label
 |      |  | |  |                of the parent/lower magnification image or a hyphen if there is no parent image  -,a,b,c,d,...)
 |      |  | |  |
 |      |  | |  +----------------<font color=red>Species Organ designator</font> (human H, mouse M, bladder B, prostate P)
 |      |  | |
 |      |  | +---------------- <font color=red>Section index</font> (1,2,3,4,...)
 |      |  |
 |      |  +------------------ <font color=red>Specimen block index</font> (A,B,C,D,... or A1,A2,A3,...)
 |      |
 |      |
 |      +--------------------- <font color=red>Case designtor</font> (YR-NNN)
 |
 +---------------------------- <font color=red>Staining Antibody</font> (no space after CD)
</PRE>

<P>The <font color=red>Image index</font> is just a sequential
index of letter for the image.  After
z, continue with aa,ab,ac if that ever occurs.</P>

<P>The <font color=red>Parent image designator</font> is the
<font color=red>Image index</font> of the image of next
lower magnification that contains the current image.
Use a - if there is no suitable parent.</P>

<BR>
<BR>
<BR>



<?php
  include("../includes/footer.inc.php");
?>

