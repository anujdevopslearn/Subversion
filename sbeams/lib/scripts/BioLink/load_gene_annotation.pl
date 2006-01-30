#!/usr/local/bin/perl

###############################################################################
# Program     : load_gene_annotation.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script is a first attempt at transforming the gene
#               data in GO into something I can integrate into proteomics
#               queries more easily
#
###############################################################################



###############################################################################
# Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib qw ( ../../perl );
use vars qw ($sbeams $sbeamsPROT $q
             $PROG_NAME $USAGE %OPTIONS $QUIET $DEBUG $DATABASE $TESTONLY
             %GO_leaf $GODATABASE $MYSQLGODBNAME
             $current_contact_id $current_username
	     $MAX_LEVELS
            );


#### Set up SBEAMS core module
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Proteomics::Tables;
use SBEAMS::BioLink::Tables;

$sbeams = SBEAMS::Connection->new();


#### Set program name and usage banner
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] --xref_dbname xxx
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag
  --testonly          Set flag which prevents executing SQL writes
  --xref_dbname       Defines which GO xref_dbname to load (e.g. FB, SGD)
  --godatabaseprefix  Database prefix of the local Gene Onology database (e.g. go.dbo.)

 e.g.:  $PROG_NAME --testonly --xref_dbname FB

EOU


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
  "xref_dbname:s","godatabaseprefix:s","mysqlgodbname:s",
  )) {
  print "$USAGE";
  exit;
}

my $VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
$TESTONLY = $OPTIONS{"testonly"} || 0;
if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
  print "  TESTONLY = $TESTONLY\n";
}



###############################################################################
# Set Global Variables and execute main()
###############################################################################
main();
exit(0);



###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
###############################################################################
sub main {

  #### Do the SBEAMS authentication and exit if a username is not returned
  exit unless ($current_username = $sbeams->Authenticate(
    work_group=>'developer',
  ));


  $sbeams->printPageHeader() unless ($QUIET);
  handleRequest();
  $sbeams->printPageFooter() unless ($QUIET);


} # end main



