{package SBEAMS::Glycopeptide::Glyco_peptide_load;
		
# Module handles loading peptide/protein information into the unipep
# database (AKA glycopeptide).  Due to a change in input file format 
# there are currently some unused subroutines, will cull when possible.

use strict;

use File::Basename;
use File::Find;
use File::stat;
use Data::Dumper;
use Carp;
use FindBin;
use POSIX qw(strftime);
use Benchmark;

		
use SBEAMS::Connection qw($log);
use SBEAMS::Connection::Tables;
use SBEAMS::Glycopeptide::Tables;
use SBEAMS::Glycopeptide;

my $module = SBEAMS::Glycopeptide->new();


#######################################################
# Constructor
#######################################################
sub new {
	my $class = shift;
	
  my %args = @_;
  my $sbeams = $args{sbeams} || SBEAMS::Connection->new();
  my $verbose = $args{verbose} || 0;
  my $debug  = $args{debug};
  my $test_only = $args{test_only};
  my $file = $args{file};
  my $release = $args{release} || $args{file};
  
  my $self = {    _file => $file,
               _release => $release};
	
  bless $self, $class;
	
  $self->setSBEAMS($sbeams);
  $self->verbose($verbose);
  $self->debug($debug);
  $self->testonly($test_only);
	
  return $self;
}
###############################################################################
# Cache the main SBEAMS object
###############################################################################
sub setSBEAMS {
  my $self = shift;
  my $sbeams = shift;
  $self->{_SBEAMS} = $sbeams;
}


###############################################################################
# Provide the main SBEAMS object
###############################################################################
sub getSBEAMS {
  my $self = shift;
  return $self->{_SBEAMS};
}

###############################################################################
# Get/Set the VERBOSE status
#
#
###############################################################################
sub verbose {
	my $self = shift;
  my $verbose = shift;
		
	if (defined $verbose){ #it's a setter
		$self->{_VERBOSE} = $verbose;
	}

	return $self->{_VERBOSE};
}
###############################################################################
# Get/Set the DEBUG status
#
#
###############################################################################
sub debug {
	my $self = shift;
	
		
	if (@_){
		#it's a setter
		$self->{_DEBUG} = $_[0];
	}else{
		#it's a getter
		$self->{_DEBUG};
	}
}
###############################################################################
# Get/Set the TESTONLY status
#
#
###############################################################################
sub testonly {
	my $self = shift;
	if (@_){
		#it's a setter
		$self->{_TESTONLY} = $_[0];
	}else{
		#it's a getter
		return $self->{_TESTONLY} || 0;
	}
}

##############################################################################
# Get file to parse
#
#
###############################################################################
sub getfile {
	my $method = 'getfile';
	my $self = shift;
	
	return	$self->{_file};
}

sub insert_ipi_db {
	my $self = shift;
  my %args = @_;

  my @all_data = ();
  
  my $file = $self->getfile();

  open DATA, $file || die "Unable to open file $file $!\n";
  my %heads;

	my $count = 0;
	my $insert_count = 1;
  my $t0 = new Benchmark;
  my %stats;

  my $sbeams = $self->getSBEAMS();
  my %time;

  # Hash of info for IPI records
  my %file_data;
  my %seq_to_accession;
  $self->{_seq_to_id} = {};
  
  print "Processing file\n";
  while(<DATA>) {
    chomp;
    my @tokens = split( /\t/, $_, -1);
    $count ++;
			
    # populate global hash of col_name => col_index. 
		if ($count == 1){
      # Make them lower case for consistancy
      @tokens = map {lc($_)} @tokens;

      # Build header index hash
		  @heads{@tokens} = 0..$#tokens;

      # See if col headers have changed
      $self->checkHeaders(\%heads);
 
      # Everything has checked out, start inserts.
      # Does this version already exist?
    	$self->check_version(%args);

      next;
    }

    # print progress 'bar'
    unless ( $count % 100 ){
      print '*';
#      print "\n"; last;  # Short circuit!
    }
    unless ( $count % 5000 ){
      my $t1 = new Benchmark;
      my $time =  timestr(timediff($t1, $t0)); 
      $time =~ s/^[^\d]*(\d+) wallclock secs.*/$1/;
      my $verb = ( $args{testonly} ) ? 'Found' : 'Processed';
      print "$verb $count records, $time seconds\n";
    }

    my $ipi = $tokens[$heads{'ipi'}];
                                      
    if ( $stats{$ipi} || $self->check_ipi($ipi) ) {
      $stats{$ipi}++;
    } else {
      $stats{$ipi}++;
      $stats{total}++;

      my $motif = 'N[^P][ST]';

      my $sites = $module->get_site_positions( seq => $tokens[$heads{'protein sequences'}],
                                           pattern => $motif,
                                        index_base => 1);


      # Get theoretical digestion of protein
      my $peptides = $module->do_tryptic_digestion( aa_seq => $tokens[$heads{'protein sequences'}],
                                                  flanking => 1 );
     
      foreach my $pep ( @$peptides ) {
        my $match = $module->clean_pepseq( $pep );
        $match = substr( $match, 0, 900 ) if length($match) > 900; 
        # hash peptide sequence to ipi_data_id info
        $self->{_seq_to_id}->{uc($match)} ||= {};
        $self->{_seq_to_id}->{uc($match)}->{$ipi}++;
      }

      $file_data{$ipi} = { rowdata => \@tokens,
                          peptides => $peptides,
                             sites => $sites };
    }
#    last if $stats{total} > 100;
  } # End file reading loop

  print "Read $count records\n";
#  return if $args{testonly};

  # Rubber, meet road...
  print "Inserting data\n";

  $sbeams->initiate_transaction();
  my $commit_interval = 20;
  # Insert version record
  $self->add_ipi_version( %args ) unless $args{testonly};
  $count = 0;
  for my $acc ( sort(keys( %file_data) ) ) {
    $count++;
    # print progress 'bar'
    unless ( $count % 100 ){
      print '*';
    }
    unless ( $count % 5000 ){
      my $t1 = new Benchmark;
      my $time =  timestr(timediff($t1, $t0)); 
      $time =~ s/^[^\d]*(\d+) wallclock secs.*/$1/;
      my $verb = ( $args{testonly} ) ? 'loaded' : 'processed';
      print "$verb $count records, $time seconds\n";
    }


    my $tokens = $file_data{$acc}->{rowdata};
    eval {
      my $ipi_id = $self->add_ipi_record( $tokens );
      my $site_idx = $self->add_glycosites( glyco_score => $tokens->[$heads{'nxt/s score'}],
                                            ipi_data_id => $ipi_id,
                                       protein_sequence => $tokens->[$heads{'protein sequences'}],
                                               site_idx => $file_data{$acc}->{sites}
                                            );

       $self->add_predicted_peptides( sequence => $tokens->[$heads{'protein sequences'}],
                                   ipi_data_id => $ipi_id, 
                                      site_idx => $file_data{$acc}->{sites},
                                           ipi => $acc,
                                      peptides => $file_data{$acc}->{peptides} );
      };
      if ( $@ ) {
        $sbeams->rollback_transaction();
        die( "$@" );
      } else {
        # Space commits to once per n sequences
        unless ( $count % $commit_interval ) {
          $sbeams->commit_transaction(); 
          $sbeams->initiate_transaction();
        }
      }
    }
    $sbeams->commit_transaction(); 
#    $stats{max} = ( $stats{$ipi} > $stats{max} ) ? $stats{$ipi} : $stats{max};
#  for my $k ( keys(%time) ) { print "$k => $time{$k}\n"; }
#  $count -= 1;
#  print "\n\n$stats{total} unique ipi entries in $count total rows (max count was $stats{max})\n";
#  my $t2 = new Benchmark;
#  print "\nFinished in " . timestr(timediff($t2, $t0)) . "\n";
}

###############################################################################
# process_data_file
#
###############################################################################
sub process_data_file {
	my $self = shift;
  my %args = @_;
  $args{load_peptides} = 1 if !defined $args{load_peptides};
	
  my @all_data = ();
  
  my $file = $self->getfile();

  open DATA, $file || die "Unable to open file $file $!\n";
  my %heads;

	my $count = 0;
	my $insert_count = 1;
  my $t0 = new Benchmark;
  while(<DATA>) {
    chomp;
    my @tokens = split( /\t/, $_, -1);
			
    # populate global hash of col_name => col_index. 
		if ($count == 0){
      # Make them lower case for consistancy
      @tokens = map {lc($_)} @tokens;

      # Build header index hash
		  @heads{@tokens} = 0..$#tokens;
			$count ++;

      # See if col headers have changed
      $self->checkHeaders(\%heads);

    }
    $count ++;

    # print progress 'bar'
    unless ( $count % 100 ){
      print '*';
    }
    unless ( $count % 5000 ){
      my $t1 = new Benchmark;
      my $time =  timestr(timediff($t1, $t0)); 
      $time =~ s/^[^\d]*(\d+) wallclock secs.*/$1/;
      my $verb = ( $args{testonly} ) ? 'Found' : 'Processed';
      print "$verb $count records, elapsed time $time seconds\n";
    }

		$self->add_ipi_record( \@tokens ) unless $self->check_ipi($tokens[$heads{'ipi'}]);
		
		my $glyco_pk = $self->add_glyco_site( \@tokens );
			
	  if ( $tokens[$heads{'predicted tryptic nxt/s peptide sequence'}] ) {
	  	$self->add_erpdicted_peptide( glyco_pk   => $glyco_pk,
									              	  line_parts => \@tokens);
    }
			
    # add identifed peptide iff there is one.
	  if ( $args{load_peptides} && $tokens[$heads{'identified sequences'}] ) {
    
		  $self->add_identified_peptides( glyco_pk   => $glyco_pk,
	                  								  line_parts => \@tokens);
    }
			
  }
  if ( $args{testonly} ) {
    print "\nIPI file had correct headers, $count total rows\n";
    exit;
  }
  my $t2 = new Benchmark;
  my $pcnt = $self->{_id_peps};
  print "\nTotal peptides was " .  scalar(keys(%$pcnt) ) ."\n";
  print "\n\nLoaded $count total records in " . timestr(timediff($t2, $t0)) . "\n";
}


sub checkHeaders {
  my $self = shift;
  my $heads = shift;
  my %heads = %$heads;
  my @known_columns = ( 'IPI',
                            'Protein Name',
                            'Protein Sequences',
                            'Protein Symbol',
                            'Swiss-Prot',
                            'Summary',
                            'Synonyms',
                            'Protein Location',
                            'signalP',
                            'TM',
                            'TM location',
                            'Peptide IPI',
                            'NXT/S Location',
                            'NXT/S Score',
                            'Predicted Tryptic NXT/S Peptide Sequence',
                            'Predicted Peptide Mass',
                            'Database Hits',
                            'Database Hit IPIs',
                            'Min Similarity Score',
                            'Detection Probability',
                            'Identified Sequences',
                            'Tryptic Ends',
                            'Peptide ProPhet',
                            'Identified Peptide Mass',
                            'Identified Tissues',
                            'Number Observations',
                         );
  @known_columns = map { lc($_) } @known_columns;
  my @current_cols = keys(%heads);

  for my $curr_col ( @current_cols ) {
    unless( grep /$curr_col/, @known_columns ) {
      die "Column $curr_col is not known by the parser\n";
    }
  }

  for my $parser_col ( @known_columns ) {
    unless( grep /$parser_col/, @current_cols ) {
      die "Column $parser_col is missing in this file\n";
    }
  }
  # We got past the checks, cache the header values.
  $self->{_heads} = \%heads;
  return 1;
}

=head1 example columns
0 IPI => IPI00015102
1 Protein Name => CD166 antigen precursor
2 Protein Sequences => MESKGASSCRLLFCLLISATVFRPGLGWYTVNSAYGDTIIIPCRLDVPQNLMFGKWKYEKPDGSPVFIAFRSSTKKSVQYDDVPEYKDRLNLSENYTLSISNARISDEKRFVCMLVTEDNVFEAPTIVKVFKQPSKPEIVSKALFLETEQLKKLGDCISEDSYPDGNITWYRNGKVLHPLEGAVVIIFKKEMDPVTQLYTMTSTLEYKTTKADIQMPFTCSVTYYGPSGQKTIHSEQAVFDIYYPTEQVTIQVLPPKNAIKEGDNITLKCLGNGNPPPEEFLFYLPGQPEGIRSSNTYTLMDVRRNATGDYKCSLIDKKSMIASTAITVHYLDLSLNPSGEVTRQIGDALPVSCTISASRNATVVWMKDNIRLRSSPSFSSLHYQDAGNYVCETALQEVEGLKKRESLTLIVEGKPQIKMTKKTDPSGLSKTIICHVEGFPKPAIQWTITGSGSVINQTEESPYINGRYYSKIIISPEENVTLTCTAENQLERTVNSLNVSAISIPEHDEADEISDENREKVNDQAKLIVGIVVGLLLAALVAGVVYWLYMKKSKTASKHVNKDLGNMEENKKLEENNHKTEA
3 Protein Symbol => ALCAM
4 Swiss-Prot => Q13740
5 Summary =>
6 Synonyms => CD166 antigen precursor (Activated leukocyte-cell adhesion molecule) (ALCAM).
7 Protein Location => S
8 signalP =>  28 Y 0.988 Y
9 TM => 1
10 TM location => o528-550i
11 Num Nxts Sites => 10
12 Nxts Sites => 91,95,167,265,306,337,361,457,480,499
13 Peptide IPI => IPI00015102
14 NXT/S Location => 265
15 NXT/S Score => 0.6163598427746358
16 Predicted Tryptic NXT/S Peptide Sequenc.e => K.EGDN#ITLK.C
17 Predicted Peptide Mass => 888.444684
18 Database Hits => 1
19 Database Hit IPIs => IPI00015102
20 Min Similarity Score => 1.0
21 Detection Probability =>
22 Identified Sequences => K.NAIKEGDN#ITLK.C
23 Tryptic Ends => 2
24 Peptide ProPhet => 0.8636
25 Identified Peptide Mass => 1315.7

=cut

sub insert_peptides {
  my $self = shift;
  my %args = @_;

  my $err;
  for my $opt ( qw( release peptide_file format ) ) {
    $err = ( $err ) ? $err . ', ' . $opt : $opt if !defined $args{$opt};
  }
  die ( "Missing required parameter(s): $err in " . $self->whatsub() ) if $err;

  $self->testonly( $args{testonly} );

  # insert peptide search record
  my $psid = $self->insert_peptide_search( %args );

  my $observed;
  # check which format was specified, read file
  if ( $args{format} eq 'interact-tsv' ) {
    $observed = $self->read_tsv( %args );
  } else {
    die "Unsupported file format\n";
  }

  # insert observed peptide
  $self->insert_observed_peptides( %args, 
                                   peptides => $observed, 
                              pep_search_id => $psid
                                 );


  # insert observed_to_ipi record(s) - indicate original


  my $match = $module->clean_pepseq( $args{aa_seq} );
  if ( length($match) > 900 ) {
    print STDERR "Truncating long value for matching sequence\n";
    $match = substr( $match, 0, 900 );
  }
}

sub insert_peptide_search {
  my $self = shift;
  my %args = @_;
  my $err;
  for my $opt ( qw( peptide_file sample_id ipi_version_id ) ) {
    $err = ( $err ) ? $err . ', ' . $opt : $opt if !defined $args{$opt};
  }
  die ( "Missing required parameter(s): $err in " . $self->whatsub() ) if $err;

  my $fname = basename( $args{peptide_file} );

  my $sbeams = $self->getSBEAMS();

  # Make sure this file hasn't already been loaded
  my ($dup) = $sbeams->selectrow_array( <<"  END" );
  SELECT COUNT(*) FROM $TBGP_PEPTIDE_SEARCH 
  WHERE search_file = '$fname'
  AND sample_id = $args{sample_id}
  AND ref_db_id = $args{ipi_version_id}
  END

  die "Duplicate input file detected: $fname\n" if $dup;
  
  my $rowdata = { search_file => $fname,
                  sample_id => $args{sample_id},
                  ref_db_id => $args{ipi_version_id},
                  comment => "Loaded " . $sbeams->get_datetime(),
  };

  
  # Insert row
  my $id = $sbeams->updateOrInsertRow( table_name  => $TBGP_PEPTIDE_SEARCH,
                                       rowdata_ref => $rowdata,
                                       return_PK   => 1,
                                       verbose     => $self->verbose(),
                                       testonly    => $self->testonly(),
                                       insert      => 1,
                                       PK          => 'peptide_search_id',
                                     );
  return $id;
}


sub insert_observed_peptides {
  my $self = shift;
  my %args = @_;
  my $err;
  for my $opt ( qw( ipi_version_id peptides pep_search_id ) ) {
    $err = ( $err ) ? $err . ', ' . $opt : $opt if !defined $args{$opt};
  }
  die ( "Missing required parameter(s): $err in " . $self->whatsub() ) if $err;

  # this call will populate 3 hashes, seq->data_id, data_id => sequence, and ipi_id -> data_id
  $self->get_ipi_seqs( ipi_version_id => $args{ipi_version_id} );

  my $seqs = $self->{_seq_to_id};
  my $accs = $self->{_acc_to_id};
  my $ids = $self->{_id_to_seq};

  my @keys = keys( %{$seqs} );
  print "Found $#keys seqs\n";
  
  my $heads = get_interact_tsv_headers();
  my $sbeams = $self->getSBEAMS();

  my $cnt;
  my $insert_cnt;
  my $t0 = time();
  my $pcnt = scalar( @{$args{peptides}} );
  print "Inserting peptides ($pcnt candidates)\n"; 
  for my $obs ( @{$args{peptides}} ) {
    $cnt++;

    my $clean_pep = $module->clean_pepseq( $obs->[$heads->{Peptide}] );
    my $clean_prot = $self->trim_space( $obs->[$heads->{Protein}] );

    my $mapteins = [];
    my $seq = uc( $clean_pep );
    my @map = grep( /$seq/, @keys );
    for my $k ( @map ) {
      foreach my $ipi ( @{$seqs->{$k}} ) {
        push @$mapteins, $ipi;
      }
    }

    # Test for error conditions.
    
    if ( !scalar(@$mapteins) ) { # Can't map peptide to reference db
      print STDERR "Unable to map sequence: $clean_pep\n";
      next;

    } elsif ( $obs->[$heads->{prob}] < 0.5 ) { # detection probability too low
      print STDERR "Low probability: $obs->[$heads->{prob}]\n";
      next;
    }
    $insert_cnt++;

    my $exp_mass = $module->mh_plus_to_mass($obs->[$heads->{'MH+'}]);
    my $calc_mass = $module->calculatePeptideMass( sequence => $clean_pep ); 
    my $out = basename( $obs->[$heads->{file}] );
    my @name = split( /\./, $out );
    unless ( scalar(@name) == 4 && $name[1] == $name[2] ) {
      warn "Mismatch in out $out: " . join( ", ", @name ) . "\n";
    }
    my ( $delta ) = $self->extract_delta( $obs->[$heads->{'MH error'}] );

    my $mass2ch = ( $name[3] ) ? $exp_mass/$name[3] : undef;

    # Set ipi data id to search match if available, else first db match
    my $ipi = $accs->{$obs->[$heads->{Protein}]} || $mapteins->[0];
    
    my $rowdata = { observed_peptide_sequence => $obs->[$heads->{Peptide}],
#    sample_id => $args{sample_id},
                            peptide_search_id => $args{pep_search_id},
                                  ipi_data_id => $ipi,
                        peptide_prophet_score => $obs->[$heads->{prob}],
                            experimental_mass => $exp_mass,
                                spectrum_path => $obs->[$heads->{file}],
                               mass_to_charge => $mass2ch,
                                      mh_plus => $obs->[$heads->{'MH+'}],
                                     mh_delta => $delta,
                            matching_sequence => $clean_pep,
                                  scan_number => $name[2],
                                 charge_state => $name[3],
                                 peptide_mass => $calc_mass
              };

   
  # Insert row
  my $obs_id = $sbeams->updateOrInsertRow( table_name  => $TBGP_OBSERVED_PEPTIDE,
                                           rowdata_ref => $rowdata,
                                           return_PK   => 1,
                                           verbose     => $self->verbose(),
                                           testonly    => $self->testonly(),
                                           insert      => 1,
                                           PK          => 'peptide_search_id',
                                         );

  unless ( $cnt % 25 ){
    print '*';
  }
  unless ( $cnt % 500 ){
    print "\n";
  }

  my %seen;
  for my $id ( @$mapteins ) { # For each IPI that this peptide maps to
    unless ( $seen{$id} ) {
      $seen{$id}++;
      # Insert rows into observed_to_ipi table
      $sbeams->updateOrInsertRow( table_name  => $TBGP_OBSERVED_TO_IPI,
                                   rowdata_ref => { ipi_data_id => $id, observed_peptide_id => $obs_id },
                                   return_PK   => 0,
                                   verbose     => $self->verbose(),
                                   testonly    => $self->testonly(),
                                   insert      => 1,
                                   PK          => 'observed_to_ipi_id',
                                  );


      # Insert row(s) into observed_to_glycosite table
      my $coords = $module->map_peptide_to_protein( protseq => $ids->{$id},
                                        multiple_mappings => 1,
                                                   pepseq => uc($clean_pep)
                                                 );

#      print "Does $clean_pep map to $ids->{$id}\n";
#      for my $cd ( @$coords ) { print "$cd->[0], $cd->[1]\n"; }
#      print "Done coords\n";
      my $gsites = $module->getIPIGlycosites( ipi_data_id => $id );
#      for my $gs ( @$gsites ) { print "$gs->[0] => $gs->[1]\n"; }

      my $mapped = 0;
      for my $coord_pair ( @$coords ) {
        for my $ipi_sites ( @$gsites ) {
          if ( $coord_pair->[0] <= $ipi_sites->[1] &&  $coord_pair->[1] >= $ipi_sites->[1] ) {
            $mapped++;
            # Insert rows into observed_to_glycosite table
            $sbeams->updateOrInsertRow( table_name  => $TBGP_OBSERVED_TO_GLYCOSITE,
                                   rowdata_ref => { observed_peptide_id => $obs_id, 
                                                    glycosite_id => $ipi_sites->[0],
                                                    site_start => $ipi_sites->[1],
                                                    site_stop => $ipi_sites->[1] + length($clean_pep),
                                                  },
                                   return_PK   => 0,
                                   verbose     => $self->verbose(),
                                   testonly    => $self->testonly(),
                                   insert      => 1,
                                   PK          => 'observed_to_glycosite_id',
                                  );
            }
          }
        # If a peptide spans multiple sites, we'll map them all, but we won't try 
        # to map a peptide to a protein in multiple places.
        last if $mapped;  
        }
      }
    }



#  last if $cnt >= 1;
  }
  my $tdiff = time() - $t0;
  print "\n\n";
  print "Inserted $insert_cnt rows of $cnt in $tdiff seconds\n"; 
}

sub extract_delta {
  my $self = shift;
  my $delta = shift;

# has the form of (+2.4) or (-0.4)
  $delta = s/\(//g;
  $delta = s/\)//g;
  $delta = s/\+//g;
  return $delta;
}

sub map_proteins {
  my $self = shift;
  my %args = @_;
  my $err;
  for my $opt ( qw( peptide ipi_version_id ) ) {
    $err = ( $err ) ? $err . ', ' . $opt : $opt if !defined $args{$opt};
  }
  die ( "Missing required parameter(s): $err in " . $self->whatsub() ) if $err;

  if ( !$self->{_db_seqs} ) {
    $self->{_db_seqs} = $self->get_ipi_seqs( ipi_version_id => $args{ipi_version_id} );
    $self->{_db_keys} = [ keys( %{$self->{_db_seqs}} ) ];
  }
  
  my $seq = uc( $args{peptide} );
  my @mapteins; # array of ipi's to which this peptide maps
  my @map = grep( /$seq/, @{$self->{_db_keys}} );
  for my $k ( @map ) {
    foreach my $ipi ( @{$self->{_db_seqs}->{$k}} ) {
      push @mapteins, $ipi;
    }
  }
  return \@mapteins;

  # DB lookup was too dang slow
  my $peptide = '%' . $args{peptide} . '%';
  my $sql =<<"  END";
  SELECT ipi_data_id, ipi_accession_number FROM $TBGP_IPI_DATA 
  WHERE ipi_version_id = $args{ipi_version_id}
  AND protein_sequence like '$peptide'
  END

  my $sbeams = $self->getSBEAMS();
  my @ipi_data;
  while( my $row = $sbeams->selectSeveralColumnsRow( sql => $sql ) ) {
    if ( $row->[1] eq $args{protein} ) {
      unshift @ipi_data, $row->[0];
    } else {
      push @ipi_data, $row->[0];
    }
  }
  return \@ipi_data;
}

sub get_ipi_seqs {
  my $self = shift;
  my %args = @_;
  my $err;
  for my $opt ( qw( ipi_version_id ) ) {
    $err = ( $err ) ? $err . ', ' . $opt : $opt if !defined $args{$opt};
  }
  die ( "Missing required parameter(s): $err in " . $self->whatsub() ) if $err;

  my $peptide = '%' . $args{peptide} . '%';
  my $sql =<<"  END";
  SELECT ipi_data_id, protein_sequence, ipi_accession_number FROM $TBGP_IPI_DATA 
  WHERE ipi_version_id = $args{ipi_version_id}
  END
  my %seq2id;
  my %acc2id;
  my %id2seq;
  my $sbeams = $self->getSBEAMS();
  while( my $row = $sbeams->selectSeveralColumnsRow( sql => $sql ) ) {
#    $seq2ipi{$row->[1]} ||= [];
    push @{$seq2id{$row->[1]}}, $row->[0];
    $acc2id{$row->[2]} = $row->[0];
    $id2seq{$row->[0]} = $row->[1];
  }
  $self->{_seq_to_id} = \%seq2id;
  $self->{_acc_to_id} = \%acc2id;
  $self->{_id_to_seq} = \%id2seq;
  return 1;
}

sub get_interact_tsv_headers {
  my $self = shift;
  my %heads = ( prob => 0,
              ignore => 1,
                file => 2,
               'MH+' => 3,
          'MH error' => 4,
               XCorr => 5,
                 dCn => 6,
                  Sp => 7,
              SpRank => 8,
           IonsMatch => 9,
             IonsTot => 10,
             Protein => 11,
          '#DupProt' => 12,
             Peptide => 13 );
  for my $k (keys( %heads ) ) {
    $heads{lc($k)} = $heads{$k};
  }
  return \%heads;
}

sub read_tsv {
  my $self = shift;
  my %args = @_;

  my $sbeams = $self->getSBEAMS();

  my $file = $args{peptide_file};
  open DATA, $file || die "Unable to open file $file $!\n";

  my $heads = get_interact_tsv_headers();
	my $count = 0;
  my @peptides;
  print "Processing peptides\n";
  while(<DATA>) {
    chomp;
    my @tokens = split( /\t/, $_, -1);
    for my $t ( @tokens ) {
      $t =~ s/^\s*\"*//;
      $t =~ s/\"*\s*$//;
    }
    if ( $tokens[0] eq 'prob' && $tokens[1] eq 'ignore' && $tokens[2] eq 'file' ) {
      # this column has a header row
      next;
    }
    $count ++;
    push @peptides, \@tokens;

    # print progress 'bar'
    unless ( $count % 25 ){
      print '*';
    }
    unless ( $count % 500 ){
      print "\n";
    }
  }
  print "\n\n";
  return \@peptides;
}


##############################################################################
#Add the identifed_peptide for a row
###############################################################################
sub add_identified_peptides{  # deprecated
	my $self = shift;
	my $method = 'add_identified_peptides';
	my %args = @_;
	my $row = $args{line_parts};
	my $glyco_pk = $args{glyco_pk};
  my %heads = %{$self->{_heads}};
  my $sbeams = $self->getSBEAMS;
	
  my $id_seq = $row->[$heads{'identified sequences'}];

  # make sure we have an identifed peptide otherwise do nothing
	return unless ( $id_seq ); 

  # Special case, some peptides have the sequence 'N.AME.?', has some meaning
  # Can't cope with this now, log it and return FIXME
  if ( $id_seq eq 'N.AME.?' || $id_seq eq '...' ) {
#    print STDERR "Got an oddball, $row->[$heads{'ipi'}]: $id_seq ($row->[$heads{'predicted tryptic nxt/s peptide sequence'}])\n"; 
    return;
    }
	
	my $ipi_acc = $row->[$heads{'ipi'}];
	my $clean_seq = $self->clean_seq($id_seq); 
	my ($start, $stop) = $self->map_peptide_to_protein(peptide=> $clean_seq,
													   protein_seq => $row->[$heads{'protein sequences'}]);

  my $iden_pep_id;
  # Insert new id'd peptide or use cached version
  if ( !$self->{_id_peps}->{$id_seq} ) {
    my $matching_sequence = $module->clean_pepseq( $id_seq );
	
    # First, add row to the identified peptide table
	  my %id_pep_row = ( 	
					identified_peptide_sequence => $id_seq,
  				tryptic_end				        	=> $row->[$heads{'tryptic ends'}],
					peptide_prophet_score 		  => $row->[$heads{'peptide prophet'}],
					peptide_mass 			        	=> $row->[$heads{'identified peptide mass'}],
					glyco_site_id  		          => $glyco_pk,
					matching_sequence           => $matching_sequence,
					n_obs                       =>  $row->[$heads{'number observations'}]
			);
    my $sbeams = $self->getSBEAMS();
	
    # returns identified_peptide_id for new row
  	$iden_pep_id = $sbeams->updateOrInsertRow(				
							  table_name  => $TBGP_IDENTIFIED_PEPTIDE,
				   			rowdata_ref => \%id_pep_row,
				   			return_PK   => 1,
				   			verbose     => $self->verbose(),
				   			testonly    => $self->testonly(),
				   			insert      => 1,
				   			PK          => 'identified_peptide_id',
				   		   );
    # Cache value for later use!
    $self->{_id_peps}->{$id_seq} = $iden_pep_id;
  } else {
    $iden_pep_id = $self->{_id_peps}->{$id_seq};
#    print "Using cached, $row->[$heads{'identified sequences'}] => $iden_pep_id\n";
  }

  # Now, add row to identified_to_ipi lookup(join) table
  my %iden_to_ipi_row = ( ipi_data_id => $self->get_ipi_data_id($ipi_acc),
                          glyco_site_id => $glyco_pk,
                          identified_peptide_id => $iden_pep_id,
					                identified_start      => $start,
			                		identified_stop       => $stop, 
                        );

  # Insert row
	$sbeams->updateOrInsertRow( table_name  => $TBGP_IDENTIFIED_TO_IPI,
              				   			rowdata_ref => \%iden_to_ipi_row,
				   		               	return_PK   => 0,
		              		   			verbose     => $self->verbose(),
	              			   			testonly    => $self->testonly(),
              				   			insert      => 1,
			              	   			PK          => 'identified_to_ipi_id',
	            		   		    );

				   		   
	if ($self->verbose()>0){
		print (__PACKAGE__."::$method Added IDENTIFIED PEPTIDE pk '$iden_pep_id'\n");
	}
	
	$self->peptide_to_tissue($iden_pep_id, $row);
	
	return $iden_pep_id;
}


##############################################################################
#Add peptide_to_tissue information
###############################################################################
sub peptide_to_tissue {
	my $self = shift;
	my $identified_peptide_id = shift;
	my $row = shift;
  my %heads = %{$self->{_heads}};
	
	my $method = 'peptide_to_tissue';
	my $samples = $row->[$heads{'identified tissues'}];

  my @samples = split( ",", $samples, -1 );
  my $sbeams = $self->getSBEAMS();

  if ( !$self->{_sample_tissues} ) {
    my $sql = "SELECT sample_name, sample_id FROM $TBGP_UNIPEP_SAMPLE";
    $self->{_sample_tissues} = $sbeams->selectTwoColumnHashref( $sql );
#    foreach my $k ( keys ( %{$self->{_sample_tissues}} ) ) { print "$k\n"; }
  }

  foreach my $sample ( @samples ) {

    # Trim leading and trailing space
    $sample =~ s/^\s*//g;
    $sample =~ s/\s*$//g;

	  # bernd means lymphocyte for the time being
		$sample =~ s/bernd/lymphocytes/g;
    
    # We didn't find tissue type in lookup, try to autocreate
    unless ( $self->{_sample_tissues}->{$sample} ) {
      $self->{_sample_tissues}->{$sample} = $self->newGlycoSample( $sample ) ||
          die "Unable to create new sample type: $sample";
    }
    my %rowdata = ( identified_peptide_id => $identified_peptide_id, 
                               sample_id  => $self->{_sample_tissues}->{$sample}
                  );
	
	  $sbeams->updateOrInsertRow( return_PK   => 0,
                                table_name  => $TBGP_PEPTIDE_TO_SAMPLE,
				   		                	rowdata_ref => \%rowdata,
			                	   			verbose     => $self->verbose(),
			                	   			testonly    => $self->testonly(),
		                		   			insert      => 1,
	                			   			PK          => 'peptide_to_tissue_id',
				   		   );
  }
}


sub newGlycoSample {
  my $self = shift;
  my $sample = shift;
  my $sbeams = $self->getSBEAMS();
  my $tissue_sql = $sbeams->evalSQL ( <<"  END" );
  SELECT tissue_type_id 
  FROM $TBGP_TISSUE_TYPE WHERE 
  tissue_type_name = 'unknown'
  END

  my $dbh = $sbeams->getDBHandle();
  my ( $tissue_id ) = $dbh->selectrow_array( $tissue_sql ) ||
    die "Unable to find 'unknown' tissue type, cannot insert new samples";

  my %rowdata = ( tissue_type_id => $tissue_id,
                  sample_name => $sample );

  my $sample_id =  $sbeams->updateOrInsertRow( return_PK   => 1,
                                table_name  => $TBGP_UNIPEP_SAMPLE,
				   		                	rowdata_ref => \%rowdata,
			                	   			verbose     => $self->verbose(),
			                	   			testonly    => $self->testonly(),
		                		   			insert      => 1,
	                			   			PK          => 'sample_id' );

  if ( $sample_id ) {
    print STDERR "Created new sample entry for $sample: $sample_id\n";
    return $sample_id;
  } else {
    return undef;
  }

}

##############################################################################
#Add the predicted peptide for a row
###############################################################################
sub add_erpdicted_peptide {
	my $method = 'add_erpdicted_peptide';
	my $self = shift;
	
	my %args = @_;
	my $row = $args{line_parts};
	my $glyco_pk = $args{glyco_pk};
  my %heads = %{$self->{_heads}};
	
	my $ipi_acc = $row->[$heads{'ipi'}];
	my $peptide_sequence = $row->[$heads{'predicted tryptic nxt/s peptide sequence'}];
  if ( length($peptide_sequence) > 900 ) {
    $peptide_sequence = substr( $peptide_sequence, 0, 900 );
  }

	my $clean_seq = $self->clean_seq($peptide_sequence); 

  my $sbeams = $self->getSBEAMS();
	
   # We may now be getting proteins only, skip this bloc if no predicted peptide
  if ( $row->[$heads{'predicted tryptic nxt/s peptide sequence'}] 
       && $ipi_acc && $clean_seq ) {

  	#my $fixed_predicted_seq = $self->fix_predicted_peptide_seq($row->[16]);
  	my ($start, $stop) = $self->map_peptide_to_protein(peptide=> $clean_seq,
	     												   protein_seq => $row->[$heads{'protein sequences'}]);
	
    my $det_prob = 0 ; #$row->[$heads{'detection probablility'}] || 0;

    my $matching_sequence = $module->clean_pepseq( $peptide_sequence );

  	#TODO WARNING DETECTION PROBABLITY IS FAKE>  DATA IS NOT COMPLETE
  	my %rowdata_h = ( 	
					ipi_data_id 				=> $self->get_ipi_data_id($ipi_acc),
					predicted_peptide_sequence => $row->[$heads{'predicted tryptic nxt/s peptide sequence'}],
					predicted_peptide_mass 		=> $row->[$heads{'predicted peptide mass'}],
					detection_probability 		=> $det_prob, #
					number_proteins_match_peptide => $row->[$heads{'database hits'}],
					matching_protein_ids 		=> $row->[$heads{'database hit ipis'}],
					protein_similarity_score	=> $row->[$heads{'min similarity score'}],
					predicted_start 			=> $start,
					predicted_stop 				=> $stop,
					glyco_site_id  				=> $glyco_pk,
          matching_sequence => $matching_sequence
	  		);
    #TODO REMOVE SIZE LIMIT OF DATA	
  	#my %rowdata_h = $self->truncate_data(record_href => \%rowdata_h); #some of the data will need to truncated to make it easy to put all data in varchar 255 or less
    	my $rowdata_ref = \%rowdata_h;
	

    	my $predicted_peptide_id = $sbeams->updateOrInsertRow(				
							table_name=>$TBGP_PREDICTED_PEPTIDE,
				   			rowdata_ref=>$rowdata_ref,
				   			return_PK=>1,
				   			verbose=>$self->verbose(),
				   			testonly=>$self->testonly(),
				   			insert=>1,
				   			PK=>'predicted_peptide_id',
				   		   );
				   		   
	  if ($self->verbose()>0){
		  print (__PACKAGE__."::$method Added PREDICTED PEPTIDE pk '$predicted_peptide_id'\n");
  	}
	
  	return $predicted_peptide_id;
  }
}


###############################################################################
# fix_predicted_peptide_seq 
# predicted peptide sequences did not have a trailing . denoting the peptide/protein
#cleavage site.  Need to add it back in
###############################################################################
sub fix_predicted_peptide_seq {
	my $method = 'fix_predicted_peptide_seq';
	my $self = shift;
	my $pep_seq = shift;
	
	if ($pep_seq =~ s/(.)$/.$1/){
		if($self->verbose){
			print (__PACKAGE__."::$method ADDED TRAILING CUT SITE '$pep_seq'\n");
	}
		return $pep_seq;
	}else{
		confess(__PACKAGE__."$method COULD NOT REPLACE THE TRAILING CUT SITE in '$pep_seq'\n"); 
	}
	
}


sub trim_space {
	my $self = shift;
	my $seq = shift;
  $seq =~ s/^\s*//g;
  $seq =~ s/\s*$//g;
  return $seq;
}

###############################################################################
# clean_seq remove the start and finish protein aa.  Remove any non aa from
# from a peptide sequence
###############################################################################
sub clean_seq {
	my $method = 'clean_seq';
	my $self = shift;
	my $pep_seq = shift;
	unless($pep_seq){
		confess(__PACKAGE__."$method MUST PROVIDE A PEPTIDE SEQUENCE YOU GAVE '$pep_seq'\n");
	}	
	 $pep_seq =~ s/^.//; #remove first aa
		unless($pep_seq){
#      return '';
		confess(__PACKAGE__."$method PEP SEQ IS GONE'$pep_seq'\n");
	}	
	
	 $pep_seq =~ s/.$//; #remove last aa
	
	 $pep_seq =~ s/\W//g;	#remove any '*' '.' '#' signs
	
	unless($pep_seq){
#      return '';
		confess(__PACKAGE__."$method PEP SEQ IS GONE'$pep_seq'\n");
	}	
	
	if($self->verbose){
			print (__PACKAGE__."::$method CLEAN SEQ '$pep_seq'\n");
	}
	 if ($pep_seq =~ /\W/){
		confess(__PACKAGE__."$method PEPTIDE SEQUENCE  IS NOT CLEAN '$pep_seq'\n"); 
	}
	return $pep_seq;
}
	
###############################################################################
#map_peptide_to_protein
###############################################################################
sub map_peptide_to_protein {
	my $method = 'map_peptide_to_protein';
	my $self = shift;
	my %args = @_;
	my $pep_seq = $args{peptide};
	my $protein_seq = $args{protein_seq};
#  return ( 0, 0 ) unless $args{peptide};
	
	if ( $protein_seq =~ /$pep_seq/ ) {

		#add one for the starting position since we want the start of the peptide location
		my $start_pos = length($`) +1;    
    # subtract 1 since we want the true end 
		my $stop_pos = length($pep_seq) + $start_pos - 1 ;  
		if($self->verbose){
			print (__PACKAGE__."::$method $pep_seq START '$start_pos' STOP '$stop_pos'\n");
		}
		if ($start_pos >= $stop_pos){
			confess(__PACKAGE__. "::$method STOP LESS THAN START START '$start_pos' STOP '$stop_pos'\n");
		}
		return ($start_pos, $stop_pos);	
	}else{
		print STDERR "No mapping possible: PEPTIDE '$pep_seq' DOES NOT MATCH '$protein_seq'\n";
    return( 0, 0 );
		confess(__PACKAGE__. "::$method PEPTIDE '$pep_seq' DOES NOT MATCH '$protein_seq'\n");
	}
	
}

#
# Add predicted tryptic peptide
#
sub insert_predicted {

	my $self = shift;
  my %args = @_;

  my $err;
  for my $opt ( qw( ipi ipi_data_id aa_seq start_idx stop_idx ) ) {
    $err = ( $err ) ? $err . ', ' . $opt : $opt if !defined $args{$opt};
  }
  die ( "Missing required parameter(s): $err in " . $self->whatsub() ) if $err;

  my $match = $module->clean_pepseq( $args{aa_seq} );
  if ( length($match) > 900 ) {
    print STDERR "Truncating long value for matching sequence\n";
    $match = substr( $match, 0, 900 );
  }

  $self->{_loaded_peptide} ||= {};
  if ( $self->{_loaded_peptide}->{$args{aa_seq}} ) {
# This code kept multiple instances of the same aa sequence from being loaded.
#    return $self->{_loaded_peptide}->{$args{aa_seq}};
  }


#  $self->{_seq_to_id}->{$match}->{$args{ipi}}++;
  my $n_match = 0;
  my $match_str = '';

  for my $k ( keys( %{$self->{_seq_to_id}->{$match}} ) ) {
    next unless $k;
    $n_match++;
    $match_str = ( $match_str ) ? "$match_str, $k" : $k;
  }

  my $mass = $module->calculatePeptideMass( sequence => $match); # Fixme use methyl Cys & N => D?
  my $detection_prob = -1;
  my $prot_sim_score = -1;

  my $rowdata = { ipi_data_id => $args{ipi_data_id},
   predicted_peptide_sequence => $args{aa_seq},
       predicted_peptide_mass => $mass,
        detection_probability => $detection_prob,
     n_proteins_match_peptide => $n_match,
         matching_protein_ids => $match_str,
     protein_similarity_score => $prot_sim_score,
              predicted_start => $args{start_idx},
               predicted_stop =>  $args{stop_idx},
            matching_sequence => $match};
  
  my $sbeams = $self->getSBEAMS();


 	my $predicted_id = $sbeams->updateOrInsertRow( return_PK => 1,
                                                table_name => $TBGP_PREDICTED_PEPTIDE,
                                               rowdata_ref => $rowdata,
                                                   verbose => $self->verbose(),
                                                  testonly => $self->testonly(),
                                                    insert => 1,
                                                        PK => 'predicted_peptide_id',
                                             ); 
  $self->{_loaded_peptide}->{$args{aa_seq}} = $predicted_id;
  return $predicted_id;
}

sub whatsub {
  my $self = shift;
  my $package = shift || 0;
  my @call = caller(1);
  $call[3] =~ s/.*:+([^\:]+)$/$1/ unless $package;
  return $call[3];
}

sub add_predicted2glycosite {
	my $self = shift;
  my %args = @_;

  my $err;
  for my $opt ( qw( ipi_data_id site predicted_id ) ) {
    $err = ( $err ) ? $err . ', ' . $opt : $opt if !defined $args{$opt};
  }
  die ( "Missing required parameter(s): $err in " . $self->whatsub() ) if $err;

  my $key = $args{ipi_data_id} . $args{site};
  my $glycosite_id = $self->{_ipi2gs}->{$key} || die "Unknown site";  
  
  my $rowdata = { glycosite_id => $glycosite_id,
                    site_start => $args{site},
                     site_stop => $args{site} + 3,
          predicted_peptide_id => $args{predicted_id} };

  my $sb = $self->getSBEAMS();


 	my $id = $sb->updateOrInsertRow( return_PK => 1,
                                      table_name => $TBGP_PREDICTED_TO_GLYCOSITE,
                                     rowdata_ref => $rowdata,
                                          insert => 1,
                                         PK_name => 'predicted_to_glycosite_id',
                                                 );
  return $id;
}

sub update_peptide_sequence {
	my $self = shift;
  my %args = @_;

  my $err;
  for my $opt ( qw( aa_seq predicted_id ) ) {
    $err = ( $err ) ? $err . ', ' . $opt : $opt if !defined $args{$opt};
  }
  die ( "Missing required parameter(s): $err in " . $self->whatsub() ) if $err;

  my $sbeams = $self->getSBEAMS();
 	my $result = $sbeams->updateOrInsertRow( table_name => $TBGP_PREDICTED_PEPTIDE,
                                          rowdata_ref => { predicted_peptide_sequence => $args{aa_seq} },
                                               update => 1,
                                              PK_name => 'predicted_peptide_id',
                                             PK_value => $args{predicted_id},
                                           );
  return $result;

}

#
# Add predicted tryptic peptides, plus glycosite record if appropriate.
#
sub add_predicted_peptides {

	my $self = shift;
  my %args = @_;

  my $err;
  for my $opt ( qw( ipi ipi_data_id site_idx sequence peptides ) ) {
    $err = ( $err ) ? $err . ', ' . $opt : $opt if !defined $args{$opt};
  }
  die ( "Missing required parameter(s): $err in " . $self->whatsub() ) if $err;

  # Index into protein
  my $pidx = 0;

  # Array of glycosite locations
  my $site = shift( @{$args{site_idx}} );

  for my $peptide ( @{$args{peptides}} ) {
    # index of glycosite in peptide
    my $sidx = $pidx;

    # Increment index
    $pidx += (length( $peptide ) - 4);

    my $num_motifs = 0;
 
    my $predicted_id;
#    If peptide is 5 aa's or more -or- is a glycosite
#    my $do_insert = ( length($peptide) > 8 || ( $site && $pidx >= $site + 1 ) ) ? 1 : 0;

#
#    If peptide is a glycosite
    my $do_insert = ( $site && $pidx >= $site + 1 ) ? 1 : 0;
    $predicted_id = $self->insert_predicted( %args,  # pass through ipi_data_id, ipi accession
                                             aa_seq => $peptide,
                                          start_idx => $sidx,
                                           stop_idx => $pidx
                                    ) or die "Insert failed $!" if $do_insert;

    
    # If we are in a glyco
    while ( defined $site && $pidx >= $site ) {
      my $pepidx = ( $site - $sidx ) + 1 + $num_motifs;
      my $annot_pep = $peptide;
      substr( $annot_pep, $pepidx, 1 ) = 'N#';
#     print "$peptide => $annot_pep\n";
      my $aa = substr( $peptide, $pepidx , 3 );
#      print "\tDataID: $args{ipi_data_id}\t$pidx\t$pepidx\t$aa\t$site\n";
      $self->add_predicted2glycosite( %args, site => $site, predicted_id => $predicted_id ) if $predicted_id;
#      print "Added 2 for $predicted_id\n" if $num_motifs > 1;

      $site = shift( @{$args{site_idx}} );
#      print "\t\t$pidx\t$pepidx\t$aa\t$site\n";
      $peptide = $annot_pep;
      $num_motifs++;
      last if !defined $site;
    }
    if ( $predicted_id && $peptide =~ /#/ ) {
      $self->update_peptide_sequence( predicted_id => $predicted_id,
                                          aa_seq => $peptide );
    }
  }

}

#
# Add the glycosite(s) for current protein
#
sub add_glycosites {

	my $self = shift;
  my %args = @_;

  my $missing;
  for my $opt ( qw( protein_sequence ipi_data_id site_idx ) ) {
    $missing = ( $missing ) ? $missing . ', ' . $opt : $opt unless defined $args{$opt};
  }
  die ( "Missing required parameter(s): $missing in " . $self->whatsub() ) if $missing;

  my $sbeams = $self->getSBEAMS();
  $self->{_ipi2gs} ||= {};

  for my $site ( @{$args{site_idx}} ) {
    my $glyco_score = -1;
    my $motif_context = $self->motif_context( seq => $args{protein_sequence}, site => $site );


  	my $rowdata = { protein_glycosite_position => $site,
                                  site_context => $motif_context,
                                    glyco_score => $glyco_score,  # Fixme 
                                    ipi_data_id => $args{ipi_data_id}
                  };
	
    my $pk = $sbeams->updateOrInsertRow( table_name  => $TBGP_GLYCOSITE,
                                rowdata_ref => $rowdata,
                                return_PK   => 1,
                                verbose     => $self->verbose(),
                                testonly    => $self->testonly(),
                                insert      => 1,
                                PK          => 'glycosite_id' ) || die "putresence";
    $self->{_ipi2gs}->{$args{ipi_data_id} . $site} = $pk;
  }
  print 
  return 1;
				   		   
}
	
sub motif_context {
  my $self = shift;
  my %args = @_;

  my $missing;
  for my $opt ( qw( seq site ) ) {
    $missing = ( $missing ) ? $missing . ', ' . $opt : $opt unless defined $args{$opt};
  }
  die ( "Missing required parameter(s): $missing in " . $self->whatsub() ) if $missing;

  my $lpad = 0;
  my $rpad = 0;
  my $beg = $args{site} - 5;
  my $end = 13;
  my $len = length( $args{seq} );

  if ( $args{site} <= 5 ) {
    $lpad = 5 - $args{site};
    $beg = 0;
    $end -= $lpad;
  } 

  if ( $args{site} + 8 > $len ) {

      $rpad = ($args{site} + 8) - $len;
      $end -= $rpad;
  }

  my $context = substr( $args{seq}, $beg, $end );
  $context = '-' x $lpad . $context . '-' x $rpad;
  my $slen = length($context);

  return $context;
}

###############################################################################
#Add the glycosite for this row
###############################################################################
sub add_glyco_site_old {
	my $method = 'add_glyco_site';
	my $self = shift;
	my $row = shift;
	
  my %heads = %{$self->{_heads}};
	my $ipi_id = $row->[$heads{'ipi'}];
	
	my %rowdata_h = ( 	
				protein_glycosite_position => $row->[$heads{'nxt/s location'}],
				glyco_score =>$row->[$heads{'nxt/s score'}],
				ipi_data_id => $self->get_ipi_data_id( $ipi_id ),
			  );
	
	my $rowdata_ref = \%rowdata_h;
  my $sbeams = $self->getSBEAMS();

	my $glyco_site_id = $sbeams->updateOrInsertRow(				
							table_name=>$TBGP_GLYCOSITE,
				   			rowdata_ref=>$rowdata_ref,
				   			return_PK=>1,
				   			verbose=>$self->verbose(),
				   			testonly=>$self->testonly(),
				   			insert=>1,
				   			PK=>'glyco_site_id',
				   		   );
				   		   
	if ($self->verbose()>0){
		print (__PACKAGE__."::$method Added GLYCOSITE pk '$glyco_site_id'\n");
	
	}
	
	return $glyco_site_id;
}

###############################################################################
#Add the main info for an ipi record
###############################################################################
sub add_ipi_record {
	my $self = shift;
	my $row = shift;
	die 'Did not pass data ref' unless ( $row && ref($row) =~/ARRAY/ );
	
  my $sbeams = $self->getSBEAMS();
  my %heads = %{$self->{_heads}};

	my $cellular_location_id = $self->find_cellular_location_id($row->[$heads{'protein location'}]);
	
	my $ipi_id = $row->[$heads{'ipi'}];
	
	my $ipi_version_id = $self->ipi_version_id();
	
												
	my %rowdata_h = ( 	
				ipi_version_id => $ipi_version_id,
				ipi_accession_number =>$ipi_id,
				protein_name =>$row->[$heads{'protein name'}],
				protein_symbol =>$row->[$heads{'protein symbol'}],
				swiss_prot_acc =>$row->[$heads{'swiss-prot'}],
				cellular_location_id =>$cellular_location_id,
				transmembrane_info =>$row->[$heads{'tm location'}],
				signal_sequence_info =>$row->[$heads{'signalp'}],
				synonyms => $row->[$heads{'synonyms'}],
			  );

	%rowdata_h = $self->truncate_data(record_href => \%rowdata_h); #some of the data will need to truncated to make it easy to put all data in varchar 255 or less
	
	##Add in the big columns that should not be truncated
	
	$rowdata_h{protein_sequence} = $row->[$heads{'protein sequences'}];
	$rowdata_h{protein_summary}  = $row->[$heads{'summary'}];
	
	
	my $rowdata_ref = \%rowdata_h;
	

	my $ipi_data_id = $sbeams->updateOrInsertRow(				
							table_name=>$TBGP_IPI_DATA,
				   			rowdata_ref=>$rowdata_ref,
				   			return_PK=>1,
				   			verbose=>$self->verbose(),
				   			testonly=>$self->testonly(),
				   			insert=>1,
				   			PK=>'ipi_data_id',
				   		   );
	
	$self->{All_records}{$ipi_id} = {ipi_data_id => $ipi_data_id};

	return $ipi_data_id;
}
###############################################################################
#get ipi_data_id 
#given a ipi_accession_number 
#return id if present
#die otherwise
###############################################################################
sub get_ipi_data_id{
	my $method = 'get_ipi_data-id';
	my $self = shift;
	my $ipi_acc = shift;
	
	if (exists $self->{All_records}{$ipi_acc}){
		return $self->{All_records}{$ipi_acc}{ipi_data_id};
		
	}else{
		confess(__PACKAGE__. "::$method COULD NOT FIND ID '$ipi_acc'\n");
		
	}
	
}
###############################################################################
#Given the name of a tissue look return a tissue id
###############################################################################

sub find_tissue_id {
	my $self = shift;
	my $tissue_name = shift;
	my $code = '';
	if ($self->tissue_code_id($tissue_name)){
		#print "I SEE THE CODE **\n";
		return 	$self->tissue_code_id($tissue_name);	
	}else{
		return $self->find_tissue_code($tissue_name);
	}
}

###############################################################################
#Get/Set the tissue code_id 
###############################################################################
sub tissue_code_id {
	my $self = shift;
	
	if (@_){
		#it's a setter
		$self->{_TISSUE_NAMES}{$_[0]} = $_[1];
	}else{
		#it's a getter
		$self->{_CELLULAR_NAMES}{$_[0]};
	}

}

##############################################################################
#Query the database for the tissue code
###############################################################################
sub find_tissue_code {
	my $method = 'find_tissue_code';
	my $self = shift;
  my $tissue = shift;

  my $sbeams = $self->getSBEAMS();
  
	my $tissue_name = ( $tissue =~ /serum/i ) ? 'serum' :
                    ( $tissue =~ /prostate/i ) ? 'prostate' :
                    ( $tissue =~ /ovary/i ) ? 'ovary' :
                    ( $tissue =~ /breast/i ) ? 'breast' : 'unknown';
	
	my $sql = qq~ 	SELECT tissue_id
					FROM $TBGP_TISSUE_TYPE
					WHERE tissue_name = '$tissue_name'
		      ~;
	
	
	my ($id) = $sbeams->selectOneColumn($sql);
	if ($self->verbose){
		print __PACKAGE__. "::$method FOUND TISSUE ID '$id' FOR TISSUE '$tissue_name'\n";
		
	}
	unless ($id) {
		confess(__PACKAGE__ ."::$method CANNOT FIND ID FOR FOR TISSUE '$tissue_name'\n");
	}
	
	$self->tissue_code_id($tissue_name, $id);
	return $id;
}


###############################################################################
#If the ipi_protein has been seen return 0 otherwise retrun 1
###############################################################################
sub find_cellular_location_id{
	my $self = shift;
	my $cellular_code = shift;
	
	
	my $code = '';
	if ($self->cellular_code_id($cellular_code)){
		return 	$self->cellular_code_id($cellular_code);
		
	}else{
	
		return $self->find_cellular_code($cellular_code);
	}

}

###############################################################################
#Convert the cellular code to and a name and find it in the database
###############################################################################
sub find_cellular_code {
	my $method = 'find_cellular_code';
	my $self = shift;
	my $code = shift;
  my $sbeams = $self->getSBEAMS();

  # Lets not look it up every single time, eh?
  my $cached = $self->cellular_code_id( $code );
  return $cached if $cached;
	
	my $full_name = '';
	if ($code eq 'S'){
		$full_name = 'Secreted';
	}elsif($code eq 'TM'){
		$full_name = 'Transmembrane';
	}elsif($code eq 'A'){
		$full_name = 'Anchor';
	}elsif($code eq '0'){
		$full_name = 'Cytoplasmic';
	}elsif($code eq 'A_low' ){
		$full_name = 'Anchor';
	} else {
  	die "Unknown cellular code $code\n";
  }

	my $sql =<<"  END"; 
  SELECT cellular_location_id
  FROM $TBGP_CELLULAR_LOCATION
  WHERE cellular_location_name = '$full_name'
  END
	
  my ($id) = $sbeams->selectOneColumn($sql);
  unless ($id) {
    die "DB lookup failed for cellular code $code ($full_name)\n";
  }
	
  $self->cellular_code_id($code, $id);
  return $id;
}
###############################################################################
#Get/Set the cellular code_id cellular_code
###############################################################################
sub cellular_code_id {
	my $self = shift;
  my ( $code, $id ) = @_;
	
	if ( defined $id ){ #it's a setter
    print "Code $code is getting set to $id\n" if $self->verbose();
		$self->{_CELLULAR_CODES}{$code} = $id;
	}

  return $self->{_CELLULAR_CODES}{$code};
}

###############################################################################
#If the ipi_protein has been seen return 0 otherwise retrun 1
###############################################################################
sub check_ipi {
	my $method = 'check_ipi';
	my $self = shift;
	my $ipi_id = shift;
	
	confess(__PACKAGE__ . "::$method Need to provide IPI id '$ipi_id' is not good  \n")unless $ipi_id =~ /^IPI/;
	if (exists $self->{All_records}{$ipi_id} ){
		return 1;
	}else{
		return 0;
	}


}

###############################################################################
#check_version
###############################################################################
sub check_version {
	my $method = 'check_version';
	my $self = shift;
  my %args = @_;

  my $sbeams = $self->getSBEAMS();
		
	my $sql = qq~
  SELECT ipi_version_id
  FROM $TBGP_IPI_VERSION
  WHERE ipi_version_name = '$args{release}'
  ~;

  my ($id) = $sbeams->selectOneColumn($sql);	
#  print STDERR "$sql Found matching version $id\n";

  if ($id){
    die "Version $args{version} already exists, quitting\n";
  }
	return 1;
}


###############################################################################
#add_new_ipi_version/set ipi_version_id
###############################################################################	
sub add_ipi_version{
	my $self = shift;
  my %args = @_;

	my $file = $self->getfile();
	my $file_name = basename($file);
  my $sbeams = $self->getSBEAMS();
	
	my $st = stat($file);
	my $mod_time_string = strftime "%F %H:%M:%S.00", localtime($st->mtime);
	my $release = $self->{_release} || $file;
	
  my $orgID = $sbeams->get_organism_id( organism => $args{organism} );
  die "Unable to find organism $args{organism} in the database" unless $orgID;
  
  my $is_default = ( $args{default} ) ? 1 : 0;
# FIXME Add to schema
#				ipi_file_name => $file,

	my %rowdata_h = ( 	
				ipi_version_name => $args{release},
				ipi_version_date => $mod_time_string,
				ipi_version_file => $file_name,
        organism_id => $orgID,
        is_default => $is_default,
			  comment => $args{comment},	
			  );
	
	my $ipi_version_id = $sbeams->updateOrInsertRow(				
							table_name=>$TBGP_IPI_VERSION,
				   			rowdata_ref=> \%rowdata_h,
				   			return_PK=>1,
				   			verbose=>$self->verbose(),
				   			testonly=>$self->testonly(),
				   			insert=>1,
				   			PK=>'ipi_version_id',
				   		   	add_audit_parameters => 1,
				   		   );
				   		   
				   		   
	return $self->ipi_version_id($ipi_version_id);

}
###############################################################################
#get/set ipi_version_id
#return the ipi_version_id in either case
###############################################################################
sub ipi_version_id {
	my $self = shift;
	
	if (@_){
		#it's a setter
		$self->{_IPI_VERSION_ID} = $_[0];
		return $_[0];
	}else{
		#it's a getter
		return $self->{_IPI_VERSION_ID};
	}

}	
	


###############################################################################
#Column headers
###############################################################################
sub column_headers {
	my $self = shift;
	my $line_aref = shift;
	
	my %headers = ();
	my $count = 0;
	foreach my $name (@{$line_aref}){
		$headers{$count} = $name;
		$count ++;
	}
	
	return %headers;
}



###############################################################################
#truncate_data
#used to truncate any long fields.  Will truncate everything in a hash or a single value to 254 char.  Also will
#write out to the error log if any extra fields are truncated
###############################################################################
sub truncate_data {
    	my $method = 'truncate_data';
    	
	my $self = shift;
	
	my %args = @_;
	
	my $record_href = $args{record_href};
	my $data_aref	= $args{data_aref};
	
	confess(__PACKAGE__ . "::$method Need to provide key value pair 'record_href' OR  'data_aref'\n") unless ( ref($record_href) eq 'HASH' || ref($data_aref) eq 'ARRAY' );
	
	my %record_h = ();
	my @data = ();
	
	if ($record_href){
		%record_h = %{$record_href};
	
		foreach my $key ( keys %record_h){
		
			
			if (length $record_h{$key} > 255){
				my $big_val = $record_h{$key};
		
				$record_h{$key} = substr($record_h{$key}, 0, 255);
			
				$self->anno_error(error => 'trunc');
			}
		}
		return %record_h;
	
	}elsif($data_aref){
		@data = @$data_aref;
		
		for(my $i=0; $i<=$#data; $i++){
			if (length $data[$i] > 255){
				my $big_val = $data[$i];
		
				$data[$i] = substr($data[$i], 0, 255);
			
				$self->anno_error(error => 'trunc');
			}
		}
		return @data;
	}else{
		die "Unknown DATA TYPE FOR $method\n";
	}

	

}


##############################################################################
# anno_error
###############################################################################
sub  anno_error {
	my $self = shift;
	my %args = @_;

  $self->{_anno_error} ||= { trunc => 0, };

  if ( $args{error} ) {
    $self->{_anno_error}->{$args{error}}++;
    return;
  } 
  
  my $errstr = 'No errors reported';
  if ( $self->{_anno_error}->{trunc} ) {
    $errstr .= "Warning: $self->{_anno_error}->{trunc} values were truncated";
  }
  return $errstr;
}



}#closing bracket for the package

1;
