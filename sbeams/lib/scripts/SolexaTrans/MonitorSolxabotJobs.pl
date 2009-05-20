#!/usr/local/bin/perl -w
#
###########################################################################
## NAME
## MonitorSolxabotJobs.pl
##
## SYNOPSIS
## MonitorSolxabotJobs.pl [-dt]
##
## OPTIONS
##
## Options:
## -d, --debug	show debugging messages
## -t, --test   test mode (doesn't move the message out of INBOX)
## 
## DESCRIPTION
##
## Script to run load_solexatrans.pl when notified that Solexa data is ready
## Also catches PBS failures and sends an error message to the user and 
##   updates the ST database.
##
###########################################################################

use strict;
use warnings;
use Getopt::Long;

use IO::Socket::SSL;
use Mail::IMAPClient;
use POSIX qw(strftime);

no warnings ('substr');

# Taken from man 7 signal
my %signals = ( 1 => { 'Name' => 'SIGHUP',
                       'Desc' => 'Hangup detected on controlling terminal or death of controlling process',
                    },
                2 => { 'Name' => 'SIGINT',
                       'Desc' => 'Interrupt from keyboard',
                    },
                3 => {  'Name' => 'SIGQUIT',
                        'Desc' => 'Quit from keyboard',
                    },
                4 => {  'Name' => 'SIGILL',
                        'Desc' => 'Illegal Instruction',
                    },
                6 => {  'Name' => 'SIGABRT',
                        'Desc' => 'Abort signal from abort(3)',
                    },
                8 => {  'Name' => 'SIGFPE',
                        'Desc' => 'Floating point exception',
                    },
                9 => {  'Name' => 'SIGKILL',
                        'Desc' => 'Kill signal',
                    },
                11 => { 'Name' => 'SIGSEGV',
                        'Desc' => 'Segmentation fault - program exited abnormally.',
                    },
                13 => { 'Name' => 'SIGPIPE',
                        'Desc' => 'Broken pipe: write to pipe with no readers',
                    },
                14 => { 'Name' => 'SIGALRM',
                        'Desc' => 'Timer signal from alarm(2)',
                    },
                15 => { 'Name' => 'SIGTERM',
                        'Desc' => 'Termination signal',
                    },
            );

# from experience, these are also errors that can occur
$signals{'127'}{'Name'} = 'EXECERR';
$signals{'127'}{'Desc'} = 'An error in execution happened.';

use lib "../../perl";
use SBEAMS::Connection;
use SBEAMS::Connection::Settings qw( $PHYSICAL_BASE_DIR $LOGGING_LEVEL $LOG_BASE_DIR %DBPREFIX);
use SBEAMS::SolexaTrans::Tables;
use SBEAMS::SolexaTrans::SolexaUtilities;


my $sbeams = new SBEAMS::Connection;
my $output_mode = $sbeams->output_mode('print');
my $utilities = new SBEAMS::SolexaTrans::SolexaUtilities;
$utilities->setSBEAMS($sbeams);

sub usage {
    warn "@_\n" if @_;
    print <<EOFUSAGE;

MonitorSolexabotJobs.pl [OPTIONS ...]
OPTIONS:
    -l, --log <dir>           Log to a specific directory instead of default
    -s, --st                  Log the output of load_solexatrans.pl
    -d, --debug		      Turn on debugging messages.
    -h, -?, --help	      Display this help message
    -t, --test                Test mode
    -ns                       Don't run LoadSolexaTrans (test mode)
    -v, --verbose             Verbose

EOFUSAGE
exit;
}

my ($opt_d,$opt_h,$opt_t, $opt_l, $opt_s, $opt_ns, $opt_v);
my %options = ( 'debug|d'	=> \$opt_d,
		'help|h|?'	=> \$opt_h,
                'test|t'        => \$opt_t,
                'log|l'         => \$opt_l,
                'st|s'          => \$opt_s,
                'ns'            => \$opt_ns,
                'v|verbose'     => \$opt_v,
               );

GetOptions(%options) || usage;

usage if $opt_h;