###############################################################################
# handleRequest
###############################################################################
sub handleRequest {
  my %args = @_;


  #### Define standard variables
  my ($i,$element,$key,$value,$line,$result,$sql);


  #### Set the command-line options
  my $xref_dbname = $OPTIONS{xref_dbname};
  $DATABASE = $DBPREFIX{BioLink};
  $GODATABASE = $OPTIONS{godatabaseprefix};

  #### Verify that xref_dbname was supplied
  unless ($xref_dbname) {
    print "ERROR: --xref_dname must be supplied!\n";
    print $USAGE;
    exit;
  }


  #### Print out the header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }



  ##########################################################################


  #### Get entire flattened GO hierarchy

  #### Maximum number of levels to flatten
  $MAX_LEVELS = 20;


  #### Refresh annotation_hierarchy_level
  refreshAnnotationHierarchyLevels(
    max_levels => $MAX_LEVELS,
  );


  #### Build the SQL query
  my $sql_part1 = "SELECT OT.acc,OT.name,P1.acc,P1.name\n";
  my $sql_part2 = qq~  FROM ${GODATABASE}term OT
  LEFT JOIN ${GODATABASE}term2term TT1 ON ( OT.id = TT1.term2_id )
  LEFT JOIN ${GODATABASE}term P1 ON ( TT1.term1_id = P1.id )
~;

  for ($i=2; $i<$MAX_LEVELS; $i++) {
    my $pi = $i - 1;
    $sql_part1 .= "         ,P$i.acc,P$i.name\n";
    $sql_part2 .= "  LEFT JOIN ${GODATABASE}term2term TT$i ON ( P$pi.id = TT$i.term2_id )\n";
    $sql_part2 .= "  LEFT JOIN ${GODATABASE}term P$i ON ( TT$i.term1_id = P$i.id )\n";
  }

  my $sql = $sql_part1.$sql_part2;
  #$sql .=" WHERE OT.id BETWEEN 5000 AND 5005\n";
  #print $sql;

  #### Fetch all the term paths
  print "INFO: Fetching paths for all terms...\n";
  my @term_paths = $sbeams->selectSeveralColumns($sql);

  #### Define a hash to store all organized lineages
  my %term_lineage;

  #### Loop over each flatten term path and store in the hash
  foreach my $term_path ( @term_paths ) {
    my $leaf_acc = $term_path->[0];
    my $leaf_name = $term_path->[1];

    #### Squawk if MAX LEVELS isn't deep enough
    if ($term_path->[($MAX_LEVELS-1)*2]) {
      print "WARNING: MAX_LEVELS is not enough!\n";
    }

    #### Construct the path
    my @path;
    my $level_counter = 1;
    for ($i=$MAX_LEVELS-1; $i>0; $i--) {
      my $next_acc = $term_path->[$i*2];
      my $next_name = $term_path->[$i*2+1];
      if ($next_acc && $next_name ne 'all'
	  #&&
          #$next_name ne 'molecular_function' &&
          #$next_name ne 'biological_process' &&
          #$next_name ne 'cellular_component'
         ) {
	$level_counter++;
	push(@path,[$next_acc,$next_name]);
      }
    }
    push(@path,[$leaf_acc,$leaf_name]);

    #### If we already have information for this accession, add it.
    #### else create a new entry in the hash
    if (exists($term_lineage{$leaf_acc})) {
      push(@{$term_lineage{$leaf_acc}},\@path);
    } else{
      $term_lineage{$leaf_acc} = [ \@path ];
    }

    #print "$leaf_name($level_counter): ".join(" -> ",@path)."\n\n";

  }

  @term_paths = undef;


  ##########################################################################





  #### Load lookup hash for organism_namespace
  $sql = qq~
	SELECT organism_namespace_tag,organism_namespace_id
	  FROM ${DATABASE}organism_namespace
  ~;
  my %organism_namespace_ids = $sbeams->selectTwoColumnHash($sql);

  #### Add entries for all-caps as a hack for GO problems
  foreach my $id (keys(%organism_namespace_ids)) {
    my $ID = uc($id);
    unless ($organism_namespace_ids{$ID}) {
      $organism_namespace_ids{$ID} = $organism_namespace_ids{$id};
    }
    #### Hack to also have another capitalization
    if ($id eq 'UniProt') {
      $organism_namespace_ids{'Uniprot'} = $organism_namespace_ids{$id};
    }
  }


  #### Create a list of annotated gene products

  #### For HuIPI
  if ($xref_dbname eq 'HuIPI') {

    #### Get a list of the genes for this xref_dbname
    $sql = qq~
	SELECT DISTINCT ipi_accession,'$xref_dbname',MIN(ref_db_symbol),
               ISNULL(biosequence_accession,ipi_accession)
	  FROM ${DATABASE}goa_association GA
          LEFT JOIN $TBPR_BIOSEQUENCE B
               ON ( GA.ipi_accession = B.biosequence_gene_name AND B.biosequence_set_id = 9 )
	 WHERE ipi_accession IS NOT NULL
	   AND go_id IS NOT NULL
	 GROUP BY ipi_accession,ISNULL(biosequence_accession,ipi_accession)
	 ORDER BY ipi_accession,ISNULL(biosequence_accession,ipi_accession)
    ~;


  #### Otherwise, do it the standard way
  } else {

    #### The way we create the accession columns differs among sources
    my $accession_column_sql = "xref_key";
    $accession_column_sql = "symbol" if ($xref_dbname eq 'SGD');
    $accession_column_sql = "symbol" if ($xref_dbname eq 'SPTR');
    $accession_column_sql = "symbol" if ($xref_dbname eq 'UniProt');
    $accession_column_sql = "symbol" if ($xref_dbname eq 'TAIR');


    #### Get a list of the genes for this xref_dbname
    $sql = qq~
	SELECT GP.id AS 'gene_product_id',D.xref_dbname,symbol,
               $accession_column_sql
	  FROM ${GODATABASE}gene_product GP
	 INNER JOIN ${GODATABASE}dbxref D ON ( GP.dbxref_id = D.id )
	 WHERE D.xref_dbname = '$xref_dbname'
           AND $accession_column_sql != ''
        --   AND symbol LIKE 'FAA2'
    ~;

  }


  #### Define column map
  my %column_map = (
    '1'=>'organism_namespace_id',
    '2'=>'gene_name',
    '3'=>'gene_accession',
  );


  #### Define the transform map
  #### (see sbeams/lib/scripts/PhenoArray/update_plasmids.pl)
  my %transform_map = (
    '1' => \%organism_namespace_ids,
    '2' => \&transformGeneName,
  );

  #### Define the column that controls the UPDATing uniqueness
  my %update_keys = (
    'gene_accession'=>'3',
     );

  #### Define a hash to receive the annotated_gene_ids
  my %annotated_gene_ids = ();

  #### Execute $sbeams->transferTable() to update annotated_gene table
  print "\nTransferring SQL -> annotated_gene";
  $sbeams->transferTable(
    src_conn=>$sbeams,
    sql=>$sql,
    src_PK_name=>'gene_product_id',
    src_PK_column=>'0',
    dest_PK_name=>'annotated_gene_id',
    dest_conn=>$sbeams,
    insert=>1,
    update_keys_ref=>\%update_keys,
    column_map_ref=>\%column_map,
    transform_map_ref=>\%transform_map,
    table_name=>"${DATABASE}annotated_gene",
    newkey_map_ref=>\%annotated_gene_ids,
    verbose=>$VERBOSE,
    testonly=>$TESTONLY,
  );


  ##########################################################################


  #### Set up a hash of hashes to contain index and summary information
  my %gene_data;
  my $prev_gene_product_id;
  my $gene_product_id;


  $sql = qq~
	SELECT gene_annotation_type_tag,gene_annotation_type_id
	  FROM ${DATABASE}gene_annotation_type
  ~;
  my %gene_annotation_type_ids = $sbeams->selectTwoColumnHash($sql);


  #### For HuIPI
  if ($xref_dbname eq 'HuIPI') {

    #### Get a list of all the GO annotations for HuIPI
    $sql = qq~
	SELECT ipi_accession,ipi_accession,go_id,
	       T.name,GAT.gene_annotation_type_tag
	  FROM ${DATABASE}goa_association GA
          JOIN ${GODATABASE}term T ON ( go_id = T.acc )
          LEFT JOIN ${DATABASE}gene_annotation_type GAT
               ON ( GA.go_term_type_tag = GAT.gene_annotation_type_code )
	 WHERE ref_db_tag = 'SPTR'
	 --  AND ref_db_symbol = 'GP25_HUMAN'
	 ORDER BY ref_db_symbol,T.acc
    ~;

  } else {

    #### Get a list of all the GO annotations for this xref_dbname
    $sql = qq~
	SELECT GP.id AS 'gp_id',GP.symbol,T.acc,T.name,T.term_type
	  FROM ${GODATABASE}association A
	 INNER JOIN ${GODATABASE}term T ON ( A.term_id = T.id )
	 INNER JOIN ${GODATABASE}gene_product GP ON ( A.gene_product_id = GP.id )
	 INNER JOIN ${GODATABASE}dbxref D ON ( GP.dbxref_id = D.id )
	 WHERE 1 = 1
	--   AND GP.symbol LIKE 'Top2'
	--   AND GP.symbol LIKE 'FAA2'
	   AND D.xref_dbname = '$xref_dbname'
	 ORDER BY GP.symbol,GP.id,T.acc
    ~;

  }

  print "\nGetting list of all GO annotations for $xref_dbname...\n";
  my @rows = $sbeams->selectSeveralColumns($sql);
  print "Found ".scalar(@rows)." rows...  Process them all\n";

  #### Storage area for level-based annotations
  my $level_annotations;

  #### Loop over all rows of returned data
  my $row_counter = 0;
  foreach my $row (@rows) {

    #### Extract some values from this row
    $gene_product_id = $row->[0];
    my $gene_name = $row->[1];
    my $external_accession = $row->[2];
    my $term_type = $row->[4];


    #print "======",$prev_gene_product_id," , ",$gene_product_id,"\n"
    #  if ($VERBOSE);

    #### If we've moved onto a new gene, write some summary above the previous
    if ($prev_gene_product_id && ($prev_gene_product_id ne $gene_product_id)) {
      writeSummaryRecord(
        gene_attributes => $gene_data{$prev_gene_product_id},
        gene_product_id => $prev_gene_product_id,
        annotated_gene_ids => \%annotated_gene_ids,
      );

      writeLevelAnnotations(
        gene_product_id => $prev_gene_product_id,
        level_annotations => $level_annotations,
        gene_annotation_type_ids => \%gene_annotation_type_ids,
        annotated_gene_ids => \%annotated_gene_ids,
      );

      #### Reset the level-based annotations
      $level_annotations = undef;

    }


    #### Set some column values for stuff to insert
    my %rowdata;
    $rowdata{external_accession} = $external_accession;
    $rowdata{annotation} = $row->[3];

    print "\nProcessing gene $gene_name association to $external_accession\n"
      if ($VERBOSE);

    $rowdata{annotated_gene_id} = $annotated_gene_ids{$gene_product_id};
    unless ($rowdata{annotated_gene_id}) {
      print "Did not find a gene with gene_product_id $gene_product_id\n";
      next;
    }


    #### Get the gene_annotation_type_id for this term
    my $gene_annotation_type_id = $gene_annotation_type_ids{$term_type};
    unless ($gene_annotation_type_id) {
      print "ERROR: Unable to determine gene_annotation_type_id for:\n";
      printf("--- %s:  %s\n",$external_accession,$rowdata{annotation});
      next;
    }


    #### Set some additional parameters for this row
    $rowdata{gene_annotation_type_id} = $gene_annotation_type_id;
    $rowdata{external_reference_set_id} = 1;
    $rowdata{is_summary} = 'N';
    $rowdata{hierarchy_level} = 'leaf';

    #### If we don't already have a counter index for this gene's term-type
    #### then start a summary entry
    unless ($gene_data{$gene_product_id}->{$gene_annotation_type_id}->{idx}) {
      $gene_data{$gene_product_id}->{$gene_annotation_type_id}->{idx} = 0;
      $gene_data{$gene_product_id}->{$gene_annotation_type_id}->
        {external_accession} = $external_accession;
      $gene_data{$gene_product_id}->{$gene_annotation_type_id}->
        {annotation} = $rowdata{annotation};

    #### Otherwise, just add this new association to the list
    } else {
      $gene_data{$gene_product_id}->{$gene_annotation_type_id}->
        {external_accession} .= ';'.$external_accession;
      $gene_data{$gene_product_id}->{$gene_annotation_type_id}->
        {annotation} .= ';'.$rowdata{annotation};
    }

    #### Increase the counter and set the row attribute
    $gene_data{$gene_product_id}->{$gene_annotation_type_id}->{idx}++;
    $rowdata{idx} =
      $gene_data{$gene_product_id}->{$gene_annotation_type_id}->{idx};

    #### Insert the row
    my $result = $sbeams->insert_update_row(
      insert=>1,
      table_name=>"${DATABASE}gene_annotation",
      rowdata_ref=>\%rowdata,
      PK_name=>'gene_annotation_id',
      #return_PK=>1,
      verbose=>$VERBOSE,
      testonly=>$TESTONLY,
    );


    #### Process all the annotations to a level-by-level format
    print "Processing full level information ...\n" if ($VERBOSE);
    my @term_lineages = @{$term_lineage{$external_accession}};
    unless (@term_lineages) {
      print "ERROR: No lineage found for term $external_accession\n";
    }

    my $lineage_num = 0;

    foreach my $term_lineage ( @term_lineages ) {
      my $gene_annotation_type = $term_lineage->[0]->[1];
      my $gene_annotation_type_id =
	$gene_annotation_type_ids{$gene_annotation_type} or
	die("ERROR: Unable to decode '$gene_annotation_type'");

      #print "  Lineage $lineage_num of type $gene_annotation_type".
      #  "($gene_annotation_type_id)\n";

      my $level_num = 0;
      my $plevel;

      #### Loop over each level in the hierarchy, storing the annotation
      foreach my $level ( @{$term_lineage} ) {
	#print "    $level_num - $level->[0]:$level->[1]\n";

	#### If this is not the base category, store the annotation in a
	#### hash.  This has the benefit of removing duplicates
	if ($level_num>0) {
	  $level_annotations->{$gene_annotation_type}->{$level_num}->
	    {$level->[0]} = $level->[1];
	}

	$level_num++;
	$plevel = $level;
      }

      #### Fill down the last annotation all the way to MAX_LEVELS
      for ($i=$level_num; $i<$MAX_LEVELS; $i++) {
	$level_annotations->{$gene_annotation_type}->{$i}->
	  {$plevel->[0]} = $plevel->[1];
      }

      $lineage_num++;
    }



    #### Set this gene_product_id to the previous one
    $prev_gene_product_id = $gene_product_id;

    #### Print progress information
    $row_counter++;
    print "$row_counter..." if ($row_counter % 100 == 0);

  }



  #### Write out the summary for the last row
  writeSummaryRecord(
    gene_attributes => $gene_data{$prev_gene_product_id},
    gene_product_id => $prev_gene_product_id,
    annotated_gene_ids => \%annotated_gene_ids,
  );

  writeLevelAnnotations(
    gene_product_id => $prev_gene_product_id,
    level_annotations => $level_annotations,
    gene_annotation_type_ids => \%gene_annotation_type_ids,
    annotated_gene_ids => \%annotated_gene_ids,
  );


  return if ($xref_dbname eq 'HuIPI');



  ##########################################################################
  ##########################################################################
  ##########################################################################
  INTERPROPART:

  #### Load Interpro definition information
  open(INFILE,"/net/db/src/InterPro/names.dat");
  my $line = '';
  my %interpro_definitions;
  while ($line = <INFILE>) {
    chomp $line;
    if ($line =~ /^(IPR\d+)/) {
      my $accession = $1;
      my $annotation = substr($line,10,999);
      $interpro_definitions{$accession} = $annotation;
    }
  }
  close(INFILE);


  $prev_gene_product_id = undef;
  %gene_data = ();
  my $gene_annotation_type_id = 4;


  #### Get a list of all the GO annotations for this xref_dbname
  $sql = qq~
	SELECT GP.id AS 'gp_id',GP.symbol,D2.xref_key,COUNT(*) AS 'Count'
	  FROM ${GODATABASE}gene_product GP
	 INNER JOIN ${GODATABASE}gene_product_seq GPS ON ( GP.id = GPS.gene_product_id )
	 INNER JOIN ${GODATABASE}dbxref D1 ON ( GP.dbxref_id = D1.id )
	 INNER JOIN ${GODATABASE}seq S ON ( GPS.seq_id = S.id )
	 INNER JOIN ${GODATABASE}seq_dbxref SD ON ( S.id = SD.seq_id )
	 INNER JOIN ${GODATABASE}dbxref D2 ON ( SD.dbxref_id = D2.id )
	 WHERE 1 = 1
	--   AND GP.symbol LIKE 'Top%'
	   AND D1.xref_dbname = '$xref_dbname'
	   AND D2.xref_dbname = 'InterPro'
	 GROUP BY GP.id,GP.symbol,D2.xref_key
	 ORDER BY GP.id,GP.symbol,D2.xref_key
  ~;

  @rows = $sbeams->selectSeveralColumns($sql);

  #### Loop over all rows of returned data
  my $row_counter = 0;
  foreach my $row (@rows) {

    #### Extract some values from this row
    $gene_product_id = $row->[0];
    my $gene_name = $row->[1];
    my $external_accession = $row->[2];

    print "$gene_product_id   $gene_name  $external_accession\n"
      if ($VERBOSE);


    #### If we've moved onto a new gene, write some summary above the previous
    print "======",$prev_gene_product_id," , ",$gene_product_id,"\n"
      if ($VERBOSE);
    if ($prev_gene_product_id && ($prev_gene_product_id ne $gene_product_id)) {
      while (($key,$value) = each %{$gene_data{$prev_gene_product_id}}) {
        print "  $key = $value\n" if ($VERBOSE);
        my %rowdata;
        $rowdata{annotated_gene_id} =
          $annotated_gene_ids{$prev_gene_product_id};
        $rowdata{gene_annotation_type_id} = $key;
        $rowdata{idx} = 0;
        $rowdata{is_summary} = 'Y';
        $rowdata{hierarchy_level} = 'leaf';
        $rowdata{external_reference_set_id} = 2;
        $rowdata{external_accession} = $value->{external_accession};
        $rowdata{annotation} = $value->{annotation};

        my $result = $sbeams->insert_update_row(
          insert=>1,
          table_name=>"${DATABASE}gene_annotation",
          rowdata_ref=>\%rowdata,
          PK_name=>'gene_annotation_id',
          #return_PK=>1,
          verbose=>$VERBOSE,
          testonly=>$TESTONLY,
        );

      }
    }


    #### Set some column values for stuff to insert
    my %rowdata = ();
    $rowdata{external_accession} = $external_accession;
    $rowdata{annotation} = $interpro_definitions{$external_accession};
    unless ($rowdata{annotation}) {
      print "\nERROR: Unable to get definition for $external_accession\n";
      $rowdata{annotation} = '????';
    }

    print "\nProcessing gene $gene_name association to $external_accession\n"
      if ($VERBOSE);

    $rowdata{annotated_gene_id} = $annotated_gene_ids{$gene_product_id};
    unless ($rowdata{annotated_gene_id}) {
      die "Did not find a gene with gene_product_id $gene_product_id";
    }


    $rowdata{gene_annotation_type_id} = $gene_annotation_type_id;
    $rowdata{external_reference_set_id} = 2;
    $rowdata{is_summary} = 'N';
    $rowdata{hierarchy_level} = 'leaf';

    unless ($gene_data{$gene_product_id}->{$gene_annotation_type_id}->{idx}) {
      $gene_data{$gene_product_id}->{$gene_annotation_type_id}->{idx} = 0;
      $gene_data{$gene_product_id}->{$gene_annotation_type_id}->
        {external_accession} = $external_accession;
      $gene_data{$gene_product_id}->{$gene_annotation_type_id}->
        {annotation} = $rowdata{annotation};
    } else {
      $gene_data{$gene_product_id}->{$gene_annotation_type_id}->
        {external_accession} .= ';'.$external_accession;
      $gene_data{$gene_product_id}->{$gene_annotation_type_id}->
        {annotation} .= ';'.$rowdata{annotation};
    }

    $gene_data{$gene_product_id}->{$gene_annotation_type_id}->{idx}++;
    $rowdata{idx} =
      $gene_data{$gene_product_id}->{$gene_annotation_type_id}->{idx};

    my $result = $sbeams->insert_update_row(
      insert=>1,
      table_name=>"${DATABASE}gene_annotation",
      rowdata_ref=>\%rowdata,
      PK_name=>'gene_annotation_id',
      #return_PK=>1,
      verbose=>$VERBOSE,
      testonly=>$TESTONLY,
    );


    #### Set this gene_product_id to the previous one
    $prev_gene_product_id = $gene_product_id;

    #### Print progress information
    $row_counter++;
    print "$row_counter..." if ($row_counter % 100 == 0);

  }



  #### Write data for last entry
  print "======",$prev_gene_product_id," , ",$gene_product_id,"\n"
    if ($VERBOSE);
  if (1) {
    while (($key,$value) = each %{$gene_data{$prev_gene_product_id}}) {
      print "  $key = $value\n" if ($VERBOSE);
      my %rowdata;
      $rowdata{annotated_gene_id} =
        $annotated_gene_ids{$prev_gene_product_id};
      $rowdata{gene_annotation_type_id} = $key;
      $rowdata{hierarchy_level} = 'leaf';
      $rowdata{idx} = 0;
      $rowdata{is_summary} = 'Y';
      $rowdata{external_reference_set_id} = 2;
      $rowdata{external_accession} = $value->{external_accession};
      $rowdata{annotation} = $value->{annotation};

      my $result = $sbeams->insert_update_row(
        insert=>1,
        table_name=>"${DATABASE}gene_annotation",
        rowdata_ref=>\%rowdata,
        PK_name=>'gene_annotation_id',
        #return_PK=>1,
        verbose=>$VERBOSE,
        testonly=>$TESTONLY,
      );

    }
  }



  return;

}




