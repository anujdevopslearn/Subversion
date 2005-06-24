#!/usr/local/bin/perl -w

###############################################################################
# Program     : email_data_contributors.pl
# Author      : Nichole King <nking@systemsbiology.org>
#
# Description : This script gathers sample info
#               (sample_tag, description, is_public, and publication info)
#               and emails the data contributors asking them if info is
#               correct.
#
###############################################################################



###############################################################################
# Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use Mail::Sendmail; 


use lib "$FindBin::Bin/../../perl";
#use lib qw(/tools/lib/perl5/site_perl ../lib);
use vars qw ($sbeams $sbeamsMOD $current_username
             $PROG_NAME $USAGE %OPTIONS 
            );

#### Set up SBEAMS core module
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
$sbeams = SBEAMS::Connection->new();

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

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
    --testprint            If set, prints all email text to screen
    --testsend             If set, sends all email to me
    --sendtoall            If set, sends email to primary email contacts
    --sendto               Send email to "name1 name2 name3", for example

e.g.:  $PROG_NAME --testprint 

EOU

####### Process options #######################
unless (GetOptions(\%OPTIONS,"testprint","testsend","sendtoall",
       "sendto:s",
     )) {
    print "$USAGE";
    exit;
}

###############################################################################
# Set Global Variables and execute main()
###############################################################################
#### Read command-line arguments
my $testprint = $OPTIONS{"testprint"} || '';

my $testsend = $OPTIONS{"testsend"} || '';

my $sendtoall = $OPTIONS{"sendtoall"} || '';

my $sendto = $OPTIONS{"sendto"} || '';

unless ( $testprint || $testsend || $sendtoall || $sendto)
{

    die "$USAGE";

}

main();
exit(0);

###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
###############################################################################
sub main {

    #### Do the SBEAMS authentication and exit if a username is not returned
    exit unless ($current_username = $sbeams->Authenticate(
                  work_group=>'PeptideAtlas_admin',
    ));


    handleRequest();


} # end main

###############################################################################
# handleRequest
###############################################################################
sub handleRequest 
{

    my %args = @_;


    #### Verify required parameters

    ## --sendtoall && (--testprint || --testsend)  will not work
    if ($sendtoall  && ($testsend || $testprint)) {
        print "ERROR: select --sendtoall without a --test[option], but not both\n";
        print "$USAGE";
        exit;
    }

    unless ($sendtoall || $testsend || $testprint || $sendto) {
        print "$USAGE";
        print "ERROR: select --sendtoall  or --sendto  or  --testprint  or --testsend  for action\n";
        exit;
    }


    #### If there are any parameters left, complain and print usage
    if ($ARGV[0]){
        print "ERROR: Unresolved command line parameter '$ARGV[0]'.\n";
        print "$USAGE";
        exit;
    }


    ## Get publication information.  Structure is:
    ##  $publications{$publication_id}->{citation}
    ##  $publications{$publication_id}->{url}
    ##  $publications{$publication_id}->{pmid}
    my %publications = get_publication_info();


    ## Get sample information. Structure is:  
    ##  $samples{$sample_tag}->{description} = $sample_description;
    ##  $samples{$sample_tag}->{search_batch_id} = $search_batch_id;
    ##  $samples{$sample_tag}->{data_contributors} = $data_contributors;
    ##  $samples{$sample_tag}->{is_public} = $is_public;
    ##  $samples{$sample_tag}->{publication_ids} = $publication_ids;
    ##  $samples{$sample_tag}->{primary_contact_email} = $primary_contact_email;
    my %samples = get_sample_info();

    
    handleEmail (

        samples_ref => \%samples,
   
        publications_ref => \%publications,
   
        testprint => $testprint,
   
        testsend => $testsend,
    
        sendto => $sendto,

    );

} # end handleRequest



#######################################################################
# get_publication_info -- get all citation, url, pmid entries from
#     publication records and store it by publication_id
#######################################################################
sub get_publication_info()
{

    my %publ_info;


    my $sql = qq~
        SELECT publication_id, publication_name, uri, pubmed_ID
        FROM $TBAT_PUBLICATION
    ~;


    my @rows = $sbeams->selectSeveralColumns($sql) or 
        die "Couldn't find publication records ($!)";


    ## store query results in $publ_info
    foreach my $row (@rows) 
    {

        my ($publication_id, $publication_name, $uri, $pmid) = @{$row};

        $publ_info{$publication_id}->{citation} = $publication_name; 

        $publ_info{$publication_id}->{url} = $uri;

        $publ_info{$publication_id}->{pmid} = $pmid;

    }


    ## assert data structure contents:
    if ($testprint || $testsend)
    {

        foreach my $row (@rows)
        {

            my ($publication_id, $publication_name, $uri, $pmid) = @{$row};

            if ( $publ_info{$publication_id}->{citation} ne $publication_name)
            {

                warn "TEST fails for $publ_info{$publication_id}->{citation} ($!)";

            }

            if ( $publ_info{$publication_id}->{url} ne $uri)
            {

                warn "TEST fails for $publ_info{$publication_id}->{uri} ($!)";

            }

            if ( $publ_info{$publication_id}->{pmid} ne $pmid)
            {

                warn "TEST fails for $publ_info{$publication_id}->{pmid} ($!)";

            }


        }

    }

    return %publ_info;

}


