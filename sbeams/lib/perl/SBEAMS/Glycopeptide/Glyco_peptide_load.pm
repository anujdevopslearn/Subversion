



<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN"
"http://www.w3.org/TR/REC-html40/loose.dtd">
<!-- ViewCVS - http://viewcvs.sourceforge.net/
by Greg Stein - mailto:gstein@lyra.org -->
<html>
<head>
<title>[svn] Log of /sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm</title>
<meta name="generator" content="ViewCVS 1.0-dev">
<link rel="stylesheet" href="/cgi/viewcvs/viewcvs.cgi/*docroot*/styles.css" type="text/css">
</head>
<body>
<div class="vc_navheader">
<table width="100%" border="0" cellpadding="0" cellspacing="0">
<tr>
<td align="left"><b>

<a href="/cgi/viewcvs/viewcvs.cgi/?rev=4930&amp;sortby=date">

[svn]</a>
/

<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/?rev=4930&amp;sortby=date">

sbeams</a>
/

<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/?rev=4930&amp;sortby=date">

trunk</a>
/

<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/?rev=4930&amp;sortby=date">

sbeams</a>
/

<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/?rev=4930&amp;sortby=date">

lib</a>
/

<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/?rev=4930&amp;sortby=date">

perl</a>
/

<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/?rev=4930&amp;sortby=date">

SBEAMS</a>
/

<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/?rev=4930&amp;sortby=date">

Glycopeptide</a>
/



Glyco_peptide_load.pm


</b></td>
<td align="right">

&nbsp;

</td>
</tr>
</table>
</div>
<h1><img align=right src="/cgi/viewcvs/viewcvs.cgi/*docroot*/images/logo.png" width=128 height=48>Log of /sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm</h1>

<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/?sortby=date"><img src="/cgi/viewcvs/viewcvs.cgi/*docroot*/images/back_small.png" width=16 height=16 border=0> Parent Directory</a>



<hr noshade>
<p>No default branch<br>
Bookmark a link to HEAD:
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm">download</a>)


</p>



 



<hr size=1 noshade>




<a name="rev4930"></a>


Revision <a href="/cgi/viewcvs/viewcvs.cgi?rev=4930&amp;sortby=date&amp;view=rev"><b>4930</b></a>
 -
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?rev=4930&amp;sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?rev=4930">download</a>)





- <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?r1=4930&amp;rev=4930&amp;sortby=date&amp;view=log">[select for diffs]</a>




<br>

Modified

<i>Fri Jul 28 03:49:30 2006 UTC</i> (5 days, 14 hours ago) by <i>dcampbel</i>








<br>File length: 44106 byte(s)</b>






<br>Diff to <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?r1=4921&amp;r2=4930&amp;rev=4930&amp;sortby=date">previous 4921</a>







<pre class="vc_log">Added various ipi_loading methods.
</pre>

<hr size=1 noshade>




<a name="rev4921"></a>


Revision <a href="/cgi/viewcvs/viewcvs.cgi?rev=4921&amp;sortby=date&amp;view=rev"><b>4921</b></a>
 -
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?rev=4921&amp;sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?rev=4921">download</a>)





- <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?r1=4921&amp;rev=4930&amp;sortby=date&amp;view=log">[select for diffs]</a>




<br>

Modified

<i>Tue Jul 25 00:52:43 2006 UTC</i> (8 days, 17 hours ago) by <i>dcampbel</i>








<br>File length: 38297 byte(s)</b>






<br>Diff to <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?r1=4915&amp;r2=4921&amp;rev=4921&amp;sortby=date">previous 4915</a>







<pre class="vc_log">Changes for new schema, loading paradigm.
</pre>

<hr size=1 noshade>




<a name="rev4915"></a>


Revision <a href="/cgi/viewcvs/viewcvs.cgi?rev=4915&amp;sortby=date&amp;view=rev"><b>4915</b></a>
 -
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?rev=4915&amp;sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?rev=4915">download</a>)





- <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?r1=4915&amp;rev=4930&amp;sortby=date&amp;view=log">[select for diffs]</a>




<br>

Modified

<i>Fri Jul 21 01:06:18 2006 UTC</i> (12 days, 17 hours ago) by <i>dcampbel</i>








<br>File length: 35138 byte(s)</b>






<br>Diff to <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?r1=4746&amp;r2=4915&amp;rev=4915&amp;sortby=date">previous 4746</a>







<pre class="vc_log">Schema and new build process related changes.
</pre>

<hr size=1 noshade>




<a name="rev4746"></a>