###############################################################################
###############################################################################
###############################################################################
###############################################################################

###############################################################################
# transformGeneName
###############################################################################
sub writeSummaryRecord {
  my %args = @_;

  my $gene_attributes = $args{'gene_attributes'} || die("error 1");
  my $gene_product_id = $args{'gene_product_id'} || die("error 2");
  my $annotated_gene_ids = $args{'annotated_gene_ids'} || die("error 3");

  while ( my ($key,$value) = each %{$gene_attributes}) {
    print "  $key = $value\n" if ($VERBOSE);
    my %rowdata;
    $rowdata{annotated_gene_id} = $annotated_gene_ids->{$gene_product_id};
    $rowdata{gene_annotation_type_id} = $key;
    $rowdata{idx} = 0;
    $rowdata{is_summary} = 'Y';
    $rowdata{hierarchy_level} = 'leaf';
    $rowdata{external_reference_set_id} = 1;

    #### Add unfortunate limitation in accession size for indexing reasons
    $rowdata{external_accession} = $value->{external_accession};
    if (length($rowdata{external_accession}) > 880) {
      $rowdata{external_accession} = substr($rowdata{external_accession},0,880).
        '[...]';
    }

    #### Add unfortunate limitation in annotation size for indexing reasons
    $rowdata{annotation} = $value->{annotation};
    if (length($rowdata{annotation}) > 880) {
      $rowdata{annotation} = substr($rowdata{annotation},0,880).
        '[...]';
    }

    my $result = $sbeams->insert_update_row(
      insert=>1,
      table_name=>"${DATABASE}gene_annotation",
      rowdata_ref=>\%rowdata,
      PK_name=>'gene_annotation_id',
      verbose=>$VERBOSE,
      testonly=>$TESTONLY,
    );

  }

  return 1;

}