#######################################################################
# get_sample_info -- get relevant attributes from all
#    public sample records and store it by sample_tag
#######################################################################
sub get_sample_info
{

    my %sample_info;

    ## get sample info:
    my $sql = qq~
        SELECT sample_tag, sample_description, search_batch_id,
            data_contributors, is_public, sample_publication_ids,
            primary_contact_email
        FROM $TBAT_SAMPLE
        WHERE record_status != 'D'
        AND sample_tag != 'LnCAP_nuc3'
        AND sample_tag != 'test'
    ~;

    my @rows = $sbeams->selectSeveralColumns($sql) or 
        die "Couldn't find sample records ($!)";


    ## store query results in $sample_info
    foreach my $row (@rows) 
    {

        my ($sample_tag, $sample_description, $search_batch_id,
            $data_contributors, $is_public, $sample_publication_ids,
            $primary_contact_email) = @{$row};

        ## replace dos end of line markers (\r) and (\n) with space
        $sample_description =~ s/\r/ /g;

        $sample_description =~ s/\n/ /g;

        $data_contributors =~ s/\r/ /g;

        $data_contributors =~ s/\n/ /g;


        $sample_info{$sample_tag}->{description} = $sample_description;

        $sample_info{$sample_tag}->{search_batch_id} = $search_batch_id;

        $sample_info{$sample_tag}->{data_contributors} = $data_contributors;

        $sample_info{$sample_tag}->{is_public} = $is_public;

        $sample_info{$sample_tag}->{publication_ids} = $sample_publication_ids;

        $sample_info{$sample_tag}->{primary_contact_email} = $primary_contact_email;

    }


    if ($testprint || $testsend)
    {
 
        ## assert data structure contents
        foreach my $row (@rows) 
        {

            my ($sample_tag, $sample_description, $search_batch_id,
                $data_contributors, $is_public, $sample_publication_ids,
                $primary_contact_email) = @{$row};

            ## replace dos end of line markers (\r) and (\n) with space
            $sample_description =~ s/\r/ /g;

            $sample_description =~ s/\n/ /g;

            $data_contributors =~ s/\r/ /g;

            $data_contributors =~ s/\n/ /g;

            if ( $sample_info{$sample_tag}->{description} ne
            $sample_description)
            {

                warn "TEST fails for ".
                    $sample_info{$sample_tag}->{description} 
                    ." (perhaps more than one search batch for a sample)";

            }


            if ($sample_info{$sample_tag}->{search_batch_id} ne
            $search_batch_id)
            {

                warn "TEST fails for " .
                    $sample_info{$sample_tag}->{search_batch_id} 
                    ." (perhaps more than one search batch for a sample)";

            }


            if ($sample_info{$sample_tag}->{data_contributors} ne
            $data_contributors)
            {

                warn "TEST fails for $sample_tag data_contributors:" .
                    $sample_info{$sample_tag}->{data_contributors} 
                    ." ($!)";

            }

            if ($sample_info{$sample_tag}->{is_public} ne
            $is_public)
            {

                warn "TEST fails for 
                    $sample_info{$sample_tag}->{is_public} ($!)";

            }

            if ($sample_info{$sample_tag}->{publication_ids} ne
            $sample_publication_ids)
            {

                warn "TEST fails for 
                    $sample_info{$sample_tag}->{publication_ids} ($!)";

            }

            if ($sample_info{$sample_tag}->{primary_contact_email} ne
            $primary_contact_email)
            {

                warn "TEST fails for 
                    $sample_info{$sample_tag}->{primary_contact_email} ($!)";

            }

        } ## end assert test

    } ## end $TEST


    return %sample_info;

}

