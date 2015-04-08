package SBEAMS::Connection;

###############################################################################
# Program     : SBEAMS::Connection
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : Perl Module to handle all SBEAMS connection issues, including
#               authentication and DB connections.
#
###############################################################################


use strict;
use vars qw($VERSION @EXPORT @EXPORT_OK $invocation_mode $output_mode 
            $output_stage $table_nest_level $q);

require Exporter;
use SBEAMS::Connection::Log;

# We import the $q object created in Authenticator
use SBEAMS::Connection::Authenticator qw( $q );

our @ISA =  qw( Exporter );
our $log = SBEAMS::Connection::Log->new();

# Export the log object we created, reexport $q from Authenticator.
@EXPORT_OK = qw( $log $q );

use SBEAMS::Connection::DBConnector;
use SBEAMS::Connection::DBInterface;
use SBEAMS::Connection::HTMLPrinter;
use SBEAMS::Connection::TableInfo;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::ErrorHandler;
use SBEAMS::Connection::Utilities;
use SBEAMS::Connection::Permissions;

push @ISA, qw(SBEAMS::Connection::Authenticator 
           SBEAMS::Connection::DBConnector
           SBEAMS::Connection::DBInterface 
           SBEAMS::Connection::HTMLPrinter
           SBEAMS::Connection::TableInfo
           SBEAMS::Connection::Settings
           SBEAMS::Connection::ErrorHandler
           SBEAMS::Connection::Utilities
           SBEAMS::Connection::Permissions
           );



###############################################################################
# Global Variables
###############################################################################
$VERSION = '0.02';


###############################################################################
# Constructor
###############################################################################
sub new {

  my $this = shift;
  my $class = ref($this) || $this;
  my $self = { '_nocache_sql' => 1 };
  bless($self,$class);

  ## register with Connection::ErrorHandler:
  $self->register_sbeams($self);

  return($self);

} # end new

sub enable_sql_cache {
  my $self = shift;
  $self->{_nocache_sql} = 0;
  $log->debug( "Caching enabled" );
  $log->debug( "Caching enabled like I said" ) unless $self->{_nocache_sql};
}

###############################################################################
# Getter/setter for invocation_mode
###############################################################################
sub invocation_mode {
  my $self = shift;
  my $new_value = shift;

  my $METHOD_NAME = "invocation_mode()";

      #### If a new value was supplied, set it
  if ($new_value) {
    die "$METHOD_NAME: Illegal value '$new_value'"
      unless ($new_value eq 'http' || $new_value eq 'user' || $new_value eq 'https');
    $invocation_mode = $new_value;

  #### Otherwise, verify that we have a value or set a blank
  } elsif ( !$invocation_mode ) {
    $invocation_mode = ( $ENV{REMOTE_ADDR} ) ? 'http' : 'user';
    if ( defined $q ) {
      $invocation_mode = 'https' if $q->url() =~ /https/;
    }
  }

  #### Return the current value in either case
  return $invocation_mode;

} # end invocation_mode

#+
# Light-weight accessor
#-
sub get_output_mode {
  my $self = shift;
  return $output_mode || $self->output_mode();
}

###############################################################################
# Getter/setter for output_mode
###############################################################################
sub output_mode {
  my $self = shift;
  my $new_value = shift;

  my $METHOD_NAME = "output_mode()";

  my @legal_modes = (qw( html interactive tsv tsvfull csv csvfull xml cytoscape
                         boxtable print excel excelfull) );

  #### If a new value was supplied, set it
  if ( $new_value ) {
    if ( grep(/^$new_value$/, @legal_modes) ) {
    $output_mode = $new_value;
    } else {
     $output_mode = ( $self->invocation_mode() eq 'http' ) ? 'html' : 'tsv';
     $self->handle_error( error_type => 'bad constraint',
                             message => "'$new_value' is not a recognized output mode",
                         output_mode => $output_mode, 
                        force_header => 1 );
    }
  #### Otherwise, verify that we have a value
  } else {
    unless ($output_mode) {
      $output_mode = 'interactive';
      print "$METHOD_NAME: value has not yet been set!  This should never ".
        "happen, but I will set it to interactive just to see where this ".
        "ends up.  It is almost surely a bug that needs ".
        "to be reported.<BR><BR>\n\n";
    }
  }

  #### Return the current value in either case
  return $output_mode;

} # end output_mode


