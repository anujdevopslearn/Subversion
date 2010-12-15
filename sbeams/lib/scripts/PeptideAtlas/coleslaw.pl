#!/usr/local/bin/perl

###############################################################################
# $Id$
#
# Description : Script to check completeness and integrity of SRM transitions data in PASTRAMI (PATR)
#
###############################################################################


###############################################################################
# Generic SBEAMS setup for all the needed modules and objects
###############################################################################

use strict;
use Getopt::Long;
use File::Basename;
use FindBin;
use lib "$FindBin::Bin/../../perl";


use SBEAMS::Connection;
use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::PeptideAtlas::PeptideFragmenter;

use SBEAMS::Proteomics::PeptideMassCalculator;

$|++; # don't buffer output

my $sbeams = SBEAMS::Connection->new();
$sbeams->Authenticate();
my $patlas = SBEAMS::PeptideAtlas->new();
$patlas->setSBEAMS( $sbeams );


# Global variables
my %opts;

{  # Main

    # Authenticate or exit
    my $user = $sbeams->Authenticate(work_group=>'PeptideAtlas_admin') || 
	print_usage( "You are not permitted to perform this action" );

    &process_options();

    my %set_data = &get_set_data();
    my $set_has_organism = (exists $set_data{organism_id});  # should also check that Org != Multiple  (for some other time...)

    &validate_set ( \%set_data );

    &handle_transitions();

    print "Done!\n\n";
    exit;

} # end main


sub find_q3_ion {
    my %args = @_;

    my $q3_mz    = $args{q3_mz} || 0;
    my $max_ch   = $args{charge} || 5;
    my $sequence = $args{peptide} || '';

    return '' unless $sequence;

    my $pepfrag = new SBEAMS::PeptideAtlas::PeptideFragmenter;

    my $ions = $pepfrag->getExpectedFragments( modifiedSequence => $sequence,
					       charge => $max_ch					       
					       );

    # print "[DEBUG] -- [$max_ch] [$q3_mz] [$sequence]\n";

    my $matches = 0;
    my $num_ions;
    my $ann = '';
    my $closest = 0.2;

    foreach my $ion ( @{$ions} ) {
	$num_ions++;

	my $mdiff = ($q3_mz - $ion->{mz});
	if ( abs($mdiff) < $closest ) {
	    $ann = "$ion->{label_st}/".sprintf "%.2f", $mdiff;

	    print "We may have a match! [q3=$q3_mz] [$ann=$ion->{mz}]\n" if $opts{verbose};
	    $closest = abs($mdiff);
	    $matches++;
	}
    }

    print "[WARN] Multiple ($matches) fragment ions found within 0.2 mass tolerance; keeping the closest match.\n" if ($matches gt 1);

    if ($ann) {
	return $ann;
    } else {
	print "[WARN] There were $matches matches found among the $num_ions potential fragment (b/y) ions.\n";
	return '';
    }

}

sub process_transition_data {
    my $data = shift;
    my %rowdata = ();

    my $orig_vals = '';

    my $entry_txt = "[ENTRY $data->{srm_transition_id}]";

    if ($data->{record_status} ne 'N') {
	print "$entry_txt This transition record is not marked as active (record_status = $data->{record_status}). Skipping.\n";
	return;
    }

    if (!$data->{q1_mz} || !$data->{q3_mz}) {
	print "$entry_txt This transition record does not contain Q1/Q3 transition values!!  Skipping.\n";
	return;
    }

    # mass
    my $massCalculator = new SBEAMS::Proteomics::PeptideMassCalculator;
    my $mw = sprintf "%.1f", $massCalculator->getPeptideMass( mass_type => 'monoisotopic',
							      sequence  => $data->{modified_peptide_sequence} );

    if (!$data->{monoisotopic_peptide_mass}) {
	print "$entry_txt No Peptide Mass of precursor; will insert :: $mw\n";
	$rowdata{monoisotopic_peptide_mass} = $mw;

    } elsif ( abs($data->{monoisotopic_peptide_mass} - $mw) > 0.2) {
	print "$entry_txt Mass difference of precursor is TOO LARGE; will correct:  Database: $data->{monoisotopic_peptide_mass} :: $mw\n";
	$rowdata{monoisotopic_peptide_mass} = $mw;
	$orig_vals .= sprintf "MonoisotopicMass:%.1f;", $data->{monoisotopic_peptide_mass};

    } elsif ($opts{verbose}) {
	print "$entry_txt Mass OK:  Database: $data->{monoisotopic_peptide_mass} :: $mw\n";
    }


    # charge
    my $ch = int(0.1 + $mw/ $data->{q1_mz});

    if (!$data->{peptide_charge}) {
	print "$entry_txt No Peptide Charge of precursor; will insert :: $ch\n";
	$rowdata{peptide_charge} = $ch;

    } elsif ( $data->{peptide_charge} != $ch) {
	print "$entry_txt Charge State of precursor is INCORRECT; will update:  Database: $data->{peptide_charge} :: $ch\n";
	$rowdata{peptide_charge} = $ch;
	$orig_vals .= "PrecursorCharge:$data->{peptide_charge};";


    } elsif ($opts{verbose}) {
	print "$entry_txt Charge OK:  Database: $data->{peptide_charge} :: $ch\n";
    }


    # ion label
    my $q3 = &find_q3_ion( q3_mz   => $data->{q3_mz},
			   charge  => $ch,
			   peptide => $data->{modified_peptide_sequence} );

    print "$entry_txt No suitable Q3 ion found!\n" unless $q3;

    if (!$data->{q3_ion_label}) {
	print "$entry_txt No Q3 Ion Label found; ";

	if ($q3) {
	    print "will insert :: $q3\n";
	    $rowdata{q3_ion_label} = $q3;
	} else {
	    print "nothing to insert...\n";
	}

    } elsif ( $q3 !~ /^\Q$data->{q3_ion_label}\E/ ) { # do a substring match, since original entries will most likely not be in SpectraST notation
	print "$entry_txt Q3 Ion Label is INCORRECT; will update:  Database: $data->{q3_ion_label} :: $q3\n";
	$rowdata{q3_ion_label} = $q3;
	$orig_vals .= "Q3IonLabel:$data->{q3_ion_label};";

    } elsif ( $data->{q3_ion_label} ne $q3) {  # starts with correct string, but may be missing mass diff annotation
	print "$entry_txt Q3 Ion Label is incomplete; will update:  Database: $data->{q3_ion_label} :: $q3\n";
	$rowdata{q3_ion_label} = $q3;

    } elsif ($opts{verbose}) {
	print "$entry_txt Q3 Ion Label OK:  Database: $data->{q3_ion_label} :: $q3\n";
    }


    # did we change anything?
    if ($orig_vals) {
	$rowdata{original_values} = "$data->{original_values}; $orig_vals";
	$rowdata{original_values} =~ s/^; //;
    }


    #### UPDATE the record with the new info, if any
    if (%rowdata) {
	print "$entry_txt Updating database entry...\n" if ($opts{verbose});

	my $result = $sbeams->updateOrInsertRow(
						update => 1,
						table_name => "$TBAT_SRM_TRANSITION",
						rowdata_ref => \%rowdata,
						PK => "srm_transition_id",
						PK_value => $data->{srm_transition_id},
						verbose=>$opts{verbose},
						testonly=>$opts{testonly},
						);

	print "[ERROR] Unable to update database record for $entry_txt\n" unless $result;
	return 1;

    } else {
	print "$entry_txt Nothing to update\n" if ($opts{verbose});
	return 0;

    }

}


