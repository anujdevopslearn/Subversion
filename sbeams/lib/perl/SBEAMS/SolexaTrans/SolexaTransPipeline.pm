package SBEAMS::SolexaTrans::SolexaTransPipeline;
use base qw(Class::AutoClass);
use strict;
use warnings;
use Carp;
use Data::Dumper;
use FileHandle;
use DBI;

use lib qw(../../);
use SBEAMS::SolexaTrans::ProcessExport;
use SBEAMS::SolexaTrans::Data::Babel;
use SBEAMS::SolexaTrans::Genomes;
use SBEAMS::SolexaTrans::RestrictionSites;
use SBEAMS::SolexaTrans::FileUtilities qw(parse3);
use SBEAMS::SolexaTrans::SlimseqClient;

use vars qw(@AUTO_ATTRIBUTES @CLASS_ATTRIBUTES %DEFAULTS %SYNONYMS);
@AUTO_ATTRIBUTES = qw(project_name motif res_enzyme export_index tag_length
		      base_dir output_dir export_dir genome_dir project_dir
                      qsub_filename
		      restriction_enzyme ref_genome ref_org
		      export_files lane2sample_id
		      export_filename_format
		      use_old_patman_output
		      db_host db_name db_user db_pass 
		      babel_db_host babel_db_name babel_db_user babel_db_pass
		      dbh babel
		      );
@CLASS_ATTRIBUTES = qw(res_sites slimseq_json genomes);
%DEFAULTS = (
	     output_dir=>'output', 
	     export_dir=>'export_files',
	     genome_dir=>'genomes',
	     tag_length=>36,
	     export_filename_format=>'s_%d_export.txt',
	     db_host=>'mysql', db_name=>'solexa_1_0', db_user=>'SolexaTags', db_pass=>'STdv1230',
	     babel_db_host=>'grits', 
	     babel_db_name=>'disease_data_3_9',babel_db_user=>'root',babel_db_pass=>'',
	     );
%SYNONYMS = ();

Class::AutoClass::declare(__PACKAGE__);

sub _init_self {
    my ($self, $class, $args) = @_;
    return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this
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

    # We can't really depend on the caller to take the trouble to include the slimseq
    # params, so we'll have to at least be capable of fetching them ourself:
    # get project info from slimseq (writes into $self)
    if (my $project_name=$self->project_name) {
	warn "fetching slimseq opts...\n";
	$self->slimseq_opts($project_name);
    }
    $self->derive_options() if !$self->project_dir;

    my %export_files=$self->get_export_files();
    $self->verify_required_opts();

    my @genome_fastas=$self->get_genomes();

    my ($total_reads,$total_tags)=(0,0);
    while (my ($lane,$export_file)=each %export_files) {
	my $sample_id=$self->lane2sample_id->{$lane};
	my $pe=SBEAMS::SolexaTrans::ProcessExport->new(export_file=>$export_file,
				  base_dir=>$self->base_dir,
				  project_name=>$self->project_name,
				  lane=>$lane,
				  sample_id=>$sample_id,
				  motif=>$self->motif,
				  ref_fasta=>join('/',$self->base_dir,$self->ref_fasta), # going to BARF
				  use_old_patman_output=>$self->use_old_patman_output,
				  patman_max_mismatches=>1,
				  babel=>$self->babel, dbh=>$self->dbh,
				  );
	my $tags=$pe->count_tags(); # annnd, why? We don't use $tags anywhere in this sub
        $pe->lookup_tags($ref_table);
	$pe->run_patman();

	# store results
	$pe->normalize();
	$self->store_data($pe,$lane);
	$self->store_cpm($pe,$lane);
	$pe->update_ref_db($self->get_ref_tablename());

	# tabulate any global stats
	$total_reads+=$pe->n_reads;
	$total_tags+=$pe->n_tags;
    }
    warn "$total_reads total reads, $total_tags total tags\n";

    my $now=scalar localtime;
    warn "$now: done\n";
}

########################################################################

sub slimseq_opts {
    my ($self)=@_;
    my $project_name=$self->project_name;

    my $slimseq=SBEAMS::SolexaTrans::SlimseqClient->new;
    my $project=$slimseq->gather_sample_info($project_name);
    warn "project is ",Dumper($project) if $ENV{DEBUG};
    my @opts=qw(export_index restriction_enzyme export_files ref_genome);
    do {$self->$_($project->{$_})} foreach @opts;

    # currently not really making use of ref_genome...
    my ($g_org,$g_name)=map {lc $_} split(/\|/,$project->{ref_genome});
    $self->ref_org($g_org);
#    my $genomes=$self->genomes;	# TODO: probably going to change this...?
#    $self->ref_fasta(join("/",$self->genome_dir,$genomes->get_genome($g_org,$g_name)));
    # do we really want to retain ref_fasta? no

    if (my $res_enz=uc $self->restriction_enzyme) {
	$self->motif($self->res_sites->motif($res_enz));
    }

    $self->lane2sample_id($project->{lane2sample_id});
    $self->tag_length($project->{tag_length});
    $project;
}

