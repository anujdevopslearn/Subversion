#!/usr/local/bin/perl -w
#!/local/bin/perl -w

use vars qw(%DBPREFIX);
use Getopt::Long;
use FindBin qw( $Bin );
use lib ( "$Bin/../../perl" );
use lib ( "/net/dblocal/www/html/sbeams/lib/perl" );
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::BEDB::Tables;
use SBEAMS::BioLink::Tables;
use SBEAMS::Biosap::Tables;
use SBEAMS::Connection::Tables;
use SBEAMS::Cytometry::Tables;
use SBEAMS::Genotyping::Tables;
use SBEAMS::Immunostain::Tables;
use SBEAMS::Inkjet::Tables;
use SBEAMS::Interactions::Tables;
use SBEAMS::Microarray::Tables;
use SBEAMS::Ontology::Tables;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::PhenoArray::Tables;
use SBEAMS::ProteinStructure::Tables;
use SBEAMS::Proteomics::Tables;
use SBEAMS::SNP::Tables;
use SBEAMS::Tools::Tables;
use SBEAMS::Oligo::Tables;

use strict;

## Global variables ##
my $verbose = 0;
my $base = "/net/dblocal/www/html/sbeams/lib/";
my $msg = '';

main();
exit 0;

sub main {

  # Make connection
  my $sbeams = new SBEAMS::Connection;
  $sbeams->Authenticate() || die "Insufficient priviliges";
  my $dbh = $sbeams->getDBHandle() || die( "Unable to get database handle" );

  
  # Fetch passed options
  my %args = checkOpts();
#  foreach( keys( %args ) ){ print "$_ => $args{$_}\n" }
  my @modules = ( $args{all} ) ? keys(%DBPREFIX) :  @{$args{module}};


  # Loop de loop
  my $t_ok = 0;
  my $t_error = 0;
  my $t_undef = 0;
  my $mcount = 0;
  foreach my $mod ( @modules ){ 
    next if $mod eq 'APD';
    $mcount++;
    $msg .=<<"    END";


Module $mod, Prefix $DBPREFIX{$mod}
******************************************************
    END

    my $tref = readTableFile( $mod );
    my $cref = readColumnFile( $mod );
    my $results = checkSql( $tref, $cref, $dbh, $args{verbose}, $mod );
    # Increment counters
    $t_ok += $results->{ok};
    $t_error += $results->{problems};
    $t_undef += $results->{notdef};

    # Add current stats
    $msg .=<<"    END";
$results->{problems} tables had Errors
$results->{ok} tables were OK
$results->{notdef} tables were not defined in table_properties file

Details:
================
$results->{errs};
    END

    # Append any errors

  }
  print <<"  END_PRINT";
Summary
**********************
Total modules processed: $mcount
Total tables with tab_property errors: $t_error
Total tables without errors: $t_ok
Total tables not defined in table_property files: $t_undef
    
Individual module information
**********************
$msg

  END_PRINT

}  # End main

sub checkSql {
  my ( $tref, $cref, $dbh, $verbose, $mod ) = @_;
  my %sql;
  foreach my $table ( keys( %$tref ) ) {
    my $cols = join( ", ", keys( %{$cref->{$table}} ) );
    $sql{$table} = ( $cols ) ? "SELECT $cols FROM $tref->{$table}\n" : '';
  }
  $dbh->{RaiseError} = 1;
  my %results = ( problems => 0,
                  ok => 0,
                  errs => '' );

  for my $table ( keys( %sql ) ) { 
  my $err = '';
    eval {
      my $sth = $dbh->prepare( $sql{$table} );
      $sth->execute();
      $err = $dbh->errstr();
    };
    if ( $@ ) {
      $results{errs} .= "#######\n";
      $results{errs} .= "Execute error on $table\n";
      if($verbose) {
        $results{errs} .= "#######\n";
        $results{errs} .= "DBI Error:\n $@\n\n";
        $results{errs} .= "#######\n";
        $results{errs} .= "SQL that cause error:\n $sql{$table}\n";
        my $checkerr = '';
        my $result = '';
        my $csth;
        eval {
          $csth = $dbh->prepare( "SELECT TOP 1 * FROM $tref->{$table}" );
          $csth->execute();
          };
        if ( $@ ) {
          $results{errs} .= "Error fetching columns for $tref->{$table}: $checkerr\n";
        } else {
          $result = $csth->fetchrow_hashref();
          $results{errs} .= "#######\n";
          $results{errs} .= "Table_property defined $table columns are:\n " . join( ', ', keys( %$result ) ) . "\n\n";
        }
      }
      $results{problems}++;
    } else { 
      # print "OK on table $table\n" if $verbose;
      $results{ok}++;
    }
  }
#  $results{errs} .= "Saw $results{problems} tables with errors\n";
#  $results{errs} .= "Saw $results{ok} tables without errors\n";
  my @dberrs = checkdb( $dbh, $mod, $tref );
  $results{errs} .= $dberrs[1];
  $results{notdef} = $dberrs[0];
  return \%results;
}

