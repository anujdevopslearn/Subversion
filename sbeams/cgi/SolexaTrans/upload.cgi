#!/usr/local/bin/perl 


###############################################################################
# Set up all needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;
use Data::Dumper;
use File::Basename;
use Time::Local;
use lib qw (../../lib/perl);
use vars qw ($sbeams $sbeamsMOD $sbeams_solexa_groups $utilities
             $q $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS $DISPLAY_SUMMARY $template);
use DBI;
use CGI::Carp qw(fatalsToBrowser croak);
use POSIX;
use Site;
use UploadPipeline;
use Batch;

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::SolexaTrans;
use SBEAMS::SolexaTrans::Settings;
use SBEAMS::SolexaTrans::Tables;
use SBEAMS::SolexaTrans::SolexaUtilities;
use SBEAMS::SolexaTrans::Solexa_file_groups;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::SolexaTrans;
$utilities = new SBEAMS::SolexaTrans::SolexaUtilities;
$sbeams_solexa_groups = new SBEAMS::SolexaTrans::Solexa_file_groups;

$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

$sbeamsMOD->setSBEAMS($sbeams);
$utilities->setSBEAMS($sbeams);
$sbeams_solexa_groups->setSBEAMS($sbeams);

###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] key=value kay=value ...
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag

 e.g.:  $PROG_NAME [OPTIONS] [keyword=value],...

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s")) {
  print "$USAGE";
  exit;
}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET   = $OPTIONS{"quiet"} || 0;
$DEBUG   = $OPTIONS{"debug"} || 0;
if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
}


###############################################################################
# Set Global Variables and execute main()
###############################################################################
$PROGRAM_FILE_NAME = 'upload.cgi';
$DISPLAY_SUMMARY = "DISPLAY_SUMMARY";		#key used for a CGI param

main();
exit(0);



###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
###############################################################################
sub main {

  # Do the SBEAMS authentication and exit if a username is not returned
  exit unless ($current_username = $sbeams->Authenticate(
    # connect_read_only=>1,
    # allow_anonymous_access=>1,
    # permitted_work_groups_ref=>['Proteomics_user','Proteomics_admin'],
  ));


  # Read in the default input parameters
  my %parameters;
  my $n_params_found = $sbeams->parse_input_parameters(
    q=>$q,parameters_ref=>\%parameters);
  #$sbeams->printDebuggingInfo($q);

  # Process generic "state" parameters before we start
  $sbeams->processStandardParameters( parameters_ref=>\%parameters);

  if  ( $parameters{output_mode} =~ /xml|tsv|excel|csv/){
    # print out results sets in different formats
    print_output_mode_data(parameters_ref=>\%parameters);
  }else{
    # Gonna return a web page.
    $sbeamsMOD->printPageHeader();
    print_javascript();
    $sbeamsMOD->updateSampleCheckBoxButtons_javascript();
    handle_request(ref_parameters=>\%parameters);
    $sbeamsMOD->printPageFooter();
  }
} # end main


###############################################################################
# print_javascript 
##############################################################################
sub print_javascript {

    my $uri = "$CGI_BASE_DIR/$SBEAMS_SUBDIR/";

print qq~
<script type="text/javascript">
<!--
<!-- $uri -->
function testFunc(){
 alert("clicked");
}   
    //Determines what browser is being used and what OS is being used.
    // convert all characters to lowercase to simplify testing
    var agt=navigator.userAgent.toLowerCase();
    
// *** BROWSER VERSION ***
    var is_nav  = ((agt.indexOf('mozilla')!=-1) && (agt.indexOf('spoofer')==-1)
                && (agt.indexOf('compatible') == -1) && (agt.indexOf('opera')==-1)
									 && (agt.indexOf('webtv')==-1));
var is_ie   = (agt.indexOf("msie") != -1);
var is_opera = (agt.indexOf("opera") != -1);

// *** PLATFORM ***
    var is_win   = ( (agt.indexOf("win")!=-1) || (agt.indexOf("16bit")!=-1) );
var is_mac    = (agt.indexOf("mac")!=-1);
var is_sun   = (agt.indexOf("sunos")!=-1);
var is_linux = (agt.indexOf("inux")!=-1);
var is_unix  = ((agt.indexOf("x11")!=-1) || is_linux);

//-->
</SCRIPT>
~;
return 1;
}

