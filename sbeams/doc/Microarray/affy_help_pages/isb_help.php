<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<HTML>
<?php
  /* $Id$ */
  $TITLE="Affymetrix Facility Documentation";

  include("includes/transformation_info.inc.php");
  include("includes/style.inc.php");

  include("includes/header.inc.php");

  include("includes/navbar.inc.php");
 $help_name = $_GET[help_page];

error_reporting(0);
if ($help_name){
	
	/* USE THIS SECTION TO HAVE XALAN TRANSFORM THE XML PAGES, NEED TO SETUP THE JSP FOUND ON 
	   http://xml.apache.org/xalan-j/
	
	$url = "$TOMCAT_SERVER?PMA=foo&XML=$XML_URL/$help_name&XSL=$XSLT_URL"; 
	
	$array = file ("$url");
	if (! $array){
		print_error_report($url);
		exit;
	}
	
	while (list(,$line) = each($array)) {
		$all_help_data .= $line;
	}
	*/
	
	
	$clean_name = escapeshellarg($help_name);
	$all_help_data = `xsltproc $XSLT_PATH $XML_PATH/$clean_name`;
	
	
}
function print_error_report ($url){
	echo "<h1>Opps... There was an error trying to make the requested page</h1>";
	echo "Follow this url to see the error <a href='$url'>View Error Report</a>";
	exit;
}

echo $all_help_data;

?>




<?php
  include("$DOCUMENT_ROOT/includes/footer.inc.php");
?>