###############################################################################
# transformGeneName
###############################################################################
sub transformGeneName {
  my $input = shift;
  my $output;

  return unless (defined($input) && $input gt '');

  #### Define the greek letter lookup
  my %greek_letters = (
    'a'=>'alpha',
    'b'=>'beta',
    'g'=>'gamma',
    'd'=>'delta',
    'e'=>'epsilon',
    'z'=>'zeta',
    'ee'=>'eta',
    'th'=>'theta',
    'i'=>'iota',
    'k'=>'kappa',
    'l'=>'lambda',
    'm'=>'mu',
    'n'=>'nu',
    'x'=>'xi',
    'o'=>'omicron',
    'p'=>'pi',
    'r'=>'rho',
    's'=>'sigma',
    't'=>'tau',
    'u'=>'upsilon',
    'ph'=>'phi',
    'kh'=>'chi',
    'ps'=>'psi',
    'PS'=>'Psi',
    'oh'=>'omega',
  );


  $output = $input;

  if ($output =~ /\&/) {
    while ($output =~ /\&(.+?)gr;/) {
      my $letter = $1;
      my $greek_letter = $greek_letters{$letter};
      unless ($greek_letter) {
        die "ERROR: Unrecognized greek letter '$letter'";
      }
      my $substring = "\&${letter}gr;";
      $output =~ s/$substring/$greek_letter/g;
    }

    if ($output =~ /\&/) {
      die "Unable to resolve all &'s in '$output'";
    }


  }

  return $output;

}



