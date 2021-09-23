#!/usr/local/bin/perl 
###############################################################################
## Program     : get_table_columns.pl 
##
## Description : export table information from PeptideAtlas database
##
################################################################################
#
#
## 
#
use strict;
use Getopt::Long;
use FindBin;
$|++;

use lib "$ENV{SBEAMS}/lib/perl/";
use vars qw ($sbeams $sbeamsMOD $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY 
             $TABLE_NAME ); 

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

$sbeams = new SBEAMS::Connection;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

$sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);

$PROG_NAME = $FindBin::Script;

my %tables = (
	peptide_mapping => 1,
	peptide_instance => 1,
	peptide_instance_sample => 1,
	peptide_instance_search_batch => 1,
	modified_peptide_instance => 1,
	modified_peptide_instance_sample => 1,
	modified_peptide_instance_search_batch => 1,
	spectrum => 1,
	spectrum_identification => 1,
	spectrum_ptm_identification => 1,
	protein_identification => 1,
	biosequence_relationship => 1,
	biosequence_id_atlas_build_search_batch => 1,
	ptm_summary => 1,
	#nextprot_mapping => 1,
	#nextprot_chpp_summary => 1,
	#nextprot_chromosome_mapping => 1,
	#	atlas_build_search_batch => 1,
	# atlas_build_sample => 1,
	#	search_batch_statistics => 1,
	#	dataset_statistics => 1,
	# spectra_description_set => 1,
	#SEARCH_KEY => 1,
	#SEARCH_KEY_LINK => 1,
);

my $sql = qq~
	use peptideatlas_2
	SELECT TABLE_NAME , COLUMN_NAME
	FROM INFORMATION_SCHEMA.COLUMNS
	WHERE TABLE_SCHEMA = 'dbo'
	AND COLUMNPROPERTY(object_id(TABLE_NAME), COLUMN_NAME, 'IsIdentity') = 1
	ORDER BY TABLE_NAME
~;
my %auto_inc_columns =();
my @rows = $sbeams->selectSeveralColumns($sql);
foreach my $row (@rows){
  $auto_inc_columns{lc($row->[0])}{lc($row->[1])} =1;
}

my %foreign_keys = ();
$sql = qq~
	use peptideatlas_2
	SELECT  obj.name AS FK_NAME,
			sch.name AS [schema_name],
			tab1.name AS [table],
			col1.name AS [column],
			tab2.name AS [referenced_table],
			col2.name AS [referenced_column]
	FROM sys.foreign_key_columns fkc
	INNER JOIN sys.objects obj
			ON obj.object_id = fkc.constraint_object_id
	INNER JOIN sys.tables tab1
			ON tab1.object_id = fkc.parent_object_id
	INNER JOIN sys.schemas sch
			ON tab1.schema_id = sch.schema_id
	INNER JOIN sys.columns col1
			ON col1.column_id = parent_column_id AND col1.object_id = tab1.object_id
	INNER JOIN sys.tables tab2
			ON tab2.object_id = fkc.referenced_object_id
	INNER JOIN sys.columns col2
			ON col2.column_id = referenced_column_id AND col2.object_id = tab2.object_id
~;
@rows = $sbeams->selectSeveralColumns($sql);
foreach my $row (@rows){
	#FK_NAME,schema_name,table,column,referenced_table,referenced_column,
	#FK__proteotyp__prote__4999D985,dbo,proteotypic_peptide_xspecies_mapping,proteotypic_peptide_mapping_id,proteotypic_peptide_mapping,proteotypic_peptide_mapping_id,
  my ($fk_name, $schema_name, $table_name, $column_name, $referenced_table, $referenced_column_name) = @$row;
  $foreign_keys{lc($table_name)}{lc($column_name)}{ref_table} = 'AT_'. lc($referenced_table);  
  $foreign_keys{lc($table_name)}{lc($column_name)}{ref_col} = lc($referenced_column_name);
}

my %primary_keys =();
$sql = qq~
  use peptideatlas_2

	select schema_name(tab.schema_id) as [schema_name], 
			pk.[name] as pk_name,
			ic.index_column_id as column_id,
			col.[name] as column_name, 
			tab.[name] as table_name
	from sys.tables tab
			inner join sys.indexes pk
					on tab.object_id = pk.object_id 
					and pk.is_primary_key = 1
			inner join sys.index_columns ic
					on ic.object_id = pk.object_id
					and ic.index_id = pk.index_id
			inner join sys.columns col
					on pk.object_id = col.object_id
					and col.column_id = ic.column_id
	order by schema_name(tab.schema_id),
			pk.[name],
			ic.index_column_id
~;
@rows = $sbeams->selectSeveralColumns($sql);
foreach my $row (@rows){
  my ($pk_name, $column_id, $column, $column_name, $table_name) = @$row;
  $primary_keys{lc($table_name)}= lc($column_name) ; 
}



