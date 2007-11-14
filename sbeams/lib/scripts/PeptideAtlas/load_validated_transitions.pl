#!/usr/local/bin/perl -w

###############################################################################
# $Id: load_atlas_build.pl 5269 2007-02-24 00:36:12Z edeutsch $
#
# Description : Script to load file of validated MRM transitions
#
###############################################################################


###############################################################################
   # Generic SBEAMS setup for all the needed modules and objects
###############################################################################

# Fields in peptide_annotations table:
# modified_peptide_annotation_id     modified_peptide_sequence     peptide_charge     q1_mz     q3_mz     q3_ion_label     transition_suitability_level_id     publication_id     annotater_name     annotater_contact_id     comment     date_created             created_by_id     date_modified            modified_by_id     owner_group_id     record_status    
# ---------------------------------  ----------------------------  -----------------  --------  --------  ---------------  ----------------------------------  -----------------  -----------------  -----------------------  ----------  -----------------------  ----------------  -----------------------  -----------------  -----------------  ---------------- 
# 1                                  DADPDTFFAK                    2                  563.8     825.4     y1-7             2                                   1                  (null)             2                        (null)      2007-06-09 22:19:27.867  2                 2007-06-09 22:19:27.867  2                  40                 N                
# 2                                  DADPDTFFAK                    2                  563.8     940.4     y1-8             3                                   1                  (null)             2                        (null)      2007-06-09 22:24:20.383  2                 2007-06-09 22:24:20.383  2                  40                 N                

use strict;
use Getopt::Long;
use FindBin;
#use lib "$FindBin::Bin/../../perl/SBEAMS/PeptideAtlas";
use lib "$FindBin::Bin/../../perl";

# Set up SBEAMS core module
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::BioLink;

# Set up PeptideAtlas module
use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

my $sbeams = new SBEAMS::Connection;
my $biolink = new SBEAMS::BioLink;
my $atlas = new SBEAMS::PeptideAtlas;
$atlas->setSBEAMS($sbeams);

# Global variables
my %opts;
my $headers;
my $head_idx;

{  # Main

  # Authenticate or exit
  my $user = $sbeams->Authenticate(work_group=>'PeptideAtlas_admin') || 
             print_usage( "You are not permitted to perform this action" );

  process_options();

  my $transitions = read_transition_file();
  load_transitions( $transitions );

} # end main

#+
# Read specified transitions file, return ref to array of trans hashrefs 
#-
sub read_transition_file {
  open MTF, $opts{mrm_transition_file} ||    
     print_usage( "Unable to open transition file $opts{mrm_transition_file}" );
  my @transitions;

  # These are the fields we'll store
  my $req = get_required_fields();

  while ( my $line = <MTF> ) {
    my @line = split( "\t", $line, -1 );
    if ( !$headers ) {
      $headers = \@line;
      # Check file format
      $head_idx = validate_headers( $headers );
      next;
    }
  
    my %row;
    for my $req_param ( @$req ) {
      my $file_idx = $head_idx->{$req_param}; 
      $row{$req_param} = ( defined($line[$file_idx]) ) ? $line[$file_idx] : '';
    }
    push @transitions, \%row;
  }

  # each element in transitions is a hashref 
  return \@transitions;

} # end read_transitions_file

#+
# Compare headers read from file with those we allow
#-
sub validate_headers {
  my $headers = shift;
  my %head_idx;
  my $cnt = 0;
  # Loop through headers, hash keyed by header points to column idx in the file
  for my $header ( @$headers ) {
    print "Adding $header\n" if $opts{verbose} > 4;
    $head_idx{$header} = $cnt++;
  }

  for my $key ( @{get_required_fields()} ) {
    print_usage("Invalid transition file format: missing $key") unless $head_idx{$key};
  }
  return \%head_idx;

} # end validate_headers

