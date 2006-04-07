#!/usr/local/bin/perl -w 
#+
# Command line script for installing SBEAMS.  Assumes that the sbeams source
# has already been downloaded as a tarball and unpacked, or else exported from
# the Subversion repository, will set up a sbeams and dev1 instance
#-

use File::Basename;
use Getopt::Long;
use FindBin qw($Bin);
use DBI;

use lib "$Bin/../../perl/";

use strict;

# Globals
# my $sbeams = new SBEAMS::Connection;
my %opts = ( module => [] );

# paths (relative to $SBEAMS) of helper scripts
my %scripts = ( Core       => 'lib/scripts/Core/build_core_dirs.sh',
                Microarray => 'lib/scripts/Microarray/build_ma_dirs.sh',
                encrypt_db => 'lib/scripts/Core/encryptDbPasswd.pl',
                crypt_pass => 'lib/scripts/Core/crypt.pl',
                schema     => 'lib/scripts/Core/build_schema.sh' );

# Array of supported modules
my @modules = qw(Microarray);

# Failed attempt to resolve the chicken/egg paradox
#BEGIN {
#  use FindBin qw($Bin);
#  unless ( -e "$Bin/../../conf/SBEAMS.conf" ) {
#    system( "cp $Bin/../../conf/SBEAMS.conf.template $Bin/../../conf/SBEAMS.conf" );
#  }
#}


{ # Main

  # collect and validate cmdline opts, set SBEAMS environment variable
  process_options();

  # Does sbeamscommon infrastructure exist?
  if ( -e "$ENV{SBEAMS}/../sbeamscommon" ) {
    # Setup is partially complete.
    unless ( $opts{force} ) {
      usage( "(at least) partial setup detected, use --force to overwrite" );
    } 
    print "Continuing install with force option\n" if $opts{verbose};
  }

  # Run core installer shell script, builds dirs/links
  print "Building Core directory structure\n" if $opts{verbose};
  system( "$ENV{SBEAMS}/$scripts{Core}" );

  # Optionally run individual module installer scripts 
  for my $m ( @{$opts{module}} ) {
    next unless $scripts{$m};
    print "Building $m directory structure\n" if $opts{verbose};
    my $results = system( "$ENV{SBEAMS}/$scripts{$m}" );
  }
  
  # Get user settings from sbeams.config file
  my ( $conf, $pop ) = read_config_file();
  
  # Write SBEAMS.conf file with values from template file
  print "Writing config files\n" if $opts{verbose};
  write_config_file( $conf );

  # Update Core POPULATE script 
  update_core_populate($pop);

  # Run build_schema script for core, biolink, and optional modules
  build_schema($conf);

}

sub build_schema {
  my $conf = shift;
  print "Building schema\n" if $opts{verbose};
  my $modstring = ( $opts{module} ) ? join " ", @{$opts{module}} : '';
  $ENV{DBUSER} = $conf->{DB_USER};
  $ENV{DBPASS} = $conf->{_DB_PASS};
  $ENV{DBTYPE} = ( $conf->{DB_TYPE} =~ /MS SQL/ ) ? 'mssql' :
                 ( $conf->{DB_TYPE} =~ /MySQL/ ) ? 'mysql' : 'pgsql';

  system( "$ENV{SBEAMS}/$scripts{schema}  $modstring "  );

}


sub read_config_file {

  # Find file with config values 
  my $cf = $opts{config} || "$ENV{SBEAMS}/lib/conf/sbeams.config";
  unless ( -e $cf ) {
    gen_tmp_config( config => $cf );
    usage( "Can't find configuration file" );
  }

  # Read config file
#  eval "use SBEAMS::Connection::Settings";
#  my $secs = SBEAMS::Connection::Settings::readIniFile( source_file => $cf );
  my $section = 'default';
  my %conf;
  my %pop;
  open( CFG, $cf ) || usage( "Unable to open config file" );
  while ( my $line = <CFG> ) {
    if ( $line =~ /\[\w+\]/ ) {
      $section = ( $line =~ /populate/ ) ? 'populate' : 'default';
      next;
    }
    next if $line =~ /^\s*$/ || $line =~ /^\s*#/;
    my @line = split /=/, $line;
    my $k = shift(@line);
    # Might have multiple equal signs...
    my $v = join "=", @line; 
    ($k) = $k =~ /^\s*(.*?)\s*$/;
    ($v) = $v =~ /^\s*(.*?)\s*$/;
    if ( $section eq 'default' ) {
      $conf{$k} = $v;
    } else {
      $pop{$k} = $v;
    }
    
  }
  return ( \%conf, \%pop );
}