open (TC, ">table_columns.txt") or die "cannot open table_columns.txt\n";
print TC "table_name\tcolumn_index\tcolumn_name\tcolumn_title\tdatatype\tscale\tprecision\tnullable\tdefault_value\tis_auto_inc\tfk_table\tfk_column_name\tis_required\tinput_type\tinput_length\tonChange\tis_data_column\tis_display_column\tis_key_field\tcolumn_text\toptionlist_query\turl\n";
open (TP, ">table_property.txt") or die "cannot open table_property.txt\n";
print TP "table_name\tCategory\ttable_group\tmanage_table_allowed\tdb_table_name\tPK_column_name\tmulti_insert_column\ttable_url\tmanage_tables\tnext_step\n";

foreach my $table (keys %tables){
 my $sql  = qq~
  use peptideatlas_2
  select * 
	FROM INFORMATION_SCHEMA.COLUMNS
	WHERE TABLE_NAME = '$table'
 ~;


	my @rows = $sbeams->selectSeveralColumns($sql);
  foreach my $row (@rows){
    $_  = lc for @$row;
    my ($table_catalog,$table_schema,$table_name,$column_name,$ordinal_position,$column_default,$is_nullable,$data_type,$character_maximum_length,$character_octet_length,$numeric_precision,$numeric_precision_radix,$numeric_scale,$datetime_precision,$character_set_catalog,$character_set_schema,$character_set_name,$collation_catalog,$collation_schema,$collation_name,$domain_catalog,$domain_schema,$domain_name) = @$row;
   # output:
   #table_name,column_index,column_name,column_title,datatype,scale,precision,nullable,default_value,is_auto_inc,fk_table,fk_column_name,is_required,input_type,input_length,onChange,is_data_column,is_display_column,is_key_field,column_text,optionlist_query,url
    print TC "AT_$table_name\t$ordinal_position\t$column_name\t$column_name\t$data_type\t$character_maximum_length\t". 
              "$numeric_precision\t$is_nullable\t$column_default\t";

    if ($primary_keys{$table} eq $column_name && not defined $auto_inc_columns{$table_name}{$column_name}){
      print "table=$table primary_key_column=$column_name auto_inc=F\n";
    }
    if (defined $auto_inc_columns{$table_name}{$column_name}){
      print TC "Y\t";
    }else{
      print TC "N\t";
    }
    if (defined  $foreign_keys{$table_name}{$column_name}){
      print TC "$foreign_keys{$table_name}{$column_name}{ref_table}\t$foreign_keys{$table_name}{$column_name}{ref_col}\t"; 
    }else{
      print TC "\t\t";
    }
    print TC "\n";
		#table_name  Category  table_group manage_table_allowed  db_table_name PK_column_name  multi_insert_column table_url manage_tables next_step
		#AT_peptide_instance Peptide Instance  PeptideAtlas_infrastructure NO  $TBAT_PEPTIDE_INSTANCE  peptide_instance_id
  }
  #print "$table $primary_keys{$table}\n";
	print TP "AT_$table\t$table\tPeptideAtlas_infrastructure\tNO\t\$TBAT_". uc ($table) ."\t$primary_keys{$table}\n";
  
}
close TC;
close TP;

exit;

__DATA__

input: 
select * from information_schema.columns
where table_name = 'ptm_summary'
AND EXTRA like '%auto_increment%'

,TABLE_CATALOG,TABLE_SCHEMA,TABLE_NAME,COLUMN_NAME,ORDINAL_POSITION,COLUMN_DEFAULT,IS_NULLABLE,DATA_TYPE,CHARACTER_MAXIMUM_LENGTH,CHARACTER_OCTET_LENGTH,NUMERIC_PRECISION,NUMERIC_PRECISION_RADIX,NUMERIC_SCALE,DATETIME_PRECISION,CHARACTER_SET_CATALOG,CHARACTER_SET_SCHEMA,CHARACTER_SET_NAME,COLLATION_CATALOG,COLLATION_SCHEMA,COLLATION_NAME,DOMAIN_CATALOG,DOMAIN_SCHEMA,DOMAIN_NAME,
,----------------,---------------,-------------,-------------------------,-------------------,-----------------,--------------,------------,---------------------------,-------------------------,--------------------,--------------------------,----------------,---------------------,------------------------,-----------------------,---------------------,--------------------,-------------------,----------------------------,-----------------,----------------,--------------,
,PeptideAtlas_2,dbo,ptm_summary,id,1,(null),NO,int,(null),(null),10,10,0,(null),(null),(null),(null),(null),(null),(null),(null),(null),(null),
,PeptideAtlas_2,dbo,ptm_summary,atlas_build_id,2,(null),NO,int,(null),(null),10,10,0,(null),(null),(null),(null),(null),(null),(null),(null),(null),(null),
,PeptideAtlas_2,dbo,ptm_summary,biosequence_id,3,(null),NO,int,(null),(null),10,10,0,(null),(null),(null),(null),(null),(null),(null),(null),(null),(null),
,[Executed:,7/2/21,2:57:50,PM,PDT,],[Execution:,21/ms],

