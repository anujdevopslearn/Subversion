package DataLoader;
//-----------------------------------------------------------------------------------------------
import javax.swing.*;
import javax.swing.border.TitledBorder;
import java.awt.*;
import java.awt.event.*;
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

  private Hashtable condData;
//-----------------------------------------------------------------------------------------------
  public DataSaverPanel(WizardContext wc) {
	setWizardContext(wc);
	condData = (Hashtable)wizardContext.getAttribute(WIZARD_HASH_CONDITIONS);
	setLayout(new BorderLayout());
	setBorder(new TitledBorder("Step 5.  Save Data and Exit"));

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

	JPanel sbeamsPanel = new JPanel();
	sbeamsCheck = new JCheckBox("Save to SBEAMS");
	sbeamsPanel.add(sbeamsCheck);
	sbeamsPanel.setPreferredSize(filePanel.getPreferredSize());

	JPanel savePanel = new JPanel();
	savePanel.setLayout(new GridLayout(0,1));
	savePanel.add(instructionPanel);
	savePanel.add(filePanel);
	savePanel.add(sbeamsPanel);

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


	StringBuffer xmlbuf = new StringBuffer();
	String exptName =(String)wizardContext.getAttribute(WIZARD_EXPERIMENT); 
	xmlbuf.append("<?xml version=\"1.0\" ?>"+"\n");
	xmlbuf.append("<experiment name=\"");
	xmlbuf.append(exptName);
	xmlbuf.append("\" date=\""+date+"\">"+"\n");
	xmlbuf.append ("\t");
	xmlbuf.append("<predicate category='species' value='");
	xmlbuf.append((String)wizardContext.getAttribute(WIZARD_ORGANISM));
	xmlbuf.append("'/>"+"\n");

	xmlbuf.append ("\t");
	xmlbuf.append("<predicate category='perturbation' value='");
	xmlbuf.append((String)wizardContext.getAttribute(WIZARD_PERTURBATION));
	xmlbuf.append("'/>\n");

	xmlbuf.append ("\t");
	xmlbuf.append("<predicate category='strain' value='");
	xmlbuf.append((String)wizardContext.getAttribute(WIZARD_STRAIN));
	xmlbuf.append("'/>"+"\n");

	String manipulationType = (String)wizardContext.getAttribute(WIZARD_MANIPULATION_TYPE);
	if (manipulationType != null) {
	  xmlbuf.append ("\t");
	  xmlbuf.append("<predicate category='manipulationType' value='");
	  xmlbuf.append(manipulationType);
	  xmlbuf.append("'/>"+"\n");
	}

	String manipulatedVariable = (String)wizardContext.getAttribute(WIZARD_MANIPULATED_VARIABLE);
	if (manipulatedVariable != null) {
	  xmlbuf.append("\t");
	  xmlbuf.append("<predicate category='manipulatedVariable' value='");
	  xmlbuf.append(manipulatedVariable);
	  xmlbuf.append("'/>"+"\n");
	}

	xmlbuf.append("\t");
	xmlbuf.append("<dataset status='primary' type='log10 ratios'>"+"\n");
	xmlbuf.append("\t\t"+"<uri>");
	xmlbuf.append("httpIndirect://db.systemsbiology.net:8080/halo/DataFetcher.py/");
	xmlbuf.append(exptName);
	xmlbuf.append(".ratio</uri>"+"\n");
	xmlbuf.append("\t</dataset>"+"\n");

	xmlbuf.append("\t");
	xmlbuf.append("<dataset status='derived' type='lambdas'>"+"\n");
	xmlbuf.append("\t\t"+"<uri>");
	xmlbuf.append("httpIndirect://db.systemsbiology.net:8080/halo/DataFetcher.py/");
	xmlbuf.append(exptName);
	xmlbuf.append(".lambda</uri>"+"\n");
	xmlbuf.append("\t</dataset>"+"\n");

	for (int m=0;m<conds;m++){
	  String conditionName = conditions[m];
	  ec = (ExperimentCondition)condData.get(conditionName);
	  Vector varVector = ec.getVariables();
	  xmlbuf.append("\t");
	  xmlbuf.append("<condition alias='");
	  xmlbuf.append(ec.getConditionAlias());
	  xmlbuf.append("'>"+"\n");
	  for (int h=0;h<varVector.size();h++){
		ConditionVariable cv = (ConditionVariable)varVector.elementAt(h);
		String var = cv.getVariableTag();
		xmlbuf.append("\t\t");
		xmlbuf.append(var+"\n");
	  }
	  xmlbuf.append("\t"+"</condition>"+"\n");
	}
	xmlbuf.append("</experiment>"+"\n");

	// Validate XML
	try{
	  VerifierFactory factory = new com.sun.msv.verifier.jarv.TheFactoryImpl();
	  Schema schema = factory.compileSchema("experiment.xsd");
	  Verifier verifier = schema.newVerifier();
	  if( verifier.verify(xmlbuf.toString()) ) {
		System.out.println("Document is valid");
		TextWriter xmlWriter = new TextWriter(xmlFile);
		xmlWriter.write(xmlbuf.toString());
		xmlWriter.close();
		return;
	  } else {
		System.out.println("Document is NOT valid");
	  }
	}catch (Exception e) {
	  e.printStackTrace();
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
  public void actionPerformed(ActionEvent e) {
	String command = e.getActionCommand();
	if (CHOOSE_DIRECTORY.equals(command) ||
		(DIRECTORY_CHECK.equals(command) &&
		 fileCheck.isSelected()) ) {
	  JFileChooser fc = new JFileChooser();
	  fc.setFileSelectionMode(JFileChooser.DIRECTORIES_ONLY);
	  int returnVal = fc.showDialog(this, "Select Output Directory");
	  if (returnVal == JFileChooser.APPROVE_OPTION) {
		String path = (fc.getSelectedFile()).toString();
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
	  String message = new String("Data Has Been Saved!\n\n"+
								  "Click 'Finish' to Exit\n\n"+
								  "Thanks for using the Data Loader");
	  JOptionPane.showMessageDialog(this,
									message,
									"Data Loading Complete", 
									JOptionPane.INFORMATION_MESSAGE);
	  return true;
	}
  }// validateFinish
//-----------------------------------------------------------------------------------------------
  public void finish() {
  }// finish
//-----------------------------------------------------------------------------------------------
}
