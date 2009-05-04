package SBEAMS::SolexaTrans::ProcessExport;
use base qw(Class::AutoClass);
use strict;
use warnings;
use Carp;
use Data::Dumper;
use SBEAMS::SolexaTrans::PatmanClient;
use SBEAMS::SolexaTrans::Repeats;

use vars qw(@AUTO_ATTRIBUTES @CLASS_ATTRIBUTES %DEFAULTS %SYNONYMS);
@AUTO_ATTRIBUTES = qw(export_file tags 
		      n_reads n_repeats n_tags
		      project_name lane ss_sample_id motif truncate
		      genome_id ref_fasta
		      patman_max_mismatches use_old_patman_output
		      babel dbh
		      fuse
		      );
@CLASS_ATTRIBUTES = qw(repeats repeat_length output_dir);
%DEFAULTS = (patman_max_mismatches=>1,
	     fuse=>0,
	     truncate=>0,
	     );
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
    my $filename=$self->export_file or confess "no export_file???";
    my $now=scalar localtime;
    warn "$now: counting tags in $filename...\n";
    open (TAGS,"$filename") or die "Can't open $filename: $!";

    my $tags=$self->tags;
    my $repeat_length=$self->repeat_length;
    my $n_reads=0;
    my $n_repeats=0;
    my $fuse=$self->fuse||0;
    my $truncate=$self->truncate;

    while (<TAGS>) {
	chomp;
	my @fields=split(/\t/);
	my $tag=lc $fields[8];
	next if $tag=~/[^acgt]/;
	if ($truncate) {
	    $tag=substr($tag,0,-$truncate);
	} else {
	    $tag=~s/t[acgt]?$//;
	}
	next unless $tag;
	$n_reads++;

	do {$self->repeats->tally_repeat($tag); next} if $self->repeats->is_repeat($tag);
	$tags->{$tag}->{count}++;
	$tags->{$tag}->{length}=length $tag;

	last if --$fuse==0;
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
# mark found tags with {locus_link_eid},{genome_id},{from_ref_db} (the last is just a flag)
sub lookup_tags {
    my ($self,$ref_tablename)=@_;
    my $tags=$self->tags;
    my $dbh=$self->dbh or confess "no dbh";

#    my $count=$dbh->selectcol_arrayref("SELECT COUNT(*) FROM $ref_tablename")->[0];
#    return unless $count>0;

    my $n_found=0;
    while (my ($tag,$hash)=each %$tags) {
	my $sql="SELECT locus_link_eid,genome_id FROM $ref_tablename WHERE tag='$tag'";
	my $rows=$dbh->selectall_arrayref($sql);
	next unless $rows && @$rows==1;
	my ($ll,$genome_id)=@{$rows->[0]};
	$hash->{locus_link_eid}=$ll;
	$hash->{genome_id}=$genome_id;
	$hash->{from_ref_db}=1;
	$n_found++;
    }
    warn "lookup_tags: found $n_found tags in ref_db\n";
}

# if a tag is assigned, remove it from %tags to save space
sub remove_assigned {
    my ($self)=@_;
    my $tags=$self->tags;
    
}


# insert any tag with a locus_link_eid, but without {from_ref_db} set, into the ref db
sub update_ref_db {
    my ($self,$ref_tablename)=@_;
    my $tags=$self->tags;
    warn "inserting found tags back into ref db...\n";
    my $stm=$self->dbh->prepare("INSERT INTO $ref_tablename (tag,locus_link_eid,rna_acc,genome_id) VALUES (?,?,?,?)");
    my $n_added=0;
    while (my ($tag,$hash)=each %$tags) {
	next unless $hash->{locus_link_eid} && !$hash->{from_ref_db};
	my ($ll,$rna_accs,$genome_id)=@$hash{qw(locus_link_eid rna_accs genome_id)};
	my $rna_acc=join(',',@$rna_accs);
	$stm->execute($tag,$ll,$rna_acc,$genome_id);
	$n_added++;
	$hash->{from_ref_db}=1;
    }
    warn "update_ref_db: added $n_added new genes to $ref_tablename\n";
}
#------------------------------------------------------------------------

# run patman program on unassigned tags
# Steps are:
# - write unassigned tags to a fasta file
# - call patman on the input file, against some ref_fasta genome
# - parse the results; 
sub run_patman {
    my ($self,%argHash)=@_;

    my $patman=SBEAMS::SolexaTrans::PatmanClient->new();

    # write all tags in fasta format and run patman program:
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
	my $rc=$patman->run(query=>$fasta_file, target=>$self->ref_fasta, 
			    output=>"$fasta_file.patman",options=>$options);
#	warn "patman: rc=$rc\n";
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
    my $genome_id=$self->genome_id or confess "no genome_id";
    my $n_added=0;
    while (my ($tag,$list)=each %$matches) {

	# gather rna_accs from patman output:
	my %rna_accs;		# local list of rna_accs (and counts) for this tag
	foreach my $h (@$list) {
	    my $rna_acc=$h->{rna_acc};
	    if ($rna_acc=~/[A-Z][A-Z]_\d+/) { $rna_acc=$& }
	    $rna_acc=~s/\s.*//;	# trim anything after whitespace...?
	    $rna_accs{$rna_acc}++;
#	    $tags->{$tag}->{rna_accs}={$h->{rna_acc}}++;	# was commented out; due to size of %tags?
	}

	# determine if there is a unique locus_link_eid for this tag:
	# do so by collecting all mappings of rna_acc->locus_link_eid;
	# if there is only one such resulting ll, retain it
	# regardless, retain the entire list of ll's
	my @rna_accs=keys %rna_accs;
	if (@rna_accs) {
	    $tags->{$tag}->{genome_id}=$genome_id;
	    $n_added++;
	    $tags->{$tag}->{rna_accs}=\@rna_accs; # was commented out; due to size of %tags?
	    my $lls=$self->rnas2lls(\@rna_accs);
	    $tags->{$tag}->{lls}=$lls;
	    if (@$lls==1) {
		$tags->{$tag}->{locus_link_eid}=$lls->[0];
	    }
	}
    }
    warn "run_patman: marked $n_added genes from genome_id=$genome_id";
}

sub is_ambiguous {
    my ($self,$tag)=@_;
    my $h=$self->tags->{$tag} or return undef;
    my $lls=$h->{lls} or return undef;
    ref $lls eq 'ARRAY' && @$lls>1;
}

sub output_dir {
    my $self=shift;
    join('/',$self->output_dir,$self->project_name);
}

sub tmp_fasta_filename {
    my $self=shift;
    my $project_name=$self->project_name;
    my $sample_id=$self->ss_sample_id;
    my $output_dir=$self->output_dir;
    my $lane=$self->lane;
    "$output_dir/$project_name.$sample_id.$lane.fa";
}

sub write_fasta {
    my ($self,$filename)=@_;
    open (FASTA,">$filename") or die "Can't open $filename for writing: $!";
    my $motif=$self->motif;

    my $tags=$self->tags;
    my $n_tags=0;
    while (my ($tag,$hash)=each %$tags) {
	next if $hash->{genome_id}; # used as a flag; perhaps a status field instead?
	print FASTA "> $tag\n$motif$tag\n";
	$n_tags++;
    }
    close FASTA;
    warn "$filename written ($n_tags tags)\n";
    $filename;
}

sub rnas2lls {
    my ($self,$rna_accs)=@_;
    my @accs;
    foreach my $rna_acc (@$rna_accs) {
	$rna_acc=~/[A-Z][A-Z]_\d+/ or next;
	push @accs,$&;
    }

    my $rna2ll=$self->babel->translate(src_ids=>\@accs,src_type=>'sequence_acc',dst_type=>'gene_locuslink');
    # $rna2ll is a hash: k=$rna_acc, v=list of locus_link_eids
    my %lls;
    while (my ($rna_acc,$lls)=each %$rna2ll) {
	foreach my $ll (@$lls) {
	    $lls{$ll}=$ll;
	}
    }
#    warn "rnas2lls: rna_accs are ",Dumper($rna_accs);
#    warn "rnas2lls: lls are ",Dumper(\%lls);
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
