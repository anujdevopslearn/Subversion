#!/usr/local/bin/perl -w
#!/local/bin/perl -w

use Getopt::Long;
use FindBin qw( $Bin );
use File::Basename;
use File::Copy;
use lib ( "$Bin/../../perl" );
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Immunostain::Tables;

use strict;

main();
exit 0;

sub main {

  # Make connection
  my $sbeams = new SBEAMS::Connection;
  $sbeams->Authenticate() || die "Insufficient priviliges";
  my $dbh = $sbeams->getDBHandle() || die( "Unable to get database handle" );

  # Fetch passed options
  my %args = checkOpts();

  getImages( \%args, $dbh );

  }  # End main

sub getImages {

  my $args = shift;
  my $dbh = shift;

  my $export_path = $args->{export_path};

  my $sth = $dbh->prepare( <<"  END_SQL" );
  SELECT assay_image_id, processed_image_file, raw_image_file
  FROM $TBIS_ASSAY_IMAGE 
  END_SQL
  $sth->execute();

  my $data_path = $PHYSICAL_BASE_DIR . '/data/IS_assay_image/';
  $data_path =~ s/\/dev\w\w\//\//;

  while ( my ( $id, $proc, $raw ) = $sth->fetchrow_array() ) {
    my $old;
    my $new;
    if ( $proc ) { # default to processed file
      $old = "$data_path/${id}_processed_image_file.dat";
      $new = "$export_path/$proc";
      unless ( -e $old ) { # Is source file there?
        print "OLD IS $old\n";
        exit;
        print STDERR "Unable to find file for $proc ($old)\n";
        next;
      }
      if ( -e $new ) { # Is destination file there?
        print STDERR "file $new already exists ($id)\n";
        next;
      }

    } elsif ( $raw && $args->{use_raw} eq 'Yes' ) {
      $old = "$data_path/${id}_raw_image_file.dat";
      $new = "$export_path/$raw";
      unless ( -e $old ) {
        print STDERR "Unable to find file for $raw ($old)\n";
        next;
      }
      if ( -e $new ) {
        print STDERR "file $new already exists ($id)\n";
        next;
      }
      
    } else {
      print STDERR "No file found for ID: $id\n";
      next;
    }

  system( "/bin/cp -i $old '$new'" );
  }
}

sub checkOpts {
    my %args;
    GetOptions( \%args,"verbose", "export_path=s", "use_raw:s" );
    unless ( $args{export_path} ) {
      print "You must specify an export path\n";
      printUsage();
      exit 1;
    }
    $args{use_raw} ||= 'Yes';
    $args{use_raw} = ucfirst( $args{use_raw} );

    return %args;
  }
    


sub printUsage {
  my $program = basename( $0 );
  print <<"  EOU";
  Usage: $program -e my/export/path [-v] [-u Yes/No]
  Options:
    --verbose, -v           Set verbose messaging
    --export_path, -e       Directory to which to export file(s)
    --use_raw, -u           allow export of raw files or only processed files. 
                            Default is Yes. 
  EOU
}

