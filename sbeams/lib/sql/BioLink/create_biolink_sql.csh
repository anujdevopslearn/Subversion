#!/bin/csh

setenv SBEAMS /net/dblocal/www/html/devNK/sbeams
cd $SBEAMS/lib/scripts/Core

foreach dbtype ( mssql mysql pgsql )
  ./generate_schema.pl --table_prop ../../conf/BioLink/BioLink_table_property.txt \
  --table_col ../../conf/BioLink/BioLink_table_column.txt --schema_file \
  ../../sql/BioLink/BioLink --destination_type $dbtype
end
