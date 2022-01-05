#!/usr/local/bin/perl 
use strict;
use DBI;
use Getopt::Long;
use File::Basename;
use Cwd qw( abs_path );
use FindBin;
use Data::Dumper;
use FileHandle;

use lib "$FindBin::Bin/../../perl";
use lib '/net/db/projects/spectraComparison';

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::PeptideAtlas;


$|++; # don't buffer output

my $sbeams = SBEAMS::Connection->new();
$sbeams->Authenticate();

my $atlas = SBEAMS::PeptideAtlas->new();
$atlas->setSBEAMS( $sbeams );

my $args = process_args();

my $dbh = $sbeams->getDBHandle();
$dbh->{RaiseError}++;

# TODO
# implement delete
# code to check supplied elution_time_type_id
# code to print list of available elution_time_type_id
# supress insert if other records with same type exist?
#

{ # Main 

  if ( $args->{delete} ) {
    print "Not yet implemented, alas!\n";
    exit;
  }

  if ( $args->{load} ) {

    open CAT, $args->{catalog_file} || die "unable to open cat file $args->{catalog_file}";
    my $cnt = 0;
    while ( my $line = <CAT> ) {
      chomp $line;
      my @line = split( "\t", $line, -1 );

      next if $line[0] =~ /Peptide/i;
      next if $line[0] =~ /Sequence/i;

      $args->{stderr_col} ||= 2;
      $args->{elution_time_col} ||= 1;
      unless( $args->{keep_rt} ) {
        $line[$args->{elution_time_col}] = $line[$args->{elution_time_col}]/60;
      }

      my $clean_seq = $line[0];
      $clean_seq =~ s/\[\d+\]//g;
      $cnt++;

      $line[$args->{stderr_col}] = -1 if $line[$args->{stderr_col}] =~ /NA/;

      my $rowdata = { peptide_sequence => $clean_seq,
                      modified_peptide_sequence => $line[0],
                      elution_time => $line[$args->{elution_time_col}],
                      SIQR => $line[$args->{stderr_col}],
                      elution_time_type_id => $args->{type_id},
                      elution_time_set => '' };

      my $id = $sbeams->updateOrInsertRow( insert => 1,
                                      table_name  => '$TBAT_ELUTION_TIME',
                                      rowdata_ref => $rowdata,
                                      verbose     => $args->{verbose},
                                     return_PK    => 1,
                                               PK => 'elution_time_id',
                                      testonly    => $args->{testonly} );
      print STDERR '*' unless $cnt % 500;
      print STDERR "\n" unless $cnt % 12500;
    }

    close CAT;
    print STDERR "loaded $cnt total rows\n";
  }

} # End Main


sub process_args {

  my %args;
  GetOptions( \%args, 'load', 'delete', 'catalog_file=s', 'type_id:i', 'stderr_col:i', 'elution_time_col:i', 'keep_rt' );

  print_usage() if $args{help};

  my $missing = '';
  for my $opt ( qw( type_id catalog_file ) ) {
    $missing = ( $missing ) ? $missing . ", $opt" : "Missing required arg(s) $opt" if !$args{$opt};
  }
  print_usage( $missing ) if $missing;

  unless ( $args{load} || $args{'delete'} ) {
    print_usage( "Must specify at least one of load and delete" );
  }

  if ( $args{load} && !$args{catalog_file} ) {
    print_usage( "Must catalog file in load mode" );
  }

  return \%args;
}


sub print_usage {
  my $msg = shift || '';
  my $exe = basename( $0 );

  print <<"  END";
      $msg

usage: $exe --elut type_id [ --load --cat catalog_file --dele ] 

   -d, --delete         Delete records with defined type_id
   -h, --help           print this usage and exit
   -l, --load           Load RT Catalog 
   -c, --catalog_file   File with RT Catalog data (we will load peptide sequence and RT mean
  END

  exit;

}

__DATA__
