package FileManager;

use Digest::MD5 qw/md5_base64/;
use strict;
use Data::Dumper;

#### Method: new
# The new routine
####
sub new {
	my $class = shift;
	my $self = {};
	bless $self, $class;
	return $self;
}

#### Method: create
# Create a new file repository
####
sub create {
	my $self = shift;
	my ($basepath) = @_;
	my $token = $self->rand_token;
	#print "TOKEN '$token'\n";
	my $path = "$basepath/$token";
	#print "FOLDER PATH '$path'\n";  #delete for production
	umask(0000);					#delete for production
	my $umask = umask();			#delete for production
	
	mkdir($path, 0777) || return 0;	#TURN TO 0700 for PRODUCTION !!!!
	$self->{'token'} = $token;
	$self->{'path'} = $path;
	#chown(-1, 1052, $path);
	return 1;
}

#### Method: init_with_token
# Connect to an existing repository with a given token
####
sub init_with_token {
	my $self = shift;
	my ($basepath, $token) = @_;
	my $path = "$basepath/$token";
#print STDERR "INIT PATH '$path'\n";
	# Make sure the token contains only alphanumeric characters
	if (grep(/[^0-9a-zA-Z\-]/, $token)) {
		return 0;
	}
	opendir(DIR, $path) || return 0;
	closedir(DIR);
	$self->{'token'} = $token;
	$self->{'path'} = $path;
	#print STDERR "INIT PATH '$path'\n";
	return 1;
}

#### Method: token
# Accessor method for token
####
sub token {
	my $self = shift;
	return $self->{'token'};
}

#### Method: path
# Accessor method for path
####
sub path {
	my $self = shift;
	return $self->{'path'};
}

#### Method: analysis_id
# Getter Setter for Analysis ID
####
sub analysis_id {
	my $self = shift;
	my $analysis_id = shift;
	if ($analysis_id){
		$self->{'analysis_id'} = $analysis_id;
		return 0;
	}else{
		
		return $self->{'analysis_id'};
	}
}

#### Method: filenames
# Returns an array of all the file names in the repository
# Returns undef if there were problems reading the directory
####
sub filenames {
	my $self = shift;
	my $path = $self->{'path'};
	
	if (!$path) { return undef; }
	opendir(DIR, $path) || return undef;
	my @filenames = readdir(DIR);
	closedir(DIR);
	
	return undef if (! @filenames);
	
	@filenames = grep(!/^\./, @filenames);
	@filenames = grep(!/^core\./,@filenames);
	#@filenames = sort {(stat("$path/$a"))[9] <=> (stat("$path/$b"))[9]} @filenames;
##Sort by the sample portion of the file name
##First store all sample names then by the file stat info
	my @sample_names = ();
	foreach my $filename (@filenames){
		my @hold = ();
		push @hold, $filename;
		push @hold, (stat("$path/$filename"))[9];

		
		if ($filename =~ /\d+_\d+_(.*)\.CEL/){   #Example file name at ISB 20040421_04_C4-2_3.CEL
			push @hold, $1;
		}else{
			push @hold, $filename;
		}	
		#print "HOLD INFO FILE '$filename' INFO '@hold'<br>";
		push @sample_names, [@hold];
	}
		
	
        {
        # This block was spewing tons of warnings, basically due to incorrect
        # 'type' with the cmp and <=> operators.  Turned off for now, should
        # revisit FIXME. 
        no warnings;
	@filenames = map{$_->[0]} 
				 sort {  
                                           my @a_fields = @$a[1..$#$a]; 
					   my @b_fields = @$b[1..$#$a]; 
                                           for ( @a_fields ) { $_ = '' unless defined $_; }
                                           for ( @b_fields ) { $_ = '' unless defined $_; }
							
					   $a_fields[2] cmp $b_fields[2]
								     ||
					   $a_fields[1] <=> $b_fields[1]
							 
				  } @sample_names;
        }
				  
	
				  
	return @filenames;
}

#### Method: file_exists
# Returns 1 if the file exists. 0 if not.
####
sub file_exists {
	my $self = shift;
	my ($filename) = @_;
	my $path = $self->{'path'};
	my @filenames = $self->filenames;
	
	return 0 if !$filename;
	foreach my $name (@filenames) {
		return 1 if ($filename eq $name);
	}
	
	return 0;
}

#### Method: savefh
# Saves a copy of the file associated with the given file handle 
# with the given name (assumes binary). Returns 1 on success.
####
sub savefh {
	my $self = shift;
	my ($fh, $filename) = @_;
	my $path = $self->{'path'};
	my ($bytesread, $buffer);
	
	if (!$fh || !$path || grep(/\//, $filename)) { return 0; }
	open(OUTFILE, ">$path/$filename") || return 0;
	while ($bytesread = read($fh, $buffer, 10240)) {
        print OUTFILE $buffer;
    }
    close(OUTFILE);
    
    return 1;
}

#### Method: remove
# Unlinks the filenames passed as arguments. If no arguments
# are given, deletes all files. Returns 1 on success.
####
sub remove {
    my $self = shift;
    my @filenames = @_;
	my $path = $self->{'path'};
	my ($filename, $cnt);
	
	if (!$path) { return 0; }
	if (!@filenames) {
		@filenames = $self->filenames;
	}
	foreach $filename (@filenames) {
		unlink("$path/$filename") || return 0;
		
	}
	
	return 1;
}

########################################
# THESE METHODS ARE MORE OR LESS PRIVATE
########################################

#### Method: rand_token
# Generate a random token
####
sub rand_token {
	my $token = md5_base64(time * $$);
	$token =~ s/[+\/=]//g;
	return $token;
}

1;
