#!/usr/local/bin/perl 

###############################################################################
# Program     : load_consensus_library.pl
# Author      : Nichole King
#
# Description : Load the consensus library (msp or spectrast) into the consensus 
#               spectrum tables.
###############################################################################

use strict;
use Getopt::Long;
use FindBin;
use Cwd qw( abs_path );

use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams $sbeamsMOD $q $current_username 
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
         );
$|++;


#### Set up SBEAMS core module
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::Proteomics::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:
  --verbose n            Set verbosity level.  default is 0
  --quiet                Set flag to print nothing at all except errors
  --debug n              Set debug flag
  --help                 Print usage statement and exit

  --load                 load the library
  --test                 test only, don't write records
  --path                 path to library file
  --comment              Description of library. 
  --library_name         Name for consensus library
  --organism_name        Organism name (e.g. yeast, Human,...)

  --delete id            delete the library with consensus_library_id
  --list                 List existing library name/id pairs

 e.g.: ./$PROG_NAME --path /data/yeast.msp --library_name 'NIST Sc' --organism_name Yeast --load
EOU


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","test", 'help',
                   "load", "library_name:s", "organism_name:s", 'list',
                   "path:s", "delete:s", 'comment=s', "project_id:i"  ) ) {
    print "\n$USAGE\n";
    exit;
  }

$VERBOSE = $OPTIONS{"verbose"} || 0;

$QUIET = $OPTIONS{"quiet"} || 0;

$DEBUG = $OPTIONS{"debug"} || 0;

$TESTONLY = $OPTIONS{"test"} || 0;

unless ( $OPTIONS{'delete'}  || $OPTIONS{'load'} || $OPTIONS{'test'} ) {
    print "\n$USAGE\n";
    print "Need --load or --test or --delete id\n";
    exit(0);
}

if ( $OPTIONS{'load'} || $OPTIONS{'test'} ) {
    unless ($OPTIONS{path} && $OPTIONS{library_name}
    && $OPTIONS{organism_name} && $OPTIONS{project_id} )
    {
        print "\n$USAGE\n";
        print "Need --path and --library_name ";
        print " and --organism_name\n";
        exit(0);
    }
}

if ( $OPTIONS{help} ) {
    print "\n$USAGE\n";
    exit(0);
}

if ( $OPTIONS{list} ) {
  printBuildList();
  exit(0);
}


###############################################################################
# Set Global Variables and execute main()
###############################################################################
main();

exit(0);
###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
###############################################################################
sub main 
{
    #### Do the SBEAMS authentication and exit if a username is not returned
    exit unless (
        $current_username = $sbeams->Authenticate(work_group=>'PeptideAtlas_admin')
    );

    $sbeams->printPageHeader() unless ($QUIET);

    handleRequest();

    $sbeams->printPageFooter() unless ($QUIET);

} # end main


###############################################################################
# handleRequest
###############################################################################
sub handleRequest 
{
    my %args = @_;

    if ($OPTIONS{load} || $OPTIONS{test} )
    {
        my $organism_id = getOrganismId(
            organism_name => $OPTIONS{organism_name} 
        );

        ## make sure file exists
        my $file_path = abs_path( $OPTIONS{path} );

        unless (-e $file_path)
        {
            print "File does not exist: $file_path\n";
            exit(0);
        }

        populateRecords(organism_id => $organism_id, 
                          file_path => $file_path,
													verbose => $OPTIONS{verbose},
             consensus_library_name => $OPTIONS{library_name},
                    library_comment => $OPTIONS{comment}
                       );
    }

    if ($OPTIONS{delete}) {
        removeConsensusLibrary( consensus_library_id => $OPTIONS{delete} );
        exit 0;
    }

} # end handleRequest


