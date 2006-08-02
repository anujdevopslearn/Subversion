



<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN"
"http://www.w3.org/TR/REC-html40/loose.dtd">
<!-- ViewCVS - http://viewcvs.sourceforge.net/
by Greg Stein - mailto:gstein@lyra.org -->
<html>
<head>
<title>[svn] Log of /sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm</title>
<meta name="generator" content="ViewCVS 1.0-dev">
<link rel="stylesheet" href="/cgi/viewcvs/viewcvs.cgi/*docroot*/styles.css" type="text/css">
</head>
<body>
<div class="vc_navheader">
<table width="100%" border="0" cellpadding="0" cellspacing="0">
<tr>
<td align="left"><b>

<a href="/cgi/viewcvs/viewcvs.cgi/?rev=4921&amp;sortby=date">

[svn]</a>
/

<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/?rev=4921&amp;sortby=date">

sbeams</a>
/

<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/?rev=4921&amp;sortby=date">

trunk</a>
/

<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/?rev=4921&amp;sortby=date">

sbeams</a>
/

<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/?rev=4921&amp;sortby=date">

lib</a>
/

<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/?rev=4921&amp;sortby=date">

perl</a>
/

<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/?rev=4921&amp;sortby=date">

SBEAMS</a>
/

<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/?rev=4921&amp;sortby=date">

Glycopeptide</a>
/



Glyco_query.pm


</b></td>
<td align="right">

&nbsp;

</td>
</tr>
</table>
</div>
<h1><img align=right src="/cgi/viewcvs/viewcvs.cgi/*docroot*/images/logo.png" width=128 height=48>Log of /sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm</h1>

<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/?sortby=date"><img src="/cgi/viewcvs/viewcvs.cgi/*docroot*/images/back_small.png" width=16 height=16 border=0> Parent Directory</a>



<hr noshade>
<p>No default branch<br>
Bookmark a link to HEAD:
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm">download</a>)


</p>



 



<hr size=1 noshade>




<a name="rev4921"></a>


Revision <a href="/cgi/viewcvs/viewcvs.cgi?rev=4921&amp;sortby=date&amp;view=rev"><b>4921</b></a>
 -
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?rev=4921&amp;sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?rev=4921">download</a>)





- <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?r1=4921&amp;rev=4921&amp;sortby=date&amp;view=log">[select for diffs]</a>




<br>

Modified

<i>Tue Jul 25 00:52:43 2006 UTC</i> (8 days, 17 hours ago) by <i>dcampbel</i>








<br>File length: 12767 byte(s)</b>






<br>Diff to <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?r1=4915&amp;r2=4921&amp;rev=4921&amp;sortby=date">previous 4915</a>







<pre class="vc_log">Changes for new schema, loading paradigm.
</pre>

<hr size=1 noshade>




<a name="rev4915"></a>


Revision <a href="/cgi/viewcvs/viewcvs.cgi?rev=4915&amp;sortby=date&amp;view=rev"><b>4915</b></a>
 -
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?rev=4915&amp;sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?rev=4915">download</a>)





- <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?r1=4915&amp;rev=4921&amp;sortby=date&amp;view=log">[select for diffs]</a>




<br>

Modified

<i>Fri Jul 21 01:06:18 2006 UTC</i> (12 days, 17 hours ago) by <i>dcampbel</i>








<br>File length: 12770 byte(s)</b>






<br>Diff to <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?r1=4743&amp;r2=4915&amp;rev=4915&amp;sortby=date">previous 4743</a>







<pre class="vc_log">Schema and new build process related changes.
</pre>

<hr size=1 noshade>




<a name="rev4743"></a>


Revision <a href="/cgi/viewcvs/viewcvs.cgi?rev=4743&amp;sortby=date&amp;view=rev"><b>4743</b></a>
 -
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?rev=4743&amp;sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?rev=4743">download</a>)





- <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?r1=4743&amp;rev=4921&amp;sortby=date&amp;view=log">[select for diffs]</a>




<br>

Modified

<i>Sat Jun 10 01:28:13 2006 UTC</i> (7 weeks, 4 days ago) by <i>dcampbel</i>








<br>File length: 12769 byte(s)</b>






<br>Diff to <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?r1=4673&amp;r2=4743&amp;rev=4743&amp;sortby=date">previous 4673</a>







<pre class="vc_log">Added ability to search with entrez gene_id, allows links from kegg maps to work.
</pre>

<hr size=1 noshade>




<a name="rev4673"></a>


