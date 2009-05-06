package Site;

use FindBin;
use lib "$FindBin::Bin/../../lib/perl";

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::TabMenu;
use SBEAMS::SolexaTrans;
use SBEAMS::SolexaTrans::Settings;
use strict;

my $sbeams = new SBEAMS::Connection;
my $sbeamsMOD = new SBEAMS::SolexaTrans;

our @ISA    = qw/Exporter/;
our @EXPORT = qw/site_header site_footer
  $BC_UPLOAD_DIR $RESULT_URL $BIOC_URL $CGI_URL $SAMPLE_GROUP_XML
  $ADMIN_EMAIL $R_BINARY $R_LOCAL_BIN $R_LIBS $USE_FRAMES $DEBUG $AFFY_ANNO_PATH
  $JAVA_PATH $JWS_PATH $TOMCAT $KEYSTORE $KEYPASS $KEYALIAS
  $IMG_BASE_DIR
  $SH_HEADER $BATCH_SYSTEM %BATCH_ENV $BATCH_BIN $BATCH_ARG
  $MEV_JWS_BASE_DIR $MEV_JWS_BASE_HTML $SHARED_JAVA_DIR $SHARED_JAVA_HTML/;
 

# Name of xml file holding sample group info
our $SAMPLE_GROUP_XML = 'File_sample_groups.xml';

# Job web accessible URL
our $RESULT_URL = "$CGI_BASE_DIR/SolexaTrans/View_Solexa_files.cgi";
our $CGI_URL = "$CGI_BASE_DIR/SolexaTrans";

# cgi-bin URL and site URL
our $BIOC_URL = "$CGI_BASE_DIR/SolexaTrans/bioconductor";

# Admin e-mail
our $ADMIN_EMAIL = $sbeamsMOD->get_admin_email();

# Location of R binary & R libraries
our $R_BINARY = $sbeamsMOD->get_R_exe_path();
our $R_LOCAL_BIN = $sbeamsMOD->get_local_R_exe_path();
our $R_LIBS = $sbeamsMOD->get_R_lib_path();

our $IMG_BASE_DIR = "$PHYSICAL_BASE_DIR/images/tmp/SolexaTrans";

#Java Path
our $JAVA_PATH = $sbeams->get_java_path();
our $KEYSTORE  = $sbeams->get_jnlp_keystore();
our $KEYPASS   = $sbeams->get_keystore_passwd();
our $KEYALIAS  = $sbeams->get_keystore_alias();
#our $JWS_PATH  = "/local/tomcat/webapps/microarray";
#our $TOMCAT    = "http://db:8080/microarray";

#MEV (Multiple experiment viewer from TIGR) Info
our $MEV_JWS_BASE_DIR  = "$PHYSICAL_BASE_DIR/tmp/SolexaTrans/Make_MEV_jws_files/jws";
our $MEV_JWS_BASE_HTML = "$SERVER_BASE_DIR/$HTML_BASE_DIR/tmp/SolexaTrans/Make_MEV_jws_files/jws";
our $SHARED_JAVA_DIR   = "$PHYSICAL_BASE_DIR/usr/java/share";
our $SHARED_JAVA_HTML  = "$SERVER_BASE_DIR/$HTML_BASE_DIR/usr/java/share/MEV";

# Use frames for showing results
our $USE_FRAMES = 0;

# Turn on debugging output
our $DEBUG = 0;

# Append commands to the top of shell scripts (environment variables, etc.)
our $SH_HEADER = <<'END';
export PATH=$PATH:/usr/sbin:/usr/local/bin
END

# Batch system to use (fork, sge, pbs)
our $BATCH_SYSTEM = $sbeamsMOD->get_batch_system() || 'fork';

# Batch system environment variables
our %BATCH_ENV = ( SGE_ROOT => "/path/to/sge" );

# Batch system binary directory
our $BATCH_BIN = "sudo -u solxabot /usr/local/bin";

# Batch system additional job submission arguments
our $BATCH_ARG = "";

#### Subroutine: site_header
# Print out leading HTML
####
sub site_header {
	my ($title) = @_;

  # Switched to manual FORM declaration, start_form method wouldn't allow
  # needed override of '_tab' parameter.
#  my $form =<<"  END";
#  <FORM ACTION='upload.cgi' enctype="application/x-www-form-urlencoded">
#    <INPUT TYPE=hidden NAME='_tab' VALUE=1>
#		<TABLE BORDER=0>
#    <TR CLASS=grey_bg>
#		      <TD>Start a New Analysis Session</TD>
#	      	<TD><INPUT TYPE="Submit" VALUE="Start Session"></INPUT></TD>
#    </TR></TABLE>
#  </FORM>
#  END

#  my $tabmenu = SBEAMS::Connection::TabMenu->new( cgi => $q, maSkin => 1 );

 	# Preferred way to add tabs.  label is required, helptext optional
# 	$tabmenu->addTab( label    => 'File Groups', 
#                    url      => "upload.cgi?_tab=1",
#                    helptext => 'View Groups of affy Files' );
# 	$tabmenu->addTab( label    => 'Normalized Data', 
#                    url      => "upload.cgi?_tab=2",
#                    helptext => 'View completed normalized analysis runs' );
# 	$tabmenu->addTab( label    => 'Analysis Results', 
#                    url      => "upload.cgi?_tab=3",
#                    helptext => 'View differential expression runs' );

#  print "$form<BR>\n $tabmenu\n";

#  print <<END;
#<div style="text-align: center">
#<a href="upload.cgi?_tab=1">Upload Files</a> |
#<a href="upload.cgi?_tab=2" >View Normalized Data</a> |
#<a href="upload.cgi?_tab=3">View Experimental results</a> |
#</div>
#END


}

#### Subroutine: site_footer
# Print out lagging HTML
####
sub site_footer {

	print <<END;
</body>
</html>
END
}

1;
