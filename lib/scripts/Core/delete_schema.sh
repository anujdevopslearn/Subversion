#!/bin/bash

# Simple shell script which runs through a series of steps for core,
# biolink, and any other modules specified on the command line.
# Not especially error-tolerant, and meant for initial installs only.

# In order to use, you must specify the user, pass, and db (type) vars below.
# You will also have to set the $SBEAMS environment variable to a path up
# to and including and sbeams installation (ls shows lib, cgi, etc)
# The presumtion is that the user will provide a list of modules to delete,
# excluding BioLink and Core, which are deleted by default and need to go
# in in a particular order (last out, first in).  $* loops through @ARGV

# Script will: Loop through DROP constraints/tables files and generally 
# erase the database.  Use with caution, and never vs. a production database.

# Note: Uses -i flag to ignore errors, but due to dependencies it is 
# sometimes necessary to run script more than once to fully remove all 
# tables.

# Safety catch, must be removed prior to use
echo "Do not run vs. production database!";
exit;

# usage: delete_schema.sh [ module1 ] [ module2, ]

if [ "$SBEAMS" == "" ]
then
  echo "Please set SBEAMS environment variable"
  exit
fi
# Make sure we're in the right place
if [ ! -e "$SBEAMS/lib/perl" ]
then
  echo "Missing needed directory"
  exit
fi

export PATH=$SBEAMS/lib/scripts/Core:$PATH
user='username'
pass="password"
dbtype='mysql'
#db='pgsql'
#db='mssql'

cd $SBEAMS/lib/sql

# DROP stuff to make way for install
for mod in $* BioLink Core
do

  echo Deleting $mod schema elements
  cd $mod
  pwd
  ls

  for cfile in DROPCONSTRAINTS DROP_MANUAL_CONSTRAINTS DROPINDEXES DROPTABLES APD_DROPTABLES
  do
  
    echo Working with $cfile
    if [ -e ${mod}_${cfile}.${dbtype} ]
    then 
      echo Running ${mod}_${cfile}.${dbtype}
      if [ `grep -il '^GO' ${mod}_${cfile}.${dbtype}` ]
      then
        echo GO
        $SBEAMS/lib/scripts/Core/runsql.pl -u $user -p $pass -i --delimit GO -s ${mod}_${cfile}.${dbtype} 
      else
        echo NOGO
        $SBEAMS/lib/scripts/Core/runsql.pl -u $user -p $pass -i -s ${mod}_${cfile}.${dbtype} 
      fi
    elif [ -e "${mod}_${cfile}.sql" ] 
    then
      echo "Running ${mod}_${cfile}.sql";
      if [ `grep -il '^GO' ${mod}_${cfile}.sql` ]
      then
        $SBEAMS/lib/scripts/Core/runsql.pl -u $user -p $pass -i --delimit GO -s ${mod}_${cfile}.sql 
      else
        $SBEAMS/lib/scripts/Core/runsql.pl -u $user -p $pass -i -s ${mod}_${cfile}.sql 
      fi
    else
      echo "${mod}_${cfile}.${dbtype} Not found";
    fi
   
   done
   cd ..
done
