package SBEAMS::SolexaTrans::SolexaTransPipeline;
use base qw(Class::AutoClass);
use strict;
use warnings;
use Carp;
use Data::Dumper;
use FileHandle;
use DBI;
use File::Copy;

use SBEAMS::SolexaTrans::ProcessExport;
use SBEAMS::SolexaTrans::Data::Babel;
use SBEAMS::SolexaTrans::Genomes;
use SBEAMS::SolexaTrans::RestrictionSites;

use vars qw(@AUTO_ATTRIBUTES @CLASS_ATTRIBUTES %DEFAULTS %SYNONYMS);
@AUTO_ATTRIBUTES = qw(project_name motif res_enzyme tag_length truncate
		      output_dir genome_dir 
		      ref_org genome_ids
		      export_file lane ss_sample_id
		      use_old_patman_output patman_max_mismatches
		      db_host db_name db_user db_pass dsn
		      babel_db_host babel_db_name babel_db_user babel_db_pass
		      dbh babel
		      fuse
		      status timestamp
		      );
@CLASS_ATTRIBUTES = qw(res_sites genomes);
%DEFAULTS = (
	     genome_dir=>'genomes',
	     tag_length=>36,
	     db_host=>'mysql', db_name=>'solexa_1_0', db_user=>'SolexaTags', db_pass=>'STdv1230',
	     babel_db_host=>'grits', 
	     babel_db_name=>'disease_data_3_9',babel_db_user=>'root',babel_db_pass=>'',
	     truncate=>0,
	     fuse=>0,
	     status=>'unknown',
	     );
%SYNONYMS = ();

Class::AutoClass::declare(__PACKAGE__);

sub _init_self {
    my ($self, $class, $args) = @_;
    return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this

    # Insure output_dir ends in project_name:
    my ($output_dir,$project_name)=$self->get_attrs(qw(output_dir project_name));
#    if ($output_dir !~/$project_name/) {
#	$self->output_dir("$output_dir/$project_name");
#    }

}

sub _class_init {
    my ($class)=@_;
    $class->genomes(SBEAMS::SolexaTrans::Genomes->new);
    $class->res_sites(SBEAMS::SolexaTrans::RestrictionSites->new);
}

sub run {
    my ($self)=@_;
    $self->verify_required_opts();
    $self->status('running');
    $self->get_dbh;
    $self->get_babel;
    my $ref_table=$self->get_ref_tablename;
    $self->create_ref_table($ref_table) unless $self->table_exists($ref_table);
    $self->genomes->dbh($self->dbh);
    $self->create_output_dir;

    my ($total_reads,$total_tags)=(0,0);
    my $pe=SBEAMS::SolexaTrans::ProcessExport->new(export_file=>$self->export_file,
						   lane=>$self->lane,
						   ss_sample_id=>$self->ss_sample_id,
						   project_name=>$self->project_name,
						   motif=>$self->motif,
						   truncate=>$self->truncate,
						   output_dir=>$self->output_dir,
						   use_old_patman_output=>$self->use_old_patman_output,
						   patman_max_mismatches=>$self->patman_max_mismatches,
						   babel=>$self->babel, dbh=>$self->dbh,
						   fuse=>$self->fuse,
						   );
    
    $pe->count_tags(); # annnd, why? We don't use $tags anywhere in this sub
    $pe->lookup_tags($ref_table);
    
    my @genomes=$self->get_genomes();
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

    # tabulate global stats
    $total_reads+=$pe->n_reads;
    $total_tags+=$pe->n_tags;
    warn "$total_reads total reads, $total_tags total tags\n";
    $self->write_stats;

    my $now=scalar localtime;
    warn "$now: done\n";
    $self->status('finished');
    $self->timestamp=>time;
}

########################################################################

sub verify_required_opts {
    my ($self)=@_;
    my @required=qw(ref_org motif project_name lane ss_sample_id output_dir);
    my @missing=grep {defined $_} map {defined $self->$_? undef:$_} @required;
    warn "verify_required_opts():",Dumper($self) if $ENV{DEBUG};
    die "missing fields (options): ",join(', ',@missing),"\n" if @missing;
    warn "all required options seem to be present\n";
}

