package SBEAMS::SolexaTrans::PatmanClient;
use base qw(Class::AutoClass);
use strict;
use warnings;
use Carp;
use Data::Dumper;

use vars qw(@AUTO_ATTRIBUTES @CLASS_ATTRIBUTES %DEFAULTS %SYNONYMS);
@AUTO_ATTRIBUTES = qw(queries targets output options patman barf);
@CLASS_ATTRIBUTES = qw(default_options);
%DEFAULTS = (patman=>'/users/vcassen/software/patman/patman',
	     default_options=>{},
#	     barf=>'/users/vcassen/software/patman/patman',
	     );
%SYNONYMS = ();

Class::AutoClass::declare(__PACKAGE__);

sub _init_self {
    my ($self, $class, $args) = @_;
    return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this
}

sub run {
    my ($self,%argHash)=@_;
    my ($query, $target, $output, $options)=@argHash{qw(query target output options)};

    # start with default options, then copy over anything in $argHash{options};
    my %options=%{$self->default_options};
    if ($options) {
	while (my ($k,$v)=each %$options) {
	    $options{$k}=$v;
	}
    }
    my $opt_str=join(' ',map {"$_ $options{$_}"} keys %options);

    my $patman=$self->patman or confess "no patman???";
    my $cmd="$patman $opt_str -D $target -P $query -o $output";
    my $now=scalar localtime;
    warn "$now: patman: $cmd\n";
    my $rc=system($cmd)>>8;
    $now=scalar localtime;
    warn "$now: patman done (rc=$rc)\n";
}

sub run_many {
    my ($self,%argHash)=@_;
    my ($queries, $targets, $output)=@argHash{qw(queries targets output)};

    # start with default options, then copy over anything in $argHash{options};
    my %options=%{$self->default_options};
    if (my $opts=$argHash{options}) {
	while (my ($k,$v)=each %$opts) {
	    $options{$k}=$v;
	}
    }
    my $options=join(' ',map {"$_ $options{$_}"} keys %options);

    # map options back to a string
    my $patman=$self->patman;# or confess "no patman???";
    warn "patman is $patman";
    my $t_str=join(' ', map {"-D $_"} @$targets);
    my $q_str=join(' ', map {"-P $_"} @$queries);
    my $cmd="$patman $options $t_str $q_str -o $output";
    warn "patman: $cmd";
    my $rc=system($cmd)>>8;
}

# parse patman output
# return a hash: k=$tag, v=hashlette (keys=tag,rna_acc,pos,strand,n_mismatches)
sub parse {
    my ($self,%argHash)=@_;
    my $output=$argHash{output}||$self->output or confess "no output";
    my $max_mismatches=$argHash{max_mismatches} || 100000; # i dunno; sumthin big
    my $min_length=$argHash{min_length} || 0;
    warn "parsing $output...\n";

    my %matches;
    open (OUTPUT,"$output") or die "Can't open $output: $!\n";
    while (<OUTPUT>) {
	chomp;
	my ($rna_acc,$tag,$start,$stop,$strand_sym,$n_mismatches)=split(/\t/);
	$tag=trim_ws($tag);
	next if $n_mismatches>$max_mismatches;
	next if length $tag<$min_length;
	my $strand=$strand_sym eq '+'? 1:-1;
	
	my $h={tag=>$tag,
	       rna_acc=>$rna_acc,
	       pos=>$start,
	       strand=>$strand,
	       n_mismatches=>$n_mismatches,
	   };
	push @{$matches{$tag}},$h;
    }

    close OUTPUT;
    my $n_matches=scalar keys %matches;
    warn "parse: returning $n_matches unique tag matches\n";
    wantarray? %matches:\%matches;

}

sub trim_ws { $_[0]=~s/\s*//g; $_[0]}
1;