###############################################################################
# Handle Request
###############################################################################
sub handle_request {
  my %args = @_;


  #### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};


  #### Define variables for Summary Section
  my $project_id = $parameters{PROJECT_ID} || $sbeams->getCurrent_project_id; 

  ## Need to add a MainForm in order to facilitate proper movement between projects.  
  # Otherwise some cgi params that we don't want might come through.
  print qq~ <FORM METHOD="post" NAME="MainForm" action="$CGI_BASE_DIR/$SBEAMS_SUBDIR/upload.cgi">
       <INPUT TYPE="hidden" NAME="apply_action_hidden" VALUE="">
       <INPUT TYPE="hidden" NAME="set_current_work_group" VALUE="">
       <INPUT TYPE="hidden" NAME="set_current_project_id" VALUE="">
  </form>
  ~;

  #### Show current user context information
  $sbeams->printUserContext();
  $current_contact_id = $sbeams->getCurrent_contact_id();

  if ($parameters{jobname} && $parameters{status} eq 'failed') {
    fail_upload(ref_parameters=>$ref_parameters);
  } elsif ($parameters{Get_Data} || $parameters{jobname}) {
    start_upload(ref_parameters=>$ref_parameters);
  } else {
    print_upload_form(ref_parameters=>$ref_parameters);
  }

  return;

}# end handle_request


###############################################################################
# print_upload_form
###############################################################################
sub print_upload_form {
  my %args = @_;

  my $sql = '';

  my %resultset = ();
  my $resultset_ref = \%resultset;
  my %max_widths;
  my %rs_params = $sbeams->parseResultSetParams(q=>$q);
  my $base_url = "$CGI_BASE_DIR/SolexaTrans/Samples.cgi";
  my $manage_table_url = "$CGI_BASE_DIR/SolexaTrans/ManageTable.cgi?TABLE_NAME=ST_";

  my %url_cols   = ();
  my %hidden_cols  = ();
  my $limit_clause = '';
  my @column_titles = ();

  my ($display_type, $selected_tab_numb);

  my $solexa_info;
  my @default_checkboxes   = ();
  my @checkbox_columns   = ();

  #$sbeams->printDebuggingInfo($q);
  #### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'} || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};

  my $project_id = $sbeams->getCurrent_project_id();
  my ($name, $pass, $uid, $gid, $quota, $comment, $gcos, $dir, $shell, $expire) = getpwnam($current_username);
  my ($group_name, $passwd, $grid, $members) = getgrgid($gid);

  my $apply_action=$parameters{'action'} || $parameters{'apply_action'} || 'QUERY';

  ## HACK: If set_current_project_id is a parameter, we do a 'QUERY' instead of a 'VIEWRESULTSET'
  if ($parameters{set_current_project_id}) {
      $apply_action = 'QUERY';
  }

  # return a sql statement to display all the arrays for a particular project
  $sql = $sbeams_solexa_groups->get_uploadable_samples_sql(project_id    => $project_id, );

  %url_cols = ( 'Sample_Tag'      => "${manage_table_url}solexa_sample&slimseq_sample_id=\%0V",
                'Select_Analysis _OPTIONS' => { 'embed_html' => 1 }
              );

  %hidden_cols = (
                   "Sample_ID" => 1,
                   'Job_Name' => 1,
                   'Job_ID' => 1,
                 );

  @default_checkboxes = qw(Select_Analysis);  #default file type to turn on the checkbox
  @checkbox_columns = qw(Select_Analysis);

  #### If the apply action was to recall a previous resultset, do it
  if ($apply_action eq "VIEWRESULTSET"  && $apply_action ne 'QUERY') {

        $sbeams->readResultSet(
         resultset_file=>$rs_params{set_name},
         resultset_ref=>$resultset_ref,
         query_parameters_ref=>\%parameters,
          resultset_params_ref=>\%rs_params,
         );

  } else {
          # Fetch the results from the database server
          $sbeams->fetchResultSet( sql_query => $sql,
                             resultset_ref => $resultset_ref );

  }

  # start the form to run STP on solexa samples
  print $q->start_form(-name =>'select_samplesForm');

  append_job_controls( resultset_ref => $resultset_ref
                 );

  prepend_checkbox( resultset_ref => $resultset_ref,
                    checkbox_columns => \@checkbox_columns,
                    default_checked => \@default_checkboxes,
                  );

  my $cbox = $sbeamsMOD->get_sample_select_cbox(box_names => \@checkbox_columns,
                                                default_file_types => \@default_checkboxes);

  # Set the column_titles to just the column_names, reset first.
  @column_titles = ();
  for my $title ( @{$resultset_ref->{column_list_ref}} ) {
    if ($cbox->{$title}) {
      push @column_titles, "$title $cbox->{$title}";
    } else {
      push @column_titles, $title;
    }
  }

  ###################################################################

  $log->info( "writing" );
  #### Store the resultset and parameters to disk resultset cache
  $rs_params{set_name} = "SETME";
  $sbeams->writeResultSet(resultset_file_ref=>\$rs_params{set_name},
                            resultset_ref=>$resultset_ref,
                            query_parameters_ref=>\%parameters,
                            resultset_params_ref=>\%rs_params,
                            query_name=>"$SBEAMS_SUBDIR/$PROGRAM_FILE_NAME",
                           );


  #### Display the resultset
  $sbeams->displayResultSet(resultset_ref=>$resultset_ref,
                                query_parameters_ref=>\%parameters,
                                rs_params_ref=>\%rs_params,
                                url_cols_ref=>\%url_cols,
                                hidden_cols_ref=>\%hidden_cols,
                                max_widths=>\%max_widths,
                                column_titles_ref=>\@column_titles,
                                base_url=>$base_url,
                                no_escape=>1,
                                nowrap=>1,
                                show_numbering=>1,
                                );

  print   $q->hidden(-name=>'step',-default=>2,-override=>1);
  print   $q->br,
          $q->submit(-name=>'Get_Data',
                     #will need to change value if other data sets need to be run
                     -value=>'Start Uploads');

  print $q->reset;
  print $q->endform;


}