sub derive_options {
    my ($self)=@_;
    $self->project_dir(join('/',$self->base_dir,$self->output_dir,$self->project_name));
}

sub verify_required_opts {
    my ($self)=@_;
    my @required=qw(ref_genome motif project_name export_dir 
		    export_dir export_files export_filename_format);
    my @missing=grep {defined $_} map {defined $self->$_? undef:$_} @required;
    warn "self:",Dumper($self) if $ENV{DEBUG};
    die "missing fields (options): ",join(', ',@missing),"\n" if @missing;
    warn "all required options seem to be present\n";
}

########################################################################

sub get_export_files {
    my ($self)=@_;
    my $export_files = $self->export_files if $self->export_files;
    # Options.pm will have this as an empty array or an array with values if -export_files was passed in
    if ($export_files && scalar @$export_files >0) {  
        my ($export_dir,$export_index)=$self->group_export_files(export_files =>$export_files);
        print "export dir $export_dir export_index $export_index\n" if $ENV{DEBUG};
        $self->export_index($export_index);
        $self->export_dir($export_dir);
    }

    my ($base_dir,$export_dir,$project_name,$export_index,$export_filename_format)=
	$self->get_attrs(qw(base_dir export_dir project_name export_index export_filename_format));
    $export_dir="$base_dir/$export_dir" unless $export_dir=~m|^/|;

    my %files;
    foreach my $lane (split('',$export_index)) {
	$files{$lane}="$export_dir/$project_name/".sprintf($export_filename_format,$lane);
    }
    wantarray? %files:\%files;
}


# return a list of all genome_ids to search
sub get_genomes {
    my ($self)=@_;
    my $genomes=$self->genomes;
    my $org=$self->ref_org;

    my @paths;
    my $path=$genomes->select(fields=>['path'],
                              values=>{org=>$self->ref_org,
                                       name=>$self->ref_org.' RNA'})->[0]->[0];
    push @paths,$path if $path;
    $path=$genomes->select(fields=>['path'],
                           values=>{org=>'e_coli'})->[0]->[0];
    push @paths,$path if $path;
    die "genome paths: ",Dumper(\@paths);
}


########################################################################


# store tags, unassigned, and ambiguous data:
# (creates tables, writes files, and loads data from files)
sub store_data {
    my ($self,$pe,$lane)=@_;
    my $tags=$pe->tags;
    my $project_name=$self->project_name;

    # open files:
    my $tags_filename=$self->get_output_filename($lane,'tags');
    open(TAGS,">$tags_filename") or die "Can't write to $tags_filename: $!";
    my $unkn_filename=$self->get_output_filename($lane,'unkn');
    open(UNKN,">$unkn_filename") or die "Can't write to $unkn_filename: $!";
    my $ambg_filename=$self->get_output_filename($lane,'ambg');
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
	my $filename=$self->get_output_filename($lane,$suffix);
	my $tablename=$self->get_tablename($lane,$suffix);
	my $sql="LOAD DATA INFILE '$filename' INTO TABLE $tablename";
	$self->dbh->do($sql);
    }
}




#-----------------------------------------------------------------------

sub get_tablename { 
    my ($self,$lane,$suffix)=@_;
    confess "no lane" unless $lane;
    confess "no suffix" unless $suffix;
    my $project_name=$self->project_name;
    my $sample_id=$self->lane2sample_id->{$lane} or confess "no sample_id for $lane in ",Dumper($self->lane2sample_id);
    
    join('_',$project_name,$sample_id,$suffix);
}

sub get_ref_tablename {
    my ($self)=@_;
    my $tag_length=$self->tag_length;
    sprintf("ref_tags_%d",$tag_length);
}

sub get_output_filename {
    my ($self,$lane,$suffix)=@_;
    my $sample_id=$self->lane2sample_id->{$lane};
    my ($project_dir,$project_name)=$self->get_attrs(qw(project_dir project_name));
    "$project_dir/$project_name.$sample_id.$suffix";
}

#-----------------------------------------------------------------------



