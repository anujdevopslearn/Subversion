package SBEAMS::SolexaTrans::SequenceCmp;
use base qw(Class::AutoClass);
use strict;
use warnings;
use Carp;
use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin/lib";
use FileUtilities qw(slurpFile spitString);

use vars qw(@AUTO_ATTRIBUTES @CLASS_ATTRIBUTES %DEFAULTS %SYNONYMS);
@AUTO_ATTRIBUTES = qw(rm_tmps blast_opts);
@CLASS_ATTRIBUTES = qw(blast_exe tmp_dir barf);
%DEFAULTS = (blast_exe=>'/users/vcassen/software/blast/bin/bl2seq',
	     blast_opts=>'-W 4 -E 2 -G 0',
	     tmp_dir=>'/users/vcassen/software/blast/tmp',
	     barf=>1,
	     rm_tmps=>1,
	     );
%SYNONYMS = ();

Class::AutoClass::declare(__PACKAGE__);

sub _init_self {
    my ($self, $class, $args) = @_;
    return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this
}

sub _class_init {
    my ($class)=@_;
    $class->tmp_dir('/users/vcassen/software/blast/tmp');
}

# compare two strings
# return the score from blast
sub cmp {
    my ($self,$s1,$s2)=@_;
    
    my $tmp_dir=$self->tmp_dir or confess "no tmp_dir";

    my $tmpfile1=join('/',$tmp_dir,substr($s1,0,18).'.fa');
    my $fasta1="> $s1\n$s1\n";
    spitString($fasta1,$tmpfile1);

    my $tmpfile2=join('/',$tmp_dir,substr($s2,0,18).'.fa');
    my $fasta2="> $s2\n$s2\n";
    spitString($fasta2,$tmpfile2);

    my $blast_exe=$self->blast_exe;
    my $blast_opts=$self->blast_opts;
    my $cmd="$blast_exe $blast_opts -i $tmpfile1 -j $tmpfile2 -p blastn";
    open (BLAST,"$cmd |") or die "Can't open pipe to $cmd: $!";
    my $score;
    while (<BLAST>) {
	if (/Score = ([\d.]+) bits/) {
	    $score=$1;
#	    warn "got Score=$score!\n";
	    last;
	} elsif (/No hits found/) {
#	    warn "aww, no hits\n";
	    $score=0;
	    last;
	} elsif (/Lambda/) {
	    last;
	}
    }
    close BLAST;
    if ($self->rm_tmps) {
	unlink $tmpfile1;
	unlink $tmpfile2;
    }
    $score;			# can be undef;
}

__PACKAGE__->_class_init;

1;
