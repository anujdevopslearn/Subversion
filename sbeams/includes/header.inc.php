<?php
  /* $Id$ */
  $SBEAMS="/dev2/sbeams";
?>

<!-- Begin the whole-page table -->
<a name="TOP"></a>
<table border=0 width="680" cellspacing=0 cellpadding=3>


<!-- -------------- Top Line Header: logo and big title ------------------- -->
<tr>
<td bgcolor="#cdd1e7">
<a href="http://www.systemsbiology.org/"><img height=60 width=60 border=0 alt="ISB Main" src="<?php echo $SBEAMS ?>/images/ISBlogo60t.gif"></a><a href="http://db.systemsbiology.net/"><img height=60 width=60 border=0 alt="ISB DB" src="<?php echo $SBEAMS ?>/images/ISBDBt.gif"></a>
</td>

<?php
  if ($TITLE) {
?>
<td background="<?php echo $SBEAMS ?>/images/plaintop.jpg">
<center><H1><?php echo $TITLE ?></H1></center>
&nbsp;&nbsp;&nbsp;&nbsp;[&nbsp;<a href="/projects/">PROJECTS</a>&nbsp;]
&nbsp;&nbsp;&nbsp;&nbsp;[&nbsp;<a href="<?php echo $SBEAMS ?>/">SBEAMS</a>&nbsp;]
</td></tr>
<?php
  }
?>
