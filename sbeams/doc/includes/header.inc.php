<?php
  /* $Id$ */
?>

<!-- Begin the whole-page table -->
<a name="TOP"></a>
<table border=0 width="680" cellspacing=0 cellpadding=3>


<!-- -------------- Top Line Header: logo and big title ------------------- -->
<tr>
<td bgcolor="#1d3887">
<a href="http://www.systemsbiology.org/"><img height=60 width=60 border=0 alt="ISB Main" src="/images/MiscLogos/ISBnewLogo60t3.gif"></a><a href="http://db.systemsbiology.net/"><img height=60 width=60 border=0 alt="ISB DB" src="/images/MiscLogos/dbLogo60t3.gif"></a>
<!-- <a href="http://www.systemsbiology.org/"><img height=60 width=120 border=0 alt="ISB Main" src="/images/ISB_logo_blue_tiny120.png"></a> -->
</td>

<?php
  if ($TITLE) {
?>
<td background="/images/spacer_dkblue.gif">
<H1><font color="white"><?php echo $TITLE ?></H1>
&nbsp;&nbsp;&nbsp;&nbsp;[&nbsp;<a href="/projects/"><font color="orange">PROJECTS</font></a>&nbsp;]
&nbsp;&nbsp;&nbsp;&nbsp;[&nbsp;<a href="/sbeams/"><font color="orange">SBEAMS</font></a>&nbsp;]
</font></td></tr>
<?php
  }
?>
