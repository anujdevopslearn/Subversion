#PBS -N solexa_test
#PBS -M bea
#PBS -o /net/dblocal/www/html/devDM/sbeams/lib/scripts/SolexaTrans/solexa_test.out

/tools64/bin/perl process_solexa.pl -name DTRA_lung -eff s_%d_export.txt.1000 -tag_length 18 -babel_db_host=grits -use_old_patman_output
#/tools64/bin/perl process_solexa.pl -eff s_%d_export.txt.1000 -tag_length 18 -babel_db_host=grits -use_old_patman_output -export_files /users/dmauldin/STP_test/FC93202-GAI392-02102009/s_6_export.txt.1000 -project_dir /users/dmauldin/STP_test -motif GATC -ref_genome human -name DTRA_lung