sub test_db_connection {

  # User-defined settings
  my ( $user, $pass, $dbserver, $dbdriver, $dbname ) = @_;

  $dbdriver =~ s/\$DB_SERVER/$dbserver/g;
  $dbdriver =~ s/\$DB_DATABASE/$dbname/g;

  eval {
    my $dbh = DBI->connect($dbdriver, $user, $pass, {RaiseError => 1})
  };
  usage( "Failed to connect to the database: $@" ) if $@;

  print "Database connection tested OK\n" if $opts{verbose};


#  if ( $dbtype eq 'MS SQL Server' ) {
#  } elsif ( $dbtype eq 'MySQL' ) {
#  } elsif ( $dbtype eq 'PostgreSQL' ) {
#  }

#  eval {
#    use SBEAMS::Connection;
#    my $sbeams = SBEAMS::Connection->new();
#    my $dbh = $sbeams->getDBHandle();
#  };
#  usage($@) if $@;
}

sub update_core_populate {

  my $pop = shift;

  my %info = %$pop;

  # Check that there are values
  for my $k ( keys( %info ) ) {
    next if $k eq 'PASSWORD';
    usage( "Missing parameterage $k" ) unless $info{$k};
  }

  my $pop_file = "$ENV{SBEAMS}/lib/sql/Core/Core_POPULATE.sql";

  # Try to save a version
  for( my $i = 1; $i < 10; $i++ ) {
    unless( -e "$pop_file.$i" ) {
      system( "cp $pop_file $pop_file.$i" );
      last;
    }
  }

  # Open populate file for reading, slurp it in.
  my @pop;
  { 
    undef local $/;
    open ( POP,  $pop_file ) || usage( "Unable to open SQL file for reading" );
    @pop = split /\n/, <POP>;
  }
  close POP;
  
  open ( POP_W,  ">$pop_file" ) || usage( "Unable to open SQL file for writing" );

  my $edit = 0;
  for my $line ( @pop ) {
    chomp $line;

    $edit = 1 if ( $line =~ /^\/\*\s*EDIT BELOW:/ );
    $edit = 0 if ( $line =~ /^\/\*\s*EDIT ABOVE:/ );

    if ( !$edit ) {
      print POP_W "$line\n";
      next;
    }

    $line =~ s/First/$info{FIRSTNAME}/g;
    $line =~ s/LastName/$info{LASTNAME}/g;
    $line =~ s/NISusername/$info{USERNAME}/g;

    if ( $info{PASSWORD} && $line =~ /NULL/ ) {
      #$info{PASSWORD} = `$ENV{SBEAMS}/$scripts{crypt_pass} $info{PASSWORD}`;
      my $passwd = `$ENV{SBEAMS}/$scripts{crypt_pass} $info{PASSWORD}`;
      chomp $passwd;
      print "Translated $info{PASSWORD} into $passwd\n";  

      $line =~ s/NULL/\'$passwd\'/g;
    } elsif ( $line =~ /UPDATE user_login SET password/ ) {
      # Skip this line (don't print it)
      next;
    }
    print POP_W "$line\n";
  }
  close POP_W;
}

