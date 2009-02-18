package SBEAMS::SolexaTrans::SolexaTransPipeline;
use base qw(Class::AutoClass);
use strict;
use warnings;
use Carp;
use Data::Dumper;
use FileHandle;
use DBI;

use SBEAMS::SolexaTrans::ProcessExport;
use SBEAMS::SolexaTrans::Data::Babel;
use SBEAMS::SolexaTrans::Genomes;
use SBEAMS::SolexaTrans::RestrictionSites;

use vars qw(@AUTO_ATTRIBUTES @CLASS_ATTRIBUTES %DEFAULTS %SYNONYMS);
@AUTO_ATTRIBUTES = qw(project_name motif res_enzyme tag_length
		      output_dir genome_dir 
		      restriction_enzyme ref_genome ref_org
		      export_file lane ss_sample_id
		      use_old_patman_output
		      db_host db_name db_user db_pass 
		      babel_db_host babel_db_name babel_db_user babel_db_pass
		      dbh babel
		      );
@CLASS_ATTRIBUTES = qw(res_sites slimseq_json genomes);
%DEFAULTS = (
	     genome_dir=>'genomes',
	     tag_length=>36,
	     db_host=>'mysql', db_name=>'solexa_1_0', db_user=>'SolexaTags', db_pass=>'STdv1230',
	     babel_db_host=>'grits', 
	     babel_db_name=>'disease_data_3_9',babel_db_user=>'root',babel_db_pass=>'',
	     );
%SYNONYMS = ();

Class::AutoClass::declare(__PACKAGE__);

sub _init_self {
    my ($self, $class, $args) = @_;
    return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this
    $self->verify_required_opts();
}

sub _class_init {
    my ($class)=@_;
    $class->genomes(SBEAMS::SolexaTrans::Genomes->new);
    $class->res_sites(SBEAMS::SolexaTrans::RestrictionSites->new);
}

sub run {
    my ($self)=@_;
    $self->get_dbh;
    $self->get_babel;
    my $ref_table=$self->get_ref_tablename;
    $self->create_ref_table($ref_table) unless $self->table_exists($ref_table);
    $self->genomes->dbh($self->dbh);

    my @genomes=$self->get_genomes();
    my ($total_reads,$total_tags)=(0,0);
    my $pe=SBEAMS::SolexaTrans::ProcessExport->new(export_file=>$self->export_file,
						   lane=>$self->lane,
						   ss_sample_id=>$self->ss_sample_id,
						   project_name=>$self->project_name,
						   motif=>$self->motif,
						   output_dir=>$self->output_dir,
						   use_old_patman_output=>$self->use_old_patman_output,
						   patman_max_mismatches=>1,
						   babel=>$self->babel, dbh=>$self->dbh,
						   );
    
    my $tags=$pe->count_tags(); # annnd, why? We don't use $tags anywhere in this sub
    $pe->lookup_tags($ref_table);
    
    foreach my $genome (@genomes) {
	my ($genome_id,$ref_fasta)=@$genome{qw(genome_id path)};
	$pe->genome_id($genome_id);
	$pe->ref_fasta($ref_fasta);
	$pe->run_patman();
    }

    # store results
    $pe->normalize();
    $self->store_data($pe);
    $self->store_cpm($pe);
    $pe->update_ref_db($self->get_ref_tablename());

    # tabulate any global stats
    $total_reads+=$pe->n_reads;
    $total_tags+=$pe->n_tags;

    warn "$total_reads total reads, $total_tags total tags\n";

    my $now=scalar localtime;
    warn "$now: done\n";
}

########################################################################

sub verify_required_opts {
    my ($self)=@_;
    my @required=qw(ref_genome motif project_name lane ss_sample_id output_dir);
    my @missing=grep {defined $_} map {defined $self->$_? undef:$_} @required;
    warn "self:",Dumper($self) if $ENV{DEBUG};
    die "missing fields (options): ",join(', ',@missing),"\n" if @missing;
    warn "all required options seem to be present\n";
}

########################################################################


# return a list of all genome_ids to search
sub get_genomes {
    my ($self)=@_;
    my $genomes=$self->genomes;
    my $org=$self->ref_org;

    my @paths;
    if (my $path=$genomes->select(fields=>['genome_id','path'],
				  values=>{org=>$self->ref_org,
					   name=>$self->ref_org.' RNA'})->[0]) {
	my %h;
	@h{qw(genome_id path)}=@$path;
	push @paths,\%h;
    }
    
    if (my $path=$genomes->select(fields=>['genome_id','path'],
				  values=>{org=>'e_coli'})->[0]) {
	my %h;
	@h{qw(genome_id path)}=@$path;
	push @paths,\%h;
    }
    wantarray? @paths:\@paths;
}


