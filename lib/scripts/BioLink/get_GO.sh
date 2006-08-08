#!/bin/bash
HELP=$( cat <<'SETVAR'
#####################################################################
# Simple script to download Gene Ontology data from godatabase.org
# It also prepares the files for upload to MS-SQL database
#
# It checks for the presence of the latest GO files based on the
# current (system) date. It will not re-download files. You must
# remove old files if you wish to do so (e.g. if you have a corrupt
# or incomplete download)
#
# Optional parameter 'lastmonth' will trigger a download of last
# month''s files. (e.g. in case current month is not available)
#
# You will have to set the $SBEAMS environment variable to a path up
# to and including sbeams (ls shows lib/  scripts/  etc...), and
# $GOARC is an area where the GO source files will be stored and unpacked,
# which is best not under $SBEAMS. (e.g.  /local/data/gene_ontology/ )
#
# Files are downloaded to directory $GOARC/YYYY-MM-01/
#
# This script does NOT load any data into the database.
# 
#####################################################################
SETVAR
)

# Any arguments?
lastmonth=""
showhelp=""
dbtype="mssql"

for i in $* 
do
    if [ "$i" == "help" ]
    then
	showhelp="true"
    elif [ "$i" == "lastmonth" ]
    then
	lastmonth="true"
    elif [ "$i" == "mysql" ]
    then
	dbtype="mysql"
    elif [ "$i" == "mssql" ]
    then
	dbtype="mssql"
    fi
done

if [ "$showhelp" == "true" ]
then
    echo "$HELP"
    exit 
fi


# Check that SBEAMS and GOARC are directories
if [ "$SBEAMS" == "" ]
then
    echo "Please set SBEAMS environment variable"
    exit
elif [ ! -d "$SBEAMS/" ]
then
    echo "SBEAMS environment variable incorrectly set: does not point to a directory.";
    exit
fi

if [ "$GOARC" == "" ]
then
    echo "Please set GOARC environment variable"
    exit
elif [ ! -d "$GOARC/" ]
then
    echo "GOARC environment variable incorrectly set: does not point to a directory.";
    exit
fi


# Set up file names based on current date
if [ "$lastmonth" == "true" ]
then
    MONTH=`date -d 'last month' +%Y-%m-01`
    DATAFILE="go_"`date -d 'last month' +%Y%m`"-assocdb"
else
    MONTH=`date +%Y-%m-01`
    DATAFILE="go_"`date +%Y%m`"-assocdb"
fi
GZFILE=${DATAFILE}-data.gz
TGZFILE=${DATAFILE}-tables.tar.gz

echo "[ cd $GOARC ]"
cd $GOARC


# Are the current files available on the server yet?
RETURNCODE=$(wget -nv --spider http://archive.godatabase.org/full/$MONTH 2>&1)
if [ "$RETURNCODE" == "200 OK" ]
then
    echo "Current month files are available!"
else
    echo "Current month files are NOT available."
    echo "Please check back later, or use the lastmonth parameter to retrieve previous month's files."
    exit 
fi


# Set up month directory
if [ -d "$MONTH/" ]
then
    echo "Directory $MONTH already exists..."
else
    echo "[ mkdir $MONTH ]"
    mkdir $MONTH
fi

echo "[ cd $MONTH ]"
cd $MONTH

# Download data file
if [ -e "$GZFILE" ]
then
    echo "File $GZFILE already exists...NOT downloading"
else
    echo "[ wget -O $GZFILE http://archive.godatabase.org/full/$MONTH/$GZFILE ]"
    wget -O $GZFILE http://archive.godatabase.org/full/$MONTH/$GZFILE
fi

# Download tables file
if [ -e "$TGZFILE" ]
then
    echo "File $TGZFILE already exists...NOT downloading"
else
    echo "[ wget -O $TGZFILE http://archive.godatabase.org/full/$MONTH/$TGZFILE ]"
    wget -O $TGZFILE http://archive.godatabase.org/full/$MONTH/$TGZFILE
fi

# Expand data file
if [ -e "$DATAFILE.mysql" ]
then
    echo "File $DATAFILE.mysql already exists...NOT creating it"
else
    echo "[ gunzip -c $GZFILE > $DATAFILE.mysql ]"
    gunzip -c $GZFILE > $DATAFILE.mysql
fi


# Prepare MS-SQL files for upload to database 
if [ "$dbtype" == "mssql" ]
then

    if [ -d "${DATAFILE}-tables/" ]
    then
	echo "Directory ${DATAFILE}-tables already exists...NOT creating it"
    else
	echo "[ tar -zxvf $TGZFILE ]"
	tar -zxvf $TGZFILE
    fi

    echo "[ cd ${DATAFILE}-tables ]"
    cd ${DATAFILE}-tables

    echo "[ rm *.sql ]"
    rm *.sql


    if [ -e "GO.BCP.bat" ]
    then
	echo "Looks like the GO.BCP files have already been created...NOT running GOMySQL2MSSQL.pl"
    else
	echo "[ $SBEAMS/lib/scripts/BioLink/GOMySQL2MSSQL.pl --in ../${DATAFILE}.mysql --out GO --bcpuser sbeamsadmin --bcppass xxxxxx --bcpdatabase go ]"
	# Replace xxxxxx in the following command with the sbeamsadmin password
	$SBEAMS/lib/scripts/BioLink/GOMySQL2MSSQL.pl \
	    --in ../${DATAFILE}.mysql --out GO \
	    --bcpuser sbeamsadmin --bcppass xxxxxx --bcpdatabase go
    fi


    for file in *.txt
    do
	echo "[ mv $file $file.before ]"
	mv $file $file.before
	echo "[ cat $file.before | sed -e 's/\t\\N/\t/g' | sed -e 's/\\\t/  /g' | unix2dos > $file ]"
	cat $file.before | sed -e 's/\t\\N/\t/g' | sed -e 's/\\\t/  /g' | unix2dos > $file
    done

    echo "[ rm *.before ]"
    rm *.before
fi



# Show path and file info
echo "Directory listing:"
pwd
ls -alrt

exit
