#!/bin/bash

# Safety catch, must be removed prior to use
echo "Do not run vs. production database!";

# Simple shell script which runs through a series of steps for core,
# biolink, and any other modules specified on the command line.
# Not especially error-tolerant, and meant for initial installs only.

# In order to use, you must specify the user, pass, and db (type) vars below.
# You will also have to set the $SBEAMS environment variable to a path up
# to and including and sbeams installation (ls shows lib, cgi, etc)
# The presumtion is that the user will provide a list of modules to install,
# excluding BioLink and Core, which are installed by default and need to go
# in in a particular order (last out, first in).  $* loops through @ARGV

# Script will: generate_schema, runsql.pl on all schema/populate files, 
# populate driver tables, and insert initial 'refdata'.

# Set some variables appropriate to this installation
user='database'
pass='password'
db='mysql'

# Allow these to be set via enviroment variables, which have precedence
if [ "$DBUSER" != "" ]
then
  user="$DBUSER";
fi
if [ "$DBPASS" != "" ]
then
  pass="$DBPASS";
fi
if [ "$DBTYPE" != "" ]
then
  db="$DBTYPE";
fi

if [ "$SBEAMS" == "" ]
then
  echo "Please set SBEAMS environment variable"
  exit
fi
base="$SBEAMS"
if [ ! -e "${base}/lib/perl" ]
then
  echo "Missing needed directory"
  exit
fi


echo "Are you sure you want to continue?  10 seconds to press cntl-C and stop."
sleep 10

#for mod in Core BioLink $*
#do
#  $SBEAMS/lib/scripts/Core/addModule.pl $mod
#done
#exit

# CREATE tables and whatnot
for mod in Core BioLink $*
do
  if [ ! -e ${base}/lib/sql/$mod ] 
  then
    mkdir ${base}/lib/sql/$mod
    chmod a+rw ${base}/lib/sql/$mod
  fi

  cd ${base}/lib/conf/$mod
  echo "Generating schema files for $mod"
  ${base}/lib/scripts/Core/generate_schema.pl --table_p ${mod}_table_property.txt --table_c ${mod}_table_column.txt --schema ../../sql/${mod}/${mod} -m $mod --dest $db

  echo Building $mod schema elements
  cd ../../sql/$mod

  for cfile in CREATETABLES POPULATE CREATECONSTRAINTS CREATE_MANUAL_CONSTRAINTS ADD_MANUAL_CONSTRAINTS CREATEINDEXES APD_CREATETABLES APD_CREATEINDEXES
  do
  
    if [ -e "${mod}_${cfile}.${db}" ]
    then 

      echo Running ${mod}_${cfile}.${db};

      if [ `grep -il '^GO' ${mod}_${cfile}.${db}` ]
      then
        echo GO
        $SBEAMS/lib/scripts/Core/runsql.pl -u $user -p $pass -i --delimit GO -s ${mod}_${cfile}.${db}
      else
        echo NOGO
        $SBEAMS/lib/scripts/Core/runsql.pl -u $user -p $pass -i -s ${mod}_${cfile}.${db}
      fi

    elif [ -e "${mod}_${cfile}.sql" ]
    then 
      echo "Running ${mod}_${cfile}.sql";

      if [ `grep -il '^GO' ${mod}_${cfile}.sql` ]
      then
        echo GO
        $SBEAMS/lib/scripts/Core/runsql.pl -u $user -p $pass -i --delimit GO -s ${mod}_${cfile}.sql
      else
        echo NOGO
        $SBEAMS/lib/scripts/Core/runsql.pl -u $user -p $pass -i -s ${mod}_${cfile}.sql
      fi

    else
      echo "${mod}_${cfile}.xxx Not found";
    fi
   
   done
   cd ..
done
# Load driver tables
echo Loading driver tables
cd ../conf
for mod in Core BioLink $*
do
  cd $mod
  for driver in table_property.txt table_column.txt table_column_manual.txt
  do
    if [ -e ${mod}_${driver} ]
    then
    ${base}/lib/scripts/Core/update_driver_tables.pl ${mod}_${driver}
    fi
  done
  cd ..
done

# Load xml data
echo Loading xml data
cd ../refdata
for mod in Core BioLink $*
do
  if [ -e $mod ]
  then
    cd $mod
    for xml in *.xml
    do
      echo Loading $xml
      if [ $xml == "MGED_ontolgy_tables.xml" ]
      then
        ${base}/lib/scripts/Core/DataImport.pl --ignorePKs -s ${xml}
      else
        ${base}/lib/scripts/Core/DataImport.pl -s ${xml}
      fi
    done
    cd ..
  fi
  if [ "$mod" != "Core" ]
  then
    $SBEAMS/lib/scripts/Core/addModule.pl $mod
  fi
done

