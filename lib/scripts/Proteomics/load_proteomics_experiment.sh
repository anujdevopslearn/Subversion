#!/bin/bash

###############################################################################
# Program     : load_proteomics_experiment.sh
# Author      : Sandra Loevenich <loevenich@imsb.biol.ethz.ch>
# $Id$
#
# Description : Utility wrapper to load_proteomics_experiment.pl
#               Similar to load_proteomics_experiment.csh (but bash)
#    
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################

## Configure the following variables 
##
## EXPLIST is a space-separated list of experiment_tags
## SEQUENCE is the name of the sequence searched against
## SEARCHBATCH is the search_batch subdirectory
## UNPACKTGZ is "y" if the .tgz files need to be unpacked
## DOLOAD is "y" if the initial load needs to happen
## DOUPDATE is "y" if the experiment update needs to happen
## EMAILADDR is an email address that will be notified upon completion

set -e  # exit immediately if any command returns an error


## EDITME 
PROJECT="my project identifier"
EXPLIST="exp_747"
SEQUENCE="Dm_ENS_27.3c"
SEARCHBATCH="tppdefault"
ANALYSIS=${SEQUENCE}_${SEARCHBATCH}




FIXIPI="" 
UNPACKTGZ="y"
DOLOAD="y"
DOUPDATE="y"


EMAILADDR="myname@mydomain.org"

BASEDIR="/my/tpp/output/path/"
SBEAMS="/my/sbeams/installation/"




date


if [ "$UNPACKTGZ" == "y" ]; then

  for EXPTAG in $EXPLIST 
  do
    cd $BASEDIR/$EXPTAG/$ANALYSIS
    for file in `ls *.tgz`
    do
      dirname=$BASEDIR/$EXPTAG/$ANALYSIS/${file/.tgz/ }
      if [ ! -d $dirname ]; then
        echo "log> creating $dirname"
        mkdir $dirname
      else
        echo "log> $dirname already exists"
      fi
        echo "log> unpacking $file"
        cd $dirname
        tar -zxf ../$file
        cd -
    done
  done

  echo "$BASEDIR/($EXPLIST) Step 1 untaring complete." | mail -s "$PROJECT $EXPLIST SBEAMS -unpacking- complete" $EMAILADDR
  echo "$BASEDIR/($EXPLIST) Step 1 untaring complete." | mail -s "$PROJECT $EXPLIST SBEAMS -unpacking- complete" $EMAILADDR2

fi



cd $SBEAMS/lib/scripts/Proteomics


if [ "$DOLOAD" == "y" ]; then
  for EXPTAG in $EXPLIST 
  do
   ./load_proteomics_experiment.pl --experiment_tag $EXPTAG --load $FIXIPI --search_subdir=$ANALYSIS
  done

  echo "$BASEDIR/($EXPLIST) Step 2 DOLOADing complete." | mail -s "$PROJECT $EXPLIST SBEAMS -loading- complete" $EMAILADDR
  echo "$BASEDIR/($EXPLIST) Step 2 DOLOADing complete." | mail -s "$PROJECT $EXPLIST SBEAMS -loading- complete" $EMAILADDR2

fi



if [ "$DOUPDATE" == "y" ]; then
  for EXPTAG in $EXPLIST 
  do
    ./load_proteomics_experiment.pl --experiment_tag $EXPTAG \
      --update_from_summary_files \
      --update_search \
      --update_probabilities \
      --search_subdir=${ANALYSIS} 


  done

  echo "$BASEDIR/($EXPLIST) step 3 DOUPDATEing complete." | mail -s "$PROJECT $EXPLIST SBEAMS -updating- complete" $EMAILADDR
  echo "$BASEDIR/($EXPLIST) step 3 DOUPDATEing complete." | mail -s "$PROJECT $EXPLIST SBEAMS -updating- complete" $EMAILADDR2

fi




exit