Revision <a href="/cgi/viewcvs/viewcvs.cgi?rev=4746&amp;sortby=date&amp;view=rev"><b>4746</b></a>
 -
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?rev=4746&amp;sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?rev=4746">download</a>)





- <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?r1=4746&amp;rev=4930&amp;sortby=date&amp;view=log">[select for diffs]</a>




<br>

Modified

<i>Sat Jun 10 01:30:32 2006 UTC</i> (7 weeks, 4 days ago) by <i>dcampbel</i>








<br>File length: 33877 byte(s)</b>






<br>Diff to <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?r1=4672&amp;r2=4746&amp;rev=4746&amp;sortby=date">previous 4672</a>







<pre class="vc_log">Modified to reflect new column heading from java merge code.
</pre>

<hr size=1 noshade>




<a name="rev4672"></a>


Revision <a href="/cgi/viewcvs/viewcvs.cgi?rev=4672&amp;sortby=date&amp;view=rev"><b>4672</b></a>
 -
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?rev=4672&amp;sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?rev=4672">download</a>)





- <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?r1=4672&amp;rev=4930&amp;sortby=date&amp;view=log">[select for diffs]</a>




<br>

Modified

<i>Sat Apr 22 01:55:26 2006 UTC</i> (3 months, 1 week ago) by <i>dcampbel</i>








<br>File length: 33857 byte(s)</b>






<br>Diff to <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?r1=4381&amp;r2=4672&amp;rev=4672&amp;sortby=date">previous 4381</a>







<pre class="vc_log">Fixed to work with latest version of merger output.
</pre>

<hr size=1 noshade>




<a name="rev4381"></a>


Revision <a href="/cgi/viewcvs/viewcvs.cgi?rev=4381&amp;sortby=date&amp;view=rev"><b>4381</b></a>
 -
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?rev=4381&amp;sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?rev=4381">download</a>)





- <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?r1=4381&amp;rev=4930&amp;sortby=date&amp;view=log">[select for diffs]</a>




<br>

Modified

<i>Thu Feb  2 02:52:32 2006 UTC</i> (5 months, 4 weeks ago) by <i>dcampbel</i>








<br>File length: 33115 byte(s)</b>






<br>Diff to <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?r1=4279&amp;r2=4381&amp;rev=4381&amp;sortby=date">previous 4279</a>







<pre class="vc_log">Updated to user fewer global variables, allow to work with other scripts.
</pre>

<hr size=1 noshade>




<a name="rev4279"></a>


Revision <a href="/cgi/viewcvs/viewcvs.cgi?rev=4279&amp;sortby=date&amp;view=rev"><b>4279</b></a>
 -
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?rev=4279&amp;sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?rev=4279">download</a>)





- <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?r1=4279&amp;rev=4930&amp;sortby=date&amp;view=log">[select for diffs]</a>




<br>

Modified

<i>Fri Jan 13 06:01:36 2006 UTC</i> (6 months, 2 weeks ago) by <i>dcampbel</i>








<br>File length: 32220 byte(s)</b>






<br>Diff to <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?r1=4269&amp;r2=4279&amp;rev=4279&amp;sortby=date">previous 4269</a>







<pre class="vc_log">More Atlas/Glyco peptide split.
</pre>

<hr size=1 noshade>




<a name="rev4269"></a>


Revision <a href="/cgi/viewcvs/viewcvs.cgi?rev=4269&amp;sortby=date&amp;view=rev"><b>4269</b></a>
 -
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?rev=4269&amp;sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?rev=4269">download</a>)





- <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?r1=4269&amp;rev=4930&amp;sortby=date&amp;view=log">[select for diffs]</a>




<br>

Modified

<i>Thu Jan 12 21:48:50 2006 UTC</i> (6 months, 2 weeks ago) by <i>dcampbel</i>








<br>File length: 32220 byte(s)</b>


<br>Copied from: <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm?rev=4268&amp;sortby=date&amp;view=log">sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm</a> revision 4268





<br>Diff to <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?p1=sbeams%2Ftrunk%2Fsbeams%2Flib%2Fperl%2FSBEAMS%2FPeptideAtlas%2FGlyco_peptide_load.pm&amp;r1=4136&amp;r2=4269&amp;rev=4269&amp;sortby=date">previous 4136</a>







<pre class="vc_log">More fallout from the Atlas/Glyco peptide divorce...
</pre>

<hr size=1 noshade>

Filename: sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm<br>


<a name="rev4136"></a>


Revision <a href="/cgi/viewcvs/viewcvs.cgi?rev=4136&amp;sortby=date&amp;view=rev"><b>4136</b></a>
 -
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm?rev=4136&amp;sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm?rev=4136">download</a>)





