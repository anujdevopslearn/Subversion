package SBEAMS::SolexaTrans::Data::Babel;
#################################################################################
#
# Author:	Victor Cassen
# Created:	28Jul08
# $Id: Babel.pm,v 1.5 2008/11/10 17:50:47 phonybone Exp $
#
#################################################################################
use strict;
use warnings;
use Carp;
use Data::Dumper;
use vars qw($dbhandler);
use DBI;

use base qw(Class::AutoClass);
use vars qw(@AUTO_ATTRIBUTES @CLASS_ATTRIBUTES %SYNONYMS %DEFAULTS);
@AUTO_ATTRIBUTES=qw(id db_host db_name db_user db_pw);
%SYNONYMS=(db_pass=>'db_pw');
@CLASS_ATTRIBUTES=qw(_dbh tableinfo sources types history src_type2col 
		     add_sql babel_table join_types);
%DEFAULTS=(
	   history=>{
	       locus_link=>'gene_history',
	       hgnc=>'hgnc_history',
	       ipi=>'ipi_history',
	       uniprot=>'uniprot_history',
	   },
	   babel_table=>'babel_tables',
	   # so src_type2col clearly depends on external naming conventions
	   # column names must be "unique", in as much as 
	   src_type2col=>{
	       gene=>{
		   locuslink=>'locus_link_eid',
		   hgnc=>'hgnc_eid',
		   biocarta=>'biocarta_pathway_gene_id',
		   kegg=>'kegg_pathway_gene_id',
		   ensembl=>'ensembl_eid',
		   rgd=>'rgd_eid',
		   mgd=>'mgd_eid',
		   symbol=>'symbol',
		   gi=>'sequence_gi',
		   synonym=>'synonym',
	       },
	       pathway=>{
		   reactome=>'reactome_pathway_eid',
	       },
	       protein=>{
		   ipi=>'ipi_eid',
		   gi=>'protein_gi',
		   ensembl=>'protein_eid',
		   pepatlas=>'pepatlas_eid',
		   uniprot=>'uniprot_eid',
		   acc=>'protein_eid',
	       },
	       publication=>{
		   pubmed=>'pubmed_eid',
	       },
	       function=>{
		   ec=>'ec_eid',
	       },
	       sequence=>{
		   unigene=>'sequence_eid',
		   ensemble=>'transcript_eid',
		   gi=>'transcript_gi',
		   epcondb=>'epcondb_transcript_eid',
		   acc=>'transcript_eid',
	       },
	       cluster=>{
		   unigene=>'unigene_eid',
	       },
	       tissue=>{
		   tissue_expression=>'tissue_id',
	       },
	       go=>{
		   go=>'go_eid',
	       },
	       omim=>{
		   omim=>'omim_eid',
	       },
	       probe=>{
		   affy=>'probe_id',
	       },
	   },
	   add_sql=>{omim_omim=>'omim_type="gene"',
		 },
	   join_types=>[qw(gene_locuslink)],
	   );

Class::AutoClass::declare(__PACKAGE__);

# have to defer this until runtime in order that $dbhandler is created
our $_init_class_called=0;
sub _init_class {
    my ($class)=@_;
    return if $_init_class_called;

    eval "use GDxBase::Globals qw(:all)";# warn $@ if $@ && $ENV{DEBUG};

    $class->load_tables;
    my $src_type2col=$class->src_type2col;
    $class->types([keys %$src_type2col]);
    my %sources;
    foreach my $type (@{$class->types}) {
	my $h=$src_type2col->{$type};
	my @s=keys %$h;
	@sources{@s}=@s;
    }
    $class->sources([keys %sources]);
    $_init_class_called=1;
}

sub dbh {
    my ($self)=@_;
    my $class=ref $self || $self;
    return $class->_dbh if $class->_dbh;

    my $dbh;
    if (defined $dbhandler && ref $dbhandler && $dbhandler->isa('GDxBase::DBHandler')) {
	$dbh=$dbhandler->get_dbh('CORE') or confess "no dbh";
    } elsif (ref $self) {
	my $db_host=$self->db_host;
	my $db_name=$self->db_name;
	my $db_user=$self->db_user;
	my $db_pass=$self->db_pw;
	if (defined $db_host && defined $db_name && defined $db_user && defined $db_pass) {
	    my $dsn="DBI:mysql:host=$db_host:database=$db_name";
#	    warn "dsn is $dsn";
	    $dbh=DBI->connect($dsn,$db_user,$db_pass);
	}
    }
    confess "unable to connect to database: $DBI::errstr (dbhandler=$dbhandler)" unless $dbh;
    $class->_dbh($dbh);
}

