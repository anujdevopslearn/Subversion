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
for consistency:

<PRE>
CD90 02-002A 1 b a 100.jpg
 |      |  | | | |  |
 |      |  | | | |  +--------- Total image magnification (20,40,100,200,400,...)
 |      |  | | | |
 |      |  | | | +------------ Parent image designator (-,a-b,c,d,...)
 |      |  | | |
 |      |  | | +-------------- Image index (a,b,c,d,e,...)
 |      |  | |
 |      |  | +---------------- Section index (1,2,3,4,...)
 |      |  |
 |      |  +------------------ Specimen block index (A,B,C,D,....)
 |      |
 |      +--------------------- Case designtor YR-NNN
 |
 +---------------------------- Staining Antibody
</PRE>


<BR>
<BR>
<BR>



<?php
  include("../includes/footer.inc.php");
?>

