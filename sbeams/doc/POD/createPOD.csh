#!/bin/csh


  #### Create all needed subdirectories
  foreach dir ( SBEAMS SBEAMS/Connection )
    if ( ! -d $dir ) then
      mkdir $dir
    endif
  end


  #### Define needed source directories
  set HTMLROOT=/sbeams/doc
  set INDIR=../../lib/perl/SBEAMS
  set OUTDIR=SBEAMS


  #### For each module, create the documentation
  foreach file ( Connection )
    pod2html --title=$file \
      --infile=$INDIR/$file.pm --outfile=$OUTDIR/$file.html \
      --index --recurse
  end


  #### Make the POD for the various modules in Connection
  set INDIR=../../lib/perl/SBEAMS/Connection
  set OUTDIR=SBEAMS/Connection

  foreach file ( Authenticator DBConnector DBInterface ErrorHandler \
                 HTMLPrinter Permissions PubMedFetcher Settings \
                 TableInfo Tables Utilities )
    pod2html --infile=$INDIR/$file.pm --outfile=$OUTDIR/$file.html \
      --index --recurse --libpods=Authenticator:DBConnector:DBInterface \
      --title SBEAMS::Connection::$file
  end