########################################################################


# store tags, unassigned, and ambiguous data:
# (creates tables, writes files, and loads data from files)
sub store_data {
    my ($self,$pe)=@_;
    my $lane=$self->lane;
    my $tags=$pe->tags;
    my $project_name=$self->project_name;

    # open files:
    my $tags_filename=$self->get_output_filename('tags');
    open(TAGS,">$tags_filename") or die "Can't write to $tags_filename: $!";
    my $unkn_filename=$self->get_output_filename('unkn');
    open(UNKN,">$unkn_filename") or die "Can't write to $unkn_filename: $!";
    my $ambg_filename=$self->get_output_filename('ambg');
    open(AMBG,">$ambg_filename") or die "Can't write to $ambg_filename: $!";

    # write to files:
    while (my ($tag,$hash)=each %$tags) {
	my ($count,$cpm,$ll,$lls)=@$hash{qw(count cpm locus_link_eid lls)};
	if (defined $ll) {
	    print TAGS join("\t",$ll,$tag,$count,$cpm),"\n";
	} elsif (defined $lls) {
	    my $n_lls=scalar @$lls;
	    my $lls_csv=join(',',@$lls);
	    print AMBG join("\t",$tag,$lls_csv,$n_lls,$count,$cpm),"\n";
	} else {
	    print UNKN join("\t",$tag,$count,$cpm),"\n";
	}
	    
    }
    close TAGS;
    close UNKN;
    close AMBG;
    warn "$tags_filename written\n";
    warn "$ambg_filename written\n";
    warn "$unkn_filename written\n";

    # load data into db tables:
    $self->create_tag_table($lane);
    $self->create_unassigned_table($lane);
    $self->create_ambiguous_table($lane);
    foreach my $suffix (qw(tags unkn ambg)) {
	my $filename=$self->get_output_filename($suffix);
	my $tablename=$self->get_tablename($suffix);
	my $sql="LOAD DATA INFILE '$filename' INTO TABLE $tablename";
	$self->dbh->do($sql);
    }
}




#-----------------------------------------------------------------------

sub get_tablename { 
    my ($self,$suffix)=@_;
    my ($project_name,$sss_id,$lane)=$self->get_attrs(qw(project_name ss_sample_id lane));
    join('_',$project_name,$sss_id,$lane,$suffix);
}


sub get_ref_tablename {
    my ($self)=@_;
    my $tag_length=$self->tag_length;
    sprintf("ref_tags_%d",$tag_length);
}

sub get_output_filename {
    my ($self,$suffix)=@_;
    my ($output_dir,$project_name,$ss_sid,$lane)=$self->get_attrs(qw(output_dir project_name ss_sample_id lane));
    "$output_dir/$project_name.$lane.$ss_sid.$suffix";
}

#-----------------------------------------------------------------------



sub create_tag_table {
    my ($self,$lane)=@_;
    my ($tablename)=$self->get_tablename('tags');
    my $tag_length=$self->tag_length;
    my $sql=<<"    SQL";
CREATE TABLE $tablename (
locus_link_eid INT NOT NULL,
tag CHAR($tag_length) NOT NULL,
count INT NOT NULL,
cpm DOUBLE NOT NULL,
genome_id INT NOT NULL,
INDEX (locus_link_eid),
INDEX (tag)
)
    SQL
    $self->dbh->do("DROP TABLE IF EXISTS $tablename");
    $self->dbh->do($sql) or die "error creating table: $sql\n$DBI::errstr";
    warn "$tablename: shazam!\n";
}

sub create_unassigned_table {
    my ($self,$lane)=@_;
    my ($tablename)=$self->get_tablename('unkn');
    my $tag_length=$self->tag_length;
    my $sql=<<"    SQL";
CREATE TABLE $tablename (
tag CHAR($tag_length) NOT NULL,
count INT NOT NULL,
cpm DOUBLE NOT NULL,
INDEX (tag)
)
    SQL
    $self->dbh->do("DROP TABLE IF EXISTS $tablename");
    $self->dbh->do($sql) or die "error creating table: $sql\n$DBI::errstr";
    warn "$tablename: shazam!\n";
}

sub create_ambiguous_table {
    my ($self,$lane)=@_;
    my ($tablename)=$self->get_tablename('ambg');
    $self->dbh->do("DROP TABLE IF EXISTS $tablename");

    my $tag_length=$self->tag_length;
    my $sql=<<"    SQL";
CREATE TABLE $tablename (
tag CHAR($tag_length) NOT NULL,
locus_link_eids TEXT NOT NULL,
n_lls INT NOT NULL,
count INT NOT NULL,
cpm DOUBLE NOT NULL,
INDEX (tag)
)
    SQL
    $self->dbh->do($sql) or die "error creating table: $sql\n$DBI::errstr";
    warn "$tablename: shazam!\n";
}