sub create_tag_table {
    my ($self,$lane)=@_;
    my ($tablename)=$self->get_tablename($lane,'tags');
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
    my ($tablename)=$self->get_tablename($lane,'unkn');
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
    my ($tablename)=$self->get_tablename($lane,'ambg');
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
    my ($self,$pe,$lane)=@_;
    my $project_name=$self->project_name;
    my $cpm_tablename=$self->get_tablename($lane,'cpm');
    $self->create_cpm_table($cpm_tablename);
    my $tag_tablename=$self->get_tablename($lane,'tags');
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
    my ($self,$lane)=@_;
    my $report={};
    my @lanes=$lane? ($lane):keys %{$self->lane2sample_id};
    foreach $lane (@lanes) {
	foreach my $suffix (qw(tags ambg unkn)) {
	    my $tablename=$self->get_tablename($lane,$suffix);
	    my $sql="SELECT sum(count) FROM $tablename";
	    my $col=$self->dbh->selectcol_arrayref($sql);
	    my $key=join('_',$suffix,$lane,'total_tags');
	    $report->{$key}=$col->[0];
	    $report->{total_tags}+=$col->[0];

 	    $sql="SELECT count(*) from $tablename";
 	    $col=$self->dbh->selectcol_arrayref($sql);
	    $key=join('_',$suffix,$lane,'unique_tags');
	    $report->{$key}=$col->[0];

	    # Can't do unique tags this way because the same tags exist across tables.
# 	    $report->{$suffix."_unique_tags"}=$col->[0];
# 	    $report->{total_unique_tags}+=$col->[0];
	}
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

# create a qsub script and run it
# this will wind up calling run() above via a created perl script
# NOT FINISHED WITH THIS!
# return the qsub job id (string including qsub host)
sub qsub {
    my ($self,%argHash)=@_;
    warn "qsub: args are ",Dumper(\%argHash);

    # check for qsub executable:
    my $qsub=`which qsub`;
    chomp $qsub;
#    confess "qsub not in path $ENV{PATH}:" unless -x $qsub;

    # build and write qsub script:
    my $qsub_script=$self->qsub_script(%argHash);
    my $qsub_filename=$self->qsub_filename(%argHash);
    print $qsub_script;
#    open (QSUB,">$qsub_filename") or die "Can't open $qsub_filename for writing: $!";
#    print QSUB $qsub_script;
#    close QSUB;
    
    # invoke qsub on qsub script:
#    my $cmd="$qsub $qsub_filename";
#    my $job_id=`$cmd`;
return int(rand(1000));
}

# Generates a shell script that will run the perl program
# that starts the SolexaTransPipeline (process_solexa.pl).
sub qsub_script {
    my ($self,%argHash)=@_;
#    my @required_opts=qw(project_name base_dir output_dir email);
    my @required_opts=qw(base_dir output_dir email);
    my @missing=grep {!defined $argHash{$_}} @required_opts;
    confess "missing opts: ",join(', ',@missing) if @missing;

#    if ($options{export_files}) {
    if ($argHash{export_files}) {  # DM 02/06/2009
	my ($export_dir,$export_index)=$self->group_export_files(%argHash);
	$argHash{export_dir}=$export_dir;
	$argHash{export_index}=$export_index;
    }

   # DM removed an additional 'export_dir' from beginning 02/06/2009 
    my @optional_opts=qw(tag_length motif res_enzyme genome
			 export_index output_dir export_dir genome_dir
			 ref_fasta export_filename_format use_old_patman_output
			 db_host db_name db_user db_pass 
			 babel_db_host babel_db_name babel_db_user babel_db_pass
			 debug
                         qsub_filename
			 );

    my ($project_name,$base_dir,$output_dir,$email)=
	@argHash{qw(project_name base_dir output_dir email)};
    my $qsub_filename= $argHash{"qsub_filename"} || $self->qsub_filename(%argHash);

    my $qsub=<<"QSUB";
#PBS -N solexa_pipeline.$project_name
#PBS -M $email
#PBS -m ea
#PBS -o $qsub_filename.out
#PBS -e $qsub_filename.err

touch $output_dir/timestamp;
QSUB
    
    my $cmd="perl $base_dir/process_solexa.pl";
    my @opts;
    foreach my $opt (@required_opts, @optional_opts) {
	push @opts, "-$opt $argHash{$opt}" if defined $argHash{$opt};
    }
    my $opts=join(' ',@opts);
 
#    my $script=$options{script} || 'process_solexa.pl';
    my $script=$argHash{script} || 'process_solexa.pl'; # DM 02/06/2009
    $script="$base_dir/$script" unless $script=~m|^/|;
    confess "$script not found and/or not executable: $!" unless -x $script;
#    $qsub.="perl $base_dir/echo.pl $opts\n"; # leave this around for debugging
    $qsub.="perl $script $opts\n";


}

sub qsub_filename {
    my ($self,%argHash)=@_;
    my $base_dir=$argHash{base_dir} or confess "no base_dir";
    my $output_dir=$argHash{output_dir} or confess "no output_dir";
    my $project_name=$argHash{project_name} or confess "no project_name";
    
    "$base_dir/$output_dir/$project_name/$project_name.qsub";
}

# return an export_dir, export_index
sub group_export_files {
    my ($self,%argHash)=@_;
    my $export_files=$argHash{export_files} or confess "no export_files";
    confess "export_files not a listref: $export_files" unless ref $export_files eq 'ARRAY';

    my $base_dir;
    my @i;
    foreach my $ef (@$export_files) {
	my ($dir,$base,$suf)=parse3($ef);
	my $filename="$base.$suf";
	$base_dir||=$dir;
	confess "differing base directories:\n$base_dir\n$dir" unless $base_dir eq $dir;
	$filename=~/^s_(\d)_export/ or 
	    confess "malformed filename: $filename (must match 's_\\d_export')";
	$i[$1]=1;
    }

    my $index=join("",(grep {$i[$_]?$_:undef} (0..$#i)));
    ($base_dir,$index);
}


__PACKAGE__->_class_init();

1;