###############################################################################
# fail_upload
###############################################################################
sub fail_upload {
  my %args = @_;

  my $sql = '';

  my %resultset = ();
  my $resultset_ref = \%resultset;
  my %max_widths;
  my %rs_params = $sbeams->parseResultSetParams(q=>$q);
  my $base_url = "$CGI_BASE_DIR/SolexaTrans/Samples.cgi";
  my $manage_table_url = "$CGI_BASE_DIR/SolexaTrans/ManageTable.cgi?TABLE_NAME=ST_";

  my %url_cols   = ();
  my %hidden_cols  = ();
  my $limit_clause = '';
  my @column_titles = ();

  my ($display_type, $selected_tab_numb);

  my $solexa_info;
  my @default_checkboxes   = ();
  my @checkbox_columns   = ();

  #$sbeams->printDebuggingInfo($q);
  #### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'} || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};

  my $project_id = $sbeams->getCurrent_project_id();
  my ($name, $pass, $uid, $gid, $quota, $comment, $gcos, $dir, $shell, $expire) = getpwnam($current_username);
  my ($group_name, $passwd, $grid, $members) = getgrgid($gid);

  my $apply_action=$parameters{'action'} || $parameters{'apply_action'} || 'QUERY';

  ## HACK: If set_current_project_id is a parameter, we do a 'QUERY' instead of a 'VIEWRESULTSET'
  if ($parameters{set_current_project_id}) {
      $apply_action = 'QUERY';
  }

  if ($parameters{jobname} && $parameters{status} eq 'failed') {
    my $jobname = $parameters{jobname};
    my $status_ref = $utilities->check_sbeams_job_status(jobname=>$jobname);
    if (!$status_ref) { error("Could not find that job in the database"); }
    my ($status, $status_time) = @$status_ref;
    my $diff = diff_time($status_time);
    if ($status eq 'UPLOADING' && $diff > 2) {
      my $analysis_id = $utilities->check_sbeams_job(jobname=>$jobname);
      if (!$analysis_id) { error("Could not find that job in the database"); }

      my $path = $sbeamsMOD->solexa_delivery_path();
      # check if the original job is uploading

      my $error = 0;
      open ID, "$path/$jobname/id" or $error = 1;
      my $id;
      if (!$error) {
        $id = <ID>;
        close ID;
      }
      my $uerror = 0;
      if (!$id) {
        open UID, "$path/$jobname/update_id" or $uerror = 1;
        if (!$uerror) {
          $id = <UID>;
          close UID;
        }
      }

      if (!$id && $error && $uerror) {
        update_db($analysis_id, "No PID in job ID", 'PROCESSED');
      }

      my $job = new Batch;
      $job->type($BATCH_SYSTEM);
      $job->name($jobname);
      $job->id($id);
      $job->cancel ||
            update_db($analysis_id, "That job is not currently running",'PROCESSED');

      unlink("$path/$jobname/id") if !$error;
      unlink("$path/$jobname/update_id") if !$uerror;

      open(ERR, ">>$path/$jobname/${jobname}_upload.err") ||
            update_db($analysis_id, "Upload canceled, but couldn't write artificial out file $path/$jobname/${jobname}_upload.err");
      print ERR "Upload canceled by user\n";
      close(ERR);

      update_db($analysis_id, "Upload successfully canceled: <strong>$jobname</strong>");

    } else {
      error("You cannot cancel this upload within two days of last status update");
    }

  }
}

