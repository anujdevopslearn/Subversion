#!/bin/bash

# Simple script to setup an sbeams directory structure.

# You will have to set the $SBEAMS environment variable to a path up
# to and including but not including sbeams installation (ls shows sbeams)

# Script will: Set up various directories and symlinks, and the sbeamscommon
# directory.  It will attempt to modify Core_POPULATE.sql to hold user's NIS
# info, but this is sketchy.  If given the single argument 'download', will try
# to fetch the latest version of sbeams from the sbeams.org site.

# Will set up a main sbeams and a dev1 dev branch.

# Requires sudo access; not a surprise since we need to chown and whatnot.


if [ "$SBEAMS" == "" ]
then
  echo "Please set SBEAMS environment variable"
  exit
fi
arg=""
for i in $* 
do
  arg=$i
done
  

if [ ! -d "$SBEAMS/sbeams" ]
then
  echo "You must first install the codebase";
  if [ "$arg" == "download" ]
  then
    wget http://www.sbeams.org/download/sbeams-0.22.0.tar.gz
    tar xvfz sbeams-0.22.0.tar.gz
  else
    exit;
  fi
fi

echo Clean up...
cd $SBEAMS
sudo rm -Rf sbeamscommon/ dev1/
cd sbeams
sudo rm -f tmp var doc/includes lib/conf/Core/AvailableModules.conf lib/conf/SBEAMS.conf
find lib/refdata/Microarray/*data* -exec rm -Rf {} \;


echo "Setting up sbeamscommon"
cd $SBEAMS
mkdir sbeamscommon
cd sbeamscommon

# Set up tmp spaces
mkdir tmp tmp/images
mkdir images images/tmp
sudo chmod a+rw images/tmp
sudo chmod -R a+rw tmp

# Set up shared conf area
mkdir lib lib/conf lib/conf/Core
touch lib/conf/Core/AvailableModules.conf
if [ -e /tmp/staging/SBEAMS.conf ] 
then
  echo "using stored config file"
  cp /tmp/staging/SBEAMS.conf lib/conf/SBEAMS.conf
else
  cp $SBEAMS/sbeams/lib/conf/SBEAMS.conf.template lib/conf/SBEAMS.conf
fi

# Set up shared var
mkdir var var/resultsets var/logs var/upload var/sessions
touch var/logs/debug.log var/logs/info.log var/logs/warn.log var/logs/error.log
sudo chmod -R g+w var
cd $SBEAMS 
sudo chmod -R g+w sbeamscommon/lib/conf
sudo chown -R apache:sbeams sbeamscommon

# Use the common stuff
cd sbeams
ln -s includes doc/includes
ln -s $SBEAMS/sbeamscommon/var .
ln -s $SBEAMS/sbeamscommon/tmp .
ln -s $SBEAMS/sbeamscommon/images/tmp images/tmp
ln -s $SBEAMS/sbeamscommon/lib/conf/SBEAMS.conf lib/conf
ln -s $SBEAMS/sbeamscommon/lib/conf/Core/AvailableModules.conf lib/conf/Core

if [ -e /tmp/staging/Core_POPULATE.sql ]
then
  cp /tmp/staging/Core_POPULATE.sql $SBEAMS/sbeams/lib/sql/Core
fi
perl -pi -e '$name=`whoami`;chomp $name;s/NISusername/$name/' $SBEAMS/sbeams/lib/sql/Core/Core_POPULATE.sql
perl -pi -e '$name=`whoami`;chomp $name; $name=`crypt.pl $name`;chomp $name;s/PutOutputOfcrypt\.plHere/$name/' $SBEAMS/sbeams/lib/sql/Core/Core_POPULATE.sql

cd $SBEAMS/sbeams/doc/POD
./createPOD.csh

# Why use dev1 first?
cd $SBEAMS
mkdir dev1
cd dev1/
echo Copying codebase...
cp -a ../sbeams .

