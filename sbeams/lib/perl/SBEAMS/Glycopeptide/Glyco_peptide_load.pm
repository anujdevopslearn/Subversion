{package SBEAMS::Glycopeptide::Glyco_peptide_load;
		



##############################################################
use strict;
#use vars qw($sbeams $self);		#HACK within the read_dir method had to set self to global: read below for more info

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
	my $sbeams = $args{sbeams};
	my $verbose = $args{verbose} || 0;
	my $debug  = $args{debug};
	my $test_only = $args{test_only};
	my $file = $args{file};
	my $release = $args{release} || $args{file};
  
	my $self = {   _file => $file,
             	_release => $release};
	
	bless $self, $class;
	
	$self->setSBEAMS($sbeams);
	$self->verbose($verbose);
	$self->debug($debug);
	$self->testonly($test_only);
	$self->check_version();
	
	return $self;
	
	
}
###############################################################################
# Receive the main SBEAMS object
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
		$self->{_TESTONLY};
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
  while(<DATA>){
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
      next;
    }

		$self->add_ipi_record( \@tokens ) unless 
                                      $self->check_ipi($tokens[$heads{'ipi'}]);
		
		my $glyco_pk = $self->add_glyco_site( \@tokens );
			
	  if ( $tokens[$heads{'predicted tryptic nxt/s peptide sequence'}] ) {
	  	$self->add_predicted_peptide( glyco_pk   => $glyco_pk,
									              	  line_parts => \@tokens);
    }
			
    # add identifed peptide iff there is one.
	  if ( $args{load_peptides} && $tokens[$heads{'identified sequences'}] ) {
    
		  $self->add_identified_peptides( glyco_pk   => $glyco_pk,
	                  								  line_parts => \@tokens);
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
				print "Loaded $count records, elapsed time $time seconds\n";
			}
    }
    my $t2 = new Benchmark;
    my $pcnt = $self->{_id_peps};
    print "Total peptides was " .  scalar(keys(%$pcnt) ) ."\n";
    print "\n\nLoaded $count total records in " . timestr(timediff($t2, $t0)) . "\n";
  }