###############################################################################
# start_upload
###############################################################################
sub start_upload {
  my %args = @_;

  my $sql = '';

  my %resultset = ();
  my $resultset_ref = \%resultset;
  my %max_widths;
  my %rs_params = $sbeams->parseResultSetParams(q=>$q);
  my $base_url = "$CGI_BASE_DIR/SolexaTrans/Samples.cgi";
  my $manage_table_url = "$CGI_BASE_DIR/SolexaTrans/ManageTable.cgi?TABLE_NAME=ST_";

  my %url_cols   = ();
  my %hidden_cols  = ();
  my $limit_clause = '';
  my @column_titles = ();

  my ($display_type, $selected_tab_numb);

  my $solexa_info;
  my @default_checkboxes   = ();
  my @checkbox_columns   = ();

  #$sbeams->printDebuggingInfo($q);
  #### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'} || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};

  my $project_id = $sbeams->getCurrent_project_id();
  my ($name, $pass, $uid, $gid, $quota, $comment, $gcos, $dir, $shell, $expire) = getpwnam($current_username);
  my ($group_name, $passwd, $grid, $members) = getgrgid($gid);

  my $apply_action=$parameters{'action'} || $parameters{'apply_action'} || 'QUERY';

  ## HACK: If set_current_project_id is a parameter, we do a 'QUERY' instead of a 'VIEWRESULTSET'
  if ($parameters{set_current_project_id}) {
      $apply_action = 'QUERY';
  }

print Dumper(\%parameters);
  print "Starting uploads:<br>";

  my %unique_solexa_analysis_ids;
  # this has to remain select_samples because the cbox code is in solexautilities and 
  # I don't want to make a copy of that method that only changes the name of the javascript box
  # TODO: Should be rewritten so that the function takes in what you want the boxes to be called
  if ($parameters{select_samples}) {
     my $solexa_analysis_id_string =  $parameters{select_samples};
    my @solexa_analysis_ids = split(/,/, $solexa_analysis_id_string);
    %unique_solexa_analysis_ids = map {split(/__/, $_) } @solexa_analysis_ids;
  } elsif ($parameters{jobname}) {
    my $solexa_analysis_id = $utilities->check_sbeams_job(jobname=> $parameters{jobname}); 
    $unique_solexa_analysis_ids{$solexa_analysis_id} = 1;
  }

  if (scalar keys %unique_solexa_analysis_ids > 0) {
    foreach my $analysis_id (sort {$a <=> $b} ( keys %unique_solexa_analysis_ids)) {

      my $sql = $sbeams_solexa_groups->get_start_upload_info_sql(solexa_analysis_id => $analysis_id);

      my @upload_info = $sbeams->selectSeveralColumns($sql);
      my $sample = $upload_info[0]->[0];
      my $jobname = $upload_info[0]->[1];

      my $pipeline_job_directory = $sbeamsMOD->solexa_delivery_path();;
      my $job_dir = $pipeline_job_directory.'/'.$jobname;

      $jobname .= '_upload'; # change the jobname so it doesn't overwrite the previous job scripts

      print "Starting upload for sample $sample and job $jobname in $job_dir<br>";


      my $project_name = $sbeams->getCurrent_project_name;

      my $perl_script = generate_perl(analysis_id => $analysis_id,
                                      job_dir => $job_dir,
                                      project_name => $project_name,
                                      jobname => $jobname,
                                      sample => $sample,
                                     );

      my $error = create_files(job_dir => $job_dir,
                               jobname => $jobname,
                               script => $perl_script,
                              );

      error($error) if $error != 1;

      my $job = new Batch;
      $job->cputime('48:00:00'); # default at 48 hours for now
      $job->type($BATCH_SYSTEM);
      print "script $job_dir/$jobname.sh<br>";
      $job->script("$job_dir/$jobname.sh");
      $job->name($jobname);
#      $job->group($group_name);
      $job->out("$job_dir/$jobname.out");
      $job->queue("dev");
      $job->mem("10kb");
      eval {
      $job->submit;
      };
      if ($@) {
       error("Couldn't start a job for $jobname - $@");
      }
      open (ID, ">$job_dir/upload_id") ||
        error("Couldn't write out an id for $jobname in $job_dir/upload_id");
      print ID $job->id;
      close(ID);
      chmod(0666,"$job_dir/upload_id");

      print "<br>\n";
      print "<br>\n";

      
    }

  }

}

