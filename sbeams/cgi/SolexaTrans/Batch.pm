package Batch;

use strict;
use POSIX 'setsid';
use Data::Dumper;
use FindBin;

use lib "$FindBin::Bin/../../../lib/perl";
use SBEAMS::Connection qw($log $q);
# Necessary variables in main package:
# %BATCH_ENV - environment variables necessary for batch submission
# $BATCH_BIN - path to binary directory
# $BAGCH_ARG - additional arguments to supply to submit program

#### Method: new
# The new routine
####
sub new {
	my $class = shift;
	my $self = {};
	bless $self, $class;
	$self->initialize();
	return $self;
}

#### Method: initialize
# Initialize instance variables to default values
####
sub initialize {
	my $self = shift;
	
	$self->{'type'} = undef;
	$self->{'script'} = undef;
	$self->{'name'} = undef;
	$self->{'out'} = undef;
	$self->{'error'} = undef;
	$self->{'cputime'} = undef;
	$self->{'id'} = undef;
	
	return 1;
}

#### Method: type
# Get or set value
####
sub type {
    my $self = shift;
    if (@_) { $self->{'type'} = shift }
    return $self->{'type'};
}

#### Method: script
# Get or set value
####
sub script {
    my $self = shift;
    if (@_) { $self->{'script'} = shift }
    return $self->{'script'};
}

#### Method: name
# Get or set value
####
sub name {
    my $self = shift;
    if (@_) { $self->{'name'} = shift }
    return $self->{'name'};
}

#### Method: out
# Get or set value
####
sub out {
    my $self = shift;
    if (@_) { $self->{'out'} = shift }
    return $self->{'out'};
}

#### Method: error
# Get or set value
####
sub error {
    my $self = shift;
    if (@_) { $self->{'error'} = shift }
    return $self->{'error'};
}

#### Method: cputime
# Get or set value
####
sub cputime {
    my $self = shift;
    if (@_) { $self->{'cputime'} = shift }
    return $self->{'cputime'};
}

#### Method: id
# Get or set value
####
sub id {
    my $self = shift;
    if (@_) { $self->{'id'} = shift }
    return $self->{'id'};
}

#### Method: submit
# Submit job to the batch system, returns undef for failure
####
sub submit {
    my $self = shift;
    if ($self->type eq "fork") {
        return $self->submit_fork;
    } elsif ($self->type eq "sge") {
        return $self->submit_sge;
    } elsif ($self->type eq "pbs") {
        return $self->submit_pbs;
    } else {
        
        return undef;
    }
}

#### Method: cancel
# Cancel a job submitted to the batch system, returns undef for failure
####
sub cancel {
    my $self = shift;
    if ($self->type eq "fork") {
        return $self->cancel_fork;
    } elsif ($self->type eq "sge") {
        return $self->cancel_sge;
    } elsif ($self->type eq "pbs") {
        return $self->cancel_pbs;
    } else {
        return undef;
    }
}

########################################
# THESE METHODS ARE MORE OR LESS PRIVATE
########################################

#### Method: submit_fork
# Run the job locally as a forked process
####
sub submit_fork {
    my $self = shift;
    my ($command, $pid);
    
    if (!($pid = fork)) {
        if (!defined $pid) {
            # Fork didn't work
		    return undef;
		}
		# Child process
     	open(STDIN, '/dev/null');
        open(STDOUT, '>/dev/null');
        open(STDERR, '>/dev/null');
        setsid();
     	
     	$command  = $self->script;
     	$command .= " > " . ($self->out ? $self->out : "/dev/null");
     	$command .= " 2> " . ($self->error ? $self->error : "/dev/null");
     	system($command);
     	
     	exit(0);
    }
    $self->id($pid);
    
    return $self->id;
}

