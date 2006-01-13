{package SBEAMS::Glycopeptide::Test_glyco_data;
	

####################################################
=head1 NAME

=head1 DESCRIPTION


=head2 EXPORT

None by default.



=head1 SEE ALSO


=head1 AUTHOR

Pat Moss, E<lt>pmoss@systemsbiology.org<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 by Pat Moss

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.3 or,
at your option, any later version of Perl 5 you may have available.


=cut
##############################################################
use strict;
use vars qw($sbeams);		

use File::Basename;
use File::Find;
use File::Path;
use Data::Dumper;
use Carp;
use FindBin;

use Bio::Graphics;
use Bio::SeqIO;
use Bio::SeqFeature::Generic;
use Bio::Annotation::Collection;
use Bio::Annotation::Comment;
use Bio::Annotation::SimpleValue;

use SBEAMS::Glycopeptide::Get_peptide_seqs;

use SBEAMS::Connection qw($log);


###############################################################################
# Constructor
###############################################################################
sub new{
    
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {aa_seq   => 'MESKGASSCRLLFCLLISATVFRPGLGWYTVNSAYGDTIIIPCRLDVPQNLMFGKWKYEKPDGSPVFIAFRSSTKKSVQYDDVPEYKDRLNLSENYTLSISNARISDEKRFVCMLVTEDNVFEAPTIVKVFKQPSKPEIVSKALFLETEQLKKLGDCISEDSYPDGNITWYRNGKVLHPLEGAVVIIFKKEMDPVTQLYTMTSTLEYKTTKADIQMPFTCSVTYYGPSGQKTIHSEQAVFDIYYPTEQVTIQVLPPKNAIKEGDNITLKCLGNGNPPPEEFLFYLPGQPEGIRSSNTYTLMDVRRNATGDYKCSLIDKKSMIASTAITVHYLDLSLNPSGEVTRQIGDALPVSCTISASRNATVVWMKDNIRLRSSPSFSSLHYQDAGNYVCETALQEVEGLKKRESLTLIVEGKPQIKMTKKTDPSGLSKTIICHVEGFPKPAIQWTITGSGSVINQTEESPYINGRYYSKIIISPEENVTLTCTAENQLERTVNSLNVSAISIPEHDEADEISDENREKVNDQAKLIVGIVVGLLLAALVAGVVYWLYMKKSKTASKHVNKDLGNMEENKKLEENNHKTEA',
		summary  => "This is a really neat protein, but there is no summary",
		protein_name => "CD166 antigen precursor",
		protein_symbol=> "ALCAM",
		ipi_id		   => 'IPI00015102',
		swiss_prot		=> 'Q13740',
		synonyms	=> 'CD166 antigen precursor (Activated leukocyte-cell adhesion molecule) (ALCAM).',
		trans_membrane_locations => "o528-550i",
		numb_tm_domains => 1,
		signal_sequence_info	=> "28 Y 0.988 Y",
		cellular_location		=> "S",
		

};#end of the fake data hash;


    bless $self, $class;
    return($self);
}

########################################
#fake predicted seqs
##########################
sub get_fake_predicted_seqs{
	my $self = shift;
	
	#This is the data comming from the database
	my @data = (
{peptide_seq => 'R.LN#LSENYTLSISNAR.I',
glyco_score => 0.577602130073826,
peptide_id => 21,
predicted_mass => 1945.03811099999,
glyco_site_location => 91,
database_hits => 1,
database_hits_ipi_ids => 'IPI00015102',
similarity => 1,
},
{peptide_seq => 'R.LNLSEN#YTLSISNAR.I',
glyco_score => 0.422450448292768,
peptide_id => 22,
predicted_mass => 1945.03811099999,
glyco_site_location => 95,
database_hits => 1,
database_hits_ipi_ids => 'IPI00015102',
similarity => 1,
},
{peptide_seq => 'K.LGDCISEDSYPDGN#ITWYR.N',
glyco_score => 0.932317846874691,
peptide_id => 23,
predicted_mass => 2427.08011,
glyco_site_location => 167,
database_hits => 1,
database_hits_ipi_ids => 'IPI00015102',
similarity => 1,
},
{peptide_seq => 'K.EGDN#ITLK.C',
glyco_score => 0.616359842774635,
peptide_id => 24,
predicted_mass => 1101.548834,
glyco_site_location => 265,
database_hits => 1,
database_hits_ipi_ids => 'IPI00015102',
similarity => 1,
},
{peptide_seq => 'R.N#ATGDYK.C',
glyco_score => 0.811379022161403,
peptide_id => 25,
predicted_mass => 1008.444718,
glyco_site_location => 306,
database_hits => 1,
database_hits_ipi_ids => 'IPI00015102',
similarity => 1,
},
{peptide_seq => 'K.SMIASTAITVHYLDLSLN#PSGEVTR.Q',
glyco_score => 0.675093555434175,
peptide_id => 26,
predicted_mass => 2912.50656999999,
glyco_site_location => 337,
database_hits => 1,
database_hits_ipi_ids => 'IPI00015102',
similarity => 1,
},
{peptide_seq => 'R.N#ATVVWMK.D',
glyco_score => 0.791812362290788,
peptide_id => 27,
predicted_mass => 1200.60735199999,
glyco_site_location => 361,
database_hits => 1,
database_hits_ipi_ids => 'IPI00015102',
similarity => 1,
},
{peptide_seq => 'K.TIICHVEGFPKPAIQWTITGSGSVIN#QTEESPYINGR.Y',
glyco_score => 0.632364321731518,
peptide_id => 28,
predicted_mass => 4315.173557,
glyco_site_location => 457,
database_hits => 1,
database_hits_ipi_ids => 'IPI00015102',
similarity => 1,
},
{peptide_seq => 'K.IIISPEEN#VTLTCTAENQLER.T',
glyco_score => 1,#0.591478511357944
peptide_id => 29,
predicted_mass => 2583.321401,
glyco_site_location => 480,
database_hits => 1,
database_hits_ipi_ids => 'IPI00015102',
similarity => 1,
},
{peptide_seq => 'R.TVNSLN#VSAISIPEHDEADEISDENR.E',
glyco_score => 0,#0.482276504963288
peptide_id => 30,
predicted_mass => 3120.459546,
glyco_site_location => 499,
database_hits => 1,
database_hits_ipi_ids => 'IPI00015102',
similarity => 1,
},
);
		   
	
		

	return @data;
}
#

########################################
#fake identified seqs
##########################
sub get_fake_identifed_seqs{
	my $self = shift;
	my @data = (
#{peptide_id => 21,
#peptide_seq => 'N.#LSENYTLSISNARISDEK.R',
#number_tryptic_peptides => 1,
#peptide_prophet_score => 0.9391,
#peptide_mass => 2041.2,
#identifed_tissues => 'serum',
#},
{peptide_id => 22,
peptide_seq => 'N.LSEN#YTLSISNARISDEK.R',
number_tryptic_peptides => 1,
peptide_prophet_score => 0.9391,
peptide_mass => 2041.2,
identifed_tissues => 'serum',
},
{peptide_id => 24,
peptide_seq => 'K.NAIKEGDN#ITLK.C',
number_tryptic_peptides => 2,
peptide_prophet_score => 0.8636,
peptide_mass => 1315.7,
identifed_tissues => 'serum',
},
{peptide_id => 30,
peptide_seq => 'R.TVNSLN#VSAISIPEHDEADEISDENR.E',
number_tryptic_peptides => 2,
peptide_prophet_score => 0.7966,
peptide_mass => 2858,
identifed_tissues => 'serum',
},
);
	
return @data;
}

} #end of package
1;
