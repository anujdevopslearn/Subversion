#!/usr/bin/env perl
# This program needs to be commented.
use lib "$ENV{ 'ALCYT' }/lib"; # get the location of the Alcyt package
use Text::Wrap;
use Alcyt;

# check the command line for appropriate switches
if ( $#ARGV < 1 ) {
    usage();
}

# Default values 
$outsuffix = ".afcs";  # suffix for ascii file
$head   = 0;  # default is not to show header
$pwp    = 0;  # This is actually determined from the header.
$flsp   = 0;
$plsp   = 0;
$wavep  = 0;
$specp  = 0;
$bluep  = 0;
$greenp = 0;
$redp   = 0;
$rate   = 0;  # default to not computing the event rate

for ($i = 0; $i <= $#ARGV; $i++) {
    if ($ARGV[$i] eq '-f') {
        $i++;
        $infile = $ARGV[$i];
    }
    elsif ($ARGV[$i] eq '-outsuf') {
        $i++;
        $outsuffix = $ARGV[$i];
    }
    elsif ($ARGV[$i] eq '-head') {
        $head = 1;
    }
    elsif ($ARGV[$i] eq '-wa') {
        $i++;
        $wavep = $ARGV[$i];
    }
    elsif ($ARGV[$i] eq '-sp') {
        $i++;
        $specp = $ARGV[$i];
    }
    elsif ($ARGV[$i] eq '-fl') {
        $i++;
        $flsp = $ARGV[$i];
    }
    elsif ($ARGV[$i] eq '-pw') {
        $i++;
        $pwp = $ARGV[$i];
    }
    elsif ($ARGV[$i] eq '-pl') {
        $i++;
        $plsp = $ARGV[$i];
    }
    elsif ($ARGV[$i] eq '-bl') {
        $i++;
        $bluep= $ARGV[$i];
    }
    elsif ($ARGV[$i] eq '-gr') {
        $i++;
        $greenp = $ARGV[$i];
    }
    elsif ($ARGV[$i] eq '-re') {
        $i++;
        $redp = $ARGV[$i];
    }
    elsif ($ARGV[$i] eq '-rate') {
        $rate = 1;
    }
    else {
	print "mkstd.pl: Unrecognized command-line option: $ARGV[$i]\n";
        usage();
    }
}

# Read in the header to determine where the text and data sections are in
# in the file.
@header = read_fcs_header($infile);
if (($header[0] ne 'FCS2.0') && ($header[0] ne 'FCS3.0')) {
    die "fcs2ascii.pl: File $infile does not appear to be an FCS file.\n";
}

# Strip out all of the keyword-value pairs.
@field  = get_fcs_keywords($infile,@header);
@keys   = get_fcs_keys(@field);
@values = get_fcs_keyvalues(@field);

$num_events = get_num_events(@field);

# If the command-line option -head is set, just dump the text part of the
# file to the screen.
if ($head == 1) {
    for ($i = 0  ; $i <= ($#keys) ; $i++) {
#	print" $keys[$i]\t\t$values[$i]\n";
	getc;
    }
    die "Number of events: $num_events\n";
}

# Generate the root filename  
if ($infile =~ /(\w+).fcs/) { 
    $outfile = "$1.afcs";
} else {
    die "mkstd.pl: $infile does not have .fcs extension, cannot generate root filename.\n";
}
$outfile = "./test.afcs";
# Write the header part of the output file.
print "Converting $infile to $outfile. \n";

open(OUTFILE,">$outfile") or die "fcs2ascii.pl: Can't open $outfile for writing.\n";

# Dump out the basic header parameters which describe the location of the
# data.
printf OUTFILE ("# %8s%9s%9s%9s%9s%9s%9s\n",$header[0],$header[1],$header[2],$header[3],$header[4],$header[5],$header[6]);

# Write the header parameters to the output file.
# Also add the standard column headings.
for ($i = 0; $i <= $#keys ; $i++) {
    print OUTFILE "\# $keys[$i]\t\t$values[$i]\n";
    if ($field[$i] eq '$TOT') {
	$num_events = $field[$i+1];
	print "Number of events: $num_events\n";
    }
}
print OUTFILE "################################################################################################\n";
print OUTFILE "# Event No.     time     rate   cls   cts   lut   pw    fls   pls   wave  spec  blue  grn   red \n";
print OUTFILE "#   (0)          (1)      (2)   (3)   (4)   (5)   (6)  (7)   (8)    (9)  (10)  (11)  (12)  (13) \n";
print OUTFILE "################################################################################################\n";
close(OUTFILE);

# Extract as much information as we can automatically from the header.
# Each element in this array contains the number of the corresponding 
# parameter in the input file.  These are supplied by the user on the
# command-line with the default value being 0.  For example, if in the
# input .fcs file, the forward-scatter measurement was parameter 4,
# we would have $flsp = 4.
# Time is measured by the cytometer electronics
# and the rate is a computed parameter.  Currently, the event rate is not
# determined, but in this capability could be added later so we add a place
# holding column.  Also, we currently support only three colors, but this
# could be expanded in the future.
$num_par =  get_num_pars(@field);
%inpars = ();
($inpars{timelow},$inpars{timehigh}) = get_time_par(@field);
$inpars{lut}      = get_lut_par(@field);
$inpars{cls}      = get_cls_par(@field);
$inpars{cts}      = get_cts_par(@field);
$inpars{pw}       = get_pw_par(@field); 
$inpars{fls}      = $flsp;
$inpars{pls}      = $plsp;
$inpars{wave}     = $wavep;
$inpars{spec}     = $specp;
$inpars{blue}     = $bluep;
$inpars{green}    = $greenp;
$inpars{red}      = $redp;

dump_data2($infile,$outfile,$header[3],2,$num_par,$num_events,%inpars);

# Compute the event rate and add it to the output file if specified.
if ($rate == 1) {
    print "mkstd.pl: Computing event rate.\n";
    compute_rate($outfile);
} else {
    print "mkstd.pl: Not computing event rate.\n";
}

sub usage {
# This subroutine prints out some useful usage info if the number or type of
# command line switches is incorrect.

    $Text::Wrap::columns = 80; $pre1=""; $pre2="";
print wrap($pre1,$pre2, 
"
USAGE: mkstd.pl -f <input .fcs file> [-outsuf <suffix for output file>] 
[-head] [-wa <wavelength param. number>] [-sp <spectrograph parm. number>]
[-fl <forward scatter param. number>] [-pl <perp. scatter param. number>]
[-pw <pulse width param number>] [-bl <blue parm. number>]
[-gr <green param number>] [-re <red param number>]

This program converts an FCS file to an ASCII list.  The resulting
file is optimized for up to three flourescent colors, forward and
perpendicular scatter, as well as a wavelength and spectral intensity
channels.  Parameters not assigned on of the standard designations are
appended as additional columns.

\n");
    die "Exiting mkstd.pl\n\n";
}
