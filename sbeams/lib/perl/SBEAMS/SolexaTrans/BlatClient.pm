package SBEAMS::SolexaTrans::BlatClient;
use base qw(Class::AutoClass);
use strict;
use warnings;
use Carp;
use Data::Dumper;

use vars qw(@AUTO_ATTRIBUTES @CLASS_ATTRIBUTES %DEFAULTS %SYNONYMS);
@AUTO_ATTRIBUTES = qw(query target output options);
@CLASS_ATTRIBUTES = qw(blat_dir exe default_opts);
%DEFAULTS = (blat_dir=>'/users/vcassen/software/blat',
	     exe=>'blat',
	     default_opts=>{oneOff=>0,
		    ooc=>'$blat_dir/11.ooc',
		    minScore=>0,
		    out=>'blast8',
		},
	     
	     );
%SYNONYMS = ();

Class::AutoClass::declare(__PACKAGE__);

sub _init_self {
    my ($self, $class, $args) = @_;
    return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this
}

# runs the blat program
# returns the $rc code from the system call (0 means success, anything else means failure)
sub run {
    my ($self,%argHash)=@_;
    my ($query,$target,$output,$options)=@argHash{qw(query target output options)};
    $query||=$self->query;
    $target||=$self->target;
    $output||=$self->output;
    $options||=$self->options;

    my $blat_dir=$self->blat_dir;
    my $blat_options="-oneOff=1 -ooc=$blat_dir/11.ooc -minScore=0 -out=blast8";

    while (my ($opt,$value)=each %{$self->default_opts}) {
	next if $options->{$opt};
	my $eval=eval "\"$value\"";
	$options->{$opt}=$eval;
    }
    my $opt_str=join(' ',map {"$_=$options->{$_}"} keys %$options);

    die "no such blat_db: $target ($!)\n" unless -r $target;
    $output||=$query.'.blat';

    # run blat:
    my $rc;
    if ($options->{use_blat_cache} && -r $output) {
	warn "skipping blat run\n";
    } else {
	my $blat_exe="$blat_dir/blat";
	my $blat_cmd="$blat_exe $opt_str $target $query $output";
	warn "Calling BLAT:\n$blat_cmd...\n";
	$rc=system($blat_cmd)/256;
    }
    $rc;
}

# return a hash containing match info:
# {matches}=>list of matches (hashlette) according to certain criteria:
#      each hashlette: keys=tag,rna_acc,pos,strand,n_mismatches
# {n_matches}=>total number of matches
# {total_hits}=>total number of hits reported by BLAT, including ones that
#               didn't meet the criteria
sub parse {
    my ($self,%argHash)=@_;
    my ($output,$max_mismatch,$min_length)=@argHash{qw(output max_mismatch min_length)};

    # parse output;
    # put everything in local %ambiguous for starters, then transfer to 
    # %gene2tag where appropriate.  Have to do it this way because
    # it's easier to parse $blat_outupt (we don't have to detect
    # single hits.  Hits are 1/line, so we'd have to parse two lines
    # to know if the hit was signular or not.  Ugh).

    # output format is (blast8)
    # [0] query id
    # [1] database sequence (subject) id
    # [2] percent identity
    # [3] alignment length
    # [4] number of mismatches
    # [5] number of gap openings
    # [6] query start
    # [7] query end
    # [8] subject start
    # [9] subject end
    # [10] Expect value
    # [11] HSP bit score

    open (BLATS,$output) or die "Can't open $output???: $!\n";
    my %tags;
    my $n=0;

    warn "parsing BLAT file $output...\n";
    my @matches;
    my $total_hits=0;
    my $prefix=$argHash{prefix};

    while (<BLATS>) {
#	warn readable($n)."...\n" if (++$n%100_000==0);
	chomp;
	next unless $_;
	my @fields=split(/\t/);
	next unless @fields>9; 
#	next unless $fields[0]=~/^\d+$/i; # skip header lines
	$total_hits++;

	my $tag=$fields[0];
	$tag=~s/^$prefix// if $prefix;

	# only accept (near?) perfect matches:
	my $tag_length=length $tag;
	my $n_mismatches=$fields[4];
	next unless $tag_length>=$min_length && $n_mismatches<=$max_mismatch;

	my $rna_acc=$fields[1];
	my $pos=$fields[8];
	my $strand=$fields[8]>$fields[9]? 1:-1;

	my $h2={tag=>$tag,
		rna_acc=>$rna_acc,
		pos=>$pos,
		strand=>$strand,
		n_mismatches=>$n_mismatches,
	    };
	push @matches,$h2;
    }
    close BLATS;
    my %hash=(matches=>\@matches,
	      n_matches=>scalar @matches,
	      total_hits=>$total_hits);
    wantarray? %hash:\%hash;
}


1;
