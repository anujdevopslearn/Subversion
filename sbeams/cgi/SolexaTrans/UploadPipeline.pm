package UploadPipeline;

use FindBin;
use lib "$FindBin::Bin/../../lib/perl";

use strict;

our @ISA    = qw/Exporter/;
our @EXPORT = qw/upload_tag_info perl_process_tags
                 upload_gene_info perl_process_genes
                 alter_db_status
                /;


#### Subroutine: alter_db_status
sub alter_db_status {
    my $status = shift;

    my $pscript =<<"INSERT_TAGS";

            \$rowdata_ref->{"status"}             = '$status';

            \$sbeams->updateOrInsertRow(
                                         table_name=>\$TBST_SOLEXA_ANALYSIS,
                                         rowdata_ref => \$rowdata_ref,
                                         PK=>'solexa_analysis_id',
                                         PK_value => \$analysis_id,
                                         update=>1,
                                         verbose=>\$verbose,
                                         testonly=>\$testonly,
                                         add_audit_parameters=>1,
                                        );
INSERT_TAGS

return $pscript;

}


#### Subroutine: upload_tag_info
sub upload_tag_info {
     my $pscript = <<"PEND6";

            my \$file_root = \$project_name.'.'.\$sample_id;

            my \$date_created = strftime "\%m/\%d/\%Y \%I:\%M:\%S \%p", localtime(time);

            my \$created_by_id=\$sbeams->getCurrent_contact_id();
            my \$owner_group_id=\$sbeams->getCurrent_work_group_id();
            my \$record_status='N';

            my \$dbh = \$sbeams->getDBHandle();
            \$dbh->{RaiseError} = 1;

            my \$psql = "Insert into \$TBST_TAG
                          (tag, date_created, created_by_id,
                                date_modified, modified_by_id, owner_group_id, record_status)
                          values
                          (?, CURRENT_TIMESTAMP, '\$created_by_id',
                              CURRENT_TIMESTAMP, '\$created_by_id', '\$owner_group_id', '\$record_status')
                         ";
            my \$insert_tag = \$dbh->prepare(\$psql) || die \$DBI::errstr;

            my \$bsql = "INSERT into \$TBST_BIOSEQUENCE_TAG
                          (tag_id, biosequence_id, date_created, created_by_id,
                                                   date_modified, modified_by_id, owner_group_id, record_status)
                          values
                          (?, ?, CURRENT_TIMESTAMP, '\$created_by_id',
                                 CURRENT_TIMESTAMP, '\$created_by_id', '\$owner_group_id', '\$record_status')
                       ";
            my \$biosequence = \$dbh->prepare(\$bsql) || die \$DBI::errstr;


PEND6

return $pscript;
} 


