#!/bin/csh
#
# This script runs the reload of all configuration files from the top
#

  set CONFDIR = "../../conf"

  if ( 0 == 1 ) then
    ./update_driver_tables.pl --delete_existing
  endif


  ./update_driver_tables.pl $CONFDIR/Core/Core_table_property.txt
  ./update_driver_tables.pl $CONFDIR/Core/Core_table_column.txt

  ./update_driver_tables.pl $CONFDIR/Proteomics/Proteomics_table_property.txt
  ./update_driver_tables.pl $CONFDIR/Proteomics/Proteomics_table_column.txt
  ./update_driver_tables.pl $CONFDIR/Proteomics/Proteomics_table_column_manual.txt

  ./update_driver_tables.pl $CONFDIR/Microarray/Microarray_table_property.txt
  ./update_driver_tables.pl $CONFDIR/Microarray/Microarray_table_column.txt
  ./update_driver_tables.pl $CONFDIR/Microarray/Microarray_table_column_manual.txt

  ./update_driver_tables.pl $CONFDIR/Inkjet/Inkjet_table_property.txt
  ./update_driver_tables.pl $CONFDIR/Inkjet/Inkjet_table_column.txt
  ./update_driver_tables.pl $CONFDIR/Inkjet/Inkjet_table_column_manual.txt

  ./update_driver_tables.pl $CONFDIR/PhenoArray/PhenoArray_table_property.txt
  ./update_driver_tables.pl $CONFDIR/PhenoArray/PhenoArray_table_column.txt

  ./update_driver_tables.pl $CONFDIR/SNP/SNP_table_property.txt
  ./update_driver_tables.pl $CONFDIR/SNP/SNP_table_column.txt

  ./update_driver_tables.pl $CONFDIR/Biosap/Biosap_table_property.txt
  ./update_driver_tables.pl $CONFDIR/Biosap/Biosap_table_column.txt

  ./update_driver_tables.pl $CONFDIR/BEDB/BEDB_table_property.txt
  ./update_driver_tables.pl $CONFDIR/BEDB/BEDB_table_column.txt

  ./update_driver_tables.pl $CONFDIR/GEAP/GEAP_table_property.txt
  ./update_driver_tables.pl $CONFDIR/GEAP/GEAP_table_column.txt