sub checkdb {
  my $dbh = shift;
  my $mod = shift;
  my $tref = shift;
  $mod = ( $mod eq 'Core' ) ? 'sbeams' : $mod;
  my $err = '';
  eval {
    $dbh->do( "use $mod" );
    $err = $dbh->errstr();
  };
  if ( $@ ) {
    return( 0, "Unable to find database $mod: $err\n\n" );
  }

  my $sql = "sp_tables";
  my $sth = $dbh->prepare( $sql );
  $sth->execute();
  my @tables;
  my $tot = 0;
  while (my $r = $sth->fetchrow_hashref() ) {
    unless( !$r->{TABLE_NAME} || $r->{TABLE_NAME} =~ /^sys/ ) {
      $tot++;
      my $tval = uc($r->{TABLE_NAME}) . " ($r->{TABLE_TYPE})";
      unless( $tref->{uc($r->{TABLE_NAME})} ) {
        push @tables,  $tval . " => Not in table_properties"
      }
    }
  }
  my $inf = "$tot total tables/views in production db\n";
  $inf .= join "\n", @tables;
  return ( scalar( @tables ), $inf );

}

sub readTableFile {

  my $mod = shift || die "Failed to pass arguement reference";
  my $file = "$base/conf/$mod/$mod";

  open( TAB, "$file" . '_table_property.txt' ) || 
                           die ( "Cannot open table file $file" );
  my @expected_theads = ( qw(table_name Category table_group 
                             manage_table_allowed db_table_name PK_column_name
                             multi_insert_column table_url manage_tables
                             next_step ) );
  
  my $tline = <TAB>;
  chomp( $tline );
  $tline =~ s/[\r\n]//g;  # WTF
  my @theads = split("\t",$tline, -1);
  die "Incorrect number of entries in column file" if scalar( @theads ) != 10;
  my $index = 0;
  for ( @theads ) { 
    $_ = $1 if ( /^\"(.*)\"$/ );
    die ( "Unknown table heading $_" ) unless $_ eq $expected_theads[$index++];
  }
  my %table; # Hash keyed on table_name points at db_column_name
  while( my $line = <TAB> ) {
    $line =~ s/[\r\n]//g;  # WTF
    next if $line =~ /^\s*$/;
    my @guts = split("\t",$line, -1);
    $guts[0] =~ s/\"//g;
    $guts[4] =~ s/\"//g;
    $guts[0] = uc($guts[0]);
    next if $guts[2] eq 'QUERY';
    my @names = getRealTableName( @guts[0,4] ); 
    $table{uc($names[0])} = $names[1] if $names[0];
  }
  return \%table;

} # End readColumnFile


sub readColumnFile {

  my $mod = shift || die "Failed to pass arguement reference";
  my $file = "$base/conf/$mod/$mod";

  open( COL, "$file" . '_table_column.txt' ) || 
                          die ("Can't open column file $file");
  my @expected_cheads = ('table_name','column_index','column_name',
      'column_title','datatype','scale','precision','nullable',
      'default_value','is_auto_inc','fk_table','fk_column_name',
      'is_required','input_type','input_length','onChange','is_data_column',
      'is_display_column','is_key_field','column_text','optionlist_query',
      'url');
  
  my $cline = <COL>;
  chomp( $cline );
  $cline =~ s/[\r\n]//g;  # WTF
  my @cheads = split("\t",$cline, -1);
  die "Incorrect number of entries in column file" if scalar( @cheads ) != 22;
  my $index = 0;
  for ( @cheads ) {
    $_ = $1 if ( /^\"(.*)\"$/ );
    die "Unknown column heading $_" unless $_ eq $expected_cheads[$index++];
  }
  my %column; # hash of hashrefs where column name keys to datatype
  while( my $line = <COL> ) {
    $line =~ s/[\r\n]//g;  # WTF
    next if $line =~ /^\s*$/;
    my @guts = split("\t", $line, -1);
    $guts[0] =~ s/\"//g;
    $guts[2] =~ s/\"//g;
    $guts[4] =~ s/\"//g;
    $guts[0] = uc( $guts[0] );
    if ( $mod ne 'Core' ) {
      my @long = split "_", $guts[0];
      $guts[0] = join "_", @long[1..$#long];
    }
    $column{$guts[0]} ||= {};
    $column{$guts[0]}->{$guts[2]} = $guts[4];
  }
  return \%column;
} # End readColumnFile




  sub checkOpts {
    my %args;
    GetOptions( \%args, qw(verbose table=s column=s dsn:s all module:s@) );
    return %args;
  }
    


sub printUsage {
  print <<"  EOU";
  Usage: $0 -t tablefile -c columnfile -d DBIconnectString
  Options:
    --verbose, -v           Set verbose messaging
    --all, -a               Iterate through all known modules
    --module, -m            Specify a module or modules
    --table, -t  xxx        Set the name of table property file
    --column, -c xxx        Set the name of column property file
    --dsn, -d               DBI connect string
    
  EOU

}

sub getRealTableName {
  my $table = shift; # table name
  my $dbtable = shift; # db table name
  $dbtable =~ s/\"//g;

  my $realname = eval "\"$dbtable\"";
  my @names = split ".dbo.", $realname;
  my $realbase = @names[1];

  if ( $realname && $realbase ) { # Defined in imported symbols.
    return ( $realbase, $realname );
  } else {
    $msg .= "Unable to evaluate variable $dbtable for table $table\n";
    return;
  }

## Legacy guess work below!  

  my $prefix = substr( $table, 0, 3 ); 
  my $strip = $table;
  if ( $prefix =~ /[A-Z][A-Z]_/ ) {
    $strip =~ s/$prefix//;
  }
   
  my $linker = '.dbo.'; # linker
  return 'PeptideAtlas' . $linker . $strip if $prefix eq 'AT_';
  return 'BioLink' . $linker . $strip if $prefix eq 'BL_';
  return 'Proteomics' . $linker . $strip if $prefix eq 'PR_';
  return 'Microarray' . $linker . $strip if $prefix eq 'MA_';
  return 'BioSequence' . $linker . $strip if $prefix eq 'BS_';
  return 'InkJet' . $linker . $strip if $prefix eq 'IJ_';
  return 'SNP' . $linker . $strip if $prefix eq 'SN_';
  return 'BioSequence' . $linker . $strip if $prefix eq 'BS_';
  return 'Cytometry' . $linker . $strip if $prefix eq 'CY_';
  return 'Genotyping' . $linker . $strip if $prefix eq 'GT_';
  return 'Immunostain' . $linker . $strip if $prefix eq 'IS_';
  return 'Interactions' . $linker . $strip if $prefix eq 'IN_';
  return 'Oligo' . $linker . $strip if $prefix eq 'OG_';
  return 'Phenoarray' . $linker . $strip if $prefix eq 'PH_';
  return 'Interactions' . $linker . $strip if $prefix eq 'IN_';
  return 'ProteinStructure' . $linker . $strip if $prefix eq 'PS_';
  return 'UESC' . $linker . $strip if $prefix eq 'PH_';
  return 'sbeams' . $linker . $table;
 }
