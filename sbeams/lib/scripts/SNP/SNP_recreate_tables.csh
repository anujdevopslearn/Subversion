#!/bin/csh

  if ( -e ../sql/SNP_Create_Tables.sql ) then
    echo "Dropping and recreating SNP tables"
    cat ../sql/SNP_Create_Tables.sql | sqsh -S mssql -U kdeutsch -P kad66 -D SNP
  else
    echo "Cannot find SNP_Create_Tables.sql"
  endif


