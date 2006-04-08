package DataLoader;
//-----------------------------------------------------------------------------------------------
import java.io.*;
import javax.swing.*;
import javax.swing.border.TitledBorder;
import java.awt.*;
import java.awt.event.*;
import java.util.regex.*;
import java.util.List;
import java.util.Vector;
import java.util.Hashtable;
import java.util.Calendar;
import java.util.Date;
import java.util.GregorianCalendar;
import java.text.DecimalFormat;
import org.iso_relax.verifier.*;
//-----------------------------------------------------------------------------------------------
public class DataSaverPanel extends WizardPanel 
  implements ActionListener{
//-----------------------------------------------------------------------------------------------
  protected JTextField baseFileName;
  protected JTextField directoryPath;
  protected JCheckBox fileCheck;
  protected JCheckBox sbeamsCheck;
  protected JButton fileButton;
  protected JButton okbutton;
  protected JButton cancelButton;
  protected JLabel nameLabel;
  private String CHOOSE_DIRECTORY = "CHOOSE_DIRECTORY";
  private String DIRECTORY_CHECK = "DIRECTORY_CHECK";
  private static DecimalFormat twoDigits = new DecimalFormat("00");
  private StringBuffer status;
  private Hashtable condData;
//-----------------------------------------------------------------------------------------------
  public DataSaverPanel(WizardContext wc) {
	setWizardContext(wc);
	condData = (Hashtable)wizardContext.getAttribute(WIZARD_HASH_CONDITIONS);
	setLayout(new BorderLayout());
	setBorder(new TitledBorder("Step 5.  Save Data and Exit"));
	status = new StringBuffer();

	JPanel instructionPanel = new JPanel();
	instructionPanel.add(new JLabel("Method(s) for Saving These Data:"));

	JPanel filePanel = new JPanel();
	fileCheck = new JCheckBox("Save To Directory");
	fileCheck.setActionCommand(DIRECTORY_CHECK);
	fileCheck.addActionListener(this);
	filePanel.add(fileCheck);
	directoryPath = new JTextField(30);
	directoryPath.setEditable(false);
	filePanel.add(directoryPath);
	fileButton = new JButton ("Choose Directory...");
	fileButton.setActionCommand(CHOOSE_DIRECTORY);
	fileButton.addActionListener(this);
	filePanel.add(fileButton);

// 	JPanel sbeamsPanel = new JPanel();
// 	sbeamsCheck = new JCheckBox("Save to SBEAMS");
// 	sbeamsPanel.add(sbeamsCheck);
// 	sbeamsPanel.setPreferredSize(filePanel.getPreferredSize());

	JPanel savePanel = new JPanel();
	savePanel.setLayout(new GridLayout(0,1));
	savePanel.add(instructionPanel);
	savePanel.add(filePanel);
// 	savePanel.add(sbeamsPanel);

	JPanel outerPanel = new JPanel();
	outerPanel.add(savePanel);

	this.add(outerPanel, BorderLayout.CENTER);
  }// constructor
//-----------------------------------------------------------------------------------------------
  private void writeFiles(String baseName) {
	Calendar calendar = new GregorianCalendar();
	Date trialTime = new Date();
	calendar.setTime(trialTime);
	String date = new String(calendar.get(Calendar.YEAR)+"-"+
							 twoDigits.format( (calendar.get(calendar.MONTH)+1) )+"-"+
							 twoDigits.format( (calendar.get(calendar.DATE)) ) );

	Hashtable aliases = new Hashtable();
    String lambdaFile = baseName+".lambda";
	String ratioFile = baseName+".ratio";
	String xmlFile = baseName+".xml";
	String[] conditions = (String[])wizardContext.getAttribute(WIZARD_CONDITIONS);
	int conds = conditions.length;

	ExperimentCondition ec = (ExperimentCondition)condData.get(conditions[0]);
	String[] gene = ec.getGenes();
	float[] individualRatios = ec.getRatioData();
	float[] individualLambdas = ec.getLambdaData();


	StringBuffer predicateBuf = new StringBuffer();
	StringBuffer constantsBuf = new StringBuffer();
	StringBuffer variablesBuf = new StringBuffer();

	String exptName =(String)wizardContext.getAttribute(WIZARD_EXPERIMENT); 
	predicateBuf.append("<?xml version=\"1.0\" ?>"+"\n");
	predicateBuf.append("<experiment name=\"");
	predicateBuf.append(exptName);
	predicateBuf.append("\" date=\""+date+"\">"+"\n");
	predicateBuf.append ("\t");
	predicateBuf.append("<predicate category='species' value='");
	predicateBuf.append((String)wizardContext.getAttribute(WIZARD_ORGANISM));
	predicateBuf.append("'/>"+"\n");

	predicateBuf.append ("\t");
	predicateBuf.append("<predicate category='perturbation' value='");
	predicateBuf.append((String)wizardContext.getAttribute(WIZARD_PERTURBATION));
	predicateBuf.append("'/>\n");

	predicateBuf.append ("\t");
	predicateBuf.append("<predicate category='strain' value='");
	predicateBuf.append((String)wizardContext.getAttribute(WIZARD_STRAIN));
	predicateBuf.append("'/>"+"\n");

	String manipulationType = (String)wizardContext.getAttribute(WIZARD_MANIPULATION_TYPE);
	if (manipulationType != null) {
	  predicateBuf.append ("\t");
	  predicateBuf.append("<predicate category='manipulationType' value='");
	  predicateBuf.append(manipulationType);
	  predicateBuf.append("'/>"+"\n");
	}

	String manipulatedVariable = (String)wizardContext.getAttribute(WIZARD_MANIPULATED_VARIABLE);
	if (manipulatedVariable != null) {
	  predicateBuf.append("\t");
	  predicateBuf.append("<predicate category='manipulatedVariable' value='");
	  predicateBuf.append(manipulatedVariable);
	  predicateBuf.append("'/>"+"\n");
	}

	predicateBuf.append("\t");
	predicateBuf.append("<dataset status='primary' type='log10 ratios'>"+"\n");
	predicateBuf.append("\t\t"+"<uri>");
	//	predicateBuf.append("httpIndirect://db.systemsbiology.net:8080/halo/DataFetcher.py/");
	predicateBuf.append(exptName);
	predicateBuf.append(".ratio</uri>"+"\n");
	predicateBuf.append("\t</dataset>"+"\n");

	predicateBuf.append("\t");
	predicateBuf.append("<dataset status='derived' type='lambdas'>"+"\n");
	predicateBuf.append("\t\t"+"<uri>");
	//	predicateBuf.append("httpIndirect://db.systemsbiology.net:8080/halo/DataFetcher.py/");
	predicateBuf.append(exptName);
	predicateBuf.append(".lambda</uri>"+"\n");
	predicateBuf.append("\t</dataset>"+"\n");

	Vector constants = (Vector)wizardContext.getAttribute(WIZARD_CONSTANTS);
	predicateBuf.append("\t<constants>\n");
	for (int m=0;m<constants.size();m++) {
	  ConditionVariable cv = (ConditionVariable)constants.elementAt(m);
	  constantsBuf.append("\t\t"+cv.getVariableTag()+"\n");
	}
	variablesBuf.append("\t</constants>\n");

	for (int m=0;m<conds;m++){
	  String conditionName = conditions[m];
	  ec = (ExperimentCondition)condData.get(conditionName);
	  Vector varVector = ec.getVariables();
	  variablesBuf.append("\t");
	  variablesBuf.append("<condition alias='");
	  variablesBuf.append(ec.getConditionAlias());
	  variablesBuf.append("'>"+"\n");
	  for (int h=0;h<varVector.size();h++){
		ConditionVariable cv = (ConditionVariable)varVector.elementAt(h);
		String var = cv.getVariableTag();
		variablesBuf.append("\t\t");
		variablesBuf.append(var+"\n");
	  }
	  variablesBuf.append("\t"+"</condition>"+"\n");
	}
	variablesBuf.append("</experiment>"+"\n");

	// Write XML
	TextWriter xmlWriter = new TextWriter(xmlFile);
	xmlWriter.write(predicateBuf.toString());
	xmlWriter.write(constantsBuf.toString());
	xmlWriter.write(variablesBuf.toString());
	xmlWriter.close();

	try{
	  VerifierFactory factory = new com.sun.msv.verifier.jarv.TheFactoryImpl();
	  Schema schema = factory.compileSchema("http://db/sbeams/tmp/Microarray/dataLoader/experiment.xsd");
	  Verifier verifier = schema.newVerifier();
	  if( verifier.verify(xmlFile) ) 
		status.append("Document is valid\n");
	  else
		status.append("Document is NOT valid.\nPlease report this to mjohnson@systemsbiology.org\n");
	}catch (Exception e) {
	  e.printStackTrace();
	  status.append("Document is NOT valid.\nPlease report this to mjohnson@systemsbiology.org\n");
	}


	TextWriter lambdaWriter = new TextWriter(lambdaFile);
	TextWriter ratioWriter = new TextWriter(ratioFile);
	StringBuffer lambdaBuffer = new StringBuffer();
	StringBuffer ratioBuffer = new StringBuffer();
	float[][] ratioData = new float[conds][individualRatios.length];
	float[][] lambdaData = new float[conds][individualLambdas.length];
	ratioData[0] = individualRatios;
	lambdaData[0] = individualLambdas;

	for (int m=0;m<conds;m++) {
	  ec = (ExperimentCondition)condData.get(conditions[m]);
	  aliases.put(conditions[m], ec.getConditionAlias());
	  individualRatios = ec.getRatioData();
	  individualLambdas = ec.getLambdaData();
	  ratioData[m] = individualRatios;
	  lambdaData[m] = individualLambdas;
	}

	//Print header
	lambdaBuffer.append("GENE");
	ratioBuffer.append("GENE");
	for (int m=0;m<conds;m++) {
	  lambdaBuffer.append("\t"+(String)aliases.get(conditions[m]));
	  ratioBuffer.append("\t"+(String)aliases.get(conditions[m]));
	}
	lambdaBuffer.append("\n");
	ratioBuffer.append("\n");

	for (int m=0;m<ratioData[0].length;m++) {
	  lambdaBuffer.append(gene[m]);
	  ratioBuffer.append(gene[m]);
	  for (int h=0;h<ratioData.length;h++) {
		ratioBuffer.append("\t"+ratioData[h][m]);
		lambdaBuffer.append("\t"+lambdaData[h][m]);
	  }
	  lambdaBuffer.append("\n");
	  ratioBuffer.append("\n");
	}

	lambdaWriter.write(lambdaBuffer.toString());
	ratioWriter.write(ratioBuffer.toString());
	lambdaWriter.close();
	ratioWriter.close();

  }// writeFiles
//-----------------------------------------------------------------------------------------------
  public boolean updateRepository(String fileBase) {
	boolean successfulUpdate = false;
	Pattern reposPattern = Pattern.compile("(.*)/.*?");
	Matcher reposMatch = reposPattern.matcher(fileBase);
	if (reposMatch.matches()){
	  String repos = reposMatch.group(1);
	  repos += "/.permissions";
	  System.out.println(repos);
	  String exp = (String)wizardContext.getAttribute(WIZARD_EXPERIMENT);
	  try{
		BufferedReader br = new BufferedReader(new FileReader(repos));
		TextWriter newRepos = new TextWriter(repos);
		StringBuffer sb = new StringBuffer();
		String newLineOfText;
		while ((newLineOfText = br.readLine()) != null)
		  sb.append(newLineOfText+"\n");
		sb.append(exp+": lab\n");
		newRepos.write(sb.toString());
		newRepos.close();
		successfulUpdate = true;
	  } catch (IOException e) {
		successfulUpdate = false;
	  }
	}else {
	  successfulUpdate = false;
	}
	return successfulUpdate;
  }
//-----------------------------------------------------------------------------------------------
  public void actionPerformed(ActionEvent e) {
	String command = e.getActionCommand();
	if (CHOOSE_DIRECTORY.equals(command) ||
		(DIRECTORY_CHECK.equals(command) &&
		 fileCheck.isSelected()) ) {
	  JFileChooser fc = new JFileChooser();
	  fc.setFileSelectionMode(JFileChooser.DIRECTORIES_ONLY);
	  fc.setDialogType(JFileChooser.SAVE_DIALOG);
	  fc.setApproveButtonText("Select Output Directory");
	  int returnVal = fc.showDialog(this, null);
	  if (returnVal == JFileChooser.APPROVE_OPTION) {
		String path = (fc.getSelectedFile()).toString();
		if ((fc.getSelectedFile()).isDirectory() == false) {
		  JOptionPane.showMessageDialog(this, "Selected Path is not a Directory!\n\n"+
										"\t-Using Directory Portion of this Path.");
		  path = (fc.getSelectedFile()).getParent();
		}
		directoryPath.setText( path );
		fileCheck.setSelected(true);
		repaint();
		
	  }
	}
  }// actionPerformed
//-----------------------------------------------------------------------------------------------
 public void display() {
 }// display
//-----------------------------------------------------------------------------------------------
  public boolean hasNext() {
	return false;
  }// hasNext
//-----------------------------------------------------------------------------------------------
  public boolean validateNext(List list) {
	return false;
  }// validateNext
//-----------------------------------------------------------------------------------------------
  public WizardPanel next() {
	return new NullWizardPanel();
  }// next
//-----------------------------------------------------------------------------------------------
  public boolean canFinish() {
	return true;
  }// canFinish
//-----------------------------------------------------------------------------------------------
  public boolean canCancel() {
	return true;
  }// canCancel
//-----------------------------------------------------------------------------------------------
  public boolean validateFinish(List list) {
	if (fileCheck.isSelected() == false &&
		sbeamsCheck.isSelected() == false) {
	  list.add("Need to specify output file name");
	  return false;
	}else if(fileCheck.isSelected() == false &&
			 sbeamsCheck.isSelected() == true) {
	  list.add("SBEAMS saving is not currently functional. Please save to file");
	  return false;
	}else {
	  String path = directoryPath.getText();
	  String baseName = new String(path+"/"+wizardContext.getAttribute(WIZARD_EXPERIMENT));
	  writeFiles(baseName);
	  //	  updateRepository(baseName);
	  String message = new String("Data Has Been Saved!\n\n"+
								  "Status:\n"+status.toString()+"\n"+
								  "Thanks for using the Data Loader");
 	  JOptionPane.showMessageDialog(this,
 									message,
 									"Data Loading Complete", 
 									JOptionPane.INFORMATION_MESSAGE);
	  finish();
	  return true;
	}
  }// validateFinish
//-----------------------------------------------------------------------------------------------
  public void finish() {
  }// finish
//-----------------------------------------------------------------------------------------------
}