my $debug;
if ($opt_d) {
  $debug = 1;
}

my $module     = $sbeams->getSBEAMS_SUBDIR();

my $DATABASE = $DBPREFIX{$module};
print "DATABASE $DATABASE\n" if $opt_t;

my $work_group = 'SolexaTrans_admin';
my $CURRENT_USERNAME;
exit unless ( $CURRENT_USERNAME =
  $sbeams->Authenticate( work_group => $work_group, ) );



####################################################
### CONFIG SETTINGS
####################################################

my $mailhost='imap.gmail.com';
my $userid='Solxabot@systemsbiology.org';
my $pw='STdv1230';

my $script_dir = $PHYSICAL_BASE_DIR.'/lib/scripts/SolexaTrans';

#################################################################
### SET UP LOG
#################################################################

  my $base = ( $opt_l )   ? $opt_l :
             ( $LOG_BASE_DIR ) ? $LOG_BASE_DIR : "$PHYSICAL_BASE_DIR/var/logs";

  unless( -e $base ){
  print STDERR "Try to create base = $base\n";
    mkdir( $base ) || warn "Unable to create logging dir, $base";
  }

  my $log_file = $base.'/MonitorSolexabot.log';
  open LOG, ">>$log_file";
  print LOG "STARTING MonitorSolexabot\n";


####################################################
### CONNECT TO EMAIL
####################################################

# Open file for extracted email message
my $tempfile="/solexa/trans/tmp/message.txt";


# Open an IMAP connection to the mail server
print "INFO: Opening socket...\n" if ($debug);

my $socket = IO::Socket::SSL->new(
			PeerAddr => $mailhost,
			PeerPort => 993,
) or die "socket(): $@\n";

my $greeting = <$socket>;
chomp($greeting);
print "$greeting\n" if ($debug);
my ($id,$answer) = split /\s+/, $greeting;
die "problems logging: $greeting" if ($answer ne 'OK');

print "INFO: Setting up IMAP client\n" if ($debug);
# Open an IMAP connection to the mail server

my $imap = Mail::IMAPClient->new(
                      RawSocket => $socket,
                      User => $userid,
                      Password => $pw,
) or die "Cannot connect to $mailhost as $userid: $@\n";

print "INFO: Setting state to connected\n" if ($debug);
$imap->State(Mail::IMAPClient::Connected());
print "INFO: Logging in $userid\n" if ($debug);
$imap->login() or die "Cannot login to $mailhost as $userid: $@\n";
print "INFO: Is $userid authenticated? " if ($debug);
print $imap->IsAuthenticated(),"\n" or die "Cannot login to $mailhost as $userid: $@\n";


$imap->Debug(1) if ($debug);		# Verbose debugging messages

print "INFO: Selecting INBOX...\n" if ($debug);

$imap->select("INBOX") or die "Cannot select INBOX: $@\n"; # Select the Inbox for all future operations
$imap->Uid(1);			# Use message UID's instead of sequence numbers

print 'Total messages in Inbox: ', $imap->message_count, "\n";

#################################################################
### CHECK FOR MESSAGES THAT INDICATE TO RUN LOAD_SOLEXATRANS.PL
#################################################################

my @uids = $imap->search('SUBJECT','Solexa data ready');   #search orders only

print 'Found ', $#uids + 1, " new Solexa runs to process.\n";

my $st_log = $base.'/LST_'.strftime "%Y%m%d%H%M%S",localtime; # a timestamp of YearMonthDayHourMinuteSecond
print LOG "Writing LST log to $st_log\n";

my $st_addnew_log = $st_log. '_addnew.log';

my $st_success = 0;
if (!$opt_ns && $#uids >= 0) {
  system("$script_dir/load_solexatrans.pl --run_mode add_new --verbose 100 --debug 100 > $st_addnew_log 2>&1");
  local $/=undef;
  open ST_LOG, "$st_addnew_log" or die "Can't find log for st - $st_log\n";
  binmode ST_LOG;
  my $string = <ST_LOG>;
  close ST_LOG;
  $st_success = 1 if ($string =~ /Finished running load_solexatrans/);
} elsif ($opt_ns) {
  $st_success = 1;  # test option was supplied so automatically succeed
}