sub generate_perl {
  my (%argHash) = @_;
  my @required_opts=qw(analysis_id job_dir project_name jobname sample);
  my @missing=grep {!defined $argHash{$_}} @required_opts;
  die "missing opts: ",join(', ',@missing) if @missing;

  my ($analysis_id, $job_dir, $project_name, $jobname, $sample) =
      @argHash{qw(analysis_id job_dir project_name jobname sample)};


  my $pscript=<<"PEND";
#!/tools64/bin/perl

use Carp;
use strict;
use warnings;
use lib "$PHYSICAL_BASE_DIR/lib/perl";
use SBEAMS::Connection;
use SBEAMS::Connection::Tables;
use SBEAMS::SolexaTrans::Solexa_file_groups;
use SBEAMS::SolexaTrans::Tables;
use SBEAMS::SolexaTrans::SolexaUtilities;
use POSIX qw(strftime);

my \$verbose = 1;   # these should be 0 for production
my \$testonly = 0;

my \$sbeams = new SBEAMS::Connection;
my \$utilities = new SBEAMS::SolexaTrans::SolexaUtilities;
\$utilities->setSBEAMS(\$sbeams);

my \$current_username = \$sbeams->Authenticate();
my \%rowdata = ();
my \$rowdata_ref = \\\%rowdata;

my \$sample_id = '$sample';
my \$project_name = '$project_name';
my \$analysis_id = '$analysis_id';
my \$tag_analysis_format_file = '$PHYSICAL_BASE_DIR'.'/lib/conf/SolexaTrans/tag_analysis3.fmt';

PEND

   $pscript .= alter_db_status('UPLOADING');
   $pscript .= upload_tag_info();

   my $tag_script = perl_process_tags('MATCH', $job_dir);
#      my $unkn_script = perl_process_tags('UNKNOWN', $job_dir);
   my $ambg_script = perl_process_tags('AMBIGUOUS', $job_dir);

   $pscript .= $tag_script;
#      $pscript .= $unkn_script;
   $pscript .= $ambg_script;

   $pscript .= alter_db_status('COMPLETED');

  return $pscript;
}

###############################################################################
# create_files
#
###############################################################################
sub create_files {
    my %args = @_;
    my $job_dir = $args{job_dir};
    my $jobname = $args{jobname};
    my $perl_script = $args{script};

    print "job_dir $job_dir jobname $jobname<br>\n";
    # Create job directory
    #print STDERR "JOB DIR2 '$dir/$jobname'\n";
    unless (-d "$job_dir"){
#           umask(0000);                                        #delete for production
#               my $umask = umask();                    #delete for production

            mkdir("$job_dir", 0775) ||
                        return("Couldn't create result directory. '$job_dir' ");
            chmod(0777,"$job_dir");            #delete for production
    }

    # Create perl script that runs pipeline
    my $perl_script_name = $job_dir.'/'.$jobname.'.pl';
    open(SCRIPT, ">$perl_script_name") ||
       return("Couldn't create perl script file. '$job_dir/$jobname.pl' ");
    print SCRIPT $perl_script;
    close SCRIPT;
    chmod(0777,$perl_script_name) ||
      return("Couldn't change the mode of perl script. '$perl_script_name' ");

    my $email = $sbeams->getEmail($current_contact_id);
    $email = 'dmauldin@systemsbiology.org' unless $email;


    # Generate Shell script
    my $sh = generate_sh( 
                          job_dir => $job_dir,
                          jobname => $jobname,
                          perl_script => $perl_script_name,
                          email => $email,
                          );
    open (SH, ">$job_dir/$jobname.sh") ||
      return("Couldn't create shell script. '$job_dir/$jobname.sh' ");
    print SH $sh;
    close (SH);
    chmod(0777,"$job_dir/$jobname.sh") ||
      return("Couldnt change the mode of shell script. '$job_dir/$jobname.sh' ");

}