###############################################################################
# writeLevelAnnotations
###############################################################################
sub writeLevelAnnotations {
  my %args = @_;

  my $gene_product_id = $args{'gene_product_id'} || die("error 1");
  my $gene_annotation_type_ids = $args{'gene_annotation_type_ids'} or
    die("error 2");
  my $level_annotations = $args{'level_annotations'} || die("error 3");
  my $annotated_gene_ids = $args{'annotated_gene_ids'} || die("error 4");


  #### Create a hash for storing the values for each record
  my %rowdata;
  $rowdata{external_reference_set_id} = 1;

  #### Now that all annotations have been stored, write them out

  #### Loop over each annotation_type (e.g. molecular_function)
  while ( my ($type,$level) = each %{$level_annotations} ) {
    print "Level Annotations for $type(".
      $gene_annotation_type_ids->{$type}.")\n" if ($VERBOSE);

    #### Set the annotation_type_id (e.g. 1 for molecular_function)
    $rowdata{gene_annotation_type_id} = $gene_annotation_type_ids->{$type};

    #### Loop over each level
    for (my $level_num=1; $level_num<$MAX_LEVELS; $level_num++) {
      my $annotation = $level->{$level_num};
      print "  $level_num: " if ($VERBOSE);
      $rowdata{hierarchy_level} = $level_num;
      $rowdata{is_summary} = 'N';
      $rowdata{annotated_gene_id} = $annotated_gene_ids->{$gene_product_id};

      #### Loop over each annotation associated at that level
      my $idx = 1;
      my @accessions;
      my @descriptions;
      while ( my ($accession,$description) = each %{$annotation} ) {
        print "$description," if ($VERBOSE);

	push(@accessions,$accession);
	push(@descriptions,$description);

	$rowdata{idx} = $idx;
	$rowdata{external_accession} = $accession;
	$rowdata{annotation} = $description;

	#### Insert the row
	my $result = $sbeams->insert_update_row(
          insert=>1,
          table_name=>"${DATABASE}gene_annotation",
          rowdata_ref=>\%rowdata,
          PK_name=>'gene_annotation_id',
          verbose=>$VERBOSE,
          testonly=>$TESTONLY,
        );

	$idx++;

      } # endwhile each annotation within a level

      #### Now create a summary record
      $rowdata{idx} = 0;   # 0 means summary record
      $rowdata{is_summary} = 'Y';

      $rowdata{external_accession} = join(';',@accessions);
      #### Add unfortunate limitation in accession size for indexing reasons
      if (length($rowdata{external_accession}) > 880) {
	$rowdata{external_accession} = substr($rowdata{external_accession},0,880).
	  '[...]';
      }

      $rowdata{annotation} = join(';',@descriptions);
      #### Add unfortunate limitation in annotation size for indexing reasons
      if (length($rowdata{annotation}) > 880) {
	$rowdata{annotation} = substr($rowdata{annotation},0,880).
	  '[...]';
      }

      #### Insert the row
      my $result = $sbeams->insert_update_row(
        insert=>1,
        table_name=>"${DATABASE}gene_annotation",
        rowdata_ref=>\%rowdata,
        PK_name=>'gene_annotation_id',
        verbose=>$VERBOSE,
        testonly=>$TESTONLY,
      );

      print "\n" if ($VERBOSE);

    } # endfor each level

  } # endwhile each annotation_type


} # end writeLevelAnnotations