- <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?p1=sbeams%2Ftrunk%2Fsbeams%2Flib%2Fperl%2FSBEAMS%2FPeptideAtlas%2FGlyco_peptide_load.pm&amp;r1=4136&amp;rev=4930&amp;sortby=date&amp;view=log">[select for diffs]</a>




<br>

Modified

<i>Wed Nov 16 03:21:07 2005 UTC</i> (8 months, 2 weeks ago) by <i>dcampbel</i>








<br>File length: 32220 byte(s)</b>






<br>Diff to <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm?r1=4054&amp;r2=4136&amp;rev=4136&amp;sortby=date">previous 4054</a>







<pre class="vc_log">Modified so that cellular location doesn't have to get looked up each and every time.
</pre>

<hr size=1 noshade>

Filename: sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm<br>


<a name="rev4054"></a>


Revision <a href="/cgi/viewcvs/viewcvs.cgi?rev=4054&amp;sortby=date&amp;view=rev"><b>4054</b></a>
 -
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm?rev=4054&amp;sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm?rev=4054">download</a>)





- <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?p1=sbeams%2Ftrunk%2Fsbeams%2Flib%2Fperl%2FSBEAMS%2FPeptideAtlas%2FGlyco_peptide_load.pm&amp;r1=4054&amp;rev=4930&amp;sortby=date&amp;view=log">[select for diffs]</a>




<br>

Modified

<i>Wed Oct 19 23:49:13 2005 UTC</i> (9 months, 1 week ago) by <i>dcampbel</i>








<br>File length: 31962 byte(s)</b>






<br>Diff to <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm?r1=3723&amp;r2=4054&amp;rev=4054&amp;sortby=date">previous 3723</a>







<pre class="vc_log">Added code to make serum data loads go smoothly.  Turned Trans Membrane to Transmembrane, fixed column_header designation for ipi_hits, etc.
</pre>

<hr size=1 noshade>

Filename: sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm<br>


<a name="rev3723"></a>


Revision <a href="/cgi/viewcvs/viewcvs.cgi?rev=3723&amp;sortby=date&amp;view=rev"><b>3723</b></a>
 -
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm?rev=3723&amp;sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm?rev=3723">download</a>)





- <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?p1=sbeams%2Ftrunk%2Fsbeams%2Flib%2Fperl%2FSBEAMS%2FPeptideAtlas%2FGlyco_peptide_load.pm&amp;r1=3723&amp;rev=4930&amp;sortby=date&amp;view=log">[select for diffs]</a>




<br>

Modified

<i>Mon Jul 25 16:21:12 2005 UTC</i> (12 months, 1 week ago) by <i>dcampbel</i>








<br>File length: 31577 byte(s)</b>






<br>Diff to <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm?r1=3708&amp;r2=3723&amp;rev=3723&amp;sortby=date">previous 3708</a>







<pre class="vc_log">Modified so that proteins without predicted glycopeptides can be loaded.
</pre>

<hr size=1 noshade>

Filename: sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm<br>


<a name="rev3708"></a>


Revision <a href="/cgi/viewcvs/viewcvs.cgi?rev=3708&amp;sortby=date&amp;view=rev"><b>3708</b></a>
 -
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm?rev=3708&amp;sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm?rev=3708">download</a>)





- <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?p1=sbeams%2Ftrunk%2Fsbeams%2Flib%2Fperl%2FSBEAMS%2FPeptideAtlas%2FGlyco_peptide_load.pm&amp;r1=3708&amp;rev=4930&amp;sortby=date&amp;view=log">[select for diffs]</a>




<br>

Modified

<i>Mon Jun 27 23:16:42 2005 UTC</i> (13 months ago) by <i>dcampbel</i>








<br>File length: 31356 byte(s)</b>






<br>Diff to <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm?r1=3705&amp;r2=3708&amp;rev=3708&amp;sortby=date">previous 3705</a>







<pre class="vc_log">Added time info to progress meter.
</pre>

<hr size=1 noshade>

Filename: sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm<br>


<a name="rev3705"></a>


Revision <a href="/cgi/viewcvs/viewcvs.cgi?rev=3705&amp;sortby=date&amp;view=rev"><b>3705</b></a>
 -
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm?rev=3705&amp;sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm?rev=3705">download</a>)





- <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?p1=sbeams%2Ftrunk%2Fsbeams%2Flib%2Fperl%2FSBEAMS%2FPeptideAtlas%2FGlyco_peptide_load.pm&amp;r1=3705&amp;rev=4930&amp;sortby=date&amp;view=log">[select for diffs]</a>