sub handle_transitions {
    my $set_id = $opts{srm_transitions_set_id};

    my $sql = qq~
	SELECT *
	FROM $TBAT_SRM_TRANSITION SRM
	WHERE SRM.srm_transition_set_id = $set_id
	~;

    my @rows = $sbeams->selectHashArray($sql);
    my $numtrans = scalar (@rows);

    unless ($numtrans) {
	print "[WARN] There were no transition records found associated with this set.  Quitting.\n";
	exit;
    }

    print "[INFO] Found $numtrans transitions in this set\n" if $opts{verbose};

    my $updated = 0;

    for my $row (@rows) {
	my %data = %{$row};

	$updated += &process_transition_data(\%data);
    }

    print "[INFO] $updated transitions records were updated\n";

}


sub validate_set {
    my $data = shift;

    if ($data->{record_status} ne 'N') {
	print "This Set is not marked as active (record_status = $data->{record_status}). Quitting.\n";
	exit;
    }

    unless ($data->{instrument_id}) {
	print "[WARN] No instrument data contained in this set!\n";
    }

    unless ($data->{organism_id}) {
	print "[WARN] No organism associated with this set\n"; # -- will check individual transitions\n"; # implement this!
    }

    if ($data->{golive_date} =~ /(\d\d\d\d)-(\d\d)-(\d\d)/) {
	my $setdate = "$1$2$3";
	my ($d, $m, $y) = (localtime)[3..5];
	my $nowdate = sprintf "%d%02d%02d", $y+1900, $m+1, $d;

	if ( ($data->{is_public} ne 'Y') &&
	     ($nowdate < $setdate) ) {

	    print "[WARN] Go-Live date for this set is in the past, but it is still set to is_public = N\n";
	    # add auto-setting of is_public field?
	}

    } else {
	print "[WARN] The Go-Live Date associated with this set is not valid: $data->{golive_date}\n";
    }

}


sub get_set_data {
    my $set_id = $opts{srm_transitions_set_id};

    my $sql = qq~
	SELECT *
	FROM $TBAT_SRM_TRANSITION_SET SRM
	WHERE SRM.srm_transition_set_id = $set_id
	~;

    my @rows = $sbeams->selectHashArray($sql);

    if (!@rows) {
	print "No database entry for srm_transition_set_id = $set_id. Quitting. \n";
	exit;
    }

    my %results = %{@rows[0]};

    if ($opts{verbose}) {
	print "---- Extracted SRM set data ----\n";
	for my $key (sort keys %results) {
	    print "  $key :: $results{$key}\n";
	}
	print "---- ---------------------- ----\n";
    }

    return %results;

}


sub process_options {
    GetOptions( \%opts,"verbose", "testonly",
		"srm_transitions_set_id:s", "username:s" ) || print_usage();

    unless ( $opts{srm_transitions_set_id} ) {
	print_usage( "Missing required param srm_transition_set_id" );
    }

    $opts{verbose} ||= 0;
    $opts{testonly} ||= 0;
}


sub print_usage {
    my $message = shift || '';
    $message .= "\n";
    my $program = $FindBin::Script;

    print <<EOU;
$message
Usage: $program -s srm_transitions_set_id [-v -t]
Options:
  -v, --verbose                   Set verbose mode
  -t, --testonly                  If set, rows in the database are not changed or added
  -s, --srm_transitions_set_id    SRM transitions set ID to check

EOU
    exit;
}
