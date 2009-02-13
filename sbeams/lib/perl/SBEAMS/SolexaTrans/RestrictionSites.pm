package SBEAMS::SolexaTrans::RestrictionSites;
use base qw(Class::AutoClass);
use strict;
use warnings;
use Carp;
use Data::Dumper;

use vars qw(@AUTO_ATTRIBUTES @CLASS_ATTRIBUTES %DEFAULTS %SYNONYMS);
@AUTO_ATTRIBUTES = qw(sites);
@CLASS_ATTRIBUTES = qw();
%DEFAULTS = ();
%SYNONYMS = ();

Class::AutoClass::declare(__PACKAGE__);

my $res_sites = {
    'AVAI' => 'C[TC]CG[AG]G',
    'HAELL' => '[AG]GCGC[TC]',
    'BSSHII' => 'GCGCGC',
    'STYL' => 'CC[AT][TA]GG',
    'NOTI' => 'GCGGCCGC',
    'ECORV' => 'GATATC',
    'BBUL' => 'GCATGC',
    'NHEI' => 'GCTAGC',
    'SCAL' => 'AGTACT',
    'AGEL' => 'ACCGGT',
    'SMAL' => 'CCCGGG',
    'BAMHL' => 'GGATCC',
    'HPAII' => 'CCGG',
    'ECORI' => 'GAATTC',
    'BSAOI' => 'CG[AG][TC]CG',
    'MLUL' => 'ACGCGT',
    'CSP45I' => 'TTCGAA',
    'MBOI' => 'GATC',
    'I-PPOI' => 'CTCTCTTAAGGTAGC',
    'HINCII' => 'GT[TC][AG]AC',
    'BSTXI' => 'CCANNNNNNTGG',
    'TTHLLLI' => 'GACNNNGTC',
    'NAEL' => 'GCCGGC',
    'NGOMI' => 'GCCGGC',
    'MSPI' => 'CCGG',
    'BST71I' => 'GCAGC(8/12)',
    'XMNI' => 'GAANNNNTTC',
    'PSTL' => 'CTGCAG',
    'NCOI' => 'CCATGG',
    'SALL' => 'GTCGAC',
    'BSTOI' => 'CC[AT]GG',
    'PVUL' => 'CGATCG',
    'SACII' => 'CCGCGG',
    'BC/I' => 'TGATCA',
    'AVALI' => 'GG[AT]CC',
    'MSPAI' => 'C[AC]GC[GT]G',
    'SFII' => 'GGCCNNNNNGGCC',
    'KPNI' => 'GGTACC',
    'RVUII' => 'CAGCTG',
    'RSAL' => 'GTAC',
    'MBOII' => 'GAAGA(8/7)',
    'HSP92I' => 'G[AG]CG[TC]C',
    'HINFI' => 'GANTC',
    'BSRBRI' => 'GATNNNNATC',
    'ECO72I' => 'CACGTG',
    'HINDIII' => 'AAGCTT',
    'ACC65I' => 'GGTACC',
    'ACCILL' => 'TCCGGA',
    'ECOICRI' => 'GAGCJC',
    'A/W441' => 'GTGCAC',
    'BSTEII' => 'GGTNACC',
    'SAU3AI' => 'GATC',
    'DDEI' => 'CTNAG',
    'HPAI' => 'GTTAAC',
    'STUL' => 'AGGCCT',
    'ECLHKI' => 'GACNNNNNGTC',
    'SSPL' => 'AATATT',
    'NAR' => 'GGCGCC',
    'BSU36I' => 'CCTNAGG',
    'XMAL' => 'CCCGGG',
    'XHOII' => '[AG]GATC[TC]',
    'BSP1286I' => 'G[GAT]GC[CAT]C',
    'HSP92II' => 'CATG',
    'BG/IL' => 'AGATCT',
    'CFOI' => 'GCGC',
    'HAELIL' => 'GGCC',
    'NCII' => 'CC[GC]GG',
    'ALUL' => 'AGCT',
    'SAU96I' => 'GGNCC',
    'NSIL' => 'ATGCAT',
    'ACCI' => 'GT[AT][TG]AC',
    'SNABI' => 'TACGTA',
    'ACCB7I' => 'CANNNNNTG',
    'FOKI' => 'GGATG(9/13)',
    'VSPI' => 'ATAAT',
    'NRUI' => 'TCGCGA',
    'ACYI' => 'G[AG]CG[TC]C',
    'A/W26I' => 'GTCTC(1/5)',
    'DPNI' => 'GATC',
    'DPNII' => 'GATC',
    'SGFI' => 'GCGATCGC',
    'BSRSI' => 'ACTGGN',
    'BANI' => 'GG[TC][AG]CC',
    'CSPI' => 'CGG[AT]CCG',
    'XBAI' => 'TCTAGA',
    'SINI' => 'GG[AT]CC',
    'BGLL' => 'GCCNNNNNGGC',
    'TAQI' => 'TCGA',
    'BSTZI' => 'CGGCCG',
    'SPEL' => 'ACTAGT',
    'NDEL' => 'CATATG',
    'AATII' => 'GACGIC',
    'TRU9I' => 'TTAA',
    'BA/I' => 'TGGCCA',
    'HHAI' => 'GCGC',
    'SPHI' => 'GCATGC',
    'APAL' => 'GGGCCC',
    'BSAMI' => 'GATTGCN',
    'ECO52I' => 'CGGCCG',
    'SACI' => 'GAGGCTC',
    'BANII' => 'G[AG]GC[TC]C',
    'CLAL' => 'ATCGAT',
    'BST98I' => 'CTTAAG',
    'XHOI' => 'CTCGAG',
    'ECO47III' => 'ACGGCT',
    'DRAL' => 'TTTAAA'
    };


sub _init_self {
    my ($self, $class, $args) = @_;
    return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this
    $self->sites($res_sites);
}

sub motif {
    my ($self,$enz)=@_;
    $self->sites->{uc $enz};
}

1;