###############################################################################
# handleEmail -- Uses search_batch_id_list entries to gather info from PeptideAtlas
#                sample table
#             -- If testprint is true, prints to screen
#                Else If testsend is true, sends all email to me
##               Else sends email to primary contacts
###############################################################################
sub handleEmail 
{

    ## read arguments
    my %args = @_;

    my $testprint = $args{'testprint'} || 0;

    my $testsend = $args{'testsend'} || 0;

    my $sendto = $args{'sendto'} || '';

    my $samples_ref = $args{samples_ref} ||
        die "samples hash ($!)";

    my $publications_ref = $args{publications_ref} ||
        die "need publications ($!)";

    my %samplesHash = %{$samples_ref};

    my %publicationsHash = %{$publications_ref};


    ## create a hash of email contacts 
    ## (key = primary_email_contact, value=primary_email_contact)
    my %contact_hash = get_email_contacts (

        samples_ref => \%samplesHash,

    );


    ## if a sendto list was requested, make a hash of the list:
    my @recipients = split(" ", $sendto); 

    my %requested_contacts;

    for (my $i=0; $i <= $#recipients; $i++)
    {

        $requested_contacts{ $recipients[$i] } = $recipients[$i];

    }


    ## iterate over contact_hash to gather all info for a contact,
    ## then email that to contact
    foreach my $contact (keys %contact_hash)
    {


        ## declare string array of information to print in email
        my @info; 

        ## gather sample info:
        foreach my $sample_tag (keys %samplesHash)
        {

            if ( $samplesHash{$sample_tag}->{primary_contact_email} eq $contact )
            {

                my $is_public = $samplesHash{$sample_tag}->{is_public};

                my $data_contributors = $samplesHash{$sample_tag}->{data_contributors};

                my $description = $samplesHash{$sample_tag}->{description};

                my @publication_ids = split(/,/  , $samplesHash{$sample_tag}->{publication_ids});


                ## put sample info into string array:
                push(@info, " ");
            
                push(@info, "Sample: $sample_tag");

                push(@info, "Is Public?: $is_public");

                push(@info, "Data Contributors: $data_contributors");

                push(@info, "Description: $description");


                ## put publication info into string array:
                for (my $i=0; $i <= $#publication_ids; $i++)
                {

                    if( exists $publicationsHash{$publication_ids[$i]})
                    {

                        my $str = "Publication: " . $publicationsHash{$publication_ids[$i]}->{citation};

                        push(@info, $str);

                        $str = "    " . $publicationsHash{$publication_ids[$i]}->{url};

                        push(@info, $str);

                    }

                }

            }

        } ## end iterate over sample


        ## if a sendto list was requested, only process identical addresses:
        if ($sendto)
        {

            if ( exists $requested_contacts{$contact} )
            {

                ## send email
                emailContact(
                    
                    contact => $contact, info_array_ref => \@info,

                    testprint => $testprint, testsend => $testsend,

               );
                    
            }
        } else  
        {

            ## send email
            emailContact(

                contact => $contact, info_array_ref => \@info,

                testprint => $testprint, testsend => $testsend,

           );

           
        }

    } ## end iterate over contact

}  #end handleEmail

###############################################################################
# get_email_contacts - makes a hash of email contacts
#   with key   = primary_email_contact
#        value = primary_email_contact
###############################################################################
sub get_email_contacts
{

    my %args = @_;

    my $samples_ref = $args{samples_ref} || die "need samples ref ($!)";

    my %samplesHash = %{$samples_ref};


    my %contactHash;

    foreach my $st (keys %samplesHash)
    {

        my $contact = $samplesHash{$st}->{primary_contact_email};

        $contactHash{ $contact } = $contact;

    }

    return %contactHash;

}


############################################################################################
sub emailContact 
{

    my %args = @_;

    my $testprint = $args{'testprint'} || 0;

    my $testsend = $args{'testsend'} || 0;

    my $contact = $args{'contact'} || die "need email contact ($!)";;

    my $info_array_ref = $args{'info_array_ref'} || die "need info ref ($!)";

    
    ## make a string of info string array contents:
    my @info_array = @{$info_array_ref};

    my $str = $info_array[0];

    for (my $i=1; $i <= $#info_array; $i++)
    {

        $str = $str . "\n" . $info_array[$i];

    }


    my $recipient = $contact;


    if ($testprint || $testsend)
    {

        $recipient = "nking\@systemsbiology.org";

    }

    my $cc_name = "Nichole King";

    my $cc = "nking\@systemsbiology.org"; 

    my %mail;

    $mail{To}   = "<$recipient>";

    $mail{From} = "nking\@systemsbiology.org";

    $mail{Cc}   = "$cc_name <$cc>";

    $mail{Subject} = "PeptideAtlas records";

    $mail{Message} = "\nDear PeptideAtlas Data Contributor,

    This is an automated email asking you to check the information
enclosed.   Each dataset that you have contributed is called a sample.
With each sample name you will see information.  If you would like the 
information changed, please let me know.

   Please note the entry for Is Public?.  If this is incorrect, please
notify me right away as those with y (yes) entries will be AVAILABLE TO
THE PUBLIC THIS WEEK!


Here are your samples:

    $str


    Thank you for participating,
        Nichole

    \n \n";


    if ($testprint) 
    {

        ## print to stdout:

        print "$mail{To}\n";

        print "$mail{From}\n";

        print "$mail{Cc}\n";

        print "$mail{Subject}\n";

        print "$mail{Message}\n";


    } else 
    {

        sendmail (%mail) or die $Mail::Sendmail::error;

    }

    ##NOTE: should wrap it in HTML/MIME for email...MAC email not handling end of lines well?
}
