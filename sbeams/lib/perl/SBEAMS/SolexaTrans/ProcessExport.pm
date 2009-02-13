package SBEAMS::SolexaTrans::ProcessExport;
use base qw(Class::AutoClass);
use strict;
use warnings;
use Carp;
use Data::Dumper;
use lib qw(../../);
use SBEAMS::SolexaTrans::PatmanClient;
use SBEAMS::SolexaTrans::Repeats;

use vars qw(@AUTO_ATTRIBUTES @CLASS_ATTRIBUTES %DEFAULTS %SYNONYMS);
@AUTO_ATTRIBUTES = qw(export_file tags 
		      n_reads n_repeats n_tags
		      project_name lane sample_id motif
		      ref_fasta
		      patman_max_mismatches use_old_patman_output
		      babel
		      );
@CLASS_ATTRIBUTES = qw(repeats repeat_length base_dir base_output_dir);
%DEFAULTS = (patman_max_mismatches=>1,
	     base_output_dir=>'output');
%SYNONYMS = ();

Class::AutoClass::declare(__PACKAGE__);

sub _init_self {
    my ($self, $class, $args) = @_;
    return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this

    $self->tags({});
}


sub _class_init {
    my ($class)=@_;
    my $r=SBEAMS::SolexaTrans::Repeats->new;
    $class->repeats($r);
    $class->repeat_length($r->repeat_length);
}


sub count_tags {
    my ($self)=@_;
    my $filename=$self->export_file;
    my $now=scalar localtime;
    warn "$now: counting tags in $filename...\n";
    open (TAGS,"$filename") or die "Can't open $filename: $!\n";

    my $tags=$self->tags;
    my $repeat_length=$self->repeat_length;
    my $n_reads=0;
    my $n_repeats=0;

    while (<TAGS>) {
	chomp;
	my @fields=split(/\t/);
	my $tag=lc $fields[8];
	next unless $tag;
	$n_reads++;

#	my $tc_index=rindex($tag,'tc');
#	$tag=substr($tag,0,$tc_index) if ((length $tag)-$tc_index<=2);
	$tag=~s/t[acgt]?$//;
	
	do {$self->repeats->tally_repeat($tag); next} if $self->repeats->is_repeat($tag);
	$tags->{$tag}->{count}++;
	$tags->{$tag}->{length}=length $tag;
    }
    my $n_tags=scalar keys %$tags;
    warn "$filename: read $n_reads total tags, $n_tags unique, $n_repeats repeats\n";
    $self->n_reads($n_reads);
    $self->n_tags($n_tags);
    $self->n_repeats($n_repeats);
    close TAGS;
}

#-----------------------------------------------------------------------

# look up tags in the reference db:
# mark found tags with {locus_link_eid},{source_id},{from_ref_db} (the last is just a flag)
sub lookup_tags {
    my ($self,$ref_tablename)=@_;
    my $tags=$self->tags;
    my $dbh=$self->dbh or confess "no dbh";

    while (my ($tag,$hash)=each %$tags) {
	my $sql="SELECT locus_link_eid,source_id FROM $ref_tablename";
	my $rows=$dbh->selectcol_arrayref($sql)->[0];
	next unless @$rows==1;
	my ($ll,$source_id)=@{$rows->[0]};
	$hash->{locus_link_eid}=$ll;
	$hash->{source_id}=$source_id;
	$hash->{from_ref_db}=1;
    }
}

# insert any tag with a locus_link_eid, but without {from_ref_db} set, into the ref db
# (this might really be better as a PE.pm method? has to know about {from_ref_db} key...
sub update_ref_db {
    my ($self,$ref_tablename)=@_;
    my $tags=$self->tags;
    warn "inserting found tags back into ref db...\n";
    my $stm=$self->dbh->prepare("INSERT INTO $ref_tablename (tag,locus_link_eid,rna_acc,genome_id) VALUES (?,?,?,?)");
    my $n_added=0;
    while (my ($tag,$hash)=each %$tags) {
	next unless $hash->{locus_link_eid} && !$hash->{from_ref_db};
	my ($ll,$rna_acc,$genome_id)=@$hash->{qw(locus_link_eid rna_acc genome_id)};
	$stm->execute($tag,$ll,$rna_acc,$genome_id);
	$n_added++;
    }
    warn "added $n_added new genes\n";
}
#------------------------------------------------------------------------