<br>

Modified

<i>Mon Jun 27 17:53:40 2005 UTC</i> (13 months ago) by <i>dcampbel</i>








<br>File length: 31057 byte(s)</b>






<br>Diff to <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm?r1=3700&amp;r2=3705&amp;rev=3705&amp;sortby=date">previous 3700</a>







<pre class="vc_log">Added code to create new glyco_sample w/ unknown tissue type if encountered at runtime (rather than truncate load).
</pre>

<hr size=1 noshade>

Filename: sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm<br>


<a name="rev3700"></a>


Revision <a href="/cgi/viewcvs/viewcvs.cgi?rev=3700&amp;sortby=date&amp;view=rev"><b>3700</b></a>
 -
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm?rev=3700&amp;sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm?rev=3700">download</a>)





- <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?p1=sbeams%2Ftrunk%2Fsbeams%2Flib%2Fperl%2FSBEAMS%2FPeptideAtlas%2FGlyco_peptide_load.pm&amp;r1=3700&amp;rev=4930&amp;sortby=date&amp;view=log">[select for diffs]</a>




<br>

Modified

<i>Mon Jun 27 04:44:42 2005 UTC</i> (13 months ago) by <i>dcampbel</i>








<br>File length: 29841 byte(s)</b>






<br>Diff to <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm?r1=3670&amp;r2=3700&amp;rev=3700&amp;sortby=date">previous 3670</a>







<pre class="vc_log">Switched to heading-based rather than order based parsing;
Schema changes for identified peptides and tissues;
</pre>

<hr size=1 noshade>

Filename: sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm<br>


<a name="rev3670"></a>


Revision <a href="/cgi/viewcvs/viewcvs.cgi?rev=3670&amp;sortby=date&amp;view=rev"><b>3670</b></a>
 -
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm?rev=3670&amp;sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm?rev=3670">download</a>)





- <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?p1=sbeams%2Ftrunk%2Fsbeams%2Flib%2Fperl%2FSBEAMS%2FPeptideAtlas%2FGlyco_peptide_load.pm&amp;r1=3670&amp;rev=4930&amp;sortby=date&amp;view=log">[select for diffs]</a>




<br>

Modified

<i>Tue Jun 21 23:30:30 2005 UTC</i> (13 months, 1 week ago) by <i>dcampbel</i>








<br>File length: 28882 byte(s)</b>






<br>Diff to <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm?r1=3587&amp;r2=3670&amp;rev=3670&amp;sortby=date">previous 3587</a>







<pre class="vc_log">Converted to use headings instead of column position to find data.
various cleanup.
</pre>

<hr size=1 noshade>

Filename: sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm<br>


<a name="rev3587"></a>


Revision <a href="/cgi/viewcvs/viewcvs.cgi?rev=3587&amp;sortby=date&amp;view=rev"><b>3587</b></a>
 -
(<a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm?rev=3587&amp;sortby=date&amp;view=markup">view</a>)
(<a href="/cgi/viewcvs/viewcvs.cgi/*checkout*/sbeams/trunk/sbeams/lib/perl/SBEAMS/PeptideAtlas/Glyco_peptide_load.pm?rev=3587">download</a>)





- <a href="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm?p1=sbeams%2Ftrunk%2Fsbeams%2Flib%2Fperl%2FSBEAMS%2FPeptideAtlas%2FGlyco_peptide_load.pm&amp;r1=3587&amp;rev=4930&amp;sortby=date&amp;view=log">[select for diffs]</a>




<br>

Added

<i>Wed May 18 21:35:26 2005 UTC</i> (14 months, 2 weeks ago) by <i>pmoss</i>






<br>File length: 25723 byte(s)</b>










<pre class="vc_log">Methods to load glyco predicition data into the database
</pre>

 



<a name="diff"></a>
<hr noshade>
This form allows you to request diffs between any two revisions of
a file. You may select a symbolic revision name using the selection
box or you may type in a numeric name using the type-in text box.
<p>
<form method="get" action="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm" name="diff_select">
<input type="hidden" name="sortby" value="date" />
<table border="0" cellpadding="2" cellspacing="0">
<tr>
<td>&nbsp;</td>
<td>
Diffs between

<input type="text" size="12" name="r1" value="3587">

and

<input type="text" size="12" name="r2" value="3587">

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
<form method=get action="/cgi/viewcvs/viewcvs.cgi/sbeams/trunk/sbeams/lib/perl/SBEAMS/Glycopeptide/Glyco_peptide_load.pm">
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