# load tables all table/column info from the database into $class->tableinfo
sub load_tables {
    my ($class)=@_;
    my $tablename=$class->babel_table;
    my $sql="SELECT col1,tablename,col2 FROM $tablename";
    confess "dbh not set" unless $class->dbh;
    my $rows=$class->dbh->selectall_arrayref($sql);
    my %tables;
    foreach my $row (@$rows) {
	my ($col1,$tablename,$col2)=@$row;
	$tables{$col1}->{$col2}=$tablename;
	$tables{$col2}->{$col1}=$tablename;
    }
    $class->tableinfo(\%tables);
}

# kinda obsolete; see GDxBase/scripts/babel/load_db.pl instead
sub load_tables_from_file {
    my ($class)=@_;
    my $hostname=`hostname`;
    chomp $hostname;
    my $filename={
	'grits.systemsbiology.net'=>'/jdrf/workspace/vcassen/TACO/software/GDxBase/plugins/connectdots/disease_data_table_id_translations',
	'fala.systemsbiology.net'=>'/home/vcassen/software/GDxBase/plugins/connectdots/disease_data_table_id_translations',
    }->{$hostname} or confess "no table file on $hostname";
    
    my %tables;
    open(TABLES,$filename) or confess "Can't open $filename: $!";
    while (<TABLES>) {
	chomp;
	next if /^#/;
	next if /^\s*$/;
	my ($col1,$tablename,$col2)=split(/\s+/);
#	$col1=~s/_//g;
#	$col2=~s/_//g;
	if (my $t=$tables{$col1}->{$col2}) {
	    warn "duplicate/conflicting info: $col1->$col2=$tablename, $t\n" if $ENV{DEBUG};
	    next;
	}
	if (my $t=$tables{$col2}->{$col1}) {
	    warn "duplicate/conflicting info: $col2->$col1=$tablename, $t\n" if $ENV{DEBUG};
	    next;
	}
	$tables{$col1}->{$col2}=$tablename;
	$tables{$col2}->{$col1}=$tablename;
    }
    $class->tableinfo(\%tables);
}

# this is the main API routine.
# translates one set of ids to a different type
# returns a hash[ref]: k=original id, v=listref of ids, or csv list if $argHash{csv}
sub translate {
    my ($self,%argHash)=@_;
    my $dbh=$self->dbh;

    my $class=ref $self||$self;	# this sux, but safety first!
    $class->_init_class unless $_init_class_called;

    my $src_ids=$argHash{src_ids} or confess "no src_ids";
    my $src_type=$argHash{src_type} or confess "no src_type";
    my $dst_type=$argHash{dst_type} or confess "no dst_type";

    my ($tablename,$src_col,$dst_col)=$self->get_tableinfo($src_type,$dst_type);

    # try to do the translation via a single join if no simple translation exists:
    if (!$tablename) {
	if (my @join_args=$self->_get_join_info($src_type,$dst_type)) {
	    return $self->_translate_join(@join_args,$src_ids);
	} else {
	    confess "no translation table for '$src_type'->'$dst_type'" unless $tablename;
	}
    }

    my $db_name=$dbhandler?$dbhandler->get_db_name('CORE') : $self->db_name;
    my $add_sql=$self->add_sql->{$dst_type};
    my %dst_ids;
    foreach my $src_id (@$src_ids) {
	do {confess "empty value in ",Dumper($src_ids); next} unless $src_id;
	my $sql="SELECT $dst_col FROM $db_name.$tablename WHERE $src_col='$src_id'";
	$sql.=" AND $add_sql" if $add_sql;
	warn "$sql;" if $argHash{debug};
	my $rows=$dbh->selectall_arrayref($sql);

	# if no results and $src_type has a history table, check that
	# this isn't right; it's not actually doing the translation...
	if (!@$rows) {
	    if (my $history_table=$self->history_table($src_type)) {
		$sql="SELECT new_$src_col FROM $history_table WHERE old_$src_col='$src_id'";
		$sql.=" AND $add_sql" if $add_sql;
		warn "$sql;" if $argHash{debug};
		my $r2=$dbh->selectall_arrayref($sql);
		my $new_id=$r2->[0]->[0] if $r2 && $r2->[0];
		if ($new_id) {
		    $sql="SELECT $dst_col FROM $tablename WHERE $src_col='$new_id'";
		    $rows=$dbh->selectall_arrayref($sql);
		}
	    }
	}

	my $ids=[map {$_->[0]} @$rows];
	$ids=join(',',@$ids) if $argHash{csv};
	warn "ids are ",Dumper($ids) if $argHash{debug};
	$dst_ids{$src_id}=$ids;
    }
    wantarray? %dst_ids:\%dst_ids;
}

