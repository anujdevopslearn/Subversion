#!/bin/csh

  if (0 == 1) then
    mkdir SBEAMS
    mkdir SBEAMS/Connection
  endif


  set HTMLROOT=/sbeams/doc

  set INDIR=../../lib/perl/SBEAMS
  set OUTDIR=SBEAMS

  foreach file ( Connection )
    pod2html --title=$file --infile=$INDIR/$file.pm --outfile=$OUTDIR/$file.html \
      --index --recurse
  end



  set INDIR=../../lib/perl/SBEAMS/Connection
  set OUTDIR=SBEAMS/Connection

  foreach file ( Authenticator DBConnector DBInterface ErrorHandler HTMLPrinter Settings TableInfo Tables )
    pod2html --infile=$INDIR/$file.pm --outfile=$OUTDIR/$file.html \
      --index --recurse --libpods=Authenticator:DBConnector:DBInterface \
      --title foo
  end



