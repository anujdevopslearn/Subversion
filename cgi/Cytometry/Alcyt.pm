package    Alcyt;

require Exporter;

@ISA = (Exporter);

# list of subroutines to be exported so that they can be used in other places
@EXPORT = qw( get_fcs_key_value_hash_from_file read_fcs_header get_fcs_delimiter get_fcs_keywords get_fcs_keys get_fcs_keyvalues read_fcs_text compute_rate get_num_events get_num_pars get_pw_par get_lut_par get_time_par get_cls_par get_cts_par get_first_time dump_data dump_data2 dump_data3 dump_data_bc tobinary power_of_2 get_fcs_key_value_hash );


###############################################################################
# USAGE: @headerinfo = read_fcs_header(<FCS file>)
# This routine reads the first line of the header to figure out where 
# the text and data sections are located.
sub read_fcs_header {

    my $infile = $_[0];
    open(FCSFILE,"$infile") or die "read_fcs_header: Can't find input file $infile.";
    
    read(FCSFILE,$headerinfo[0],6); # version of .fcs standard
    read(FCSFILE,$foo,4);           # junk
    read(FCSFILE,$headerinfo[1],8); # offset to beginning of text section
    read(FCSFILE,$headerinfo[2],8); # offset to end of text section
    read(FCSFILE,$headerinfo[3],8); # offset to beginning of data section
    read(FCSFILE,$headerinfo[4],8); # offset to end of data section
    read(FCSFILE,$headerinfo[5],8); # offset to beginning of analysis section
    read(FCSFILE,$headerinfo[6],8); # offset to end of analysis section
    
    close(FCSFILE);
    return(@headerinfo);
}

###############################################################################
# USAGE: $delimiter = get_fcs_delimiter(<FCS file>,<header info array>)
# This routine takes an input file and the array returned by 
# "read_fcs_header" and extracts the character used as the delimiter.
sub get_fcs_delimiter {
    
    my $infile = shift(@_);
    my @headerinfo = @_;
    my $dummy = "";
    $delimiter = "";
    my $pre_text = $headerinfo[1];

    open(FCSFILE,"$infile") or die "get_fcs_delimiter: Can't find input file $infile.";
    
    
    read(FCSFILE,$dummy,$pre_text);   # read the section before the text
    read(FCSFILE,$delimiter,1);       # get the delimiter character
    return($delimiter);
    close(FCSFILE);

}
###############################################################################
# USAGE: $textstring = read_fcs_text(<filename>,<offset to text section>,
# <end text section>)
# Read the text section (which contains the keyword-value pairs) for 
# the given file.  The section is returned as a single string which must be
# parsed with some additional routine such as get_fcs_keywords.
sub read_fcs_text {
    my $infile = $_[0]; # file to read
    my $begin  = $_[1]; # offset to beginning of text section
    my $end    = $_[2]; # end of text section
     
    my $dummy = "";
    my $pre_text = $begin + 1;    # number of bytes to read before text
                                  # The "+1" arises because the delimiter
                                  # is the first character in the text section.
    my $size_of_text = $end - $begin; # size of text section

    open(FCSFILE,"$infile") or die "read_fcs_text: Can't find input file $infile.";
     read(FCSFILE,$dummy,$pre_text);   # read the section before the text
    read(FCSFILE,$text,$size_of_text);


    return($text);
    close(FCSFILE);
}