###############################################################################
# refreshAnnotationHierarchyLevels
###############################################################################
sub refreshAnnotationHierarchyLevels {
  my %args = @_;

  my $max_levels = $args{'max_levels'} || die("error 1");

  my $sql = "SELECT * FROM $TBBL_ANNOTATION_HIERARCHY_LEVEL";
  my @rows = $sbeams->selectSeveralColumns($sql);

  if ($VERBOSE) {
    print "MAX_LEVELS = $max_levels\n";
    print "n rows in annotation_hierarchy_level = ".scalar(@rows)."\n";
  }

  if (scalar(@rows) == $max_levels) {
    print "Table annotation_hierarchy_levels has the correct number of rows\n";
    return;
  }

  $sql = "DELETE FROM $TBBL_ANNOTATION_HIERARCHY_LEVEL";
  $sbeams->executeSQL($sql);


  my %rowdata = ( annotation_hierarchy_level_name => 'leaf' );
  $sbeams->insert_update_row(
    insert=>1,
    table_name=>"$TBBL_ANNOTATION_HIERARCHY_LEVEL",
    rowdata_ref=>\%rowdata,
    PK_name=>'annotation_hierarchy_level_id',
    verbose=>$VERBOSE,
    testonly=>$TESTONLY,
  );

  for (my $level=1; $level < $MAX_LEVELS; $level++) {
    $rowdata{annotation_hierarchy_level_name} = $level;
    $sbeams->insert_update_row(
      insert=>1,
      table_name=>"$TBBL_ANNOTATION_HIERARCHY_LEVEL",
      rowdata_ref=>\%rowdata,
      PK_name=>'annotation_hierarchy_level_id',
      verbose=>$VERBOSE,
      testonly=>$TESTONLY,
    );
  }

  print "Table annotation_hierarchy_levels updated to max_level=$max_levels\n";
  return;

}