#### Subroutine: generate_sh
# Generate the shell script to run the perl script and move files
####
sub generate_sh {
   my (%argHash)=@_;
    my @required_opts=qw(job_dir jobname perl_script email);
    my @missing=grep {!defined $argHash{$_}} @required_opts;
    die "missing opts: ",join(', ',@missing)." from supplied ",join(', ',%argHash) if @missing;

    my ($job_dir,$jobname,$perl_script, $email)=
        @argHash{qw(job_dir jobname perl_script email)};

    my $sh=<<"SH";
#!/bin/sh
#PBS -N $jobname
#PBS -M $email
#PBS -m ea
#PBS -o $job_dir/$jobname.out
#PBS -e $job_dir/$jobname.err

SH

    my $cmd="/tools64/bin/perl $perl_script";

    die "$perl_script not found and/or not executable: $!" unless -x $perl_script;
#    $qsub.="perl $base_dir/echo.pl $opts\n"; # leave this around for debugging
    $sh.= "$cmd\n";

}


###############################################################################
# prepend_checkbox
#
# prepend a checkbox which can then be shown via the displayResultSet method
###############################################################################

sub prepend_checkbox {
        my %args = @_;

        my $resultset_ref = $args{resultset_ref};
        my @default_checked = @{$args{default_checked}};        #array ref of column names that should be checked
        my @checkbox_columns = @{$args{checkbox_columns}};      #array ref of columns of checkboxes to make

        #data is stored as an array of arrays from the $sth->fetchrow_array
        # each row is a row from the database holding an aref to all the values
        my $aref = $$resultset_ref{data_ref};

        my $jobid_idx = $resultset_ref->{column_hash_ref}->{Job_ID};

        my @new_data_ref;
        ########################################################################################
        foreach my $checkbox_column (@checkbox_columns){
           my $pad = '&nbsp;&nbsp;&nbsp;';
           foreach my $row_aref (@{$aref} ) {
              my $checked = ( grep /$checkbox_column/, @default_checked ) ? 'checked' : '';

              #need to make sure the query has the slimseq_sample_id in the first column
              #    since we are going directly into the array of arrays and pulling out values
              my $job_id  = $row_aref->[$jobid_idx];

              my $link = "<input type='checkbox' name='select_samples' $checked value='VALUE_TAG' >";
              my $value = $job_id.'__Select_Analysis';
              $link =~ s/VALUE_TAG/$value/;

              my $anchor = "$pad $link";
              unshift @$row_aref, $anchor;              #prepend on the new data
           } # end foreach row

           if ( 1 ){
                #add on column header for each of the file types
                #need to add the column headers into the resultset_ref since DBInterface display results will reference this
                unshift @{$resultset_ref->{column_list_ref}} , "$checkbox_column";

                #need to append a value for every column added otherwise the column headers will not show
                prepend_precision_data($resultset_ref);
           }
        } # end foreach checkbox_column
}

###############################################################################
# prepend_precision_data
#
# need to prepend a value for every column added otherwise the column headers will not show
###############################################################################


sub prepend_precision_data {
        my $resultset_ref = shift;

        my $aref = $$resultset_ref{precisions_list_ref};

        unshift @$aref, '-10';

        $$resultset_ref{precisions_list_ref} = $aref;

        my $bref = $$resultset_ref{types_list_ref};
        unshift(@$bref,'int');
        $$resultset_ref{types_list_ref} = $bref;

        

}

###############################################################################
# append_job_controls
#
# Append on the more columns of data which can then be shown via the displayResultSet method
###############################################################################