###############################################################################
# USAGE: @keyword_array = get_fcs_keywords(<FCS file>,<@header_info_array>)
# Generates an array containing the keyword/value pairs.  Even indices
# starting at 0, contain keywords, odd indices contain values.
# The header array must be supplied.
sub get_fcs_keywords {

    my $infile     = shift(@_);
    my @headerinfo = @_;

    # Get the delimiter.
    $raw_delimiter = get_fcs_delimiter($infile,@headerinfo);

    # Read in the text part of the header into a scalar value.
    my $text = read_fcs_text($infile,$headerinfo[1],$headerinfo[2]); 

    # I ran into some trouble here when Juno switched the delimiter to
    # "|" from ":".  I could not seem to figure out a slick way to deal
    # with this so we use an "if" here.  A perl expert would probably be
    # able to figure out how to do this properly.

    if ($raw_delimiter eq "|") {
	$delim = "\\$raw_delimiter";  # Notes the double \\ trick.
    } else {
	$delim = "$raw_delimiter";
    }


    # In a standard FCS file, the delimiter character may appear within
    # a keyword as long as it appears twice.  We check for this case so that
    # it can be carefully dealt with.
    if ($text !~ /$delim$delim/) {
	@keywords = split("$delim",$text);
	#@keywords = split(/\$delimiter/,$text);
    } else {
	print "get_fcs_keywords: Trouble.  This file seems to have a comment field with two adjacent delimiters ($delim$delim).  I'm confused.  \n";
    }
    return(@keywords);
}

###############################################################################
# USAGE: @keys = get_fcs_keys(<@keyword_value_array>)
# This subroutine takes an array of keyword value pairs generated by
# "get_fcs_keywords" and returns an array containing just the keywords.
sub get_fcs_keys {

    my @keywords = @_;
    $j = 0;
    for ($i = 0 ; $i <= $#keywords - 1 ; $i+=2) {
	$keys[$j] = $keywords[$i];
	$j++
    }
    return(@keys);
}

###############################################################################
# USAGE: %keys = get_fcs_keys(<@keyword_value_array>)
# This subroutine takes an array of keyword value pairs generated by
# "get_fcs_keywords" and returns a hash of key-value pairs.
sub get_fcs_key_value_hash 
{
	my @keywords = @_;
	my %keyValue = {};
     for ($i = 0 ; $i <= scalar(@keywords)-1 ; $i+=2) 
	 {
		 $keyValue{$keywords[$i]} = $keywords[$i+1];
	 }
    return(%keyValue);
}

###############################################################################

# USAGE: %keys = get_fcs_keys(<@keyword_value_array>)
# This subroutine takes a .fcs file  and returns a hash of key-value pairs.
sub get_fcs_key_value_hash_from_file 
{
  my $file = shift;
  my @headerInfo = read_fcs_header ($file);
	my @keywords = get_fcs_keywords($file, @headerInfo);
	my %keyValue = {};
     for ($i = 0 ; $i <= scalar(@keywords)-1 ; $i+=2) 
	 {
		 $keyValue{$keywords[$i]} = $keywords[$i+1];
	 }
    return(%keyValue);
}

################################################################

# USAGE: @values = get_fcs_keyvalues(<@keyword_value_array>)
# This subroutine takes an array of keyword value pairs generated by
# "get_fcs_keywords" and returns an array containing just the keywords.
sub get_fcs_keyvalues {

    my @keywords = @_;
    $j = 0;
    for ($i = 1 ; $i <= $#keywords ; $i+=2) {
	$values[$j] = $keywords[$i];
	$j++;
    }
    return(@values);
}



