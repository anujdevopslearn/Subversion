#!/bin/csh

###############################################################################
# Program     : load_proteomics_experiment.csh
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : Utility wrapper to load_proteomics_experiment.pl
#               Use load_proteomics_experiment.start to run.
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
## BASEDIR is the project level directory location
## EXPLIST is a space-separated list of experiment_tags
## SUBDIR is the search_batch subdirectory (usually biosequence_set_tag)
## UNPACKTGZ is "y" if the .tgz files need to be unpacked
## DOLOAD is "y" if the initial load needs to happen
## DOUPDATE is "y" if the experiment update needs to happen
## EMAILADDR is an email address that will be notified upon completion

setenv BASEDIR "/full/path/to/project"
setenv EXPLIST "experiment_tag"
setenv SUBDIR "search_batch_tag"
# setenv FIXIPI "--fix_ipi"
setenv FIXIPI ""
setenv UNPACKTGZ n
setenv DOLOAD n
setenv DOUPDATE y
setenv EMAILADDR "myemail@mydomain.org"
setenv SBEAMS /full/path/to/sbeams

## end configuration section

date

if ("$UNPACKTGZ" == "y") then
  foreach EXPTAG ( $EXPLIST )
    cd $BASEDIR/$EXPTAG/$SUBDIR
    foreach file ( *.tgz )
      set dir = `echo $file | sed -e 's/\.tgz//'`
      if (! -e $dir && $dir != 'data') then
        echo "Create and cd into $dir"
        mkdir $dir
        cd $dir
        echo tar -zxf ../$file
        tar -zxf ../$file
        cd ..
      endif
    end
  end
endif


cd $SBEAMS/lib/scripts/Proteomics


if ("$DOLOAD" == "y") then
  foreach EXPTAG ( $EXPLIST )
    ./load_proteomics_experiment.pl --experiment_tag $EXPTAG \
      --load $FIXIPI --search_subdir=$SUBDIR
  end
endif


if ("$DOUPDATE" == "y") then
  foreach EXPTAG ( $EXPLIST )
    ./load_proteomics_experiment.pl --experiment_tag $EXPTAG \
      --update_from_summary_files \
      --update_search \
      --update_probabilities \
      #--update_timing \
      --search_subdir=$SUBDIR
  end
endif



echo "$BASEDIR/($EXPLIST) Load complete.  Verify." | mail -s "SBEAMS Load complete" $EMAILADDR


exit

