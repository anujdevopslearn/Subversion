# Script to build/delete/add constraints to a minimal peptide atlas schema.
# Since the atlas schema relys on Core, BioLink, and Proteomics tables, the 
# script builds those tables as well.
#$Id:$


if [ $SBEAMS  ]
then
  echo "Installation root is $SBEAMS";
else
  echo "Must set SBEAMS environment variable";
  exit;
fi

if [ $DBNAME  ]
then
  echo "Database name is $DBNAME";
else
  echo "Must set DBNAME environment variable";
  exit;
fi

if [ $DBUSER  ]
then
  echo "DBUSER is set to $DBUSER";
else
  echo "Setting DBUSER to script default (may be edited)";
  export DBUSER=sbeams;
fi

if [ $DBPASS  ]
then
  echo "DBPASS is set by enviroment";
else
  echo "Setting DBPASS to script default (may be edited)";
  export DBPASS=sbeams;
fi

cd $SBEAMS/lib/conf/

if [ ! $1 ] 
then 
  echo "Must specify a mode, build, delete, or index"
  exit;
fi

if [ $1 == 'build' ]
then
  echo "create"
  cd Core/
  svn update
  ../../scripts/Core/generate_schema.pl --su --table_p Core_table_property.txt --table_c Core_table_column.txt --des mysql --sch ../../sql/Core/Core --dbpre $DBNAME.
  ../../scripts/Core/runsql.pl -s ../../sql/Core/Core_CREATETABLES.mysql -u $DBUSER -p $DBPASS -i 
  ../../scripts/Core/runsql.pl -s ../../sql/Core/Core_POPULATE.sql -u $DBUSER -p $DBPASS -i 
  ../../scripts/Core/update_driver_tables.pl Core_table_property.txt
  ../../scripts/Core/update_driver_tables.pl Core_table_column.txt
  
  cd ../BioLink/
  svn update
  ../../scripts/Core/generate_schema.pl --su --table_p BioLink_table_property.txt --table_c BioLink_table_column.txt --des mysql --sch ../../sql/BioLink/BioLink --dbpre $DBNAME.
  ../../scripts/Core/runsql.pl -s ../../sql/BioLink/BioLink_CREATETABLES.mysql -u $DBUSER -p $DBPASS -i
  ../../scripts/Core/update_driver_tables.pl BioLink_table_property.txt
  ../../scripts/Core/update_driver_tables.pl BioLink_table_column.txt
  
  cd ../PeptideAtlas/
  svn update
  ../../scripts/Core/generate_schema.pl --su --table_p PeptideAtlas_table_property.txt --table_c PeptideAtlas_table_column.txt --des mysql --sch ../../sql/PeptideAtlas/PeptideAtlas --dbpre $DBNAME.
  ../../scripts/Core/runsql.pl -s ../../sql/PeptideAtlas/PeptideAtlas_CREATETABLES.mysql -u $DBUSER -p $DBPASS -i 
  ../../scripts/Core/update_driver_tables.pl PeptideAtlas_table_property.txt
  ../../scripts/Core/update_driver_tables.pl PeptideAtlas_table_column.txt
  
  cd ../Proteomics/
  svn update
  ../../scripts/Core/generate_schema.pl --su --table_p Proteomics_table_property.txt --table_c Proteomics_table_column.txt --des mysql --sch ../../sql/Proteomics/Proteomics --dbpre $DBNAME.
  ../../scripts/Core/runsql.pl -s ../../sql/Proteomics/Proteomics_CREATETABLES.mysql -u $DBUSER -p $DBPASS -i 
  ../../scripts/Core/update_driver_tables.pl Proteomics_table_property.txt
  ../../scripts/Core/update_driver_tables.pl Proteomics_table_column.txt
  
elif [ $1 == 'delete' ]
then
  echo "destroy"
  ../scripts/Core/runsql.pl -s ../sql/Core/Core_DROPCONSTRAINTS.mysql -u $DBUSER -p $DBPASS -i
  ../../scripts/Core/runsql.pl -s ../../sql/Core/Core_DROP_MANUAL_CONSTRAINTS.sql -u $DBUSER -p $DBPASS -i
  ../scripts/Core/runsql.pl -s ../sql/Core/Core_DROPTABLES.mysql -u $DBUSER -p $DBPASS -i 
  ../scripts/Core/runsql.pl -s ../sql/BioLink/BioLink_DROPCONSTRAINTS.mysql -u $DBUSER -p $DBPASS -i 
  ../scripts/Core/runsql.pl -s ../sql/BioLink/BioLink_DROPTABLES.mysql -u $DBUSER -p $DBPASS -i
  ../scripts/Core/runsql.pl -s ../sql/PeptideAtlas/PeptideAtlas_DROPCONSTRAINTS.mysql -u $DBUSER -p $DBPASS -i 
  ../scripts/Core/runsql.pl -s ../sql/PeptideAtlas/PeptideAtlas_DROPTABLES.mysql -u $DBUSER -p $DBPASS -i 
  ../scripts/Core/runsql.pl -s ../sql/Proteomics/Proteomics_DROPCONSTRAINTS.mysql -u $DBUSER -p $DBPASS -i 
  ../scripts/Core/runsql.pl -s ../sql/Proteomics/Proteomics_DROPTABLES.mysql -u $DBUSER -p $DBPASS -i 

elif [ $1 == 'index' ]
then
  echo "build constraints/indexes"

  cd Core/
  ../../scripts/Core/runsql.pl -s ../../sql/Core/Core_CREATECONSTRAINTS.mysql -u $DBUSER -p $DBPASS -i
  ../../scripts/Core/runsql.pl -s ../../sql/Core/Core_CREATE_MANUAL_CONSTRAINTS.sql -u $DBUSER -p $DBPASS -i

  cd ../BioLink/
  ../../scripts/Core/runsql.pl -s ../../sql/BioLink/BioLink_CREATECONSTRAINTS.mysql -u $DBUSER -p $DBPASS -i 

  cd ../PeptideAtlas/
  ../../scripts/Core/runsql.pl -s ../../sql/PeptideAtlas/PeptideAtlas_CREATECONSTRAINTS.mysql -u $DBUSER -p $DBPASS -i 
  ../../scripts/Core/runsql.pl -s ../../sql/PeptideAtlas/PeptideAtlas_CREATEINDEXES.mysql -u $DBUSER -p $DBPASS -i 

  cd ../Proteomics/
  ../../scripts/Core/runsql.pl -s ../../sql/Proteomics/Proteomics_CREATECONSTRAINTS.mysql -u $DBUSER -p $DBPASS -i 

fi
