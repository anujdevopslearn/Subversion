#!/bin/csh

date
echo "   Begin Building PeptideAtlas..."

################# variables to use in scripts  ########################

## you'll need to tailor these to your installation:
setenv PIPELINE /directory/holding/pipeline/perl/script
setenv SBEAMS /your/SBEAMS/installation/base/directory
### path to local installation of BLAST matrices
setenv BLAST_MATRICES_PATH "/package/genome/bin/data"
setenv EXPERIMENTS_LIST_PATH $PIPELINE/etc/build_list/$ORGANISM_LABEL/Experiments.list
setenv BUILD_ABS_PATH $PIPELINE/output/$VERSION
setenv BUILD_ABS_DATA_PATH $BUILD_ABS_PATH/DATA_FILES
setenv VERSION Human_NCBI36_July_2006
setenv ORGANISM_NAME Homo_sapiens
setenv ORGANISM_LABEL human
setenv ORGANISM_ABBREV Hs
### subdirectory in ftp.ensembl.org/pub:
setenv ENSEMBL_DIR "release-39/homo_sapiens_39_36a"
### for remote calls to Sanger's database:
setenv ENSMYSQLDBNAME homo_sapiens_core_39_36a
setenv ENSMYSQLDBHOST "kaka.sanger.ac.uk"
setenv ENSMYSQLDBUSER "anonymous"
setenv ENSMYSQLDBPSSWD "youremailaddress@xx.yy"
#######################################################################


### Purge or create working area:
if ( -e "$BUILD_ABS_PATH" ) then
  /bin/rm -fr $BUILD_ABS_DATA_PATH
  /bin/rm -f $BUILD_ABS_PATH/step*.out
  /bin/rm -f $BUILD_ABS_PATH/Experiments.list
else
  mkdir $BUILD_ABS_PATH
endif

cd $BUILD_ABS_PATH

mkdir $BUILD_ABS_DATA_PATH

if ( ! -e "$BUILD_ABS_DATA_PATH" ) then
 echo "ERROR creating $BUILD_ABS_DATA_PATH"
  exit
endif

#### Copy over the list of search_batch_ids and paths to build from
cp -p $EXPERIMENTS_LIST_PATH ${BUILD_ABS_PATH}/Experiments.list


##### Get the latest APD data:
## (this writes APD_Hs_all.tsv, and APD_Hs_all.fasta)
echo "   Get the latest peptide data ..."
( date; $PIPELINE/bin/peptideAtlasPipeline_ensembl.pl \
    --getPeptideList \
    --organism_name $ORGANISM_NAME \
    --organism_abbrev $ORGANISM_ABBREV \
    --min_probability 0.9 \
    --build_abs_path $BUILD_ABS_PATH \
    --build_abs_data_path $BUILD_ABS_DATA_PATH \
; date ) >& step01.out


####### Get the latest ENSEMBL data:
echo "   Get the latest ENSEMBL data ..."
( date; $PIPELINE/bin/peptideAtlasPipeline_ensembl.pl \
    --getEnsembl \
    --organism_name $ORGANISM_NAME \
    --ensembl_dir $ENSEMBL_DIR \
    --build_abs_data_path $BUILD_ABS_DATA_PATH \
; date ) >& step02.out


##### BLAST the APD peptides against the ENSEMBL data:
##(writes blast_APD_ensembl_out.txt)
echo "   BLAST the APD peptides against the ENSEMBL protein file..."
( date; $PIPELINE/bin/peptideAtlasPipeline_ensembl.pl \
    --BLASTP \
    --organism_name $ORGANISM_NAME \
    --organism_abbrev $ORGANISM_ABBREV \
    --build_abs_data_path $BUILD_ABS_DATA_PATH \
    --blast_matrices_path $BLAST_MATRICES_PATH \
; date ) >& step03.out


### Align peptides with protein reference database, then calc coords
## (writes APD_ensembl_hits.tsv, coordinate_mapping.txt)
echo "   Align peptides with protein reference database, then calc coords..."
( date; $PIPELINE/bin/peptideAtlasPipeline_ensembl.pl \
    --BLASTParse \
    --getCoordinates \
    --build_abs_path $BUILD_ABS_PATH \
    --build_abs_data_path $BUILD_ABS_DATA_PATH \
    --mysqldbhost $ENSMYSQLDBHOST \
    --mysqldbname $ENSMYSQLDBNAME \
    --mysqldbuser $ENSMYSQLDBUSER \
    --mysqldbpsswd $ENSMYSQLDBPSSWD \
    --coord_cache_dir "$PIPELINE/new_cache" \
; date ) >& step05.out


##### Run lostAndFound to make lists of peptides found and lost in Ensembl search
$PIPELINE/bin/peptideAtlasPipeline_ensembl.pl \
    --lostAndFound \
    --build_abs_data_path $BUILD_ABS_DATA_PATH \
    --organism_abbrev $ORGANISM_ABBREV
echo "   Done"
date

