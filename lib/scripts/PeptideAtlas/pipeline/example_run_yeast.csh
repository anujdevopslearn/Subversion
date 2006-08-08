#!/bin/csh

date
echo "   Begin building PeptideAtlas..."

################# variables to use in scripts  ########################
## you'll need to tailor these to your installation:
setenv PIPELINE /directory/holding/pipeline/perl/script
setenv SBEAMS /your/SBEAMS/installation/base/directory
setenv EXPERIMENTS_LIST_PATH $PIPELINE/etc/build_list/$ORGANISM_LABEL/Experiments_tiny_test.list
### path to local installation of BLAST matrices
setenv BLAST_MATRICES_PATH "/package/genome/bin/data"
setenv VERSION Yeast_SGD_Feb_2006
setenv ORGANISM_NAME Yeast
setenv ORGANISM_LABEL yeast
setenv ORGANISM_ABBREV Sc
setenv BUILD_ABS_PATH $PIPELINE/output/$VERSION
setenv BUILD_ABS_DATA_PATH $BUILD_ABS_PATH/DATA_FILES
setenv PROT_FTP_ADDR 'ftp://genome-ftp.stanford.edu/pub/yeast/data_download/sequence/genomic_sequence/orf_protein/orf_trans_all.fasta.gz'
setenv CHROM_FTP_ADDR 'ftp://genome-ftp.stanford.edu/pub/yeast/data_download/chromosomal_feature/SGD_features.tab'
#######################################################################


#### Purge or create working area:
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

##### Copy over the list of search_batch_ids and paths to build from
cp -p $EXPERIMENTS_LIST_PATH ${BUILD_ABS_PATH}/Experiments.list


###### Get the latest APD data:
### (this writes APD_Hs_all.tsv, and APD_Hs_all.fasta)
echo "   Get the latest peptide data ..."
( date; $PIPELINE/bin/peptideAtlasPipeline_yeast.pl \
    --getPeptideList \
    --organism_name $ORGANISM_NAME \
    --organism_abbrev $ORGANISM_ABBREV \
    --min_probability 0.9 \
    --build_abs_path $BUILD_ABS_PATH \
    --build_abs_data_path $BUILD_ABS_DATA_PATH \
; date ) >& step01.out


######## Get the latest Protein data:
echo "   Get the latest protein data ..."
( date; $PIPELINE/bin/peptideAtlasPipeline_yeast.pl \
    --getProteinSet \
    --prot_ftp_addr $PROT_FTP_ADDR \
    --organism_name $ORGANISM_NAME \
    --build_abs_data_path $BUILD_ABS_DATA_PATH \
; date ) >& step02.out


###### BLAST the APD peptides against the ENSEMBL data:
###(writes blast_APD_Yeast_out.txt )
echo "   BLAST the APD peptides against the ENSEMBL protein file..."
( date; $PIPELINE/bin/peptideAtlasPipeline_yeast.pl \
    --BLASTProteins \
    --organism_name $ORGANISM_NAME \
    --organism_abbrev $ORGANISM_ABBREV \
    --build_abs_data_path $BUILD_ABS_DATA_PATH \
    --blast_matrices_path $BLAST_MATRICES_PATH \
; date ) >& step03.out


####  parse the BLAST results into file
### (writes APD_Yeast_hits.tsv)
echo "   Parse BLAST results..."
( date; $PIPELINE/bin/peptideAtlasPipeline_yeast.pl \
    --parseBLASTHits \
    --organism_name $ORGANISM_NAME \
    --organism_abbrev $ORGANISM_ABBREV \
    --build_abs_data_path $BUILD_ABS_DATA_PATH \
; date ) >& step04.out

#### Align peptides with protein reference database, then calc coords
### (writes APD_Sc_hits.tsv, coordinate_mapping.txt)
echo "   Align peptides with protein reference database, then calc coords..."
( date; $PIPELINE/bin/peptideAtlasPipeline_yeast.pl \
    --getCoordinates \
    --organism_name $ORGANISM_NAME \
    --build_abs_data_path $BUILD_ABS_DATA_PATH \
    --chrom_ftp_addr $CHROM_FTP_ADDR \
; date ) >& step05.out


##### Run lostAndFound to make lists of peptides found and lost in Ensembl search
$PIPELINE/bin/peptideAtlasPipeline_yeast.pl \
    --lostAndFound \
    --build_abs_data_path $BUILD_ABS_DATA_PATH \
    --organism_abbrev $ORGANISM_ABBREV \
    --organism_name $ORGANISM_NAME
echo "   Done"
date
