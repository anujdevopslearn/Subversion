#!/bin/csh
#
# This script runs the reload of all configuration files from the top
#

  set CONFDIR = "../../conf"

  ./update_driver_tables.pl $CONFDIR/Core/Core_table_property.txt
  ./update_driver_tables.pl $CONFDIR/Core/Core_table_column.txt

  ./update_driver_tables.pl $CONFDIR/Proteomics/Proteomics_table_property.txt
  ./update_driver_tables.pl $CONFDIR/Proteomics/Proteomics_table_column.txt