###############################################################################
# populateRecords - populate consensus spectrum records with content of file
# 
# @param organism_id - organism id
# @param file_path - absolute path to library .msp file
###############################################################################
sub populateRecords
{
    my %args = @_;

    my $organism_id = $args{organism_id} || die "need organism_id";

    my $infile = $args{file_path} || die "need file_path";

    my $md5sum = system( "md5sum $args{file_path}" );

    my $consensus_library_name = $args{consensus_library_name} || 
        die "need consensus_library_name";

    my $library_comment = $args{library_comment} || '';

    my $commit_interval = 25;

#    $consensus_library_name .= '_' . $commit_interval;
    print "Loading library $consensus_library_name\n";

    # Test file open *before* inserting library record
    open(INFILE, "<$infile") || die "ERROR: Unable to open for reading $infile";


    my $consensus_library_id = insert_consensus_library(
        organism_id => $organism_id,
        library_comment => $library_comment,
        consensus_library_name => $consensus_library_name,
        md5sum => $md5sum,
        file_path => $args{file_path},
				project_id => $OPTIONS{project_id} );

    my $count = 0;

    ## can't use prepared statements, so one by one inserts here.

    my $loop_peaks = 0;
    my %spectrum;
    $sbeams->initiate_transaction();
 		print "Count is $count at " . time() . "\n";
    my $verbose = $args{verbose} || 0;
    my $idx = 0;
    while (my $line = <INFILE>) {
        chomp($line);
        next if $line =~ /^#/;
        next if $line =~ /^\s*$/;
        
        if ( $line =~ /^Name:\s(.+)\/(\d)/ ) { ## line 1 is Name
          # Now is the time to cache the idx
          $spectrum{entry_idx} = $idx;
          $spectrum{sequence} = $1;
          $spectrum{charge} = $2;
          $spectrum{modified_sequence} = $spectrum{sequence};
          $spectrum{sequence} =~ s/\[\d+\]//g;
          print STDERR "peptide $spectrum{sequence}\n" if $verbose;

          next;
        } elsif ( $line =~ /^MW:\s(.*)$/ ) { # line 2 is MW
          $spectrum{mw} = $1;
          next;
        } elsif ( $line =~ /^PrecursorMZ:\s(.*)$/ ) { # line 2 is MW
          $spectrum{PrecursorMZ} = $1;
          next;
        } elsif ( $line =~ /^Comment:/ ) { # line 3 is Comment:
          $spectrum{comment} = parseComment( comment_line => $line);
          next;
        } elsif ( $line =~ /^Num peaks:\s*(\d+)/ ||  $line =~ /^NumPeaks:\s*(\d+)/ ) { # Cache number of peaks
          $spectrum{num_peaks} = $1;
          $loop_peaks++;
          next;
        } elsif ( !$loop_peaks ) {
          next;
        }
        my %commentHash = %{$spectrum{comment}};

#    print "In commentHash!\n"; for my $k ( keys ( %commentHash ) ) { print "$k => $commentHash{$k}\n"; }

        my $sequence = $spectrum{sequence};
        my $mw = $spectrum{mw};
        my $charge = $spectrum{charge};
        my $num_peaks = $spectrum{num_peaks};
        my $modified_sequence = $spectrum{modified_sequence};

        if (exists $commentHash{Mods} && $modified_sequence eq $sequence )
        {
            $modified_sequence = getModSeq( seq => $sequence, 
                mods => $commentHash{Mods}
            );
        }

        $commentHash{'Spec'} ||= 'Single';
        my $consensus_spectrum_type_id = get_consensus_spectrum_type_id(
            consensus_spectrum_type_name => $commentHash{'Spec'}

        );

        my $protein = $commentHash{Protein};
        if ( length($protein) > 254 ) {
          print STDERR "Trimmed long protein name\n";
          $protein = substr( $protein, 0, 254 );
          print STDERR "protein was " . length(  $commentHash{Protein} ) . " but is now " . length( $protein ) . "\n";
        }

        # Triage for QQQ pseudo libs
        $commentHash{Mz_exact} ||= $spectrum{PrecursorMZ};

          print STDERR "Inserting peptide $spectrum{sequence}\n" if $verbose;
        my $consensus_library_spectrum_id = insert_consensus_library_spectrum(
            consensus_library_id => $consensus_library_id,
            consensus_spectrum_type_id => $consensus_spectrum_type_id,
            sequence => $sequence,
            modified_sequence => $modified_sequence,
            charge => $charge,
            modifications => $commentHash{Mods},
            protein_name => $protein, # commentHash{Protein},
            mz_exact => $commentHash{Mz_exact},
            precursor_intensity => $commentHash{PrecursorIntensity},
            scan_time => $commentHash{RetentionTime},
            nreps => $commentHash{Nreps},
            entry_idx => $spectrum{entry_idx}
        );

        ## insert comments
        insert_consensus_library_comments (
            comment_hash_ref => \%commentHash,
            consensus_library_spectrum_id => $consensus_library_spectrum_id,
        );

        ## loop over next num_peaks lines to get peaks and ions
        for (my $ii = 1; $ii < $num_peaks; $ii++) {
            $line = <INFILE>;

            # Not gonna store these peaks no mo!
            next;

            chomp($line);
            my ($m, $inten, $annot) = split("\t", $line, -1);

            # intensity is an int in db
            $inten = int( $inten );

            ## remove enclosing double quotes
            $annot =~ s/\"//g;

            my $label =""; ## unless overridden below
            my $chg = 1; ## unless overridden below

            ## xxxxxxx note this is only surface parsing of first ion labeled
            my @sannot = split( /\//, $annot, -1);
            my $ignore = 0;
            if (@sannot) {
                if ( $sannot[0] =~ /^(y|b|a)(.*)/ ) {
                    $label  = $1 . $2;
                    
                    ## won't use multiply charged ions eg: y^2^3
                    if ($label =~ /(.*)\^(.*)\^(.*)/)
                    {
#                      $chg = $2;
#                      $label = $1;
                       $ignore=1;
                    }
                    ## asterick means dubious peak, so removing it
                    if ( $label =~ s/\*//g)
                    {
                        $chg = 1;
                        $label = "";
                        $ignore=1;
                    }
                    if (($ignore ==0) && $label =~ /(.*)\^(.*)/)
                    {
                       $chg = $2;
                       $label = $1;
                       if ( $chg =~ /\di/ ) {
                         $chg = 1;
                         $label = "";
                         $ignore=1;
                       }
                    }
                } else {
                  $ignore++;
                }
            }
            next if $ignore;
              if ( length($annot) > 255 ) {
                $annot = substr( $annot, 0, 254 );
              }

            my %rowdata = (
                consensus_library_spectrum_id => $consensus_library_spectrum_id,
                mz => $m,
                relative_intensity => $inten,
                ion_label => $label,
                charge => $chg,
                peak_label => $annot,
            );

            $sbeams->updateOrInsertRow(
                table_name=>$TBAT_CONSENSUS_LIBRARY_SPECTRUM_PEAK,
                insert=>1,
                rowdata_ref=>\%rowdata,
                PK => 'consensus_library_spectrum_peak_id',
                return_PK=>0,
                add_audit_parameters => 0,
                verbose=>$VERBOSE,
                testonly=>$TESTONLY,
            );
        }
        $loop_peaks = 0;

        $count++;
				unless ( $count % 25 ) {
				  unless ( $count % 1000 ) {
						print "\n";
						print "Count is $count at " . time() . "\n";
					}
				}
				unless ( $count % $commit_interval ) {
					$sbeams->commit_transaction();
					$sbeams->initiate_transaction();
				}
      $idx = tell( INFILE );
    }
    $sbeams->commit_transaction();

    print "Read $count entries in library\n";
    close(INFILE) or die "ERROR: Unable to close $infile";

}


###############################################################################
#  getOrganismId
# @param organism_name - organism name (e.g. Yeast, Human, ...)
# @return organism_id
###############################################################################
sub getOrganismId
{
    my %args = @_;

    my $organism_name = $args{organism_name} || die "need organism_name";

    my $sql = qq~
        SELECT O.organism_id
        FROM $TB_ORGANISM O
        WHERE O.organism_name = '$organism_name'
        AND O.record_status != 'D'
    ~;

    my ($organism_id) = $sbeams->selectOneColumn($sql) or die
        "no organism id found with sql:\n$sql\n($!)";

    return $organism_id;
}

#######################################################################
# insert_consensus_library - insert parent record for an consensus library
#
# @param organism_id
# @return consensus_library_id
#######################################################################
sub insert_consensus_library
{
    my  %args = @_;

    my $METHOD='insert_consensus_library';

    my $organism_id = $args{organism_id} || die "need organsim_id";

    my $consensus_library_name = $args{consensus_library_name} || 
        die "need consensus_library_name";

    my $library_comment = $args{library_comment} || '';

    # private by default
    $args{project_id} ||= 476;

    my %rowdata = (
       organism_id => $organism_id,
       comment => $library_comment,
       consensus_library_name => $consensus_library_name,
       md5sum => $args{'md5sum'},
       file_path => $args{file_path},
       project_id => $args{project_id},
    );

    ## create a consensus_library record:
    my $consensus_library_id = $sbeams->updateOrInsertRow(
        table_name=>$TBAT_CONSENSUS_LIBRARY,
        insert=>1,
        rowdata_ref=>\%rowdata,
        PK => 'consensus_library_id',
        return_PK=>1,
        add_audit_parameters => 1,
        verbose=>$VERBOSE,
        testonly=>$TESTONLY,
    );

    print "INFO[$METHOD]: created consensus_library record $consensus_library_id\n";

    return $consensus_library_id;
}

#######################################################################
# insert_consensus_library_spectrum - insert a record for library spectrum
#
# @param consensus_library_id
# @param consensus_spectrum_type_id
# @param sequence 
# @param modified_sequence - not present if no mods
# @param charge 
# @param modifications - not present if no mods
# @param protein_name
# @param mz_exact
# @return consensus_library_spectrum_id
#######################################################################
sub insert_consensus_library_spectrum
{
    my  %args = @_;

    my $METHOD='insert_consensus_library_spectrum';


    # Removed protein_name from list of required params (DSC 2011-10).
    for my $arg ( qw( consensus_library_id consensus_spectrum_type_id sequence charge mz_exact ) ) {
      die "Missing required parameter $arg" unless $args{$arg};
    }

    my $consensus_library_spectrum_id = $sbeams->updateOrInsertRow(
        table_name=>$TBAT_CONSENSUS_LIBRARY_SPECTRUM,
        insert=>1,
        rowdata_ref=>\%args,
        PK => 'consensus_library_spectrum_id',
        return_PK=>1,
        add_audit_parameters => 0,
        verbose=>$VERBOSE,
        testonly=>$TESTONLY,
    );

    return $consensus_library_spectrum_id;
}


#######################################################################
# getModSeq - get a seq with modifcation string used in SBEAMS
# For example, if modification on C is Carbamidomethyl, we
# replace the location of C with C[160]
# @param seq - peptide amino acid sequence
# @param mods - the mods string from the comment field
# @return modSeq
#######################################################################
sub getModSeq
{
    my %args = @_;

    my $seq = $args{seq} || die "need seq";

    my $mods = $args{mods} || die "need mods";

    my $modSeq ='';

    ## Peptide modifications are given in the following format:
    ##    Mods=#/n,aa,tag/n,aa,tag
    ##
    ##    # is number of modifications with modifications separated
    ##        by a forward slash '/'.
    ##    mods are arranged in order of amino acid position, and if
    ##        multiple mods are arranged at a single position, they're
    ##        ordered alphabetically by a tag
    ##    n is the position of the substituted amino acid (starting from 0)
    ##    aa is the modified amino acid symbol
    ##    tag is the name of the modifications as given by Unimod (unimod.org)
    ##
    ## Only these mods have been used:
    ## { "Oxidation", 15.994915 },
    ## { "Carbamidomethyl ", 57.02146 },
    ## { "ICAT_light", 227.12 },
    ## { "ICAT_heavy", 236.12 },
    ## { "AB_old_ICATd0", 442.20 },
    ## { "AB_old_ICATd8", 450.20 },
    ## { "Acetyl", 42.0106 },
    ## { "Deamidation", 0.9840 },
    ## { "Pyro-cmC", -17.026549 },
    ## { "Pyro-glu", -17.026549 },
    ## { "Pyro_glu", -18.010565 },
    ## { "Amide", -0.984016 },
    ## { "Phospho", 79.9663},
    ## { "Methyl", 14.0157 },
    ## { "Carbamyl", 43.00581 },

    ## example: 2/3,C,Carbamidomethyl/16,C,Carbamidomethyl

    ## haven't yet accounted for them all below...

    my ($n, @loc, @aa, @modName);

    if ($mods =~ /(\d+)\/(.+?)/)
    {
        $n = $1;

        if ($mods =~ /(\d+)\/(.*)/)
        {
            my @strings = split("/", $2);

            for (my $si = 0; $si <= $#strings; $si++)
            {
                my ($l, $a, $m) = split(",",$strings[$si]);

                push(@loc, $l);

                push(@aa, $a);

                push(@modName, $m);
            }
        }
    }

    ## need to parse from bottom of loc stack to not be affected by
    ## expanding string while inserting mod strings
    for (my $i=$#loc; $i >=0; $i--)
    {
        ## if the the assert is always true, can remove this
        ## to speed it up
        my $check_aa = substr($seq, $loc[$i], 1);

        if ($check_aa eq $aa[$i])
        {
            my $seq_1 = $aa[$i]; ## seq to be replace with mod seq

            my $seq_0 = substr($seq, 0, $loc[$i]);

            my $seq_2 = substr($seq, $loc[$i] + 1, length($seq));

            ## only a few mods are present, when more, rplace this with mass hash
            ## look-ups and add modifications, round sum
            if ( $modName[$i] eq "Carbamidomethyl" && $aa[$i] eq "C")
            {
                $seq_1 = "C[160]";
            } elsif ( $modName[$i] eq "Oxidation" && $aa[$i] eq "M")
            {
                $seq_1 = "M[147]";
            } elsif ( $modName[$i] eq "ICAT_light" && $aa[$i] eq "C")
            {
                $seq_1 = "C[330]";
            } elsif ( $modName[$i] eq "ICAT_heavy" && $aa[$i] eq "C")
            {
                $seq_1 = "C[339]";
            } elsif ( $modName[$i] eq "AB_old_ICATd0" && $aa[$i] eq "C")
            {
                $seq_1 = "C[545]";
            } elsif ( $modName[$i] eq "AB_old_ICATd8" && $aa[$i] eq "C")
            {
                $seq_1 = "C[553]";
            } elsif ( $modName[$i] eq "Acetyl" && $aa[$i] eq "T")
            {
                $seq_1 = "T[143]";
            } elsif ( $modName[$i] eq "Acetyl" && $aa[$i] eq "M")
            {
                $seq_1 = "M[173]";
            } elsif ( $modName[$i] eq "Acetyl" && $aa[$i] eq "A")
            {
                $seq_1 = "A[113]"; 
            } elsif ( $modName[$i] eq "Acetyl" && $aa[$i] eq "C")
            {
                $seq_1 = "C[145]"; 
            } elsif ( $modName[$i] eq "Acetyl" && $aa[$i] eq "D")
            {
                $seq_1 = "D[157]"; 
            } elsif ( $modName[$i] eq "Acetyl" && $aa[$i] eq "E")
            {
                $seq_1 = "E[171]"; 
            } elsif ( $modName[$i] eq "Acetyl" && $aa[$i] eq "G")
            {
                $seq_1 = "G[99]"; 
            } elsif ( $modName[$i] eq "Acetyl" && $aa[$i] eq "L")
            {
                $seq_1 = "L[155]"; 
            } elsif ( $modName[$i] eq "Acetyl" && $aa[$i] eq "P")
            {
                $seq_1 = "P[139]"; 
            } elsif ( $modName[$i] eq "Acetyl" && $aa[$i] eq "S")
            {
                $seq_1 = "S[129]"; 
            } elsif ( $modName[$i] eq "Acetyl" && $aa[$i] eq "T")
            {
                $seq_1 = "T[143]"; 
            } elsif ( $modName[$i] eq "Acetyl" && $aa[$i] eq "V")
            {
                $seq_1 = "V[141]"; 
            } else
            {
                print "[WARNING] didn't code for this modification: "
                    . "$modName[$i] for sequence $seq\n";
            }

            $modSeq = $seq_0 . $seq_1 . $seq_2;
        }
    }

    ## some of these unimod terms apply to more than one site, so not
    ## sure if only top site was used...assuming so for now, but need
    ## to alter if mod amino acide doesn't match first letter here

    ## Acetyl in only 8 entries in yeast.msp, and mod is on M and T
    ##     so should be M[173] or T[143]
    ## Deamidation not in yeast.msp
    ## Pyro-cmC not in yeast.msp
    ## Pyro-glu not in yeast.msp
    ## Amide not in yeast.msp
    ## Phospo not in yeast.msp
    ## Methyl not in yeast.msp
    ## Carbamyl not in yeast.msp

    return $modSeq;
}

#######################################################################
#  parseComment - parse comment line to get select key values pairs
#
# @return %commentHash
#######################################################################
sub parseComment
{
    my %args = @_;

    my $line = $args{comment_line} || die "need comment_line";

    my %hash =();

    if ($line =~ /.*(Spec)=(\D+?)\s.*/)
    {
        $hash{$1} = $2;
    }

#   if ($line =~ /^(Comments:\s)(\w+)\s.*/)
#   {
#       $hash{'Spec'} = $2;
#   }

#   if ($line =~ /.*(Inst)=(\D+?)\s.*/)
#   {
#       $hash{$1} = $2;
#   }

    if ($line =~ /.*(Fullname)=(.+?)\s.*/) {
        $hash{$1} = $2;
    }

    ## only storing Mods if not equal to 0
    ## Mods=1/17,C,ICAT_light
    if ($line =~ /.*(Mods)=(.+?)\s.*/) {
      my $k = $1;
      my $v = $2;
      if ( $v ) {
        if ( length($v) > 255 ) {
          $hash{$k} = substr( $v, 0, 254 );
          print STDERR "Trimmed a long modstring!\n";
        } else {
          $hash{$k} = $v;
        }
      }
    }

#   if ($line =~ /.*(Mz_exact)=(.+?)\s.*/)
#   {
#       $hash{$1} = $2;
#   }
    if ($line =~ /.*(Parent)=(.+?)\s.*/) {
        $hash{'Mz_exact'} = $2;
    }

    if ($line =~ /.*(Protein)=(.+?)\s.*/)
    {
        ## remove double quotes from ends
        my $k = $1;
        my $v = $2;
        $v =~ s/\"//g;
        $hash{$k} = $v;
    }

    if ($line =~ /.*(Sample)=(.+?)\s.*/)
    {
        $hash{$1} = $2;
    }

#   if ($line =~ /.*(Dotbest)=(.+?)\s.*/)
#   {
#       $hash{$1} = $2;
#   }
#   if ($line =~ /.*(Dottheory)=(.+?)\s.*/)
#   {
#       $hash{$1} = $2;
#   }
#   if ($line =~ /.*(Probcorr)=(.+?)\s.*/)
#   {
#       $hash{$1} = $2;
#   }
    if ($line =~ /.*(Dotfull)=(.+?)\s.*/)
    {
        $hash{$1} = $2;
    }
    if ($line =~ /.*(Dot_cons)=(.+?)\s.*/)
    {
        $hash{$1} = $2;
    }
    if ($line =~ /.*(Dotrev_consens)=(.+?)\s.*/)
    {
        $hash{$1} = $2;
    }

    if ($line =~ /.*(Suspect)=(.+?)\s.*/)
    {
        $hash{$1} = $2;
    }
    if ($line =~ /.*(Look)=(.+?)\s.*/)
    {
        $hash{$1} = $2;
    }
    if ($line =~ /.*(Isgood)=(.+?)\s.*/)
    {
        $hash{$1} = $2;
    }

#   ## Specqual is the last entry in comment field:
#   if ($line =~ /.*(Specqual)=(.*)/)
#   {
#       $hash{$1} = $2;
#   }
    if ($line =~ /.*(Unassigned)=(.+?)\s.*/)
    {
        $hash{$1} = $2;
    }

    # Fetch RT, pIntensity, Nreps
    if ($line =~ /(PrecursorIntensity)=(\S+)\s/) {
      $hash{$1} = $2;
    }
    if ($line =~ /(RetentionTime)=(\S+)\s/) {
      my $rt_string = $2;
      my @rt = split( ",", $rt_string, -1 );
      $hash{$1} = $rt[0];
    }
    if ($line =~ /.*(Nreps)=(\S+)\s.*/) {
      my $reps = $2;
      my @reps = split( /\//, $reps, -1 );
      $hash{$1} = $reps[0];
    }
#    for my $k ( keys( %hash ) ) { print "$k => $hash{$k}\n"; }

    ## make a modified sequence hash
    return \%hash;
}


#######################################################################
# get_consensus_spectrum_type_id -- get consensus spectrumtype id, given 
#  name of spectrum type
#
# @param consensus_spectrum_type_name
# @return consensus_spectrum_type_id
#######################################################################
sub get_consensus_spectrum_type_id
{
    my %args = @_;

    my $consensus_spectrum_type_name = $args{consensus_spectrum_type_name}
      || die "need consensus_spectrum_type_name";

    my $sql = qq~
        SELECT consensus_spectrum_type_id
        FROM $TBAT_CONSENSUS_SPECTRUM_TYPE
        WHERE consensus_spectrum_type_name = '$consensus_spectrum_type_name'
    ~;

    my ($consensus_spectrum_type_id) = $sbeams->selectOneColumn($sql) or die
        "no consensus_spectrum_type_id found with sql:\n$sql\n($!)";

    return $consensus_spectrum_type_id;
}

#######################################################################
# removeConsensusLibrary - remove parent record and children
# @param consensus_library_spectrum_id
#######################################################################
sub removeConsensusLibrary {

  my %args = @_;

  unless ( $args{consensus_library_id} ) {
    die "Missing required option consensus_library_id";
  }

  print "lib id string is $args{consensus_library_id}\n";
  $args{consensus_library_id} =~ s/\s//g;

  for my $id ( split( ',', $args{consensus_library_id} ) ) {
    if ( $id !~ /^\d+$/ ) {
      die "illegal ID: $id\n";
    }
    print "Deleting library: ";
    printBuildList( $id );
    print "\n";

    my %table_child_relationship = (
      consensus_library => 'consensus_library_spectrum(C)',
      consensus_library_spectrum => 'consensus_library_spectrum_peak(C),consensus_library_spectrum_comment(PKLC)',
      );

    my $result = $sbeams->deleteRecordsAndChildren(
      table_name => 'consensus_library',
      table_child_relationship => \%table_child_relationship,
      delete_PKs => [ $id ],
      delete_batch => 1000,
      verbose => $VERBOSE,
      database => $DBPREFIX{PeptideAtlas},
      testonly => $TESTONLY,
    );
    $result = ' success' if $result;
    $result ||= ' failure';
    print "$result\n\n";
  }
  exit;
}


#######################################################################
# insert_consensus_library_comments
#
# @param consensus_library_spectrum_id
# @param reference to hash with comment key,value pairs
#######################################################################
sub insert_consensus_library_comments
{
    my %args = @_;

    my $comment_hash_ref = $args{comment_hash_ref} || die 
        "need comment_hash_ref";

#    my %hash = %{$comment_hash_ref};

    my $consensus_library_spectrum_id = $args{consensus_library_spectrum_id} ||
        die "need consensus_library_spectrum_id";

    my %rowdata;

    $rowdata{consensus_library_spectrum_id} = $consensus_library_spectrum_id;

#   foreach my $key (qw/ Inst Sample Dotbest Dottheory Probcorr Specqual Unassigned Fullname /)
    foreach my $key (qw/ Sample Dotfull Dot_cons Dotrev_consens Suspect Look Isgood Unassigned Fullname /) {

        next unless defined $comment_hash_ref->{$key};
        $rowdata{parameter_key} = $key;

        if ( length($comment_hash_ref->{$key}) > 1023 ) {
          print STDERR "Trimmed long param_value for param_key: $key\n";
          $rowdata{parameter_value} = substr( $comment_hash_ref->{$key}, 0, 1023 );
          print STDERR "param_val was " . length(  $comment_hash_ref->{$key} ) . " but is now " . length( $rowdata{parameter_value} ) . "\n";
        } else {
          $rowdata{parameter_value} = $comment_hash_ref->{$key};
				}

        $sbeams->updateOrInsertRow(
            table_name=>$TBAT_CONSENSUS_LIBRARY_SPECTRUM_COMMENT,
            insert=>1,
            rowdata_ref=>\%rowdata,
            PK => 'consensus_library_spectrum_comment_id',
            return_PK=>0,
            add_audit_parameters => 0,
            verbose=>$VERBOSE,
            testonly=>$TESTONLY,
        );
    }
}

sub printBuildList {
  my $id = shift;
  my $sql = "SELECT consensus_library_name, consensus_library_id FROM $TBAT_CONSENSUS_LIBRARY ";
  if ( $id ) {
    $sql .= " WHERE consensus_library_id = $id ";
  }
  $sql .= " ORDER BY consensus_library_id ASC";

  my $sth = $sbeams->get_statement_handle( $sql );
  while( my @row = $sth->fetchrow_array() ) {
    if ( $id ) {
      print "$row[0] ($row[1]}";
    } else {
      print join( "\t", @row ) . "\n";
    }
  }
}

__DATA__
my $sbeams = SBEAMS::Connection->new();
#$sbeams->output_mode( 'interactive' );
  $sbeams->Authenticate();
  my $ac = $sbeams->isAutoCommit();
  my $re = $sbeams->isRaiseError();
  $sbeams->initiate_transaction();
  $sbeams->rollback_transaction();
  $sbeams->commit_transaction();
  $sbeams->setAutoCommit( $ac );
  $sbeams->setRaiseError( $re );
