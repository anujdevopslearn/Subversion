package Help;

use FindBin;
use lib "$FindBin::Bin/../../lib/perl";

use strict;

our @ISA    = qw/Exporter/;
our @EXPORT = qw/help_all help_gen_jobs help_gen_tools
                 help_javascript help_general help_jobs help_tools
                /;

#### Subroutine: help_all
# returns all of the help options
####
sub help_all {

  my $help = help_javascript();
  $help .= qq~
    <h1>SolexaTrans Pipeline Help</h1>
  ~;

  $help .= help_general();
  $help .= help_jobs();
  $help .= help_tools();

return $help;
}

sub help_gen_jobs {

  my $help = help_javascript();
  $help .= qq~
    <h1>SolexaTrans Pipeline Help</h1>
  ~;

  $help .= help_general();
  $help .= help_jobs();

return $help;
}

sub help_gen_tools {

  my $help = help_javascript();
  $help .= qq~
    <h1>SolexaTrans Pipeline Help</h1>
  ~;

  $help .= help_general();
  $help .= help_tools();

return $help;
}

sub help_javascript {
  my $js = qq~
<script type="text/javascript">
var help_state = 'none';
function toggle_help(layer_ref) {
  if (help_state == 'inline') {
    help_state = 'none';
  } else {
    help_state = 'inline';
  }
  if (document.all) { //IS IE 4 or 5 (or 6 beta)
  eval( "document.all." + layer_ref + ".style.display = help_state");
  }
  if (document.layers) { //IS NETSCAPE 4 or below
  document.layers[layer_ref].display = help_state;
  }
  if (document.getElementById && !document.all) {
  help = document.getElementById(layer_ref);
  help.style.display = help_state;
  }
}
</SCRIPT>
~;

return $js;
}

sub help_general {

  my $help = qq~
    <h3>General</h3>
    <p>The SolexaTrans Pipeline is a program that takes the output of the Solexa Pipeline
        (from the Solexa sequencing machine) and allows users to map the export from the Solexa
        Pipeline (s_#_export.txt) to any number of genomes of their choice.  New genomes
        must be added by a SBEAMS administrator. Available genomes may be browsed from the 'Browse BioSeqs' link.</p>

    <p>The main SolexaTrans page contains a summarized list of the Solexa samples that are
        available to be processed and quick links to job control and results pages.  More detailed
        options for job creation (including the ability to start multiple jobs at once) are available
        from the 'Start Pipeline' link on the left navigation bar.</p>

  ~;

  return $help;
}

sub help_jobs {

  my $help = qq~
    <h3>Job Information</h3>
    <p>Each Solexa sample can have multiple jobs run on it with various parameters.  The SBEAMS website
        defaults to displaying the most recent job.  The various job statuses are:</p>

    <ul>
      <li> <b>QUEUED</b> - This job is queued on the cluster to begin running.</li>
      <li> <b>RUNNING</b> - This job is currently running on the cluster.</li>
      <li> <b>CANCELED</b> - This job has been canceled by the user.</li>
      <li> <b>UPLOADING</b> - This job has finished running and is uploading results to the SolexaTrans database.
          The STP files are available for use (Plots, Download, Explore, Tag Statistics), but the web query pages
          will not display results (GetCounts).</li>
      <li> <b>PROCESSED</b> - This job has finished running and has uploaded the GENE information to the SolexaTrans
            database, but UPLOADING the TAG information to the SolexaTrans database was not selected
            or failed before it completed.  The STP files are are available for use (Plots,  Download, Explore,
            Tag Statistics, GetCounts Gene Query), but the web query pages will not display results (GetCounts Tag Query).</li>
      <li> <b>COMPLETED</b> - This job has finished running and has successfully uploaded both GENE and TAG information
            into the SolexaTrans database.  All website functions are available.</li>
    </ul>
  ~;

  return $help;
}

sub help_tools {

  my $help = qq~
    <h3>Tools</h3>
    <p>The SolexaTrans SBEAMS website contains various tools that are designed to help process STP jobs
        or facilitate data analysis.</p>
    
    <ul>
      <li> <u>Main SolexaTrans Page/Plot Tag Counts</u> - The main SolexaTrans SBEAMS page contains two tools that 
              assist in data analysis.
        <ul>
          <li> <b>Compare Samples</b> - This tool creates a sortable comparison table of the detailed tag statistics for 
                selected 'UPLOADING', 'PROCESSED', or 'COMPLETED' jobs.  Shows one job per sample based on what
                is selected in the main table.</li>
          <li> <b>Draw Plots</b> - This tool creates R plots that graph the correlation coefficient between two samples.
                This tool only uses tags that have values in both samples.</li>
        </ul>
      <li> <u>Sample Tags by Job</u> - Displays some tag statistics for each job in the system.  Can be sorted and can be
            filtered so that it displays all jobs for a specific sample.</li>
      <li> <u>Sample QC</u> - Displays basic quality control information retrieved from SlimSeq (Lane Yield, Average 
            Clusters, Percent of Clusters that Pass Filtering, Percent Error) and links to the Summary file that
            is produced by the Solexa Pipeline (Illumina).
      <li> <u>Get Counts</u> - Can be used to retrieve specific tag or specfic gene counts, examine which genes a particular
            tag matches to, retrieve the top ten genes in a specific job and many additional functions.  This tool
            only functions if the job has finished the 'UPLOADING' stage.  If a job is 'PROCESSED' then some results
            may be available, but the full resultset <b>is not available</b>.  Use of this tool with a 'PROCESSED' or
            'UPLOADING' job state may give misleading results.</li>
      <li> <u>Download Data</u> - Allows the user to download data, view the Solexa Pipeline Summary file (produced by the
              Illumina software), or explore to the location of the STP output files.</li>
    </ul>
  ~;

  return $help;
}

1;