#-----------------------------------------------------------------------

# store "summarized" cpm's; sum across each tag/locuslink
sub store_cpm {
    my ($self,$pe)=@_;
    my $lane=$self->lane;
    my $project_name=$self->project_name;
    my $cpm_tablename=$self->get_tablename('cpm');
    $self->create_cpm_table($cpm_tablename);
    my $tag_tablename=$self->get_tablename('tags');
    my $sql="SELECT DISTINCT locus_link_eid FROM $tag_tablename";
    my $lls=$self->dbh->selectcol_arrayref($sql);
    my $stm=$self->dbh->prepare("INSERT INTO $cpm_tablename (locus_link_eid,total_count,total_cpm) VALUES (?,?,?)");
    foreach my $ll (@$lls) {
	$sql="SELECT count,cpm FROM $tag_tablename WHERE locus_link_eid=$ll";
	my $rows=$self->dbh->selectall_arrayref($sql);
	my ($total_count,$total_cpm)=(0,0);
	foreach my $row (@$rows) {
	    my ($count,$cpm)=@$row;
	    $total_count+=$count;
	    $total_cpm+=$cpm;
	}
	$stm->execute($ll,$total_count,$total_cpm);
    }
    my $n_genes=scalar @$lls;
    warn "stored $n_genes genes to $cpm_tablename";
}

sub create_cpm_table {
    my ($self,$tablename)=@_;
    my $sql=<<"    SQL";
CREATE TABLE $tablename (
locus_link_eid INT NOT NULL,
genome_id INT NOT NULL,
total_count INT NOT NULL,
total_cpm DOUBLE NOT NULL,
INDEX (locus_link_eid)
)
    SQL
    $self->dbh->do("DROP TABLE IF EXISTS $tablename");
    $self->dbh->do($sql);
    warn "$tablename: shazam!\n";
}

sub create_ref_table {
    my ($self,$tablename)=@_;
    my $sql=<<"    SQL";
CREATE TABLE $tablename (
tag VARCHAR(255) PRIMARY KEY,
locus_link_eid INT,
rna_acc VARCHAR(255),
genome_id INT NOT NULL
)
    SQL
    $self->dbh->do("DROP TABLE IF EXISTS $tablename");
    $self->dbh->do($sql);
    warn "$tablename: shazam!\n";
}

########################################################################

sub stats {
    my ($self)=@_;
    my $lane=$self->lane;
    my $report={};
    foreach my $suffix (qw(tags ambg unkn)) {
	my $tablename=$self->get_tablename($suffix);
	my $sql="SELECT sum(count) FROM $tablename";
	my $col=$self->dbh->selectcol_arrayref($sql);
	my $sum=$col->[0]||0;
	my $key=join('_',$suffix,$lane,'total');
	$report->{$key}=$sum;
	$report->{total_tags}+=$sum;

	$sql="SELECT count(*) from $tablename";
	$key=join('_',$suffix,$lane,'unique');
	$col=$self->dbh->selectcol_arrayref($sql);
	$report->{$key}=$col->[0];
    }
    $report;
}

########################################################################
sub get_attrs {
    my ($self,@attrs)=@_;
    my @values=map {$self->$_} @attrs;
    wantarray? @values:\@values;
}

sub get_dbh {
    my ($self)=@_;
    my ($host,$db_name,$db_user,$db_pw)=$self->get_attrs(qw(db_host db_name db_user db_pass));
    my $dsn="DBI:mysql:host=$host:database=$db_name";
    warn "dsn is $dsn: user=$db_user, pass=*****" if $ENV{DEBUG};
    my $dbh=DBI->connect($dsn,$db_user,$db_pw) 
	or die "unable to connect to database using '$dsn','$self->db_user': $DBI::errstr\n";
    $self->dbh($dbh);
}

sub get_babel {
    my ($self)=@_;
    my %babel_options;
    @babel_options{qw(db_host db_name db_user db_pass)}=
	$self->get_attrs(qw(babel_db_host babel_db_name babel_db_user babel_db_pass));
    my $babel=SBEAMS::SolexaTrans::Data::Babel->new(%babel_options);
    $babel->dbh();		# force connect early as debugging aid
    $self->babel($babel);
}

sub table_exists {
    my ($self,$tablename)=@_;
    my $sql="SELECT * FROM $tablename LIMIT 1";
    eval {local $SIG{__WARN__}=sub {}; $self->dbh->do($sql);};
    return !($@ || $DBI::errstr);
}


########################################################################


__PACKAGE__->_class_init();

1;