Revision <a href="/cgi/viewcvs/viewcvs.cgi?rev=4673&amp;sortby=date&amp;view=rev"><b>4673</b></a>
 -
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?rev=4673&amp;sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?rev=4673">download</a>)





- <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?r1=4673&amp;rev=4921&amp;sortby=date&amp;view=log">[select for diffs]</a>




<br>

Modified

<i>Sat Apr 22 01:56:25 2006 UTC</i> (3 months, 1 week ago) by <i>dcampbel</i>








<br>File length: 12124 byte(s)</b>






<br>Diff to <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?r1=4539&amp;r2=4673&amp;rev=4673&amp;sortby=date">previous 4539</a>







<pre class="vc_log">Changes for n_obs and tissue display.
</pre>

<hr size=1 noshade>




<a name="rev4539"></a>


Revision <a href="/cgi/viewcvs/viewcvs.cgi?rev=4539&amp;sortby=date&amp;view=rev"><b>4539</b></a>
 -
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?rev=4539&amp;sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?rev=4539">download</a>)





- <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?r1=4539&amp;rev=4921&amp;sortby=date&amp;view=log">[select for diffs]</a>




<br>

Modified

<i>Wed Mar 15 18:51:07 2006 UTC</i> (4 months, 2 weeks ago) by <i>dcampbel</i>








<br>File length: 12110 byte(s)</b>






<br>Diff to <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?r1=4392&amp;r2=4539&amp;rev=4539&amp;sortby=date">previous 4392</a>







<pre class="vc_log">Added peptide_cutoff constraint to approptiate queries.  Also unified SQL building for various query types, rather than replicating the above 5 times.  Made seq search wildcarding explicit.
</pre>

<hr size=1 noshade>




<a name="rev4392"></a>


Revision <a href="/cgi/viewcvs/viewcvs.cgi?rev=4392&amp;sortby=date&amp;view=rev"><b>4392</b></a>
 -
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?rev=4392&amp;sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?rev=4392">download</a>)





- <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?r1=4392&amp;rev=4921&amp;sortby=date&amp;view=log">[select for diffs]</a>




<br>

Modified

<i>Sat Feb  4 02:07:05 2006 UTC</i> (5 months, 3 weeks ago) by <i>dcampbel</i>








<br>File length: 10617 byte(s)</b>






<br>Diff to <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?r1=4388&amp;r2=4392&amp;rev=4392&amp;sortby=date">previous 4388</a>







<pre class="vc_log">Moved ipi accessors to DBInterface, added new protein query to Glyco_query.
</pre>

<hr size=1 noshade>




<a name="rev4388"></a>


Revision <a href="/cgi/viewcvs/viewcvs.cgi?rev=4388&amp;sortby=date&amp;view=rev"><b>4388</b></a>
 -
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?rev=4388&amp;sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?rev=4388">download</a>)





- <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?r1=4388&amp;rev=4921&amp;sortby=date&amp;view=log">[select for diffs]</a>




<br>

Modified

<i>Thu Feb  2 23:18:12 2006 UTC</i> (5 months, 4 weeks ago) by <i>dcampbel</i>








<br>File length: 11030 byte(s)</b>






<br>Diff to <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?r1=4279&amp;r2=4388&amp;rev=4388&amp;sortby=date">previous 4279</a>







<pre class="vc_log">Added ipi lookup queries.
</pre>

<hr size=1 noshade>




<a name="rev4279"></a>


Revision <a href="/cgi/viewcvs/viewcvs.cgi?rev=4279&amp;sortby=date&amp;view=rev"><b>4279</b></a>
 -
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?rev=4279&amp;sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?rev=4279">download</a>)





- <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?r1=4279&amp;rev=4921&amp;sortby=date&amp;view=log">[select for diffs]</a>




<br>

Modified

<i>Fri Jan 13 06:01:36 2006 UTC</i> (6 months, 2 weeks ago) by <i>dcampbel</i>








<br>File length: 10025 byte(s)</b>






<br>Diff to <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?r1=4269&amp;r2=4279&amp;rev=4279&amp;sortby=date">previous 4269</a>







<pre class="vc_log">More Atlas/Glyco peptide split.
</pre>

<hr size=1 noshade>




<a name="rev4269"></a>


Revision <a href="/cgi/viewcvs/viewcvs.cgi?rev=4269&amp;sortby=date&amp;view=rev"><b>4269</b></a>
 -
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?rev=4269&amp;sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?rev=4269">download</a>)





- <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?r1=4269&amp;rev=4921&amp;sortby=date&amp;view=log">[select for diffs]</a>




<br>

Modified

<i>Thu Jan 12 21:48:50 2006 UTC</i> (6 months, 2 weeks ago) by <i>dcampbel</i>