sub create_output_dir {
    my ($self)=@_;
    my $output_dir=$self->output_dir;
    if (-d $output_dir) {
	warn "$output_dir exists";
    } else {
	mkdir $output_dir or die "Can't create $output_dir: $!";
	warn "$output_dir created";
    }
}

########################################################################


# return a list of all genome_ids/paths to search (as a list of hashlettes)
sub get_genomes {
    my ($self)=@_;
    my $genomes=$self->genomes;
    my $org=$self->ref_org;

    my @paths;
    # if passed a list of genome_ids, search on that
    my $gids=$self->genome_ids;
    if (ref $gids eq 'ARRAY' && @$gids) {
	foreach my $gid (@$gids) {
	    if (my $path=$genomes->select(fields=>['genome_id','path'],
					  values=>{genome_id=>$gid})->[0]) {
		my %h;
		@h{qw(genome_id path)}=@$path;
		push @paths,\%h;
	    }
	}
    } else {			# otherwise, search by ref_org
	if (my $path=$genomes->select(fields=>['genome_id','path'],
				      values=>{org=>$self->ref_org,
					       name=>$self->ref_org.' RNA'})->[0]) {
	    my %h;
	    @h{qw(genome_id path)}=@$path;
	    push @paths,\%h;
	}
    }
    
#     if (my $path=$genomes->select(fields=>['genome_id','path'],
# 				  values=>{org=>'e_coli'})->[0]) {
# 	my %h;
# 	@h{qw(genome_id path)}=@$path;
# 	push @paths,\%h;
#     }
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

sub get_id {
    my ($self)=@_;
    my ($project_name,$sss_id,$fuse)=$self->get_attrs(qw(project_name ss_sample_id fuse));
#    my ($project_name,$sss_id,$lane,$fuse)=$self->get_attrs(qw(project_name ss_sample_id lane fuse));
#    $lane.="_$fuse" if $fuse;
    join('_',$project_name,$sss_id);
}

sub get_tablename { 
    my ($self,$suffix)=@_;
    join('_',$self->get_id,$suffix);
}


sub get_ref_tablename {
    my ($self)=@_;
    my $tag_length=$self->tag_length;
    sprintf("ref_tags_%d",$tag_length);
}

sub get_output_filename {
    my ($self,$suffix)=@_;
    confess "no suffix" unless $suffix;
    my ($output_dir,$project_name,$ss_sid,$fuse)=$self->get_attrs(qw(output_dir project_name ss_sample_id fuse));
#    $lane.="_$fuse" if $fuse;
#    "$output_dir/$project_name.$ss_sid.$lane.$suffix";
    "$output_dir/$project_name.$ss_sid.$suffix";
}

sub id {
    my ($self)=@_;
    my $id=join('_',$self->get_attrs(qw(project_name ss_sample_id)));
    if (my $fuse=$self->fuse) {
	$id.="_$fuse";
    }
}

# write the stats hash out to disk:
sub write_stats {
    my ($self)=@_;
    my $stats=$self->stats;
    my $fn=$self->get_output_filename('stats');
    open (STATS,">$fn") or die "Can't open $fn for writing: $!";
    foreach my $k (sort keys %$stats) {
	my $v=$stats->{$k};
	print STATS "$k\t$v\n";
    }
    close STATS;
    warn "$fn written\n";
}

# return a stats hash read in from the stats file
sub read_stats {
    my ($self)=@_;
    my $fn=$self->get_output_filename('stats');
    my $stats;
    open (STATS,"$fn") or die "Can't open $fn: $!";
    while (<STATS>) {
	chomp;
	my ($k,$v)=split(/\t/);
	$stats->{$k}=$v;
    }
    close STATS;
    $stats;
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

    my $now=time;
    my $tmpfile="/solexa/trans/tmp/TMP_CPM_$$.txt";
    $sql="SELECT LOCUS_LINK_EID, GENOME_ID, TOTAL_COUNT, TOTAL_CPM FROM $cpm_tablename INTO OUTFILE '$tmpfile'";
    $self->dbh->do($sql);
    if (my $err=$DBI::errstr) {
	warn "$sql: $err";
    } else {
  	my $filename=$self->get_output_filename('cpm');
        if (! -e $tmpfile) {
          warn "Unable to create tmp file: $tmpfile.  This means that the CPM file was not generated.".
               "To get CPM information, the CPM file ($filename) will need to be manually generated with\n$sql\n";
        } else {
#	  rename $tmpfile,$filename or die "Can't rename '$tmpfile' to '$filename': $!";
#	  my $cmd="cp $tmpfile $filename";
#          print "performing command $cmd\n";
#	  my $rc=`$cmd`;
#	  if ($rc) {
#	    warn "unable to execute '$cmd': rc=$rc";
#	    warn "To get CPM information, the CPM file ($filename) will need to be manually generated with\n'$sql;'\n ";
#	  } else {
	#    unlink $tmpfile;
#	    warn "$filename written\n";
#	  }
          system cp => $tmpfile, $filename || warn "Copy Failed - $! $?";
        }
    }
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

# returns a hash contains summary stats for the run:
sub stats {
    my ($self)=@_;
    $self->get_dbh;
    my $ss_sid=$self->ss_sample_id;
    my $report={};
    foreach my $suffix (qw(tags ambg unkn)) { 
	my $tablename=$self->get_tablename($suffix);
	$self->_count($tablename,$suffix,$report);
	$self->_sum_count($tablename,$suffix,$report);
    }

    $self->_count($self->get_tablename('cpm'),'cpm',$report);
    $report;
}

sub _count {
    my ($self,$tablename,$suffix,$report)=@_;
    my $sql="SELECT count(*) from $tablename";
    my $key=join('_',$suffix,'unique');
    my $col=$self->dbh->selectcol_arrayref($sql);
    my $sum=$col->[0]||0;
    $report->{$key}=$sum;
    $report->{total_unique}+=$sum;
}

sub _sum_count {
    my ($self,$tablename,$suffix,,$report)=@_;
    my $sql="SELECT sum(count) FROM $tablename";
    my $col=$self->dbh->selectcol_arrayref($sql);
    my $sum=$col->[0]||0;
    my $key=join('_',$suffix,'total');
    $report->{$key}=$sum;
    $report->{total_tags}+=$sum;
}

########################################################################
sub get_attrs {
    my ($self,@attrs)=@_;
    my @values=map {$self->$_} @attrs;
    wantarray? @values:\@values;
}

sub get_dbh {
    my ($self)=@_;
    return $self->dbh if $self->dbh;

    my ($host,$db_name,$db_user,$db_pw)=$self->get_attrs(qw(db_host db_name db_user db_pass));
    my $dsn="DBI:mysql:host=$host:database=$db_name";
    warn "dsn is $dsn: user=$db_user, pass=*****" if $ENV{DEBUG};
    my $dbh=DBI->connect($dsn,$db_user,$db_pw) 
	or die "unable to connect to database using '$dsn','$self->db_user': $DBI::errstr\n";
    $self->dsn($dsn);
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

# return a hash describing run as fit for JCR via addama:
# works best if called on finished pipeline object; otherwise fields
# will be undef.
sub jcr_info {
    my ($self)=@_;

    my %jcr_info;

    my @input_attrs=qw(project_name motif res_enzyme tag_length truncate
		       ref_org genome_ids ss_sample_id lane export_file
		       patman_max_mismatches
		       fuse);
    my %input;
    @input{@input_attrs}=$self->get_attrs(@input_attrs);
    $jcr_info{inputs}=\%input;

    my %output;
    # output files:
    my $output_dir=$self->output_dir;
    foreach my $suffix (qw(tags ambg unkn cpm)) {
	$output{$suffix}=$self->get_output_filename($suffix);
    }
    $jcr_info{output}->{files}=\%output;

    # database info:
    my %db_info;
    my @db_params=qw(db_host db_name db_user db_pass dsn);
    @db_info{@db_params}=$self->get_attrs(@db_params);
    foreach my $suffix (qw(tags ambg unkn cpm)) {
	$db_info{$suffix}=$self->get_tablename($suffix);
    }
    $jcr_info{output}->{databases}=\%db_info;

    $jcr_info{logs}={};		# have to get from qsub
    $jcr_info{status}={status=>$self->status,
		       timestamp=>$self->timestamp};
    $jcr_info{stats}=$self->stats;
    $jcr_info{id}=$self->id;
    $jcr_info{timestamp}=time;
    wantarray? %jcr_info:\%jcr_info;
}


__PACKAGE__->_class_init();

1;
