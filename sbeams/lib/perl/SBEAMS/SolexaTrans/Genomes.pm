package SBEAMS::SolexaTrans::Genomes;
use base qw(SBEAMS::SolexaTrans::Relational);
use strict;
use warnings;
use Carp;
use Data::Dumper;

use vars qw(@AUTO_ATTRIBUTES @CLASS_ATTRIBUTES %DEFAULTS %SYNONYMS);
@AUTO_ATTRIBUTES = qw(genome_id url name org path);
@CLASS_ATTRIBUTES = qw(table_fields tablename primary_key genomes db_name uniques indexes);
%DEFAULTS = (tablename=>'genomes',
	     table_fields=>{
		 genome_id=>'INT PRIMARY  KEY AUTO_INCREMENT',
		 org=>'VARCHAR(255) NOT NULL',
		 name=>'VARCHAR(255) NOT NULL',
		 path=>'VARCHAR(255) NOT NULL',
		 url=>'VARCHAR(255) NOT NULL',
	     },
	     indexes=>[qw(org name)],
	     uniques=>[qw(path url)],
	     primary_key=>'genome_id',
	     db_name=>'solexa_1_0',
	     );
%SYNONYMS = ();

Class::AutoClass::declare(__PACKAGE__);

# more to come
my $genomes={
    human=>{hg18=>'hg18/refMrna.fa',
	    hs_ref=>'hg18/refMrna.fa',
	},
    mouse=>{},
};

sub _init_self {
    my ($self, $class, $args) = @_;
    return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this
    $self->genomes($genomes);
}

# I have *no idea* why %DEFAULTS isn't working for these
sub _class_init {
    my ($class)=@_;
    $class->table_fields({
	genome_id=>'INT PRIMARY  KEY AUTO_INCREMENT',
	org=>'VARCHAR(255) NOT NULL',
	name=>'VARCHAR(255) NOT NULL',
	path=>'VARCHAR(255) NOT NULL',
	url=>'VARCHAR(255) NOT NULL',
    });
    $class->primary_key('genome_id');
#    $class->uniques([qw(path url)]);
}
		     
    
sub get_genome {
    my ($self,$org,$name)=@_;
    $self->genomes->{$org}->{$name}
}

sub fetch_genome_ids {
    my ($self,%argHash)=@_;

    my $sql="SELECT genome_id";
    my @wheres;
    foreach my $f (keys %{$self->table_fields}) {
	next unless defined $argHash{$f};
	my $val=$argHash{$f};
	push @wheres, "$f=".$self->dbh->quote($val);
    }
    if (@wheres) {
	my $wheres=join(' AND ',@wheres);
	$sql.=$wheres;
    }
    $self->dbh->selectcol_arrayref($sql);
}

__PACKAGE__->_class_init;

1;