#+
# Routine to collect info from template file and write that to a new 
# SBEAMS.conf file.
# -
sub write_config_file {

  # From user settings file
  my $user_config = shift;
  my %config = ( %$user_config ); 
  my @keys = (sort(keys(%config)));

  my $conf = "$ENV{SBEAMS}/lib/conf/SBEAMS.conf";

  for my $k ( @keys ) {
    if ( !defined $config{$k} || $config{$k} eq '' ) {
      next if grep ( /$k/, ( qw(DB_PASS DB_RO_PASS DB_RO_USER) ) );
      # Missing in action!
      usage( "Missing mandatory configuration param, $k\n" );
    }
  }

  # read only user is optional
  $config{DB_RO_USER} ||= $config{DB_USER};

  # To avoid looping through conf file twice, deal with passwords separately
  $config{DB_PASS} ||= get_password('DB_PASS'); 
  
  # Save this for later...
  $user_config->{_DB_PASS} = $config{DB_PASS};

  # Test db settings
  test_db_connection(@config{qw(DB_USER DB_PASS DB_SERVER DB_DRIVER DB_DATABASE)});

  # Generate encrypted version of the password
  $config{DB_PASS} = `$ENV{SBEAMS}/$scripts{encrypt_db} -c $conf -p $config{DB_PASS}`;
  chomp $config{DB_PASS};

  # If the users are the same, use the DB_USER passwd.
  if ( $config{DB_RO_USER} eq $config{DB_USER} ) {
    $config{DB_RO_PASS} = $config{DB_PASS}; 
  
  } else {  # Go through the calculation
    $config{DB_RO_PASS} ||= get_password('DB_RO_PASS'); 

    # Run password encryption 
    $config{DB_RO_PASS} = `$ENV{SBEAMS}/$scripts{encrypt_db} -c $conf -p $config{DB_RO_PASS}`;
    chomp $config{DB_RO_PASS};
  }

  # Open conf file for reading, slurp it in.
  my @conf_file;
  { 
    undef local $/;
    open ( CONF,  $conf ) || usage( "Unable to open SBEAMS.conf file for reading" );
    @conf_file = split /\n/, <CONF>;
  }
  close CONF;
  
  open ( CONF_W,  ">$conf" ) || usage( "Unable to open SBEAMS.conf file for writing" );

  my $default = 0;
  my $main = 0;
  for my $line ( @conf_file ) {
    chomp $line;

    # Crude 'what section am I in?' code.
    $default = 0 if ( $default && $line =~ /^\s*\[\S+\]+\s*$/ );
    $main = 0 if ( $main && $line =~ /^\s*\[\S+\]+\s*$/ );
    $default++ if ( !$default && $line =~ /^\s*\[default\]\s*$/ );
    $main++ if ( !$main && $line =~ /^\s*\[main\]\s*$/ );

    # Handle non-default/main content.
    if ( $default || $main ) {
      if ( $line =~ /\s*#/ || !$line ) {
        print CONF_W "$line\n";

      } else { # Get keys from line, see if we have a value
        my @line = split /=/, $line;
        my $k = shift(@line);
        my $v = join "=", @line; 


        # Trim leading/lagging white space.
        ($k) = $k =~ /^\s*(.*?)\s*$/;

        # Is it one of ours?
        if ( grep /^$k/, @keys ) {
          my $value = $config{$k};
          print CONF_W "$k     = $value\n";
        } else {
          print CONF_W "$line\n";
        }
      }

    # Pass through all other sections
    } else {
      print CONF_W "$line\n";
    }
  }
}

sub get_password {
  my $key = shift;
  my $pass = '';
  my $type = ( $key eq 'DB_PASS' ) ? 'main' : 'read-only';
  while( $pass eq '' ) {
    print "Enter password for $type db user then [Enter] (cntl-C to quit):\t";
    $|++;
    system("stty -echo");
    $pass = <>;
    system("stty echo");
    chomp $pass;
    print "\n";
    if ( $pass eq '' ) {
      print "No input received.\n";
      $|++;
    }
  }
  return $pass;
}


sub process_options {

  GetOptions(\%opts, qw( verbose base=s force usage
                         config=s module=s )) || usage( $! );

  usage() if $opts{usage};

  # was base specified?  If not, calculate relative to self
  my $sbeams = $opts{base} || `cd $Bin/../../..; pwd;`;
  chomp $sbeams;

  if ( $ENV{SBEAMS} ) {
    if ( $opts{base} &&  $sbeams ne $ENV{SBEAMS} ) {
      usage( <<"      END" );
      specified base does not agree with \$SBEAMS envrionment variable.  Please
      unset var or don't specify base.
      BASE:        $opts{base}
      ENV{SBEAMS}: $ENV{SBEAMS}
      END
      exit;
    }
  } else {
    $ENV{SBEAMS} = $sbeams;
  }

  for my $m ( @{$opts{module}} ) {
    unless ( grep /^$m$/, @modules ) {
      usage( "Invalid module $m specified, see below for supported modules" );
    }
  }
}


sub gen_tmp_config {
}

sub usage {
  my $msg = shift || '';
  my $script = basename( $0 );

  my $modlist = join ", ", @modules;
  
  print <<"  END";
$msg
Usage: $script [ options ]

Options:
-v --verbose      Verbose output
-b --base         base (root) of sbeams installation.  defaults to sbeams in
                  script path.
-f --force        Replace existing files if encountered
-c --config       Config file to use, defaults to \$base/var/tmp/sbeams.config
-m --module       Module(s) to install, prepend each with -m flag. 
                  ($modlist) 

e.g. $script -v -b /var/www/html/sbeams -m Microarray -m Module2

  END
  exit;
}
