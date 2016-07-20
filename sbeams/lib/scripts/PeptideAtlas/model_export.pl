#!/tools/bin/perl

use Data::Dumper;

use lib '/net/dblocal/www/html/devDC/sbeams/lib/perl/';
use SBEAMS::Connection;
use SBEAMS::Connection::Permissions;
use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::PeptideAtlas::ModelExport;

my $sbeams = new SBEAMS::Connection;
$sbeams->Authenticate();

my @accessible = $sbeams->getAccessibleProjects( as_guest => 1, wg_module => 'PeptideAtlas' );

my $modelexporter = new SBEAMS::PeptideAtlas::ModelExport;
my $ids = [ 6595, 5322 ];
if ( scalar( @ARGV ) ) {
  $ids = [ @ARGV ];
}

my $build_id = $ARGV[0] || 448;

my $chk_sql = qq~
SELECT atlas_build_id
FROM $TBAT_ATLAS_BUILD
WHERE atlas_build_id = $build_id
~;

my ( $build_exists ) = $sbeams->selectOneColumn( $chk_sql );
if ( $build_exists ) {
  if ( $build_exists == $build_id ) {
  } else {
    print STDERR "Build mismatch\n";
    exit;
  }
} else {
  print STDERR "Build $build_id does not exist\n";
  exit
}

$chk_sql .= " AND project_id IN ( " . join( ',', @accessible ) . " )";
my ( $build_exists ) = $sbeams->selectOneColumn( $chk_sql );
if ( $build_exists ) {
  if ( $build_exists == $build_id ) {
  } else {
    print STDERR "Build mismatch\n";
    exit;
  }
} else {
  print STDERR "Build $build_id is not accessible\n";
  exit
}

print $modelexporter->getSamples( atlas_build_id => $build_id ,
                                  format => 'ddi',
                                  public_check  => $ARGV[1] );