if ($st_success == 1) {
  print "load_solexatrans.pl ran successfully in add_new mode";
  if ($opt_s) {
    print " - $st_addnew_log for log if logging was enabled with the -s flag\n";
  } else {
    print "\n";
    unlink $st_addnew_log;
  }
}

foreach my $uid (@uids) {	# Parse each order (mail message)
  #move the message to the Processed folder
  unless ($opt_t) {
    $imap->move("Processed", $uid) or die "Could not move message: $@\n";
  }
}


#################################################################
### CHECK FOR MESSAGES THAT INDICATE A CLUSTER STP RUN FAILURE
#################################################################

my @fids = $imap->search('SUBJECT','PBS JOB');   #search orders only

print 'Found ', $#fids + 1, " PBS jobs to process.\n";

foreach my $fid (@fids) {	# Parse each order (mail message)
  my $i=0;			# Zero out items

  # save the raw message to disk for easier processing
  if (-e $tempfile) { unlink $tempfile or die "Can't delete temp file: $!\n" };
  $imap->message_to_file($tempfile,$fid) or die "Can't create temp file: $@\n";
  rename("$tempfile","$tempfile.orig");
  open IN, "$tempfile.orig";
  
  open OUT, ">$tempfile";
  while (<IN>) {
    s/\r\n$/\n/;
    s/\015//g;
    if (/=$/) {chop;chop};
    print OUT $_;
  } 
  close IN;
  close OUT;
  unlink("$tempfile.orig");
  open(MSG,$tempfile) || die "Can't open temp file: $!";

  my ($job_id, $job_name, $exit_status);
  while (<MSG>) {
    s/\s+\=20$//;
    if (/PBS Job Id:\s+([-\..\w]+)/) {	# parse the general info 1st
      $job_id = $1;
    }
    if (/Job Name:\s+([-\..\w]+)/) {
      $job_name = $1;
    }
    if (/Exit_status=(\d+)/) {
      $exit_status = $1;
    }
  } 					# end of single message (while loop)
  close MSG;

  print "Found Job $job_name with id $job_id and exit_status $exit_status\n";

  # if there's a signal that's not 0 then update the database to say that job failed  
  if ($exit_status ne 0) {
    my $signal = `echo $exit_status | perl -e '\$c=<>; chomp \$c; \$s=\$c&127; \$e=\$c>>8; print \$s'`;
    my ($name, $desc);
    if ($signals{$signal}) {
      $name = $signals{$signal}{'Name'};
      $desc = $signals{$signal}{'Desc'};
    } else {
      $name = 'UNKN';
      $desc = 'Unknown';
    }

    print "Signal $signal name $name desc $desc\n";

    my $rowdata_ref = { status => 'FAILED',
                        status_time => 'CURRENT_TIMESTAMP',
                      };

    if ($job_name =~ /_upload$/) {
        $job_name =~ s/_upload$//;
        $rowdata_ref->{'status'} = 'FAILED UPLOAD';
    }

    my $analysis_id = $utilities->check_sbeams_job(jobname => $job_name);
    if (!$analysis_id) {
        print "ERROR: Could not find a job with the name $job_name in the ST database\n";
        next;
    }

    $sbeams->updateOrInsertRow(
                                table_name => $TBST_SOLEXA_ANALYSIS,
                                rowdata_ref => $rowdata_ref,
                                PK => 'solexa_analysis_id',
                                PK_value => $analysis_id,
                                update => 1,
                                verbose => $opt_v ? 1 : 0,
                                testonly => $opt_t? 1 : 0,
                                add_audit_parameters => 1
                              );


  }


  #move the message to the Processed folder
  unless ($opt_t) {
    $imap->move("Job Processed", $fid) or die "Could not move message: $@\n";
  }
}

$imap->expunge;
$imap->logout or die "Could not logout: $@\n";
#unlink($tempfile);
 

print 'MonitorSolxabotJobs.pl ended successfully', "\n";

close LOG;