sub checkHeaders {
  my $self = shift;
  my $heads = shift;
  my %heads = %$heads;
  my @version_8_columns = ( 'IPI',
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
  @version_8_columns = map { lc($_) } @version_8_columns;
  my @current_cols = keys(%heads);

  for my $curr_col ( @current_cols ) {
    print "Checking for curr_col $curr_col\n";
    unless( grep /$curr_col/, @version_8_columns ) {
      print STDERR "Column $curr_col is not known by the parser\n";
      exit;
    }
  }

  for my $parser_col ( @version_8_columns ) {
#    print "Checking for parser_col $parser_col\n";
    unless( grep /$parser_col/, @current_cols ) {
      print STDERR "Column $parser_col is missing in this file\n";
      exit;
    }
  }
  # We got past the checks, cache the header values.
  $self->{_heads} = \%heads;
  
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
##############################################################################
#Add the identifed_peptide for a row
###############################################################################
sub add_identified_peptides{
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
    my $sql = "SELECT sample_name, sample_id FROM $TBGP_GLYCO_SAMPLE";
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
                                table_name  => $TBGP_PEPTIDE_TO_TISSUE,
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
                                table_name  => $TBGP_GLYCO_SAMPLE,
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
sub add_predicted_peptide {
	my $method = 'add_predicted_peptide';
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



###############################################################################
#Add the glycosite for this row
###############################################################################
sub add_glyco_site {
	my $method = 'add_glyco_site';
	my $self = shift;
	my $row = shift;
	
  my %heads = %{$self->{_heads}};
	my $ipi_id = $row->[$heads{'ipi'}];
	
	my %rowdata_h = ( 	
				protein_glyco_site_position => $row->[$heads{'nxt/s location'}],
				glyco_score =>$row->[$heads{'nxt/s score'}],
				ipi_data_id => $self->get_ipi_data_id( $ipi_id ),
			  );
	
	my $rowdata_ref = \%rowdata_h;
  my $sbeams = $self->getSBEAMS();

	my $glyco_site_id = $sbeams->updateOrInsertRow(				
							table_name=>$TBGP_GLYCO_SITE,
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

	return 1;
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
		#print "I SEE THE CODE **\n";
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
  	print STDERR "ERROR:Cannot find full name for CELLULAR CODE '$code'\n";
  }

	my $sql =<<"  END"; 
  SELECT cellular_location_id
  FROM $TBGP_CELLULAR_LOCATION
  WHERE cellular_location_name = '$full_name'
  END
	
	 my ($id) = $sbeams->selectOneColumn($sql);
	if ($self->verbose){
		print __PACKAGE__. "::$method FOUND CELLULAR LOCATION ID '$id' FOR CODE '$code' FULL NAME '$full_name'\n";
		
	}
	unless ($id) {
		confess(__PACKAGE__ ."::$method CANNOT FIND ID FOR CODE '$code' FULL NAME '$full_name'\n");
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
  my $sbeams = $self->getSBEAMS();
	
	my $file = $self->getfile();

  return '' unless -e $file;
	
	my $st = stat($file);
	
	#DB time '2005-05-06 14:24:37.63' 
	my $now_string = strftime "%F %H:%M:%S.00", localtime($st->mtime);
	              
		
	my $sql = qq~ SELECT ipi_version_id
					FROM $TBGP_IPI_VERSION
					WHERE ipi_version_date = '$now_string'
				~;
	
	if ($self->debug >0){
		print __PACKAGE__ ."::$method SQL '$sql'\n";
	}
	
	 my ($id) = $sbeams->selectOneColumn($sql);	
	 
	 if ($id){
	 	$self->ipi_version_id($id);
	 	if ($self->verbose){
	 		print __PACKAGE__. "::$method FOUND IPI VERSION ID IN THE DB '$id'\n";
	 	}
	 }else{
	 	my $id = $self->add_new_ipi_version();
	 	print __PACKAGE__ ."::$method MADE NEW IPI VESION ID '$id'\n";
	 	
	 }
	return 1;
}


###############################################################################
#add_new_ipi_version/set ipi_version_id
###############################################################################	
sub add_new_ipi_version{

	my $self = shift;
	my $file = $self->getfile();
	my $file_name = basename($file);
  my $sbeams = $self->getSBEAMS();
	
	my $st = stat($file);
	my $mod_time_string = strftime "%F %H:%M:%S.00", localtime($st->mtime);
	my $release = $self->{_release} || $file;
	
# FIXME Add to schema
#				ipi_file_name => $file,

	my %rowdata_h = ( 	
				ipi_version_name => $release,
				ipi_version_date => $mod_time_string,
				
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
		
				my $truncated_val = substr($record_h{$key}, 0, 254);
			
				$self->anno_error(error => "Warning HASH Value truncated for key '$key'\n,ORIGINAL VAL SIZE:". length($big_val). "'$big_val'\nNEW VAL SIZE:" . length($truncated_val) . "'$truncated_val'");
				#print "VAL '$record_h{$key}'\n"
				$record_h{$key} = $truncated_val;
			}
		}
		return %record_h;
	
	}elsif($data_aref){
		@data = @$data_aref;
		
		for(my $i=0; $i<=$#data; $i++){
			if (length $data[$i] > 255){
				my $big_val = $data[$i];
		
				my $truncated_val = substr($data[$i], 0, 254);
			
				$self->anno_error(error => "Warning DATA Val truncated\n,ORIGINAL VAL SIZE:". length($big_val). "'$big_val'\nNEW VAL SIZE:" . length($truncated_val) . "'$truncated_val'");
				#print "VAL '$record_h{$key}'\n"
				$data[$i] = $truncated_val;
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
	my $method = 'anno_error';
	my $self = shift;
	
	my %args = @_;
	
	if (exists $args{error} ){
		if ($self->verbose() > 0){
			print "$args{error}\n";
		}
		return $self-> {ERROR} .= "\n$args{error}";	#might be more then one error so append on new errors
		
	}else{
		$self->{ERROR};
	
	}


}



}#closing bracket for the package

1;