sub append_job_controls {
        my %args = @_;

        my $resultset_ref = $args{resultset_ref};

        #data is stored as an array of arrays from the $sth->fetchrow_array
        # each row is a row from the database holding an aref to all the values
        my $aref = $$resultset_ref{data_ref};

        my $jobname_idx = $resultset_ref->{column_hash_ref}->{Job_Name};
        my $status_idx  = $resultset_ref->{column_hash_ref}->{Job_Status};
        my $sample_idx  = $resultset_ref->{column_hash_ref}->{Sample_ID};
        my $status_time_idx = $resultset_ref->{column_hash_ref}->{Job_Updated};

        my @new_data_ref;
        ########################################################################################
        my $anchor = '';
        my $pad = '&nbsp;&nbsp;&nbsp;';
        foreach my $row_aref (@{$aref} ) {

          #need to make sure the query has the slimseq_sample_id in the first column
          #    since we are going directly into the array of arrays and pulling out values
          my $jobname  = $row_aref->[$jobname_idx];
          # the six statuses are: QUEUED, RUNNING, CANCELED, UPLOADING, PROCESSED, COMPLETED
          my $status   = $row_aref->[$status_idx];
          my $status_time = $row_aref->[$status_time_idx];

          if ($status eq 'UPLOADING') {
            my $diff = diff_time($status_time);
            if ($diff > 2) {  # if the number of days between the current day and the last status time update is less than 2
                              # then we want to not cancel the job.
              $anchor = "<a href=\"upload.cgi?jobname=$jobname&status=failed\">Fail Upload</a>";
            } else {
              $anchor = "No Actions";
            }
          } elsif ($status eq 'PROCESSED') {
            $anchor = "<a href=upload.cgi?jobname=$jobname>Start Upload</a>";
          } else {
            $anchor = "ERROR: Contact admin";
          }

          my $view_params = "<a href=Status.cgi?jobname=$jobname>View Params</a>";
          push @$row_aref, $view_params;

          push @$row_aref, $anchor;             #append on the new data

        } # end foreach row

        if ( 1 ){
            #need to add the column headers into the resultset_ref since DBInterface display results will reference this
            push @{$resultset_ref->{column_list_ref}} , "Job Parameters";
            push @{$resultset_ref->{column_list_ref}} , "Job Controls";

            #need to append a value for every column added otherwise the column headers will not show
            append_precision_data($resultset_ref);
            append_precision_data($resultset_ref);
        }


}


###############################################################################
# append_precision_data
#
# need to append a value for every column added otherwise the column headers will not show
###############################################################################


sub append_precision_data {
        my $resultset_ref = shift;


        my $aref = $$resultset_ref{precisions_list_ref};

        push @$aref, '-10';

        $$resultset_ref{precisions_list_ref} = $aref;

        #print "AREF '$aref'<br>";

        #foreach my $val (@$aref){
        #       print "$val<br>";
        #}

}

###############################################################################
# diff_time
###############################################################################
sub diff_time {
  my $status_time = shift;

  my $ctime = `date +'%Y-%m-%d'`;
  my ($cyear, $cmonth, $cday) = split(/-/, $ctime);
  my ($syear, $smonth, $sday) = split(/-/, $status_time);
  my $cdate = timelocal(0,0,0,$cday, $cmonth -1, $cyear -1900);
  my $sdate = timelocal(0,0,0,$sday, $smonth -1, $syear -1900);
  my $diff = abs(($cdate - $sdate)/86400);
 
  return $diff;
}

###############################################################################
# update_db
###############################################################################
sub update_db {
  my $analysis_id = shift;
  my $message = shift;
  my $status = shift || 'CANCELED';

  my $rowdata_ref = {
                       status => $status,
                       status_time => 'CURRENT_TIMESTAMP',
                    };

  $sbeams->updateOrInsertRow(
                              table_name => $TBST_SOLEXA_ANALYSIS,
                              rowdata_ref => $rowdata_ref,
                              PK => 'solexa_analysis_id',
                              PK_value => $analysis_id,
                              return_PK=>0,
                              update=>1,
                              add_audit_parameters=>1,
                            );

  result($message. '. Status is '.$status);

}

#### Subroutine: result
# Print out an result message and exit
####
sub result {
    my ($result) = @_;

        print $q->h1("Fail Job Upload");

        print $q->h2("Results:");
        print $q->p($result);


        exit(1);
}

#### Subroutine: error
# Print out an error message and exit
####
sub error {
    my ($error) = @_;

        print $q->h1("Error with job");

        print $q->h2("Error:");
        print $q->p($error);

        exit(1);
}


###############################################################################
# error_log
###############################################################################
sub error_log {
	my $SUB_NAME = 'error_log';
	
	my %args = @_;
	
	die "Must provide key value pair for 'error' \n" unless (exists $args{error});
	
	open ERROR_LOG, ">>SOLEXA_UPLOAD_ERROR_LOG.txt"
		or die "$SUB_NAME CANNOT OPEN ERROR LOG $!\n";
		
	my $date = `date`;
	
	print ERROR_LOG "$date\t$args{error}\n";
	close ERROR_LOG;
	
	die "$date\t$args{error}\n";
}