<br>File length: 10025 byte(s)</b>


<br>Copied from: <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_query.pm?rev=4268&amp;sortby=date&amp;view=log">sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_query.pm</a> revision 4268





<br>Diff to <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?p1=sbeams%2Ftrunk%2Fsbeams%2Flib%2Fperl%2FSBEAMS%2FPeptideAtlas%2FGlyco_query.pm&amp;r1=4174&amp;r2=4269&amp;rev=4269&amp;sortby=date">previous 4174</a>







<pre class="vc_log">More fallout from the Atlas/Glyco peptide divorce...
</pre>

<hr size=1 noshade>

Filename: sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_query.pm<br>


<a name="rev4174"></a>


Revision <a href="/cgi/viewcvs/viewcvs.cgi?rev=4174&amp;sortby=date&amp;view=rev"><b>4174</b></a>
 -
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_query.pm?rev=4174&amp;sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_query.pm?rev=4174">download</a>)





- <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?p1=sbeams%2Ftrunk%2Fsbeams%2Flib%2Fperl%2FSBEAMS%2FPeptideAtlas%2FGlyco_query.pm&amp;r1=4174&amp;rev=4921&amp;sortby=date&amp;view=log">[select for diffs]</a>




<br>

Modified

<i>Wed Nov 30 19:18:31 2005 UTC</i> (8 months ago) by <i>dcampbel</i>








<br>File length: 10025 byte(s)</b>






<br>Diff to <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_query.pm?r1=4052&amp;r2=4174&amp;rev=4174&amp;sortby=date">previous 4052</a>







<pre class="vc_log">Added SQL to count # of ID'd peptides for each protein in list context, fixed join between glycosite and identified lookup table to use glyco_site_id.
</pre>

<hr size=1 noshade>

Filename: sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_query.pm<br>


<a name="rev4052"></a>


Revision <a href="/cgi/viewcvs/viewcvs.cgi?rev=4052&amp;sortby=date&amp;view=rev"><b>4052</b></a>
 -
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_query.pm?rev=4052&amp;sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_query.pm?rev=4052">download</a>)





- <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?p1=sbeams%2Ftrunk%2Fsbeams%2Flib%2Fperl%2FSBEAMS%2FPeptideAtlas%2FGlyco_query.pm&amp;r1=4052&amp;rev=4921&amp;sortby=date&amp;view=log">[select for diffs]</a>




<br>

Modified

<i>Wed Oct 19 23:47:14 2005 UTC</i> (9 months, 1 week ago) by <i>dcampbel</i>








<br>File length: 9456 byte(s)</b>






<br>Diff to <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_query.pm?r1=3709&amp;r2=4052&amp;rev=4052&amp;sortby=date">previous 3709</a>







<pre class="vc_log">Modified queries to use glyco_site_id from identified_to_ipi.
</pre>

<hr size=1 noshade>

Filename: sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_query.pm<br>


<a name="rev3709"></a>


Revision <a href="/cgi/viewcvs/viewcvs.cgi?rev=3709&amp;sortby=date&amp;view=rev"><b>3709</b></a>
 -
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_query.pm?rev=3709&amp;sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_query.pm?rev=3709">download</a>)





- <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?p1=sbeams%2Ftrunk%2Fsbeams%2Flib%2Fperl%2FSBEAMS%2FPeptideAtlas%2FGlyco_query.pm&amp;r1=3709&amp;rev=4921&amp;sortby=date&amp;view=log">[select for diffs]</a>




<br>

Modified

<i>Tue Jun 28 05:56:21 2005 UTC</i> (13 months ago) by <i>dcampbel</i>








<br>File length: 9291 byte(s)</b>






<br>Diff to <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_query.pm?r1=3701&amp;r2=3709&amp;rev=3709&amp;sortby=date">previous 3701</a>







<pre class="vc_log">Allow tissues to display.
</pre>

<hr size=1 noshade>

Filename: sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_query.pm<br>


<a name="rev3701"></a>


Revision <a href="/cgi/viewcvs/viewcvs.cgi?rev=3701&amp;sortby=date&amp;view=rev"><b>3701</b></a>
 -
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_query.pm?rev=3701&amp;sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_query.pm?rev=3701">download</a>)





- <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?p1=sbeams%2Ftrunk%2Fsbeams%2Flib%2Fperl%2FSBEAMS%2FPeptideAtlas%2FGlyco_query.pm&amp;r1=3701&amp;rev=4921&amp;sortby=date&amp;view=log">[select for diffs]</a>




<br>

Modified