#### Subroutine: perl_process_tags
# Prints out a perl script that processes one of the results files from a STP job
####
sub perl_process_tags {
  my $tag_type = shift;
  my $job_dir = shift;
  my $ext;
  if ($tag_type eq 'MATCH') {
    $ext = 'tags';
  } elsif ($tag_type eq 'UNKNOWN') {
    $ext = 'unkn';
  } elsif ($tag_type eq 'AMBIGUOUS') {
    $ext = 'ambg';
  } else {
    die "Tag type not recognized in perl_process_tags: $tag_type\n";
  }


  my $script = <<EOS1;
{
           my \$tag_type_id = \$utilities->get_sbeams_tag_type(type => "$tag_type");
            my \$tag_err_file = '$job_dir/'.\$file_root.'.$ext.err';
            open TAGERR, ">\$tag_err_file" or die "can't open tag error file";
            my \$tag_in_file = '$job_dir/'.\$file_root.'.$ext';
            open(TAG, "\$tag_in_file") or die "can't open tag file";
            my \$tag_ana_file = '$job_dir/'.\$file_root.'.${ext}_ana';
            open(TAG_ANA, ">\$tag_ana_file") or die "Can't open tag_ana file";

            if (\$tag_type_id) {
              my \$cnt = 0;
              while (<TAG>) {
                chomp;
EOS1

  if ($tag_type eq 'MATCH') {
    $script .= "\t\tmy (\$gene_id, \$tag, \$count, \$cpm) = split(/\\t/, \$_);";
  } elsif ($tag_type eq 'UNKNOWN') {
    $script .= "\t\tmy (\$tag, \$count, \$cpm) = split(/\\t/, \$_);";
  } elsif ($tag_type eq 'AMBIGUOUS') {
    $script .= "\t\tmy (\$tag, \$gene_ids, \$n_lls, \$count, \$cpm) = split(/\\t/, \$_);";
  }

  $script .= <<EOS2;

                my \$tag_id = \$utilities->check_sbeams_tag(tag => \$tag);
                if (!\$tag_id) {
                  \$insert_tag->bind_param(1,\$tag) || die "Database Error ".\$dbh->errstr;
                  \$insert_tag->execute() || die "Database Error: ".\$dbh->errstr;
                  \$tag_id = \$utilities->check_sbeams_tag(tag => \$tag);

                  if (!\$tag_id || \$tag_id == '-1') {
                    print "\$tag\\t\$count\\t\$cpm\\tTag ID not found and cannot be inserted\\n";
                    next;
                  }
EOS2

  if ($tag_type eq 'MATCH') {
      $script .= <<EOS3;
                  my \$biosequence_id = \$utilities->check_sbeams_biosequence(biosequence_accession => \$gene_id);
                  if (\$biosequence_id == 0) {
                    print TAGERR "\$gene_id\\t\$tag\\t\$count\\t\$cpm\\tBiosequence ID not found\\n";
                    next;
                  }
                  \$biosequence->execute(\$tag_id, \$biosequence_id);
EOS3

  } elsif ($tag_type eq 'AMBIGUOUS') {
    $script .= <<EOS4;
                  my \@genes = split(/,/, \$gene_ids);
                  foreach my \$gene (\@genes) {
                    my \$biosequence_id = \$utilities->check_sbeams_biosequence(biosequence_accession => \$gene);
                    if (\$biosequence_id == 0) {
                      print TAGERR "\$tag\\t\$gene\\t\$count\\t\$cpm\\tBiosequence ID not found\\n";
                      next;
                    }
                    \$biosequence->execute(\$tag_id, \$biosequence_id);
                  }
EOS4
  }

      $script .= <<EOS5;
                }
               print TAG_ANA join("\\t",(\$analysis_id,\$tag_id,\$tag_type_id,\$count,\$cpm,
                                        \$date_created,\$created_by_id,
                                        \$date_created,\$created_by_id,\$owner_group_id,\$record_status))."\\n";
                \$cnt++;
                print "Processed \$cnt tags\n" if (\$cnt % 1000) == 0;
              } # end while TAG
            } else {
              die "Could not find a tag type id for '$tag_type'";
            }
            close TAG;
            close TAGERR;
            close TAG_ANA;

           {
             system("/tools/freetds/bin/freebcp \$TBST_TAG_ANALYSIS in '\$file_root.${ext}_ana' -f '\$tag_analysis_format_file' -S MSSQL -U dmauldin -P DMng449 -e $job_dir/tag_${tag_type}_error.log");
           }
           if (\$@) {
             die "Could not use freebcp - \$@";
           }
}
EOS5

return $script;
}

#### Subroutine: upload_gene_info
sub upload_gene_info {
     my $pscript = <<"PEND6";

            my \$file_root = \$project_name.'.'.\$sample_id;

            my \$date_created = strftime "\%m/\%d/\%Y \%I:\%M:\%S \%p", localtime(time);

            my \$created_by_id=\$sbeams->getCurrent_contact_id();
            my \$owner_group_id=\$sbeams->getCurrent_work_group_id();
            my \$record_status='N';

            my \$dbh = \$sbeams->getDBHandle();
            \$dbh->{RaiseError} = 1;

PEND6

return $pscript;
} 


#### Subroutine: perl_process_genes
# Prints out a perl script that processes one of the results files from a STP job
####
sub perl_process_genes {
  my $ext = shift || 'cpm';
  my $job_dir = shift;

  my $script = <<EOS1;
{

            my \$gene_err_file = '$job_dir/'.\$file_root.'.$ext.err';
            open TAGERR, ">\$gene_err_file" or die "can't open gene error file";
            my \$gene_in_file = '$job_dir/'.\$file_root.'.$ext';
            open(TAG, "\$gene_in_file") or die "can't open gene file";
            my \$gene_ana_file = '$job_dir/'.\$file_root.'.${ext}_ana';
            open(TAG_ANA, ">\$gene_ana_file") or die "Can't open gene_ana file";

            my \$cnt = 0;
            while (<TAG>) {
              chomp;
              my (\$gene_id, \$count, \$cpm) = split(/\\t/, \$_);

              my \$biosequence_id = \$utilities->check_sbeams_biosequence(biosequence_accession => \$gene_id);
              if (\$biosequence_id == 0) {
                 print TAGERR "\$gene_id\\t\$count\\t\$cpm\\tBiosequence ID not found\\n";
                 next;
              }
              print TAG_ANA join("\\t",(\$analysis_id,\$biosequence_id,\$count,\$cpm,
                                        \$date_created,\$created_by_id,
                                        \$date_created,\$created_by_id,\$owner_group_id,\$record_status))."\\n";
              \$cnt++;
              print "Processed \$cnt genes\n" if (\$cnt % 1000) == 0;
            } # end while TAG
            close TAG;
            close TAGERR;
            close TAG_ANA;

           {
             system("/tools/freetds/bin/freebcp \$TBST_GENE_ANALYSIS in '$job_dir/\$file_root.${ext}_ana' -f '\$gene_analysis_format_file' -S MSSQL -U dmauldin -P DMng449 -e $job_dir/gene_error.log");
           }
           if (\$@) {
             die "Could not use freebcp - \$@";
           }
}
EOS1

return $script;
}

1;