###############################################################################
# Getter/setter for output_stage
###############################################################################
sub output_stage {
  my $self = shift;
  my $new_value = shift;

  my $METHOD_NAME = "output_stage()";

  #### If a new value was supplied, set it
  if ($new_value) {
    die "$METHOD_NAME: Illegal value '$new_value'"
      unless ($new_value eq 'no_header_yet' || $new_value eq 'form_stage' ||
              $new_value eq 'data_stage' || $new_value eq 'footer_complete'
      );
    $output_stage = $new_value;

  #### Otherwise, verify that we have a value
  } else {
    die "$METHOD_NAME: value has not yet been set!"
      unless ($output_stage);
  }

  #### Return the current value in either case
  return $output_stage;

} # end output_stage


###############################################################################
# Getter/setter for table_nest_level
###############################################################################
sub table_nest_level {
  my $self = shift;
  my $new_value = shift;

  my $METHOD_NAME = "table_nest_level()";

  #### If a new value was supplied, set it
  if ($new_value) {
    die "$METHOD_NAME: Illegal value '$new_value'"
      unless ($new_value >= 0);
    $table_nest_level = $new_value;

  #### Otherwise, verify that we have a reasonable value
  } else {
    $table_nest_level = 0 unless ($table_nest_level);
  }

  #### Return the current value in either case
  return $table_nest_level;

} # end table_nest_level

#+
# Method allows temporary shunting of STDOUT to a file.  Useful if you wish
# to make grab output from a printing method into a scalar.
#
# Must be called in pairs with fetchSTDOUT method below, which cleans up and
# returns the captured output.
#-
sub collectSTDOUT {
  my $self = shift;

  if ( $self->{_stdout_collector} ) {
    die 'Can\'t call collectSTDOUT twice without calling fetchSTDOUT';
  }

  # Generate random filename
  $self->{_stdout_collector} = $self->getRandomString( num_chars => 20 );
  my $so_file = "$PHYSICAL_BASE_DIR/tmp/$self->{_stdout_collector}";

  # dup STDOUT
  open( OLDOUT, ">>&STDOUT" ) || die ("can't redirect STDOUT");
  close(STDOUT);

  # store dup'd STDOUT
  $self->{_OLDOUT} = *OLDOUT;
  
  # Open STDOUT as a filehandle to a temporary file
  open( STDOUT, ">$so_file" ) || die "Canna open STDOUT $!";
  return;

  # Original version relied on IO::Scalar, removed so as not to introduce
  # that dependancy.
}

#+
# Method reads cached STDOUT from tmp file and returns it as a scalar.
#-
sub fetchSTDOUT {
  my $self = shift;

  # Close file writing STDOUT
  close(STDOUT);

  # Read from temp file
  my $so_file = "$PHYSICAL_BASE_DIR/tmp/$self->{_stdout_collector}";
  open( FILEOUT, "$so_file" ) || die "Canna open FILEOUT";

  my $fileout;
  {
    undef local $/;
    $fileout = <FILEOUT>;
  }
  close FILEOUT;

  system( "rm $so_file" );
  delete $self->{_stdout_collector};

  # Restore normal STDOUT
  open(STDOUT, ">&OLDOUT") || die "Can't restore stdout: $!";

  return $fileout;

}

sub deleteSBEAMSTempFile {
  my $self = shift;
	my %args = @_;

	return unless $args{filename}; 
	$args{dirname} ||= '';
	$args{filename} .= '.' . $args{suffix}  if $args{suffix};
	my $tmp_path = "$PHYSICAL_BASE_DIR/tmp/";

	my $abs_path = join( '/', $tmp_path, $args{dirname}, $args{filename} );
	unlink( $abs_path );

}

sub writeSBEAMSTempFile {
  my $self = shift;
	my %args = @_;

  # If we don't have content, nothing to do
	return undef if !$args{content};

  # Generate random filename iff necessary 
	$args{filename} ||= $self->getRandomString( num_chars => 20 );
	$args{dirname} ||= '';
	$args{filename} .= '.' . $args{suffix}  if $args{suffix};
	my $tmp_path = "$PHYSICAL_BASE_DIR/tmp/";

	if ( $args{newdir} && $args{dirname} ) {
		$tmp_path .= $args{dirname} . '/';
		system( "mkdir $tmp_path");
	}
	my $abs_filename = $tmp_path . $args{filename};

	open( TMPFIL, ">$abs_filename" ) || $self->my_die("unable to open $abs_filename");
	print TMPFIL $args{content};
	close TMPFIL;
	return $abs_filename;
}


