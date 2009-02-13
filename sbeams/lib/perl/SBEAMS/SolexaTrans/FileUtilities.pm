use strict;
use warnings;

package SBEAMS::SolexaTrans::FileUtilities;

# $Id: FileUtilities.pm,v 1.5 2007/11/06 17:49:48 phonybone Exp $

use Carp;

use vars qw(@ISA @EXPORT_OK);
@ISA = qw(Exporter);
@EXPORT_OK = qw(slurpFile spitString appendFile directory_crawl directory_crawl_infix parse3 dir basename suffix);

sub slurpFile {
    my $filename = shift or confess "no filename";
    open (FILE, "$filename") or confess "Can't open $filename: $!";

    my $oldFilehandle = select FILE;
    my $oldRecordSep = $/;
    undef $/;
    my $contents = <FILE>;	# slurp!
    $/ = $oldRecordSep;
    select $oldFilehandle;
    close FILE;
    return $contents;
}


sub spitString {
    my $string = shift;
    my $filename = shift;
    my $lockFlag = shift || '';

    open (FILE, ">$filename.tmp") or
	confess "Unable to open $filename.tmp for writing: $!\n";

    if ($lockFlag) {
	use Fcntl ':flock';
	flock(FILE, LOCK_EX);
	seek(FILE, 0, 2);
    }
    print FILE $string or
	confess "Unable to write to $filename: $!\n";

    flock(FILE, LOCK_UN) if $lockFlag;
    close FILE or confess "Unable to close $filename: $!\n";

    rename "$filename.tmp", "$filename" or confess "Unable to rename '$filename.tmp' to '$filename': $!\n";

    return 1;
}

sub appendFile {
    my $record = shift;
    my $filename = shift;

    open (FILE, ">>$filename") or
	confess "Unable to open $filename for appending: $!\n";

    print FILE $record or
	confess "Unable to write to $filename: $!\n";

    close FILE or confess "Unable to close $filename: $!\n";
    return 1;
}

sub prependFile {
    my $record = shift;
    my $filename = shift;

    my $contents = slurpFile($filename);
    open (FILE, ">$filename") or
	confess "Can't open $filename for writing: $!\n";
    print FILE $record;
    print FILE $contents;
    close FILE;
    1;
}

=head2 directory_crawl

   Title    : directory_crawl
   Function : Perform a crawl of a directory tree
   Usage    : Called like this,
		    directory_crawl('.', 
			    sub { warn ' ' x ($_[1]*2), "got subdir $_[0]\n" },
		   		sub { warn ' ' x ($_[1]*2), "got file $_[0]\n" });

   Args     : $dir: the root of the directory to be crawled
			  $dir_hook: a ref to a subroutine to be called for each subdirectory.  It's parameters
                are the path to the subdirectory and the level of recursion
			  $file_hook: like $dir_hook, but for files
 			  $level (optional): the level of recursion (defaults to 0 for first call)
   Returns  : the output will be an indented listing of all files and subdirectories, 
				in the order of their discovery.
				This is a post-fix recursive routine.

=cut

sub directory_crawl {
    my $dir = shift or confess "no dir";
    my $dir_hook = shift || sub { };
    my $dir_args = shift;
    my $file_hook = shift || sub { };
    my $file_args = shift;
    my $level = shift || 0;

    opendir(DIR, $dir) or confess "Can't open $dir: $!";
    my @entries = grep !/^\./, readdir DIR;
    closedir DIR;

    my @subdirs;
    foreach my $entry (@entries) {
	my $path = "$dir/$entry";
	warn "crawling $path\n" if $ENV{DEBUG};
	if (-d $path) {
	    push @subdirs, "$entry";
	    &$dir_hook($path, $level, $dir_args) if ref $dir_hook eq 'CODE';
	} else {
	    &$file_hook($path, $level, $file_args) if ref $file_hook eq 'CODE';
	}
    }

    foreach my $subdir (@subdirs) {
	directory_crawl("$dir/$subdir", $dir_hook, $dir_args, $file_hook, $file_args, $level+1);
    }
}

# this is just the same as the above routine, but the recursion occurs as each directory
# is found (as opposed to processing all the files in a directory first, then recursing)
sub directory_crawl_infix {
    my $dir = shift or confess "no dir";
    my $dir_hook = shift || sub { };
    my $dir_args = shift;
    my $file_hook = shift || sub { };
    my $file_args = shift;
    my $level = shift || 0;

    opendir(DIR, $dir) or confess "Can't open $dir: $!";
    my @entries = grep !/^\./, readdir DIR;
    closedir DIR;

    foreach my $entry (@entries) {
	my $path = "$dir/$entry";
	if (-d $path) {
	    &$dir_hook($path, $level, $dir_args) if ref $dir_hook eq 'CODE';
	    directory_crawl_infix("$dir/$entry", $dir_hook, $dir_args, $file_hook, $file_args, $level+1);

	} else {
	    &$file_hook($path, $level, $file_args) if ref $file_hook eq 'CODE';
	}
    }
}

sub parse3 {
    my $path=shift or confess "no path";

    # I don't think there is a lexigraphical way to differentiate /dir from /file:
    return wantarray? ($path,'',''):[$path,'',''] if -d $path;

    my ($d,$f,$b,$s);

    if ($path =~ m|/|) {
	# split into dir and file.suffix:
	($d,$f) = $path =~ m|(.*)/(.*)|g;
    } else {
	$d = '';
	$f = $path;
    }
    ($b,$s) = $f =~ /([^.]*)\.?(.*)/;
    wantarray? ($d,$b,$s):[$d,$b,$s];
}


sub dir { (parse3($_[0]))[0]; }
sub basename { (parse3($_[0]))[1]; }
sub suffix { (parse3($_[0]))[2]; }
    
1;
