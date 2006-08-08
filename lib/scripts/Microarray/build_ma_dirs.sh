#!/bin/sh

if [ "$SBEAMS" == "" ]
then
  echo "Please set SBEAMS environment variable"
  exit
fi
if [ ! -e "$SBEAMS/lib" ]
then
  echo "Missing needed directory"
  exit
fi

cd $SBEAMS

if [  -e tmp ]
then

# These will have to be created.
mkdir $SBEAMS/tmp/Microarray \
$SBEAMS/tmp/Microarray/AFFY_ANNO_LOGS \
$SBEAMS/tmp/Microarray/R_CHP_RUNS \
$SBEAMS/tmp/Microarray/GetExpression \
$SBEAMS/tmp/Microarray/GetExpression/jws \
$SBEAMS/var/Microarray \
$SBEAMS/var/Microarray/Affy_data \
$SBEAMS/var/Microarray/Affy_data/probe_data \
$SBEAMS/var/Microarray/Affy_data/probe_data/external \
$SBEAMS/var/Microarray/Affy_data/delivery \
$SBEAMS/var/Microarray/Affy_data/annotation \
$SBEAMS/tmp/Microarray/Make_MEV_jws_files \
$SBEAMS/tmp/Microarray/Make_MEV_jws_files/jws

chgrp -R sbeams $SBEAMS/tmp/Microarray;
chgrp -R sbeams $SBEAMS/var/Microarray;
chmod -R g+ws $SBEAMS/tmp/Microarray;
chmod -R g+ws $SBEAMS/var/Microarray;

# Pipeline stuff
#sudo /usr/sbin/groupadd affydata
#sudo /usr/sbin/usermod -G affydata apache
chgrp -R affydata $SBEAMS/var/Microarray/Affy_data/delivery
chmod g+s  $SBEAMS/var/Microarray/Affy_data/delivery


#  Stop here; If desired, can copy below and use to load data.
exit;

echo "Fetching sample data"
cd $SBEAMS/lib/refdata/Microarray
wget http://www.sbeams.org/sample_data/Microarray/External_test_data.tar.gz
wget http://www.sbeams.org/sample_data/Microarray/Affy_test_data.tar.gz

echo "Processing sample data"
tar xvfz External_test_data.tar.gz
tar xvfz Affy_test_data.tar.gz
cp External_test_data/HG-U133A_annot.csv $SBEAMS/var/Microarray/Affy_data/annotation/
cp Affy_test_data/HG-U133_Plus_2_annot.csv $SBEAMS/var/Microarray/Affy_data/annotation/
 
# Make the folders to hold the CEL files
mkdir $SBEAMS/var/Microarray/Affy_data/probe_data/external/External_test
mkdir $SBEAMS/var/Microarray/Affy_data/probe_data/200404

cp External_test_data/* $SBEAMS/var/Microarray/Affy_data/probe_data/external/External_test/
cp Affy_test_data/* $SBEAMS/var/Microarray/Affy_data/probe_data/200404/

fi

cd $SBEAMS/lib/scripts/Microarray

echo Starting to load annotation files
./load_affy_annotation_files.pl --run_mode update --file_name $SBEAMS/var/Microarray/Affy_data/annotation/HG-U133A_annot.csv
./load_affy_annotation_files.pl --run_mode update --file_name $SBEAMS/var/Microarray/Affy_data/annotation/HG-U133_Plus_2_annot.csv

echo Running pre-process external data
./Pre_process_affy_info_file.pl --run_mode make_new --info_file $SBEAMS/var/Microarray/Affy_data/probe_data/external/External_test/External_test_data_master.txt

echo Running load affy array
./load_affy_array_files.pl --run_mode add_new

echo Running load RChip 
./load_affy_R_CHP_files.pl --run_mode add_new