#+
# Lists fields we need to have in file, don't necessarily require a value
#-
sub get_required_fields {

# Column headers from prototype annotation file:
#
  #  Prot_Acc        Prot_Description        Prot_Name       NCBIAcc RefSeq  Pep_Seq PrecMass        FragMass        Pep_RT  CE      PrecCharge      FragSeries      FragNr  FragCharge Pep_Mod  Pep_MRM MRM-quality     Pep_Bad Pep_Comment     Pep_Comment2    Pep_identified  MRM_comment     Project_ID

  # Compare list to required headers - initial rev based on V. Lange values
  return [qw( Pep_Seq PrecMass FragMass PrecCharge FragSeries FragNr FragCharge
              Pep_Mod Pep_MRM MRM-quality MRM_comment Pep_RT CE NCBIAcc RefSeq Prot_Name )];
 
}

sub load_transitions {
  # Transitions 
  my $transitions = shift;

  my $username = '';
  my $contact_id = '';

  # Will set only one of name/contact ID as per ED example
  if  ( $opts{username} ) {
    if ( $opts{contact_id} ) {
      $contact_id = $opts{contact_id};
    } else {
      $username = $opts{username};
    }
  } else {
    $contact_id = $sbeams->getCurrent_contact_id();
  }

  my $ph;
  for my $trans ( @$transitions ) {
    
   # Lil' debuggin'
   if ( $opts{verbose} > 4 ) {
     print  join( "\t", keys(%$trans) ) . "\n" if !$ph;
     $ph++;
     print join( "\t", @$trans{keys(%$trans)} ) . "\n"; 
   }
#   print "Pep_Seq = $trans->{Pep_Seq}\n";
#   print "Pep_Mod = $trans->{Pep_Mod}\n";

    # Should we check to make sure peptide is in an atlas?
    # Mebbe, but not for now...

  #  Prot_Acc        Prot_Description        Prot_Name       NCBIAcc RefSeq  Pep_Seq PrecMass        FragMass        Pep_RT  CE      PrecCharge      FragSeries      FragNr  FragCharge Pep_Mod  Pep_MRM MRM-quality     Pep_Bad Pep_Comment     Pep_Comment2    Pep_identified  MRM_comment     Project_ID
#  print "Pep_Seq = $trans->{Pep_Seq}\n";
    
    my $modified_seq = get_modified_seq( seq => $trans->{Pep_Seq}, mods => $trans->{Pep_Mod} );
    print "Mod seq = $modified_seq\n" if $opts{verbose} > 4;
    my $comment = parse_comment( $trans );
    print "$comment\n" if $opts{verbose} > 4;

    my %row_data = ( modified_peptide_sequence => $modified_seq,
                     peptide_charge => $trans->{PrecCharge},
                     q1_mz => $trans->{PrecMass}/$trans->{PrecCharge},
                     q3_mz => $trans->{FragMass}/$trans->{FragCharge},
                     q3_ion_label => $trans->{FragSeries} . $trans->{FragCharge} . '-' . $trans->{FragNr},
                     transition_suitability_level_id => $trans->{'MRM-quality'} + 1, # FIX ME!
                     publication_id => '',
                     annotater_name => $username,
                     annotater_contact_id => $contact_id,
                     comment => $comment,
                     matching_peptide_sequence => $trans->{Pep_Seq},
                   );
  $sbeams->updateOrInsertRow ( insert => 1,
                               table_name=>$TBAT_MODIFIED_PEPTIDE_ANNOTATION,
                               rowdata_ref=>\%row_data,
                               PK => 'modified_peptide_annotation_id',
                               return_PK => 1,
                               add_audit_parameters => 1,
                               verbose => $opts{verbose},
                               testonly => $opts{testonly},
                             );
#    for my $k ( keys( %row_data ) ) { print "$k => $row_data{$k}\n"; }
  }
}

sub parse_comment {
  my $row = shift;
  return unless $row;
  my $comment = "$row->{MRM_comment}\n";
  for my $k ( keys( %$row ) ) {
    next if $k eq 'MRM_comment';
    $comment .= "KV: $k => $row->{$k}\n"; 
  }
  return $comment;
}