sub makeSBEAMSTempLink {
  my $self = shift;
	my %args = @_;

  # If we don't have content, nothing to do
	return undef if !$args{path};

  # Generate random filename iff necessary 
	$args{linkname} ||= $self->getRandomString( num_chars => 20 );

	my $tmp_path = "/tmp/" . $args{linkname};
  unless( $args{relative} ) {
	  $tmp_path = "$PHYSICAL_BASE_DIR/$tmp_path";
  }

	if ( ! -e $tmp_path ) {
		system( "ln -s $args{path} $tmp_path");
    print STDERR "linked $args{path} to $tmp_path!\n";
	} else {
    print STDERR "$tmp_path already links to $args{path}\n";
  }
}


sub my_die {
  my $self = shift;
  # Carp fatals to browser is evil!
  my $msg = shift || '';
  print STDERR "$msg\n";
  # d = 4, i = 9, e = 5, sum is 18
  exit( 18 );
}

sub readSBEAMSTempFile {
  my $self = shift;
	my %args = @_;

  # If we don't have filename, nothing to do
	return undef if !$args{filename};
	$args{dirname} ||= '';
	my $tmp_path = "$PHYSICAL_BASE_DIR/tmp/" . $args{dirname} . '/' . $args{filename};
	if ( -e $tmp_path ) {
		undef local $/;
	  open( TMPFIL, "$tmp_path" ) || die "unable to open $tmp_path";
		my $contents = <TMPFIL>;
	  close TMPFIL;
		return $contents;
	} else {
		$log->warn( "Unable to open temp file $tmp_path" );
		return undef;
	}
}

sub doesSBEAMSTempFileExist {
  my $self = shift;
	my %args = @_;

  # If we don't have filename, nothing to do
	return undef if !defined $args{filename};
	$args{dirname} ||= '';
	my $tmp_path = "$PHYSICAL_BASE_DIR/tmp/" . $args{dirname};
	$tmp_path .= '/' . $args{filename} if $args{filename};

	if ( -e $tmp_path ) {
		return $tmp_path;
	} else {
		return 0;
	}
}

#+
# Method to add contact, user_login, and user_work_group records 
# in one fell swoop.  Will not create work group if it does not 
# already exist.
#
#-
sub addUserAndGroups {
  my $self = shift;
  my %args = @_;
  my $err;
  for my $param ( qw( first_name last_name username lab_id group_id work_groups  ) ) {
    unless ( $args{$param} ) {
			$err = ( $err ) ? $err . ', ' . $param : "Missing required param(s) $param";
		}
  }
	$self->handle_error( message => $err, error_type => 'insufficient_constraints' ) if $err;

  my $contact_where = qq~
	WHERE first_name = '$args{first_name}' AND last_name = '$args{last_name}' 
	AND record_status <> 'D'
	~;
  
  my $ulogin_where = qq~
	WHERE username = '$args{username}' 
	AND record_status <> 'D'
	~;

  my %work_groups = %{$args{"work_groups"}};  # hash of work_group_name = privilege for that work_group
  my %wg_by_id;  # hash of work_group_id = privilege for that work_group
  foreach my $work_group_name (keys %work_groups) {
    
    my $wgroup_where = qq~
	WHERE work_group_name = '$work_group_name' 
	AND record_status <> 'D'
	~;
  
    # Does work group exist?
    my $wg_id = $self->recordExists( table => $TB_WORK_GROUP,
	                                 clause => $wgroup_where,
				         field => 'work_group_id' );
    unless ( $wg_id ) {
	  $self->handle_error( message => 'Work group does not exist', error_type => 'sbeams_error' );
    }

    $wg_by_id{$wg_id} = $work_groups{$work_group_name};
  }

  # Does contact exist?
  my $contact_id = $self->recordExists( table => $TB_CONTACT, 
	                                clause => $contact_where,
                                        field => 'contact_id' );

  if ( $contact_id ) {
		$log->warn( "contact record exists, not adding" );
	} else {
		$contact_id = $self->addContact( first_name => $args{first_name},
		                                 last_name => $args{last_name},
						 lab_id => $args{lab_id},
						 group_id => $args{group_id}
                                                );
	}
  unless ( $contact_id ) {
	  $self->handle_error( message => 'Contact_id doew not exist', error_type => 'sbeams_error' );
	}

  # Does username (user_login) exist?
	my $user_login_id;
  if ( $self->recordExists( table => $TB_USER_LOGIN, clause => $ulogin_where ) ) {
		$log->warn( "user_login record exists, not adding" );
	} else {
		$user_login_id = $self->addUserLogin( username => $args{username},
		                                      contact_id => $contact_id );
	}

  foreach my $work_group_id (keys %wg_by_id) {
    my $uwgroup_where = qq~
  	WHERE contact_id = $contact_id 
	AND work_group_id = $work_group_id
	~;
	my $uwg_id;

	# Does user work group exist?
    if ( $self->recordExists( table => $TB_USER_WORK_GROUP, clause => $uwgroup_where ) ) {
		$log->debug( "record exists, skipping" );
	} else {
		$uwg_id = $self->addUserWorkGroup( contact_id => $contact_id,
		                                 privilege_id => $wg_by_id{$work_group_id},
		                                work_group_id => $work_group_id ) ;
	}
  }


  return $contact_id;
}

