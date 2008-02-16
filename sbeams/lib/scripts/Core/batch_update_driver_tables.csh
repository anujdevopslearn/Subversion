#!/bin/csh

###############################################################################
# Program     : batch_update_driver_tables.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script runs the reload of all configuration files
#               from the top.
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################

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

  ./update_driver_tables.pl $CONFDIR/Immunostain/Immunostain_table_property.txt
  ./update_driver_tables.pl $CONFDIR/Immunostain/Immunostain_table_column.txt

  ./update_driver_tables.pl $CONFDIR/Interactions/Interactions_table_property.txt
  ./update_driver_tables.pl $CONFDIR/Interactions/Interactions_table_column.txt

  ./update_driver_tables.pl $CONFDIR/BioLink/BioLink_table_property.txt
  ./update_driver_tables.pl $CONFDIR/BioLink/BioLink_table_column.txt

  ./update_driver_tables.pl $CONFDIR/Cytometry/Cytometry_table_property.txt
  ./update_driver_tables.pl $CONFDIR/Cytometry/Cytometry_table_column.txt

  ./update_driver_tables.pl $CONFDIR/ProteinStructure/ProteinStructure_table_property.txt
  ./update_driver_tables.pl $CONFDIR/ProteinStructure/ProteinStructure_table_column.txt

  ./update_driver_tables.pl $CONFDIR/PeptideAtlas/PeptideAtlas_table_property.txt
  ./update_driver_tables.pl $CONFDIR/PeptideAtlas/PeptideAtlas_table_column.txt

  ./update_driver_tables.pl $CONFDIR/Ontology/Ontology_table_property.txt
  ./update_driver_tables.pl $CONFDIR/Ontology/Ontology_table_column.txt

  ./update_driver_tables.pl $CONFDIR/Genotyping/Genotyping_table_property.txt
  ./update_driver_tables.pl $CONFDIR/Genotyping/Genotyping_table_column.txt

  ./update_driver_tables.pl $CONFDIR/Oligo/Oligo_table_property.txt
  ./update_driver_tables.pl $CONFDIR/Oligo/Oligo_table_column.txt

  ./update_driver_tables.pl $CONFDIR/Biomarker/Biomarker_table_property.txt
  ./update_driver_tables.pl $CONFDIR/Biomarker/Biomarker_table_column.txt

  ./update_driver_tables.pl $CONFDIR/Glycopeptide/Glycopeptide_table_property.txt
  ./update_driver_tables.pl $CONFDIR/Glycopeptide/Glycopeptide_table_column.txt

  ./update_driver_tables.pl $CONFDIR/SIGID/SIGID_table_property.txt
  ./update_driver_tables.pl $CONFDIR/SIGID/SIGID_table_column.txt

  ./update_driver_tables.pl $CONFDIR/Imaging/Imaging_table_property.txt
  ./update_driver_tables.pl $CONFDIR/Imaging/Imaging_table_column.txt




