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



<H2>SBEAMS Security Model</H2>

There are 6 levels of privilege:

<PRE>
privilege_id name               comment
------------ ------------------ ---------------------------------------------- 
10           administrator      Has full rights to nearly everything
20           data_modifier      Is allowed to modify anyone else's records
25           data_groupmodifier Is allowed to modify records written with
                                the current work group
30           data_writer        Is only allowed to insert new records
40           data_reader        Is only allowed to read records
50           none               Has no privilege over a given object
</PRE>

<P>Each user may belong to zero or more work groups.  The user may have
one of the 6 levels of privilege within that group.  A user may
select what group he or she is working under and permissions are
calculated based on that group.</P>

<P>Every table belongs to a table group.</P>

<P>Every work group has certain privileges (one of the above 6) over
one or more table groups.</P>

<P>A new record is written with a created_by and modified_by field
which is filled with the user creating the record.  The new record
also has a field for the current work group that the user was using
when the record was written.</P>

<P>A user may always modify a record for which the modified_by field is
himself.</P>

<P>Provided the user's current work group has similar sufficient
privilege, a user may modify a record only if he has
privilege level data_modifier or better.  Or, if he has
data_groupmodifier privilege, he may modify the record if
the current work group of the user matches the owner group of
the record.</P>

<P>An individual record may have either Normal, Locked, Modifyable
status.  A Locked record may be changed by no one but the
modified_by user regardless of other privileges.  A Modifyable
record may be modified by anyone who has write privileges to
that table.  A Normal record follows all the rules previously
laid out.</P>

<P>This system is fairly complex, but should serve current and
future security needs.  The most likely "gotcha" of the system
is users who belong to more than one group working under the
"wrong" group.  The will cause permission denied errors, and
will write records as the "wrong" group.  There is presently
no facility in the interface to change the group ownership of
a record.  It is therefore important that users watch their
current group at the top:</P>

<PRE>
  Current Login: edeutsch (2)   Current Group: Array_user (6)   Current Project: [none] (0)   [CHANGE]
</PRE>

<P>Current groups:<P>

<PRE>
work_group_name    comment
------------------ ----------------------------------------------------------- 
Admin              Administrators with nearly full privilege
Other              Default group with almost no privilege
ISB                Unused
Arrays             Fairly powerful group over most Microarray tables
IT                 IT department with no special privileges
Array_user         Standard microarray user.  Has some access to some tables
</PRE>


<BR>
<BR>
<BR>



<?php
  include("includes/footer.inc.php");
?>

