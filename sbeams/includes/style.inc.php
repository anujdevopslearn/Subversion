<?php
/* $Id$ */

if ($TITLE) {
  echo "<head>";
  echo "<title>$TITLE</title>";
}


$FONT_SIZE=9;
$FONT_SIZE_SM=8;
$FONT_SIZE_LG=12;
$FONT_SIZE_HG=14;

$client=getenv("HTTP_USER_AGENT");

if (eregi("Mozilla\/4.+X11",$client)) {
	$FONT_SIZE=12;
	$FONT_SIZE_SM=11;
        $FONT_SIZE_LG=14;
        $FONT_SIZE_HG=19;
}
?>


<!-- Style sheet definition --------------------------------------------------->
	<style type="text/css">
	//<!--
	body {  font-family: Helvetica, Arial, sans-serif; font-size: <?php echo $FONT_SIZE ?>pt; }
	th   {  font-family: Helvetica, Arial, sans-serif; font-size: <?php echo $FONT_SIZE ?>pt; font-weight: bold;}
	td   {  font-family: Helvetica, Arial, sans-serif; font-size: <?php echo $FONT_SIZE ?>pt;}
	form   {  font-family: Helvetica, Arial, sans-serif; font-size: <?php echo $FONT_SIZE ?>pt}
	pre    {  font-family: Courier New, Courier; font-size: <?php echo $FONT_SIZE_SM ?>pt}
	h1   {  font-family: Helvetica, Arial, sans-serif; font-size: <?php echo $FONT_SIZE_HG ?>pt; font-weight: bold}
	h2   {  font-family: Helvetica, Arial, sans-serif; font-size: <?php echo $FONT_SIZE_LG ?>pt; font-weight: bold}
	h3   {  font-family: Helvetica, Arial, sans-serif; font-size: <?php echo $FONT_SIZE_LG ?>pt; color: red}
	h4   {  font-family: Helvetica, Arial, sans-serif; font-size: <?php echo $FONT_SIZE_LG ?>pt}
	A:link    {  font-family: Helvetica, Arial, sans-serif; font-size: <?php echo $FONT_SIZE ?>pt; text-decoration: none; color: blue}
	A:visited {  font-family: Helvetica, Arial, sans-serif; font-size: <?php echo $FONT_SIZE ?>pt; text-decoration: none; color: darkblue}
	A:hover   {  font-family: Helvetica, Arial, sans-serif; font-size: <?php echo $FONT_SIZE ?>pt; text-decoration: underline; color: red}
	A:link.nav {  font-family: Helvetica, Arial, sans-serif; color: #000000}
	A:visited.nav {  font-family: Helvetica, Arial, sans-serif; color: #000000}
	A:hover.nav {  font-family: Helvetica, Arial, sans-serif; color: red;}
	.nav {  font-family: Helvetica, Arial, sans-serif; color: #000000}
	//-->
	</style>
</head>

<!-- Begin body: background white, text black -------------------------------->
<body bgcolor="#FFFFFF" text="#000000" TOPMARGIN=0 LEFTMARGIN=0>

