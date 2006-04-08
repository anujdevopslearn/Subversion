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
	<style type="text/css">	<!--

	//
	body  	{font-family: Helvetica, Arial, sans-serif; font-size: <?php echo $FONT_SIZE ?>pt; color:#33333; line-height:1.8}


	th    	{font-family: Helvetica, Arial, sans-serif; font-size: <?php echo $FONT_SIZE ?>pt; font-weight: bold;}
	td    	{font-family: Helvetica, Arial, sans-serif; font-size: <?php echo $FONT_SIZE ?>pt; color:#333333;}
	form  	{font-family: Helvetica, Arial, sans-serif; font-size: <?php echo $FONT_SIZE ?>pt}
	pre   	{font-family: Courier New, Courier; font-size: <?php echo $FONT_SIZE_SM ?>pt;}
	h1   	{font-family: Helvetica, Arial, Verdana, sans-serif; font-size: <?php echo $FONT_SIZE_HG ?>px; font-weight:bold; color:#0E207F;line-height:20px;}
	h2   	{font-family: Helvetica, Arial, sans-serif; font-size: <?php echo $FONT_SIZE_LG ?>pt; font-weight: bold}
	h3   	{font-family: Helvetica, Arial, sans-serif; font-size: <?php echo $FONT_SIZE_LG ?>pt; color:#FF8700}
	h4   	{font-family: Helvetica, Arial, sans-serif; font-size: <?php echo $FONT_SIZE_LG ?>pt;}
	.text_link  {font-family: Helvetica, Arial, sans-serif; font-size: <?php echo $FONT_SIZE ?>pt; text-decoration:none; color:blue}
	.text_linkstate {font-family: Helvetica, Arial, sans-serif; font-size: <?php echo $FONT_SIZE ?>pt; text-decoration:none; color:#0E207F}
	.text_link:hover   {font-family: Helvetica, Arial, sans-serif; font-size: <?php echo $FONT_SIZE ?>pt; text-decoration:none; color:#DC842F}

	.page_header {font-family: Helvetica, Arial, sans-serif; font-size:18px; font-weight:bold; color:#0E207F; line-height:1.2}
	.sub_header {font-family: Helvetica, Arial, sans-serif; font-size:12px; font-weight:bold; color:#FF8700; line-height:1.8}
	.Nav_link {font-family: Helvetica, Arial, sans-serif; font-size:<?php echo $FONT_SIZE ?>pt; line-height:1.3; color:#DC842F; text-decoration:none;}
	.Nav_link:hover {color: #FFFFFF; text-decoration: none;}
	.Nav_linkstate {cursor:hand; font-family:Helvetica, Arial, sans-serif; font-size:11px; color:#DC842F; text-decoration:none;}
	.nav_Sub {font-family: Helvetica, Arial, sans-serif; font-size:12px; font-weight:bold; color:#ffffff;}
	.highlight {font-size: 12px;font-family: Courier New,courier; font-size: <?php echo $FONT_SIZE_SM ?>pt; background-color: yellow;}
	
	.desc_cell {font-family: Helvetica, Arial, sans-serif; font-size: <?php echo $FONT_SIZE ?>pt; color:#333333; width:300px; vertical-align:text-top;}
	.extra_cell {font-family: Helvetica, Arial, sans-serif; font-size: <?php echo $FONT_SIZE ?>pt; color:#333333; width:300px; padding-left: 20px;}
	.numb_cell{font-family: Helvetica, Arial, sans-serif; font-size: <?php echo $FONT_SIZE ?>pt; color:#333333; vertical-align:text-top;}
	.code_cell{background-color: #dddddd;}
	.para{width:600px; font-weight: bold;}
	//
	-->
</style>
</head>

<!-- Begin body: background white, text black -------------------------------->
<body bgcolor="#FFFFFF" text="#000000" TOPMARGIN=0 LEFTMARGIN=0>

