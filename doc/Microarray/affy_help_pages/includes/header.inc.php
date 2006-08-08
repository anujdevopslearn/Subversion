<?php
  /* $Id$ */

 include("includes/transformation_info.inc.php");
?>



<!-- Begin the whole-page table -->
<body background="images/bg.gif" bgcolor="#FBFCFE">
<a name="TOP"></a>
<!-- -------------- Top Line Header: logo and big title ------------------- -->
<table border="0" width="680" cellspacing="0" cellpadding="0">
<tr valign="baseline">
<td width="150" bgcolor="#0E207F">
<a href="http://<?=$SERVER?>/" target="_blank"><img src="images/Logo_left.jpg" width="150" height="85" border="0" align="bottom"></a>
</td>
<td width="12"><img src="images/clear.gif" width="12" height="85" border="0"></td>
<?php
  if ($TITLE) {
?>
<td width="518" align="left" valign="bottom">
<span class="page_header"><?php echo $TITLE ?><BR>&nbsp;<BR></span>
</td>
<?php
  }
?>
</tr>
<tr valign="bottom">
<td colspan="3"><img src="images/nav_orange_bar.gif" width="680" height="18" border="0"></td>
</tr>