sub memusage {
	my $self = shift;
	my %args = @_;

	my $pid = $args{pid} || return '';

  my @results = `ps -o pmem,pid $pid`;
  my $mem = '';
  for my $line  ( @results ) {
    chomp $line;
    if ( $line =~ /\s*(\d+\.*\d*)\s+$pid/ ) {
      $mem = $1;
      last;
    }
  }
  $mem .= '% (' . time() . ')';
  return $mem;
}

###############################################################################

1;

__END__
###############################################################################
###############################################################################
###############################################################################


=head1 NAME

 SBEAMS::Connection - The SBEAMS Core database connection module

=head1 DESCRIPTION

Handles all SBEAMS connection issues, including authentication and DB 
connections.  

It multiply inherits

    SBEAMS::Connection::Authenticator

    SBEAMS::Connection::DBConnector
    
    SBEAMS::Connection::DBInterface 

    SBEAMS::Connection::HTMLPrinter

    SBEAMS::Connection::TableInfo

    SBEAMS::Connection::Settings

    SBEAMS::Connection::ErrorHandler

    SBEAMS::Connection::Utilities

    SBEAMS::Connection::Permissions


=head2 EXAMPLE USAGE

    ##load Connection modules and create instance:
    use SBEAMS::Connection;
    use SBEAMS::Connection::Settings;
    use SBEAMS::Connection::Tables;

    $sbeams = new SBEAMS::Connection;

    ##load module of interest and create instance:
    use SBEAMS::PeptideAtlas;
    use SBEAMS::PeptideAtlas::Settings;
    use SBEAMS::PeptideAtlas::Tables;

    $sbeamsMOD = new SBEAMS::PeptideAtlas;
    $sbeamsMOD->setSBEAMS($sbeams);
    $sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

    ## load CGI module and create instance:
    use CGI;
    $q = new CGI;

    ## authenticate user:
    exit unless ($current_username = $sbeams->Authenticate(
        allow_anonymous_access => 1
    ));


    ## read in parameters passed to script:
    my %parameters;

    my $n_params_found = $sbeams->parse_input_parameters(
        q => $q,
        parameters_ref => \%parameters
    );


    ## perform action or display HTML:
    if ($parameters{action} eq "doThis") {
        doThis();
    } else {
        $sbeamsMOD->display_page_header( navigation_bar => $parameters{navigation_bar});
        handle_request(ref_parameters=>\%parameters);
        $sbeamsMOD->display_page_footer();
    }




=head2 METHODS

=over

=item * B<new>

constructor registers the instance with Connection::ErrorHandler

=item * B<invocation_mode>

get/set method.  expecting values such as
    'http'
    'user' 
    'https'
    ""

=item * B<output_mode>

get/set method.  expecting values such as
   'html' 
   'interactive' 
   'tsv'
   'tsvfull' 
   'csv' 
   'csvfull'
   'xml'
   'cytoscape' 
   'boxtable'
   'excel'
   'excelfull'

output_mode is used by Connection::Authenticator, 
Connection::DBInterface, and Connection::HTMLPrinter
to direct output to html or a tsv formatted file, for example

=item * B<output_stage>

get/set method.  expecting values such as
    'no_header_yet'
    'form_stage'
    'data_stage'
    'footer_complete'


=item * B<table_nest_level>

get/set method.  expecting values >= 0


=back

=head2 BUGS

Please send bug reports to the author

=head2 AUTHOR

Eric Deutsch <edeutsch@systemsbiology.org>

=head2 SEE ALSO

SBEAMS::Connection::Authenticator

SBEAMS::Connection::DBConnector

SBEAMS::Connection::DBInterface

SBEAMS::Connection::HTMLPrinter

SBEAMS::Connection::TableInfo

SBEAMS::Connection::Settings

SBEAMS::Connection::ErrorHandler

SBEAMS::Connection::Utilities

SBEAMS::Connection::Permissions


=cut