###############################################################################
# USAGE: $number_params = get_num_pars(<@keyword_array>)
# Determines the number of parameters in the input file.
sub get_num_pars {

    my @keyword = @_;

    for ($i = 0; $i <= ($#keyword - 1) ; $i+=2) {
	if ($keyword[$i] eq "\$PAR") {
	    $num_par = $keyword[$i+1];
	    last;
	}
    }
    return($num_par);

}

###############################################################################
# USAGE: $number_events = get_num_events(<@keyword_array>)
# Determines the number of events in the input file.
sub get_num_events {

    my @keyword = @_;

    for ($i = 0; $i <= ($#keyword - 1) ; $i+=2) {
	if ($keyword[$i] eq "\$TOT") {
	    $num_event = $keyword[$i+1];
	    last;
	}
    }
    return($num_event);

}

###############################################################################
# USAGE: $pulse_width_col = get_pw_par(<@keyword_array>)
# Determine which column contains the pulse width parameter
sub get_pw_par {

    my @keyword = @_;
    $plsnum = "";

    for ($i = 0; $i <= ($#keyword -1) ; $i+=2) {
	if ($keyword[$i+1] eq "pulse width") {
	    if ($keyword[$i] =~ /\$P(\d+)N/) {
		$plsnum = $1;
	    }
	    last;
	}
    }
    if ($plsnum eq "") {
	print "<br><b>No pulse width factor.\n";
	print "Error:  Something is wrong, thisf actor should exist.\n </b><br>";
    }
    return($plsnum);
}


###############################################################################
# USAGE: $lut_number_col = get_lut_par(<@keyword_array>)
# Determine which column contains the LUT DECISIONS parameter
sub get_lut_par {

    my @keyword = @_;
    $lutnum = "";

    for ($i = 0; $i <= ($#keyword -1) ; $i+=2) {
	if ($keyword[$i+1] eq "LUT DECISIONS") {
	    if ($keyword[$i] =~ /\$P(\d+)N/) {
		$lutnum = $1;
	    }
	    last;
	}
    }
    if ($lutnum eq "") {
	print "No LUT Decision factor<br>";
    }
    return($lutnum);
}

###############################################################################
# USAGE: @time_cols = get_time_par(<@keyword_array>)
# Determine which columns contains the timing parameters
sub get_time_par {

    my @keyword = @_;
    $time1num = "";
    $time2num = "";

    for ($i = 0; $i <= ($#keyword -1) ; $i+=2) {
	if ($keyword[$i+1] eq "ADC11") {
	    if ($keyword[$i] =~ /\$P(\d+)N/) {
		$timepar[0] = $1;
	    }
	} elsif  ($keyword[$i+1] eq "ADC12") {
	    if ($keyword[$i] =~ /\$P(\d+)N/) {
		$timepar[1] = $1;
	    }
	}
    }
    if ($timepar[0] eq "") {
	print "mkstd.pl: TPAR1 parameter not found.\n";
    }
    if ($timepar[1] eq "") {
	print "mkstd.pl: TPAR2 parameter not found.\n";
    }
    
    return(@timepar);
}

###############################################################################
# Determine which column contains the CLASS DECISIONS parameter
# USAGE: $cls_par_col = get_cls_par(<@keyword_array>)
sub get_cls_par {

    my @keyword = @_;
    $clsnum = "";

    for ($i = 0; $i <= ($#keyword -1) ; $i+=2) {
	if ($keyword[$i+1] eq "CLASS DECISIONS") {
	    if ($keyword[$i] =~ /\$P(\d+)N/) {
		$clsnum = $1;
	    }
	    last;
	}
    }
    if ($clsnum eq "") {
	print "No Class decision factor<br>";
    }
    return($clsnum);
}
###############################################################################
# Determine which column contains the COUNTER parameter
# USAGE: $cts_par_col = get_cts_par(<@keyword_array>)
sub get_cts_par {

    my @keyword = @_;
    $ctsnum = "";

    for ($i = 0; $i <= ($#keyword -1) ; $i+=2) {
	if ($keyword[$i+1] eq "COUNTER") {
	    if ($keyword[$i] =~ /\$P(\d+)N/) {
		$ctsnum = $1;
	    }
	    last;
	}
    }
    if ($ctsnum eq "") {
		print  "No Count factor<br></td>";
    }
    return($ctsnum);
}

###############################################################################
# This routine finds the earliest time in a .afcs file.  It assumes that it
# is in the standard format as defined by "mkstd.pl".
sub get_first_time {
    my $infile = $_[0]; # input file
    
    open(INFILE,"$infile") or die "Alcyt.pl::get_first_time: Can't find input file $infile.\n";    
    while(<INFILE>) {
	if ($_ !~ /^\#/) {
	    @data = split ' ',$_;
	    $first_time = $data[1];
	    last;
	}
    }
    close(INFILE);
    
    return($first_time);
}
    


###############################################################################
# This routine takes a .afcs file and comptues the event rate based on the
# machine clock data listed in the data file.  It is designed to be used
# by "mkstd.pl" and is unlikely to be used directly.
sub compute_rate {
    my $infile = $_[0];
    my $clocks_per_second = 10;   # cytometer clocks / second
                                  # This has not been carefully calibrated
                                  # or verified.  For Influx only.

    # Get the earliest time in the .afcs file
    my $start_time = get_first_time($infile);
    print "$start_time\n";
    $n = 0;
    $rate = 0;

    open(OUTFILE,">MKSTDTMP.afcs") or die "Can't create MKSTDTMP.afcs.";
    open(INFILE,"$infile") or die "Alcyt.pl::mkstd.pl: Can't find input file $infile.\n";
    
    while(<INFILE>) {
	if (/^\#/) {
	    print OUTFILE "$_"; # pass comments through
	} else {
	    $n++;   # one more event
	    # The first two elements in the file are the event number and time.
	    ($event[$n],$time) = split ' ',$_;
	    
	    # Grab the rest of the data except for the rate column.
	    $end_data[$n] = substr($_,30);
	    
	    # Are we at the next time point yet?
	    if ($time >= $start_time + $clocks_per_second) {

		# Compute the rate ( in events per second ).
		$rate = ($n - 1) ;

		# Print out the data and the rate to the output file.
		for ($i = 1; $i<= ($n - 1); $i++) {
		    printf OUTFILE ("%12d%12d%6d",$event[$i],$start_time,$rate);
		    print OUTFILE "$end_data[$i]";
		}
		$start_time = $time;  # update the current time
		$event[1] = $event[$n]; # 1st even of new time period
		$end_data[1] = $end_data[$n]; # update rest of data
		$n = 1;                 # reset the event count
	    }
	}
    }
    # Take care of the last section of data.
    $rate = $n;
    for ($i = 1  ; $i <= $n ; $i++) {
	printf OUTFILE ("%12d%12d%6d",$event[$i],$time,$rate);
	print OUTFILE "$end_data[$i]";
    }
    
    close(INFILE);
    close(OUTFILE);
    
    rename("MKSTDTMP.afcs",$infile);
}

###############################################################################
# needs comments
sub dump_data {

    $infile   = shift(@_);
    $outfile  = shift(@_);
    $offset   = shift(@_);
    $size     = shift(@_); # not used
    $n_params = shift(@_);
    $n_events = shift(@_);
    %incol    = @_;    # This hash contains the column assignments for the
                       # parameters in the input datafile.  See the main
                       # code for details.

    # Next, we deal with any parameters which are not amoung the "standard
    # set".  There is probably a slicker way to do this but I don't have
    # time to think about it right now.

    # Define an array which contains the indices of all parameters.
    for ($i = 1; $i <= $n_params; $i++) {
	$cols[$i] = $i;
    }

    while (($key,$value) = each %incol) {
	$cols[$value] = 0;
    }  

    $j = 0;
    for ($i = 1; $i <= $n_params; $i++) {
	if ($cols[$i] != 0) {
	    $unnamed[$j] = $cols[$i];
	    $j++;
	}
    }

    open(OUTFILE,">>$outfile") or die "dump_data: Can't open $outfile for appending.\n";
    open(FCSFILE,"$infile") or die "dump_data: Can't find input file $infile.";

    # Throw away all of the bits up to the data part of the file.
    $pre_text = $offset;
    $dummy = "";
    read(FCSFILE,$dummy,$offset);

    # Initialize the event array.
    @event = ();

    # Read in all of the data into a 2-d array.
    for ($event_num = 1 ; $event_num <= $n_events; $event_num++) {
	for ($param = 1; $param <= $n_params; $param++) {

	    # This assumes a 16 bit data word.  Not the best way to do this.
	    read(FCSFILE,$data,2);
	    $event[$event_num][$param] = unpack("S",$data);
	}

	# Compute the time from the two 12-bit values.  Subtract off the
	# time of the earliest event in the file.
	$time[$event_num] = ( $event[$event_num][$incol{timelow}] - $event[1][$incol{timelow}]) + 4096 * ($event[$event_num][$incol{timehigh}] -  $event[1][$incol{timehigh}] ); 
    }

    # Dump all of the data to the output file.
    for ($event_num = 1 ; $event_num <= $n_events; $event_num++) {
	printf OUTFILE ("%12d",$event_num);
	printf OUTFILE ("%12d",$time[$event_num]);
	printf OUTFILE ("%6d",0); # rate, computed with other code
	printf OUTFILE ("%6d",$event[$event_num][$incol{lut}]);
	printf OUTFILE ("%6d",$event[$event_num][$incol{cls}]);
	printf OUTFILE ("%6d",$event[$event_num][$incol{cts}]);
	printf OUTFILE ("%6d",$event[$event_num][$incol{pw}]);
	printf OUTFILE ("%6d",$event[$event_num][$incol{fls}]);
	printf OUTFILE ("%6d",$event[$event_num][$incol{pls}]);
	printf OUTFILE ("%6d",$event[$event_num][$incol{wave}]);
	printf OUTFILE ("%6d",$event[$event_num][$incol{spec}]);
	printf OUTFILE ("%6d",$event[$event_num][$incol{blue}]);
	printf OUTFILE ("%6d",$event[$event_num][$incol{green}]);
	printf OUTFILE ("%6d",$event[$event_num][$incol{red}]);
	
	# Now, output all the non-standard parameters.
	for ($i = 0; $i <= $#unnamed; $i++) {
	    printf OUTFILE ("%6d",$event[$event_num][$unnamed[$i]]);
	}
	printf  OUTFILE ("\n");
    }

    close(FCSFILE);
    close(OUTFILE);

}
###############################################################################
# This is an updated version of the "dump_data" routine coded above.  The
# main difference is that this version does not load all of the data into 
# a 2-D array and therefore is significantly faster and uses far less
# memory.  This makes a big difference for large (~1,000,000 event) files.
# On a file of 535745 events, mkstd.pl using "dump_data" took 4:28 on
# diercks3, and consumed all of the available memory, making things very slow.
# Using dump_data2, the same file conversion took 1:45.
=comment
sub dump_data2 {

    $infile   = shift(@_);
    $outfile  = shift(@_);
    $offset   = shift(@_);
    $size     = shift(@_); # not used
    $n_params = shift(@_);
    $n_events = shift(@_);
    %incol    = @_; # This hash contains the column assignments for the
                    # parameters in the input datafile.  See the main
                    # code for details.

    # Next, we deal with any parameters which are not amoung the "standard
    # set".  There is probably a slicker way to do this but I don't have
    # time to think about it right now.

    # Define an array which contains the indices of all parameters.
    for ($i = 1; $i <= $n_params; $i++) {
	$cols[$i] = $i;
    }

    while (($key,$value) = each %incol) {
	$cols[$value] = 0;
    }  

    $j = 0;
    for ($i = 1; $i <= $n_params; $i++) {
	if ($cols[$i] != 0) {
	    $unnamed[$j] = $cols[$i];
	    $j++;
	}
    }

    open(OUTFILE,">>$outfile") or die "dump_data: Can't open $outfile for appending.\n";
    open(FCSFILE,"$infile") or die "dump_data: Can't find input file $infile.";

    # Throw away all of the bits up to the data part of the file.
    $pre_text = $offset;
    $dummy = "";
    read(FCSFILE,$dummy,$offset);

    # Initialize the event array.
    @firstevent = ();

    # Read the first event in order to get the starting time.
    for ($param = 1; $param <= $n_params; $param++) {
	read(FCSFILE,$data,2);
	$firstevent[$param] = unpack("S",$data);
    }
    $time0 = ( $firstevent[$incol{timelow}]) + 4096 * ($firstevent[$incol{timehigh}] ); 
    close(FCSFILE); # For ease of understanding the code and to avoid
                    # duplicating code, we close the file, then re-open
                    # it and read in the first event again along with the
                    # rest of the data.

    # Read in the data, sort it out into the correct columns, and dump
    # it to the output file.
    open(FCSFILE,"$infile") or die "dump_data2: Can't find input file $infile.";
    read(FCSFILE,$dummy,$offset); # read over header and text sections.

    for ($event_num = 1 ; $event_num <= $n_events; $event_num++) {
	for ($param = 1; $param <= $n_params; $param++) {

	    # This assumes a 16 bit data word.  Not the best way to do this.
	    read(FCSFILE,$data,2);
	    $event[$param] = unpack("S",$data);
	}

	# Compute the time from the two 12-bit values.  Subtract off the
	# time of the earliest event in the file.
	# June 12, 2003.  Change this to not subtract off the initial time
	# to allow concatenation of multiple files while preserving the time.
	# $time = $event[$incol{timelow}] + 4096 * ($event[$incol{timehigh}])  - $time0; 
	$time = $event[$incol{timelow}] + 4096 * ($event[$incol{timehigh}]);

	# Dump all of the data to the output file.
	printf OUTFILE ("%12d",$event_num);
	printf OUTFILE ("%12d",$time);
	printf OUTFILE ("%6d",0); # rate, computed with other code
	printf OUTFILE ("%6d",$event[$incol{lut}]);
	printf OUTFILE ("%6d",$event[$incol{cls}]);
	printf OUTFILE ("%6d",$event[$incol{cts}]);
	printf OUTFILE ("%6d",$event[$incol{pw}]);
	printf OUTFILE ("%6d",$event[$incol{fls}]);
	printf OUTFILE ("%6d",$event[$incol{pls}]);
	printf OUTFILE ("%6d",$event[$incol{wave}]);
	printf OUTFILE ("%6d",$event[$incol{spec}]);
	printf OUTFILE ("%6d",$event[$incol{blue}]);
	printf OUTFILE ("%6d",$event[$incol{green}]);
	printf OUTFILE ("%6d",$event[$incol{red}]);
	
	# Now, output all the non-standard parameters.
	for ($i = 0; $i <= $#unnamed; $i++) {
	    printf OUTFILE ("%6d",$event[$unnamed[$i]]);
		printf  OUTFILE ("\n");
    }
    close(FCSFILE);
    close(OUTFILE);

}
=cut
###############################################################################
# This is an updated version of the "dump_data" routine coded above.  The
# main difference is that this version does not load all of the data into 
# a 2-D array and therefore is significantly faster and uses far less
# memory.  This makes a big difference for large (~1,000,000 event) files.
# On a file of 535745 events, mkstd.pl using "dump_data" took 4:28 on
# diercks3, and consumed all of the available memory, making things very slow.
# Using dump_data2, the same file conversion took 1:45.
sub dump_data3 {

    $infile   = shift(@_);
    $outfile  = shift(@_);
    $offset   = shift(@_);
    $size     = shift(@_); # not used
    $n_params = shift(@_);
    $n_events = shift(@_);
    %incol    = @_; # This hash contains the column assignments for the
                    # parameters in the input datafile.  See the main
                    # code for details.

    # Next, we deal with any parameters which are not amoung the "standard
    # set".  There is probably a slicker way to do this but I don't have
    # time to think about it right now.

    # Define an array which contains the indices of all parameters.
    for ($i = 1; $i <= $n_params; $i++) {
	$cols[$i] = $i;
    }

    while (($key,$value) = each %incol) {
	$cols[$value] = 0;
    }  

    $j = 0;
    for ($i = 1; $i <= $n_params; $i++) {
	if ($cols[$i] != 0) {
	    $unnamed[$j] = $cols[$i];
	    $j++;
	}
    }

    open(OUTFILE,">>$outfile") or die "dump_data: Can't open $outfile for appending.\n";
    open(FCSFILE,"$infile") or die "dump_data: Can't find input file $infile.";

    # Throw away all of the bits up to the data part of the file.
    $pre_text = $offset;
    $dummy = "";
    read(FCSFILE,$dummy,$offset);

    # Initialize the event array.
    @firstevent = ();

    # Read the first event in order to get the starting time.
    for ($param = 1; $param <= $n_params; $param++) {
	read(FCSFILE,$data,2);
	$firstevent[$param] = unpack("S",$data);
    }
    $time0 = ( $firstevent[$incol{timelow}]) + 4096 * ($firstevent[$incol{timehigh}] ); 
    close(FCSFILE); # For ease of understanding the code and to avoid
                    # duplicating code, we close the file, then re-open
                    # it and read in the first event again along with the
                    # rest of the data.

    $time_high = 0;  # high bit of missing time parameter
    $current_time = 0; # start at 0 to see when we roll over

    # Read in the data, sort it out into the correct columns, and dump
    # it to the output file.
    open(FCSFILE,"$infile") or die "dump_data2: Can't find input file $infile.";
    read(FCSFILE,$dummy,$offset); # read over header and text sections.

    for ($event_num = 1 ; $event_num <= $n_events; $event_num++) {
	for ($param = 1; $param <= $n_params; $param++) {

	    # This assumes a 16 bit data word.  Not the best way to do this.
	    read(FCSFILE,$data,2);
	    $event[$param] = unpack("S",$data);
	}

	# Compute the time from the two 12-bit values.  Subtract off the
	# time of the earliest event in the file.
	if ($event[$incol{timelow}] < $current_time) { # we have rolled over
	    $time_high++
	    }
	$current_time = $event[$incol{timelow}];

	$time = $event[$incol{timelow}] + 4096 * $time_high  - $time0; 

	# Dump all of the data to the output file.
	printf OUTFILE ("%12d",$event_num);
	printf OUTFILE ("%12d",$time);
	printf OUTFILE ("%6d",0); # rate, computed with other code
	printf OUTFILE ("%6d",$event[$incol{lut}]);
	printf OUTFILE ("%6d",$event[$incol{cls}]);
	printf OUTFILE ("%6d",$event[$incol{cts}]);
	printf OUTFILE ("%6d",$event[$incol{pw}]);
	printf OUTFILE ("%6d",$event[$incol{fls}]);
	printf OUTFILE ("%6d",$event[$incol{pls}]);
	printf OUTFILE ("%6d",$event[$incol{wave}]);
	printf OUTFILE ("%6d",$event[$incol{spec}]);
	printf OUTFILE ("%6d",$event[$incol{blue}]);
	printf OUTFILE ("%6d",$event[$incol{green}]);
	printf OUTFILE ("%6d",$event[$incol{red}]);
	
	# Now, output all the non-standard parameters.
	for ($i = 0; $i <= $#unnamed; $i++) {
	    printf OUTFILE ("%6d",$event[$unnamed[$i]]);
	}
	printf  OUTFILE ("\n");
    }
    close(FCSFILE);
    close(OUTFILE);

}

###############################################################################
#
sub dump_data_bc {

    my $infile   = shift(@_);
    my $outfile  = shift(@_);
    my $offset   = shift(@_);
    my $size     = shift(@_); # not used
    my $n_params = shift(@_);
    my $n_events = shift(@_);
    my %incol    = @_; # This hash contains the column assignments for the
                       # parameters in the input datafile.  See the main
                       # code for details.

    # Next, we deal with any parameters which are not amoung the "standard
    # set".  There is probably a slicker way to do this but I don't have
    # time to think about it right now.

    # Define an array which contains the indices of all parameters.
    for ($i = 1; $i <= $n_params; $i++) {
	$cols[$i] = $i;
    }

    while (($key,$value) = each %incol) {
	$cols[$value] = 0;
    }  

    $j = 0;
    for ($i = 1; $i <= $n_params; $i++) {
	if ($cols[$i] != 0) {
	    $unnamed[$j] = $cols[$i];
	    $j++;
	}
    }


    open(OUTFILE,">>$outfile") or die "dump_data: Can't open $outfile for appending.\n";
    open(FCSFILE,"$infile") or die "dump_data: Can't find input file $infile.";

    # Throw away all of the bits up to the data part of the file.
    my $pre_text = $offset;
    my $dummy = "";
    read(FCSFILE,$dummy,$offset);

    # Initialize the event array.
    my @event = ();

    # Read in all of the data into a 2-d array.
    for ($event_num = 1 ; $event_num <= $n_events; $event_num++) {
	for ($param = 1; $param <= $n_params; $param++) {

	    # This assumes a 16 bit data word.  Not the best way to do this.
	    read(FCSFILE,$data,2);
	    $event[$event_num][$param] = unpack("S",$data);
	}

	# Compute the time from the two 12-bit values.  Subtract off the
	# time of the earliest event in the file.
	$time[$event_num] = ( $event[$event_num][$incol{timelow}] - $event[1][$incol{timelow}]) + 4096 * ($event[$event_num][$incol{timehigh}] -  $event[1][$incol{timehigh}] ); 
    }


    # Dump all of the data to the output file.
    for ($event_num = 1 ; $event_num <= $n_events; $event_num++) {
	printf OUTFILE ("%12d",$event_num);
	printf OUTFILE ("%12d",$time[$event_num]);
	printf OUTFILE ("%6d",0); # rate, computed with other code
	printf OUTFILE ("%6d",$event[$event_num][$incol{lut}]);
	printf OUTFILE ("%6d",$event[$event_num][$incol{cls}]);
	printf OUTFILE ("%6d",$event[$event_num][$incol{cts}]);
	printf OUTFILE ("%6d",$event[$event_num][$incol{pw}]);
	printf OUTFILE ("%6d",$event[$event_num][$incol{adc1}]);
	printf OUTFILE ("%6d",$event[$event_num][$incol{adc2}]);
	printf OUTFILE ("%6d",$event[$event_num][$incol{adc3}]);
	printf OUTFILE ("%6d",$event[$event_num][$incol{adc4}]);
	printf OUTFILE ("%6d",$event[$event_num][$incol{adc5}]);
	printf OUTFILE ("%6d",$event[$event_num][$incol{adc6}]);
	printf OUTFILE ("%6d",$event[$event_num][$incol{adc7}]);
	printf OUTFILE ("%6d",$event[$event_num][$incol{adc8}]);
	
	# Now, output all the non-standard parameters.
	for ($i = 0; $i <= $#unnamed; $i++) {
	    printf OUTFILE ("%6d",$event[$event_num][$unnamed[$i]]);
	}
	printf  OUTFILE ("\n");
    }

    close(FCSFILE);
    close(OUTFILE);

}

###############################################################################
# This routine takes a number and returns the binary representation of the
# number as an array with the least significant bit in aray element 0.
sub tobinary {
    my $number = $_[0];
    my $nbits  = $_[1];
    my $i = 0;
    @bit = ();
    for ($i = ($nbits) ; $i > 0; $i--) {
        $div = $number / (2**($i-1));
        if ( int($div) > 0 ) {
            $bit[$i-1] = 1;
            $number -= 2**($i-1);
        } else {
            $bit[$i-1] = 0;
        }
    }
    return(@bit);
}
###############################################################################
# This subroutine determines whether the argument is a power of 2.
sub power_of_2 {

    my $number = $_[0];

    my @bits = tobinary($number,16);

    $count = 0;
    
    for ($i = 0; $i <= $#bits; $i++) {
	if ($bits[$i] == 1) {
	    $count++;
	}
    }
    
    if ($count > 1) {
	return (0); # not a power of 2
    } else {
	return(1);  # power of 2
    }
}