# use this if only translating 1 id; wrapper to translate() above,
# but returns a list[ref] instead of a hash[ref].
sub translate1 {
    my $hash=translate(@_);
    my $id=(keys %$hash)[0];
    my $list=$hash->{$id};
    wantarray? @$list:$list;
}

########################################################################

# attempt to perform a translation using a join
# should only be called internally, after an attempt with translate() has failed
# same call signature as translate()
# this routine assumes the params are valid ($table[12] exists, etc
sub _translate_join {
    my ($self,$src_col,$table1,$table2,$join_col,$dst_col,$src_ids)=@_;
    my $dbh=$self->dbh;
    my %dst_ids;
    foreach my $src_id (@$src_ids) {
	my $sql="SELECT t2.$dst_col FROM $table1 t1 JOIN $table2 t2 ON t1.$join_col=t2.$join_col WHERE $src_col='$src_id'";
	warn "$sql;" if $ENV{DEBUG};
	my $rows=$dbh->selectall_arrayref($sql);
	# TODO: check for history table
	foreach my $row (@$rows) {
	    my $dst_id=$row->[0];
	    push @{$dst_ids{$src_id}}, $dst_id;
	}
    }
    wantarray? %dst_ids:\%dst_ids;
}

# like get_tableinfo in spirit, but supplies ($dst_col, $table1, $table2, $join_col, $src_col)
# sql will look like:
# "select t1.$dst_col from $table1 t1 join $table2 t2 on t1.$join_col=t2.$join_col where $src_col='$src_id'"
# $dst_col goes in the SELECT clause, $src_col goes in the WHERE clause, and
# $join_col goes in the JOIN clause
sub _get_join_info {
    my ($self,$src_type,$dst_type)=@_;
    
    foreach my $join_type (@{$self->join_types}) {
	my ($table1,$src_col1,$dst_col1)=$self->get_tableinfo($src_type,$join_type) or next;
	my ($table2,$src_col2,$dst_col2)=$self->get_tableinfo($join_type,$dst_type) or next;
	next unless $dst_col1 eq $src_col2;
	return ($src_col1,$table1,$table2,$dst_col1,$dst_col2);
    }
    return ();
}

########################################################################


sub history_table {
    my ($self,$src_type)=@_;
    confess "no self???" unless $self;
    confess "no type" unless $src_type;
    $src_type=~s/_eid//;
#    confess "history tables not set???" unless $self->history;
    return undef unless $self->history;	# how could this possibly be happening???
    $self->history->{$src_type};
}

# return ($tablename,$src_col,$dst_col) based on $src_type and $dst_type
sub get_tableinfo {
    my ($self,$src_type,$dst_type)=@_;

    # for now, skip mapping between src_type and src_col, use as is (also for dst)
    my $src_col=$self->get_col($src_type) or confess "no column for '$src_type'";
    my $dst_col=$self->get_col($dst_type) or confess "no column for '$dst_type'";

    my $tablename=$self->tableinfo->{$src_col}->{$dst_col};
#	confess "no translation available for $src_col -> $dst_col: ",($ENV{DEBUG}? Dumper($self->tableinfo):'');
    return ($tablename,$src_col,$dst_col) if $tablename;
    return ();
}

# translate a $type to a $col (either $src or $dst) via the %src_type2col 
sub get_col {
    my ($self,$type)=@_;
    my ($thing,$src,$remainder)=split('_',$type,3);
    confess "malformed type '$type'" if (!$src || $remainder);
    my $src_type2col=$self->src_type2col;
    my $col=$src_type2col->{$thing}->{$src};
}

# have to defer this until runtime in order that $dbhandler is created
#__PACKAGE__->_init_class;
# so don't uncomment!



1;
