<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<HTML>
<?php
  /* $Id$ */
  $TITLE="Cytometry Sample Name Convention";

  include("../includes/style.inc.php");

  include("../includes/header.inc.php");

  include("../includes/navbar.inc.php");
?>



<!-- --------------------------- Main Page Content ------------------------ -->

<table border=0 width="100%" bgcolor="#ffffff" cellpadding=10>
<tr><td align="top">



<H2>Cytometry Sample Name Convention</H2>

Immunostain image files will be named according to the following convention
for consistency, with 6 items separated by spaces:

<Pre>
02-002p_M_CD44_F_Hoechst 
|     | |  |   |    |     
|     | |  |   |    +-- <font color=red>Subsequent Sort Entity</font> 
|     | |  |   |        
|     | |  |   +----- <font color=red>Subsequent Sort Type </font> (M = Magnetic Sort, F = Flow Sort)
|     | |  | 
|     | |  +------------- <font color=red>First Sort Entity </font>
|     | |
|     | +----------------- <font color=red>First Sort Type </font> (M = Magnetic Sort, F = Flow Sort)
|     |   
|     +--------------------- <font color=red>Tissue Type </font> (p = prostate, b = bladder)
|
+---------------------------- <font color=red>Specimen Name as listed in the Immunostain database</font> 

</Pre>

<P> <font color=red>Sort Type</font> and<font color =red> Sort Entity</font> can be repeated as a unit n-times, depending on the number of sorts.</P>

<BR>
<BR>
<BR>



<?php
  include("../includes/footer.inc.php");
?>