#+
#
#-
sub get_modification_masses {
  my %known_mods = ( 'ICPL-N_light' =>  106.02,
                     'ICPL_light' => 105.02 );
  return \%known_mods;
}

#+
#
#-
sub get_modified_seq {
  my %args = @_;
  for my $k ( qw( seq mods  ) ) {
    die "Missing required parameter $k" if !$args{$k};
  }
  my $aa_masses = $biolink->get_amino_acid_masses();
  my @seq = split( '', $args{seq} );
  my @mods = split( /:/, $args{mods}, -1);

#  print "$args{seq} splits into $#seq, $args{mods} splits into $#mods\n";

  my $nterm = $mods[0];
  my $cterm = $mods[$#mods];
  
  my $mod_masses = get_modification_masses();

  my $modified_sequence = '';

  unless ( $#seq + 2 == $#mods ) {
    print ( "Conflicting sequence/modification information: $#seq and $#mods" );
  }

  # Iterate through the sequence position by position
  for ( my $idx = 0; $idx <= $#seq; $idx++ ) {
    my $aa = uc( $seq[$idx] );

    $modified_sequence .= $aa; 
    
    # mod index is off by one, n/c terminal mods handled as different.
    my $m_idx = $idx + 1;
    
    # See if we have an altered mass at this postion
    my $alt_mass = 0;

    # Add n-terminal mod to first AA
    if ( $nterm && !$idx ) {
      die( "Unknown modification $nterm" ) if !$mod_masses->{$nterm};  
      $alt_mass += $mod_masses->{$nterm} 
    }
    
    # Add c-terminal mod to last AA
    if ( $cterm && $idx == $#seq ) {
      die( "Unknown modification $cterm" ) if !$mod_masses->{$cterm};  
      $alt_mass += $mod_masses->{$cterm} 
    }

    # Add any mods on AA
    if ( $mods[$m_idx] ) {
      die( "Unknown modification $mods[$m_idx]" ) if !$mod_masses->{$mods[$m_idx]};  
      $alt_mass += $mod_masses->{$mods[$m_idx]}; 
    }

    # We have an mass altering modification
    if ( $alt_mass ) {
      die( "Unknown amino acid mass for $aa" ) if !$aa_masses->{$aa};  
      $alt_mass += $aa_masses->{$aa}; 
      $modified_sequence .= '[' . $sbeams->roundToInt( $alt_mass ) . ']';
    }
  }
  return $modified_sequence;

}

sub print_usage {
  my $message = shift || '';
  $message .= "\n";
  my $program = $FindBin::Script;

  print <<EOU;
$message
Usage: $program -m mrm_transitions_file [-v level --testonly ]
Options:
  -v, --verbose n                 Set verbosity level.  default is 0
  -t, --testonly                  If set, rows in the database are not changed or added
  -m, --mrm_transitions_file      MRM transitions file to load
  -u, --username                  (SBEAMS) username to use for transitions

EOU
  exit;
}

sub process_options {
  GetOptions( \%opts,"verbose:s", "testonly",
                     "mrm_transition_file:s", "username:s" ) || print_usage();

  unless ( $opts{mrm_transition_file} ) {
    print_usage( "missing required param transition_file" );
  }

  unless ( -e $opts{mrm_transition_file} ) {
    print_usage( "Specified file $opts{transition_file} does not exist" );
  }{
  GetOptions( \%opts,"verbose:s", "testonly",
                     "mrm_transition_file:s", "username:s" ) || print_usage();

  unless ( $opts{mrm_transition_file} ) {
    print_usage( "missing required param transition_file" );
  }

  unless ( -e $opts{mrm_transition_file} ) {
    print_usage( "Specified file $opts{transition_file} does not exist" );
  }

  if ( $opts{username} ) {
    $opts{contact_id} = $sbeams->getContact_id( $opts{username} );
  }

  $opts{verbose} ||= 0;
}

  if ( $opts{username} ) {
    $opts{contact_id} = $sbeams->getContact_id( $opts{username} );
  }

  $opts{verbose} ||= 0;
}