sub run_patman {
    my ($self,%argHash)=@_;

    my $patman=PatmanClient->new();

    # write all tags in fasta format
    my $fasta_file=$self->tmp_fasta_filename();
    unless ($self->use_old_patman_output && -r "$fasta_file.patman") {
	my $now=scalar localtime;
	warn "$now: writing tags to $fasta_file...\n";
	$self->write_fasta($fasta_file);

	# call patman w/options:
	$now=scalar localtime;
	warn "$now: calling patman...\n";
	my $options={};
	$options->{-e}=$self->patman_max_mismatches;
	warn "run_patman: options are ",Dumper($options);
	my $rc=$patman->run(query=>$fasta_file, target=>$self->ref_fasta, 
			    output=>"$fasta_file.patman",options=>$options);
	warn "patman: rc=$rc\n";
#	die "patman error: rc=$rc" if $rc;
    } else {
	warn "patman: re-using patman results in $fasta_file.patman";
    }
    # parse results:
    my $now=scalar localtime;
    warn "$now: parsing patman results...\n";
    my $matches=$patman->parse(output=>"$fasta_file.patman",
			       max_mismatches=>$self->patman_max_mismatches,
			       );

    # condense rna_acc's to ll where unique; copy ll to $tags{$tag} where appropriate:
    $now=scalar localtime;
    warn "$now: mapping rna_accs->locus_link_eids...\n";
    my $tags=$self->tags;
    while (my ($tag,$list)=each %$matches) {
	my %rna_accs;
	foreach my $h (@$list) {
	    my $rna_acc=$h->{rna_acc};
	    $rna_acc=~s/\s.*//;
	    $rna_accs{$rna_acc}++;
#	    $tags{$tag}->{rna_accs}->{$h->{rna_acc}}++;
	}

	# determine if there is a unique locus_link_eid for this tag:
	# do so by collecting all mappings of rna_acc->locus_link_eid;
	# if there is only one such resulting ll, retain it
	# regardless, retain the entire list of ll's
	my @rna_accs=keys %rna_accs;
	if (@rna_accs) {
#	    $tags->{$tag}->{rna_accs}=\@rna_accs;
	    my $lls=$self->rnas2lls(\@rna_accs);
	    $tags->{$tag}->{lls}=$lls;
	    if (@$lls==1) {
		$tags->{$tag}->{locus_link_eid}=$lls->[0];
	    }
	}
    }
}

sub is_ambiguous {
    my ($self,$tag)=@_;
    my $h=$self->tags->{$tag} or return undef;
    my $lls=$h->{lls} or return undef;
    ref $lls eq 'ARRAY' && @$lls>1;
}

sub output_dir {
    my $self=shift;
    join('/',$self->base_dir,$self->base_output_dir,$self->project_name);
}

sub tmp_fasta_filename {
    my $self=shift;
    my $project_name=$self->project_name;
    my $sample_id=$self->sample_id;
    my $output_dir=$self->output_dir;
    "$output_dir/$project_name.$sample_id.fa";
}

sub write_fasta {
    my ($self,$filename)=@_;
    open (FASTA,">$filename") or die "Can't open $filename for writing: $!";
    my $motif=$self->motif;

    my $tags=$self->tags;
    while (my ($tag,$hash)=each %$tags) {
	next if $hash->{locus_link_eid}; # used as a flag; perhaps a status field instead?
#	my $count=$hash->{count};
	print FASTA "> $tag\n$motif$tag\n";
#	print FASTA "> $tag $count\n$motif$tag\n";
    }
    close FASTA;
    warn "$filename written\n";
    $filename;
}

sub rnas2lls {
    my ($self,$rna_accs)=@_;
    my $rna2ll=$self->babel->translate(src_ids=>$rna_accs,src_type=>'sequence_acc',dst_type=>'gene_locuslink');
    # $rna2ll is a hash: k=$rna_acc, v=list of locus_link_eids
    my %lls;
    while (my ($rna_acc,$lls)=each %$rna2ll) {
	foreach my $ll (@$lls) {
	    $lls{$ll}=$ll;
	}
    }
    wantarray? keys %lls:[keys %lls];
}


sub normalize {
    my ($self)=@_;
    my $n_reads=$self->n_reads or confess "no n_reads???";
    my $scale=1_000_000/$n_reads;
    warn "scale is $scale";
    my $tags=$self->tags;
    while (my ($tag,$hash)=each %$tags) {
	my $count=$hash->{count} or do {
	    warn "no count for $tag???"; next
	    };
	$hash->{cpm}=$hash->{count}*$scale;
    }
}


__PACKAGE__->_class_init();
1;
