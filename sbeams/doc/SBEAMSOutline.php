<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<HTML>
<?php
  /* $Id$ */
  $TITLE="SBEAMS Documentation";

  include("../includes/style.inc.php");

  include("../includes/header.inc.php");

  include("../includes/navbar.inc.php");
?>



<!-- --------------------------- Main Page Content ------------------------ -->

<table border=0 width="100%" bgcolor="#ffffff" cellpadding=10>
<tr><td align="top">



<H2>SBEAMS and the Data Management Framework for ISB</H2>

2001-06-25  Eric Deutsch<BR>
2002-07-23  Revised by Eric Deutsch<BR>

<P>The Systems Biology Experiment Analysis Management System (SBEAMS) is
being designed as a framework for collecting, exploring, and exporting
data produced by a variety of biological experiments and data.</P>

<P>The framework is intended to be flexible for use with a number of
different experiments.  However, it is not necessarily about
integrating all different types of data from the beginning and forcing
it to fit in a single schema.  It seems to be generally the case that
for exploratory, scientific work, *consolidating* data in a way that
makes it easy for ad hoc queries is more successful than trying to
integrate disparate data sets from the beginning into a single schema.</P>

<P>Relational databases are excellent tools for this since those with
even basic experience at writing SQL queries can begin to explore the
data in their own way, not just in the ways for which a precooked
interface exists.</P>

<P>At its core, SBEAMS is not a single program, but rather a set of
software tools designed to get data in and out of many evolving
relational database schemas.</P>

<P>The code is designed around several Perl modules which handle most
of a communication with the relational database engine and also
provide a consistent Web front end, although the interface can also be
used from the UNIX command-line.  There's no reason certain tools
couldn't be written in Java, ROOT, etc. and made to work with the
system, although likely not through a web front end.</P>

<P>The primary interface is designed around Perl CGI scripts (ideally
very few of them, where much of the work is done by the modules or by
metadata in driver tables.)  Perl is flexible, easy to learn, supports
object oriented programming, and is very popular in the biology
community.  The drawback here is that HTML offers a rather clunky
interface, but the overwhelming advantage is that it is easily
accessible to any computer or platform without software installation,
and development in multiple parallel systems on the same server is
easy.  Even as the framework evolves rapidly, the latest version is
always available.</P>

<P>The currently envisioned components of SBEAMS:</P>
<PRE>
  - SBEAMS Core (Handles RDBMS communication, user authentication, group
                privileges, audit tracking, data-munging tools, etc.)
  - SBEAMS - Microarray  (The initial proof-of-concept target experiment
                type.  Includes data management, pipeline processing, and
                eventually analysis and export to/from the new standard
                designed to hold microarray data, MAGE-ML.)
  - SBEAMS - Inkjet (A nearly identical sister of SBEAMS - Microarray with
                cusomization and separation for the Tech Dev Inkjet setup)
  - SBEAMS - Proteomics (A system that can ingest the standard Ion Trap
                + Sequest search data products and allow exploration and
                annotation of one or more datasets)
  - SBEAMS - SNP (A system that currently allows careful curation of
                SNP data from external data sources like dbSNP,
                Celera, HGBASE in regions of local interest for the
                Illumina collaboration.  The new SNP Genotyping
                management and data pipeline will also be implemented
                in this module.
  - SBEAMS - Biosap (A system that ingests data from Featurama, a program
                that generated oligos from an input genome and BLASTs
                them against a possibly-different genome.  The oligos
                loaded into the database can then be explored to
                select an optimum set of oligos for printing onto an
                array
  - SBEAMS - BEDB (The Brain Expression DataBase.  Manage a project which
                has collected a large number of ESTs from many sources and
                aim to define a transcriptome of the brain.  Loading and
                analysis tools plus a web front end to the data is part of
                this module.
  - SBEAMS - Phenoarray (The Phenotype Array or Macroarray database designed
                for the Yeast group and their growth/invasion/adhesion
                experiment)
  - SBEAMS - GEAP  (The Gene Expression Analysis Package is an object-
                oriented set of tools that Tim brought from MIT.
                There were plans to modify this for a database
                back-end, but this is on hold for the moment.
  - SBEAMS - Tools  (A module for hosting miscellaneous tools that want to
                take advantage of user authentication and RDBMS back end)

  - SBEAMS - ?  (Future packages can be added using the existing RDBMS calls,
                authentication, permissions management and Web CGI tools to
                create a management system for additional experiments)
  - SBEAMS - Sample ?  (Once the experiment process metadata and output
                data are collected and in the same place, it is desirable
                to house the detailed data about samples in tables on the
                same server for easy correlation.  But everyone's sample
                data is different so this is tricky.  This is definitely
		a interesting future project)
  - SBEAMS - JDRF ? (A future possible JDRF central database, housing a
                number of different data for all JDRF investigators)
</PRE>


<BR>
<BR>
<BR>



<?php
  include("../includes/footer.inc.php");
?>

