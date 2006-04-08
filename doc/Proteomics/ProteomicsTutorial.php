<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<HTML>
<?php
  /* $Id$ */
  $TITLE="SBEAMS - Proteomics Tutorial";

  include("../../includes/style.inc.php");

  include("../../includes/header.inc.php");

  include("../../includes/navbar.inc.php");
?>



<!-- --------------------------- Main Page Content ------------------------ -->

<table border=0 width="100%" bgcolor="#ffffff" cellpadding=10>
<tr><td align="top">


<!-- BEGIN_CONTENT -->


<h2>
<br/>SBEAMS - Proteomics Tutorial
<br/>Eric Deutsch 
</h2>
<br/>
<p>If you have suggestions or bug reports for this tutorial, please email <a href="mailto:edeutsch@systemsbiology.org">Eric Deutsch</a>.
<br/>
<ol>
<li><b> Login:</b>
   <ul type=circle>
   <li>Go to <a href="https://db.systemsbiology.net/sbeams/" target=_blank>https://db.systemsbiology.net/sbeams/</a>
   <li>Click &#39;Login&#39; to SBEAMS.
   <li>Login with your ISB username and Windows/UNIX password or special account information if you don&#39;t have an ISB account.  Email <a href="mailto:edeutsch@systemsbiology.org">Eric Deutsch</a> if you have problems.
   </ul>
<li><b>Go to Proteomics Module Home Page and test controls</b>
   <ul type=circle>
   <li>Current Project
   <li>Projects You Own
   <li>Projects You Have Access To
   <li>Also note sections &#39;Recent Query Resultsets within the Proteomics Module&#39; and &#39;Other Links&#39;.
   <li>Click on project names to switch current projects
   <li>Switch Group and Project at the top and then finally end up at &#39;Proteomics_user&#39; or &#39;Proteomics_readonly&#39; and Project is &#39;mmarelli - Peroxisomal Proteomics&#39;.
   <li>Click on &#39;Current Project&#39; hyperlink to view project attributes
   <li>Click BACK and then [View/Edit] under Experiments.  This page allows one to add annotation to an individual experiment.
   </ul>

<li><b>Add your own Project if you don&#39;t already have one</b>
<ul type=circle>
<li>Click &#39;My Home&#39; in upper left
<li>Under Projects You Own, click [Add new project] or if you already had an SBEAMS project and didn&#39;t create a new one, edit  the existing one (again, by '[View/Edit]') and UPDATE.
<li>Fill out the form for some real project and INSERT
<li>Click on &#39;My Home&#39; and make sure it&#39;s there.  Make it the active project.
<li>Click [View/Edit], adjust the description a little, and UPDATE
<li>If you already had an SBEAMS project and didn&#39;t create a new one, edit the existing one (by '[View/Edit]') and UPDATE
</ul>
    