#### Method: submit_sge
# Submit job using the Sun Grid Engine
####
sub submit_sge {
    my $self = shift;
    my ($command);
    
    foreach (keys %::BATCH_ENV) {
        $ENV{$_} = $::BATCH_ENV{$_};
    }
    
    $command = $::BATCH_BIN . "/qsub";
    if ($self->name) { $command .= " -N " . $self->name; }
    $command .= " -o " . ($self->out ? $self->out : "/dev/null");
    $command .= " -e " . ($self->error ? $self->error : "/dev/null");
    if ($self->cputime) { $command .= " -l h_cpu=" . $self->cputime; }
    if ($::BATCH_ARG) { $command .= " " . $::BATCH_ARG; }
    $command .= " " . $self->script;
    
    open(CMDOUT, "$command|") || return undef;
    if ( <CMDOUT> =~ 'your job ([0-9]+) \(\"(.+)\"\) has been submitted' ) {
        $self->id($1);
        $self->name($2);
    };
    close(CMDOUT);
    
    return $self->id;
}

#### Method: submit_pbs
# Submit job using the Portable Batch System
####
sub submit_pbs {
    my $self = shift;
    my ($command);
    
    foreach (keys %::BATCH_ENV) {
        $ENV{$_} = $::BATCH_ENV{$_};
    }
    
    $command = $::BATCH_BIN . "/qsub";
    $command .= " -l walltime=12:00:00";
    if ($self->name) {
      $command .= " -N " . $self->name;
    }

   # Seems that pbs as of 6-20-2005 wants to write back out/err files to 
   # invokation directory.  Therefore, we'll put this line in to allow
   # jobs to finish gracefully.  
    my $script = $self->script();
    my ( $dir ) =  $script =~ /(.*\/)[^\/]+$/;
    my $outfile = ( $self->out() ) ? $self->out() : "$dir/pbs_job.out";

    $command .= " -W umask=0002 -j oe -o " . $outfile;

    # The above obviates this code, so it is commented out.
#    if ($self->out) { 
#  $command .= " -o " . $self->out(); 
#    } 
#    if ($self->error) { 
#   $command .= " -e ${dir}pbs_job.err"; 
#    }
   
    
    if ($self->cputime) { $command .= " -l walltime=" . $self->cputime; }
    if ($::BATCH_ARG) { $command .= " " . $::BATCH_ARG; }
    $command .= " " . $self->script;
    $log->error("COMMAND LINE '$command'");
    open(CMDOUT, "$command|") || die( "ERROR $!");
    $self->id(<CMDOUT>);
    close(CMDOUT);
    #print "ABOUT TO RETURN FROM SUBMIT PBS<br>";
    #print "COMMAND LINE <br>$command<br><br>";
    return $self->id;
}

#### Method: cancel_fork
# Cancel job run locally as a forked process
####
sub cancel_fork {
    my $self = shift;
    my ($command);
    
    kill(-15, $self->id) ||
        return undef;
    
    return $self->id;
}

#### Method: cancel_sge
# Cancel job submitted using the Sun Grid Engine
####
sub cancel_sge {
    my $self = shift;
    my ($command);
    
    foreach (keys %::BATCH_ENV) {
        $ENV{$_} = $::BATCH_ENV{$_};
    }
    
    $command = $::BATCH_BIN . "/qdel";
    $command .= " " . $self->id;
    
    open(CMDOUT, "$command|") || return undef;
    if ( <CMDOUT> !~ "has deleted job|has registered the job .+ for deletion" ) {
        return undef;
    }
    close(CMDOUT);
    
    return $self->id;
}

#### Method: cancel_pbs
# Cancel job submitted using the Portable Batch System
####
sub cancel_pbs {
    my $self = shift;
    my ($command);
    
    foreach (keys %::BATCH_ENV) {
        $ENV{$_} = $::BATCH_ENV{$_};
    }
    
    $command = $::BATCH_BIN . "/qdel";
    $command .= " " . $self->id;
    
    if ( system($command) ) {
        return undef;
    }
    
    return $self->id;
}

1;
