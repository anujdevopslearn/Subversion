<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<HTML>
<?php
  /* $Id$ */
  $TITLE="SBEAMS Documentation";

  include("includes/style.inc.php");

  include("includes/header.inc.php");

  include("includes/navbar.inc.php");
?>



<!-- --------------------------- Main Page Content ------------------------ -->

<table border=0 width="100%" bgcolor="#ffffff" cellpadding=10>
<tr><td align="top">

<H2>SBEAMS Driver Tables</H2>

<H3>Overview:</H3>

<P>The SBEAMS driver tables are two tables within the Core module schema that store detailed information about the tables and columns in a given module.  In addition to basic schema information such as table names, key columns, column names and data types, these tables hold information that allow them to be handled generically by a number of SBEAMS modules and scripts.  The table names are table_property and table_column, and the information to populate them is stored in tab-delimited text files in the SBEAMS directory structure under sbeams/lib/conf.  Each module has its own pair of files, and they are loaded into the database using a perl script called update_driver_tables.pl.  See below for more detail on these subjects. </P>

<H3>Use of driver table info in SBEAMS:</H3>

<UL>
 <LI>Used to create SQL to build schema.
 <LI>ManageTable scripts use info to automatically generate forms for INSERT and UPDATE of values into certain tables. 
 <UL>
   <LI>Which fields to render on the form.
   <LI>What INPUT types to render the field as (TEXT, SELECT, etc).
   <LI>How to prepare SQL stmts to INSERT/UPDATE, e.g. put quotes on strings but not integers.
   <LI>Which fields are required.
   <LI>Unique constrained columns.
 </UL>
 <LI>Association of tables into 'table groups', used to grant user/group access to resources.
 <LI>Store table names as variables of the form $TBPR_SAMPLE for SQL statement construction.  Variables are eval'd at runtime.
 </UL>

<H3>Table Property:</H3>

<P>Each module has a table property file, which stores information about tables in that module's schema.  For instance for the Proteomics module the file is:
<BR>
<BR>
sbeams/lib/conf/Proteomics/Proteomics_table_property.txt
<BR>
<BR>
The following section describes the various columns in the file, each of which has a corresponding column in the driver table itself.  See below for instructions on updating information in these files and in the table_property table in the database.

<PRE>
table_property:

 A table_name: a unique name among all SBEAMS modules.  Use module prefix before database
        table name
 B Category: Friendly title of the table
 C table_group: a table group for which access security is defined
 D manage_table_allowed: Set to YES if the ManageTable.cgi program is allowed to drive modifications
        to this table
 E db_table_name: a Perl variable for the physical table name.  Should be
        $TB{module prefix}_TABLE_NAME
 F PK_column_name: column name of the primary autogen key
 G multi_insert_column: If this table supports multi-insert logic, set to column name
 H table_url: actual URL used to manage this table.  DO NOT CHANGE
 I manage_tables: a comma-separated list of tables that should be managed as a group
 J next_step: comma-separated list of tables that might be managed next after a record inserted here
</PRE>


<H3>Table Column:</H3>

<P>Each module has a table column file, which stores information about the columns in each of the tables in that module's schema.  For instance for the Proteomics module the file is:
<BR>
<BR>
sbeams/lib/conf/Proteomics/Proteomics_table_column.txt
<BR>
<BR>
The following section describes the various columns in the file, each of which has a corresponding column in the driver table itself.  See below for instructions on updating information in these files and in the table_column table in the database.

<PRE>

table_column:
 A table_name: a unique name among all SBEAMS modules.  Must match entry in sbeams_table_property
 B column_number: numerical ordered index of columns so order is preserved
 C column_name: column name in the table
 D column_title: a friendly title that appears in the form
 E datatype: datatype of column
 F scale: scale (e.g. length for VARCHAR) of column
 G precision: precision (e.g. number of decimal places for NUMERIC) of column
 H nullable: if column is defined as NULL or NOT NULL
 I default_value: column default value for database
 J is_auto_inc: Y if this is an autogen columns (IDENTITY, SERIAL, AUTO_GEN, etc.)
 K fk_table: If column is a foreign key, what table does it refer to
 L fk_column_name: If column is a foreign key, what column in the remote table does it refer to
 M is_required: Does the ManageTable form require that this have some value
 N input_type: What type of HTML form widget type for entry (text, textarea, textdate, optionlist,
         multioptionlist,scrolloptionlist,file,fixed)
 O input_length: Size of the HTML form widget if appropriate
 P onChange: text for JavaScript onChange code for this widget
 Q is_data: Y if this is a column that should appear on the form (as opposed to housekeeping column)
 R is_displayed: Y column should be displayed in a VIEW mode.
                 N column should not be displayed.
                 P Column is private, and should be hidden on forms unless user is owner or admin
                 2 Column should be displayed if view mode is medium detail.
 S is_key_field: combination of Y columns will be checked for uniqueness before insertion
 T column text: Friendly descriptive text that appears on the form for this field
 U optionlist_query: SQL query which populates an optionlist
 V url: when this field is displayed in a table, what type of URL is attached to the data
         (pkDEFAULT means that this column is the referencing PK, SELF means column is URL itself)

</PRE>


<H3>Updating driver tables:</H3>

<P>When CREATEing or ALTERing a table, or simply updating any of the associated information in an existing table, the first step is to edit the MOD_table_property.txt and/or MOD_table_column.txt files.  The format is tab-delimited text, and some of the fields may be empty, so it is difficult to edit these files with a simple text editor.  It is recommended that you a spreadsheet application such as open office or excel to make edits.  Once you have made the appropriate changes, you should update the information stored in the database but running the following commands from the sbeams/lib/conf/MODULE directory:
<BR>
<BR>
../../scripts/Core/update_driver_tables.pl MODULE_table_property.txt
<BR>
../../scripts/Core/update_driver_tables.pl MODULE_column_property.txt
<BR>
<BR>
It is not necessary to run the script on the table_property file if you have not made changes there, but if both have changed it is preferable that the table_property file be run *after* the table_column file, to aviod a slight possiblity of users seeing information about a seemingly columnless table.  Some modules have an additional driver table file called MODULE_column_property_MANUAL.txt.  If such a file exists in a the module of interest, it must be run after running the table and column property file updates:
<BR>
<BR>
../../scripts/Core/update_driver_tables.pl MODULE_column_property_MANUAL.txt
<BR>
<BR>

</P>

<?php
  include("includes/footer.inc.php");
?>