<i>Mon Jun 27 04:45:01 2005 UTC</i> (13 months ago) by <i>dcampbel</i>








<br>File length: 8985 byte(s)</b>






<br>Diff to <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_query.pm?r1=3672&amp;r2=3701&amp;rev=3701&amp;sortby=date">previous 3672</a>







<pre class="vc_log">SQL changes due to new schema layout.
</pre>

<hr size=1 noshade>

Filename: sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_query.pm<br>


<a name="rev3672"></a>


Revision <a href="/cgi/viewcvs/viewcvs.cgi?rev=3672&amp;sortby=date&amp;view=rev"><b>3672</b></a>
 -
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_query.pm?rev=3672&amp;sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_query.pm?rev=3672">download</a>)





- <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?p1=sbeams%2Ftrunk%2Fsbeams%2Flib%2Fperl%2FSBEAMS%2FPeptideAtlas%2FGlyco_query.pm&amp;r1=3672&amp;rev=4921&amp;sortby=date&amp;view=log">[select for diffs]</a>




<br>

Modified

<i>Tue Jun 21 23:31:38 2005 UTC</i> (13 months, 1 week ago) by <i>dcampbel</i>








<br>File length: 8900 byte(s)</b>






<br>Diff to <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_query.pm?r1=3588&amp;r2=3672&amp;rev=3672&amp;sortby=date">previous 3588</a>







<pre class="vc_log">Modified query to use join table, reflects potential one to many relationship.
</pre>

<hr size=1 noshade>

Filename: sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_query.pm<br>


<a name="rev3588"></a>


Revision <a href="/cgi/viewcvs/viewcvs.cgi?rev=3588&amp;sortby=date&amp;view=rev"><b>3588</b></a>
 -
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_query.pm?rev=3588&amp;sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_query.pm?rev=3588">download</a>)





- <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm?p1=sbeams%2Ftrunk%2Fsbeams%2Flib%2Fperl%2FSBEAMS%2FPeptideAtlas%2FGlyco_query.pm&amp;r1=3588&amp;rev=4921&amp;sortby=date&amp;view=log">[select for diffs]</a>




<br>

Added

<i>Wed May 18 21:36:32 2005 UTC</i> (14 months, 2 weeks ago) by <i>pmoss</i>






<br>File length: 8788 byte(s)</b>










<pre class="vc_log">Methods to query the glyco prediction talbes
</pre>

 



<a name="diff"></a>
<hr noshade>
This form allows you to request diffs between any two revisions of
a file. You may select a symbolic revision name using the selection
box or you may type in a numeric name using the type-in text box.
<p>
<form method="get" action="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm" name="diff_select">
<input type="hidden" name="sortby" value="date" />
<table border="0" cellpadding="2" cellspacing="0">
<tr>
<td>&nbsp;</td>
<td>
Diffs between

<input type="text" size="12" name="r1" value="3588">

and

<input type="text" size="12" name="r2" value="3588">

</td>
</tr>
<tr>
<td><input type="checkbox" name="makepatch" id="makepatch" value="1"></td>
<td><label for="makepatch">Generate output suitable for use with a patch
program</label></td>
</tr>
<tr>
<td>&nbsp;</td>
<td>
Type of Diff should be a
<select name="diff_format" onchange="submit()">
<option value="h" selected>Colored Diff</option>
<option value="l" >Long Colored Diff</option>
<option value="u" >Unidiff</option>
<option value="c" >Context Diff</option>
<option value="s" >Side by Side</option>
</select>
<input type="submit" value=" Get Diffs ">
</td>
</tr>
</table>
</form>




<hr noshade>
<a name=logsort></a>
<form method=get action="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_query.pm">
<input type="hidden" name="sortby" value="date" /><input type="hidden" name="view" value="log" />
Sort log by:
<select name="logsort" onchange="submit()">
<option value="cvs" >Not sorted</option>
<option value="date" selected>Commit date</option>
<option value="rev" >Revision</option>
</select>
<input type=submit value=" Sort ">
</form>


<hr noshade>
<table width="100%" border="0" cellpadding="0" cellspacing="0">
<tr>
<td align="left">
<address><a href="mailto:edeutsch@systemsbiology.org">Email questions or problems to Eric Deutsch</a></address><br />
Powered by <a href="http://viewcvs.sourceforge.net/">ViewCVS 1.0-dev</a>
</td>
<td align="right">
<h3><a target="_blank" href="/cgi/viewcvs/viewcvs.cgi/*docroot*/help_log.html">ViewCVS and CVS Help</a></h3>
</td>
</tr>
</table>
</body>
</html>