<li><b>Register a new experiment</b>
<ul type=circle>
<li>Make your new/existing Project the Current Project
<li>Under Experiments, click [Register another experiment]
<li>Fill out the required and optional information to register the 210-spectrum dataset.  Use the &#39;mmarelli - Peroxisomal proteomics&#39; experiment for experimental configuration as an example if you wish.
<li>INSERT
<li>Click back on My Home and verify that all went in okay.
<li>At present, you cannot load your data.  You would email <a href="mailto:edeutsch@systemsbiology.org">Eric Deutsch</a> and some time later, your data would magically appear in the database.
</ul>
<li><b>Explore the &#39;mmarelli - Peroxisomal proteomics&#39; project/experiment</b>
<ul type=circle>
<li>Set the Current Project to &#39;mmarelli - Peroxisomal proteomics&#39;
<li>View project and experiment attributes
<li>View Fractions (MS Runs) (scroll down!!)
<li>Click on some TIC Plots in the table
<li>Click on an MS Run Summary and then the image and expand the image.
<li>Go back to My Home and click on &#39;P &gt; 0.9&#39; for &#39;Peroxisomal proteomics&#39;
</ul>
<li><b>Browse this dataset using hyperlinks on left navigation bar</b>
<ul type=circle>
<li>Choose Summarize Fractions
<ul type=square>
<li>Choose &#39;mmarelli - Peroxisomal proteomics&#39; experiment or project and view
</ul>
<li>Choose Browse Search Hits
<ul type=square>
<li>Select &#39;mmarelli - Peroxisomal proteomics&#39; experiment
<li>P &gt; 0.9
<li>QUERY
<li>Click on all hyper links across the table
<li>Re-sort by Xcorr descending.  Re-sort by precursor mass, Ions, etc.
<li>Page through resultset
<li>View in Excel, XML
<li>Make a histogram of Precursor m/z, then % ACN
<li>Make a scatter plot of % ACN vs EstRT(min)
<li>Click Display Option: Show SQL and QUERY
</ul>
<li>Choose Summarize over Proteins/Peptides
<ul type=square>
<li>Select &#39;mmarelli - Peroxisomal proteomics&#39; experiment
<li>P &gt; 0.9
<li>QUERY
<li>In Display options, show GO columns & Show SQL and QUERY
<li>Click on all hyper links across the table
<li>Click on Display option: Group By Peptide and QUERY
<li>Click on the 28 next to FOX2 LCTPTMPSNGTLK and examine
</ul>
<li>Choose Compare Experiments
<ul type=square>
<li>Select jranish - gricat experiment
<li>Also CTRL Select &#39;mmarelli - Peroxisomal proteomics&#39; experiment
<li>QUERY
<li>Examine differences between experiments and summary table
<li>Find overlaps by select Full Detail and &#39;>0&#39; for both Exp 1 and 2
<li>Group by peptides and examine
</ul>
<li>Choose Browse Biosequences
<ul type=square>
<li>Select Yeast ORF Database
<li>Type %perox% in Molecular Function Constraint field
<li>QUERY
<li><a href="https://db.systemsbiology.net/sbeams/cgi/Proteomics/BrowseBioSequence.cgi?apply_action=QUERY&row_limit=5000&cellular_component_constraint=%25perox%25&QUERY_NAME=PR_BrowseBioSequence&biosequence_set_id=14&action=QUERY">https://db.systemsbiology.net/sbeams/cgi/Proteomics/BrowseBioSequence.cgi?apply_action=QUERY&row_limit=5000&cellular_component_constraint=%25perox%25&QUERY_NAME=PR_BrowseBioSequence&biosequence_set_id=14&action=QUERY</a>
</ul>
<li>Choose Browse Possible Peptides
<ul type=square>
<li>'Select Yeast ORF' Database
<li>In 'Gene Name constrait', type: PEX%
<li>Select 'Cysteine Containing' and 'Unique'
<li>QUERY
</ul>
<li>Choose Protein Summary (ProteinProphet output)
   <ul type=square>
   <li>Select &#39;mmarelli - Peroxisomal proteomics&#39; experiment
   <li>Protein Group Probability &gt; 0.7
   <li>QUERY
   <li>Choose 'Full Detail' for 'Input Form Format'
   <li>Enter %perox% in cellular component
   <li>QUERY
   <li>Remove %perox% and reQUERY
   <li>Re-sort by descending Probabilty
   <li> [View this Resultset with Cytoscape]
   <li> Within Cytoscape:
      <ol compact>
      <li>Click i balloon
      <li>Expand GO, Molecular Function
      <li>Click on 3
      <li>Click &#39;Apply Annotation&#39; to all Nodes.
      <li>Click on Go Molecular Function (level 3) on right
      <li>Click Layout
      <li>Expand Go Molecular Function (level 3) on right
      <li>Click on individual GO categories and see them highlighted
      <li>Click on &#39;hydrolase&#39; and then right click on graph and see attributes
      <li>Exit Cytoscape.  Tomorrow will be all Cytoscape!
      </ol>
   </ul>
</ul>
<li><b>Choose Publications and explore.</b>  Add your favorite Proteomics paper if it&#39;s not there yet.  Enter the PubMed ID and press [TAB]; if the page doesn&#39;t automatically refresh, click [REFRESH].
<li><b>Choose Proteomics Toolkit and explore.</b>  Fragment peptide: PYLVSPVAFK.  Find all instances of this peptide in the &#39;Peroxisomal proteomics&#39; experiment and compare fragmentation list in spectrum view.
<li><b>Now use the interface to answer these questions:</b>
<ul type=circle>
<li>How many cysteine-containing peptides does the PET9 protein have?
<li>How many of these are observed in &#39;Peroxisomal proteomics&#39;
<li>Explain the difference between these results

<li>How many peroxisomal proteins were identified in the &#39;Peroxisomal proteomics&#39; Protein Summary (ProteinProphet)?

<li>Of all the (GO-annotated) yeast peroxisomal proteins, how many were identified in pxproteomi, jranish-gricat, both, and how many not seen at all? (hint: remove default &#39;# of matches constraint&#39;)
<li>Why so few peroxisomal proteins in gricat?

<li>Create a list of a few proteins not currently annotated as peroxisomal but that might be peroxisomal based on a comparison of identifications in &#39;Peroxisomal proteomics&#39; and gricat.  Email to <a href="mailto:edeutsch@systemsbiology.org">Eric Deutsch</a> the URL for your full query or resultset.
</ul>
</ol>
</td></tr></table>

<!-- END_CONTENT -->

<?php
  include("../../includes/footer.inc.php");
?>