package DataLoader;
import java.util.List;
import java.util.Hashtable;
import java.awt.*;
import java.awt.event.*;
import javax.swing.*;
import javax.swing.event.*;
import javax.swing.border.*;
import java.io.*;
import SBEAMS.*;
//-----------------------------------------------------------------------------------------------
public class FileChooserWizardPanel extends WizardPanel 
  implements ActionListener, ListSelectionListener{
//-----------------------------------------------------------------------------------------------
  private static String NEW_EXPERIMENT = "New Experiment";
  private JButton chooseFileButton;
  private JPanel imagePanel;
  private JList conditionList;
  private String experimentName = NEW_EXPERIMENT;
  private String dataFile;
  private JTextField experimentNameField;
  private String[] conditionNames;
  private BufferedReader bufferedReader;
  private StringBuffer strbuf;
  private Hashtable tempData;
  private SBEAMSClient sc;
  private Integer project_id;
  private static String expNameURL="http://db/sbeams/cgi/Microarray/ManageTable.cgi?TABLE_NAME=project&output_mode=tsv";
//-----------------------------------------------------------------------------------------------
  public FileChooserWizardPanel() {
	initialize();
  }// constructor
//-----------------------------------------------------------------------------------------------
  public FileChooserWizardPanel(String dataFile) {
	this.dataFile = dataFile;
	initialize();
	handleDataFile(dataFile);
  }// constructor
//-----------------------------------------------------------------------------------------------
  public FileChooserWizardPanel(String dataFile, String translatorFile, Integer project_id) {
	this.dataFile = dataFile;
	this.project_id = project_id;
	initialize();	
	handleDataFile(dataFile, translatorFile);
  }// constructor
//-----------------------------------------------------------------------------------------------
  public void initialize(){

	if (project_id != null) {
	  try{
		if (sc == null)
		  sc = new SBEAMSClient(true);
		Hashtable h = sc.fetchSbeamsResultSetHash(expNameURL, "project_id", "name");
		if ( h.containsKey( project_id.toString() ) ) {
		  experimentName =  (String) ( h.get(project_id.toString()) );
		  experimentName = experimentName.trim();
		  experimentName = experimentName.replaceAll("\\s","_");
		}
	  }catch (Exception e) {
		e.printStackTrace();
	  }
	}

	tempData = new Hashtable();
	setLayout(new BorderLayout());
	setBorder(new TitledBorder("Step 1. Select File to Load"));
	JPanel experimentNamePanel = new JPanel();
	experimentNamePanel.add(new JLabel("Experiment Name: "));
	experimentNameField = new JTextField(15);
	experimentNameField.requestFocus();
	experimentNamePanel.add(experimentNameField);
	add(experimentNamePanel, BorderLayout.NORTH);
	JPanel leftPanel = new JPanel(new BorderLayout());
	leftPanel.add(new JLabel("Conditions"), BorderLayout.NORTH);
	conditionList = new JList();
	conditionList.addListSelectionListener(this);
	leftPanel.add(new JScrollPane(conditionList), BorderLayout.CENTER);
	imagePanel = new JPanel(new BorderLayout());
	JSplitPane splitPane = new JSplitPane(JSplitPane.HORIZONTAL_SPLIT, leftPanel, imagePanel);
	splitPane.setDividerLocation(150);
	add(splitPane, BorderLayout.CENTER);
	JPanel buttonPanel = new JPanel();
	chooseFileButton = new JButton ("Select File");	
	chooseFileButton.addActionListener(this);
	buttonPanel.add(chooseFileButton);
	add(buttonPanel, BorderLayout.SOUTH);
  }// initialize
//-----------------------------------------------------------------------------------------------
  private boolean readFile(String filePath){
	try{
	  bufferedReader = new BufferedReader(new FileReader(filePath));
	}catch (IOException e) {
	  e.printStackTrace();
	  return false;
	}
	strbuf = new StringBuffer();
	String newLineOfText;
	int conditionMax = 0;
	try {
	  // Read file into a big string
	  while ( (newLineOfText = bufferedReader.readLine()) != null ) {
		strbuf.append(newLineOfText +"\n");
	  }
	  String all = strbuf.toString();
	  String [] dataLines = all.split("\\n");
	  // Look at 1st line (header)
	  String[] line = (dataLines[0]).split("\\s");
	  int conditions = (int)(line.length-2)/2;
	  conditionNames = new String[conditions];
	  for (int m=0;m<conditions;m++){
		conditionNames[m] = line[m+2];
	  }
	  //Handle rest of lines
	  String[] genes = new String[dataLines.length-1];
	  float[][] ratioValues = new float[conditions][dataLines.length-1];
	  float[][] lambdaValues = new float[conditions][dataLines.length-1];
	  for (int m=1;m<dataLines.length;m++) {
		line = dataLines[m].split("\\s");
		if (line.length != (2*conditions) + 2) 
		  return false;
		genes[m-1] = line[0];
		for (int h=0;h<conditions;h++){
		  ratioValues[h][m-1] = (new Float(line[h+2])).floatValue();
		  lambdaValues[h][m-1] = (new Float(line[h+2+conditions])).floatValue();
		}
	  }

	  for (int m=0;m<conditionNames.length;m++) {
		ExperimentCondition e =  new ExperimentCondition(conditionNames[m],
														 genes,
														 ratioValues[m],
														 lambdaValues[m]);
		tempData.put(conditionNames[m], e);
	  }
	}
	catch (IOException e) {
	  e.printStackTrace ();
	  return false;
	}
	return true;
  }// readFile
//-----------------------------------------------------------------------------------------------
  public void actionPerformed(ActionEvent e) {
	JFileChooser fc = new JFileChooser();
	int returnVal = fc.showOpenDialog(this);
	if (returnVal ==JFileChooser.APPROVE_OPTION) {
	  dataFile = (fc.getSelectedFile()).toString();
	  handleDataFile( dataFile );
 	}
  }// actionPerformed
//-----------------------------------------------------------------------------------------------
  private String getExperimentName() {
	String newName = JOptionPane.showInputDialog(this, 
												 "What is the name of this experiment?",
												 experimentName);
	if (newName == null || newName.equals("")) 
	  experimentName = new String(NEW_EXPERIMENT);
	else 
	  experimentName = newName;

	return experimentName;
  }// getExperimentName
//-----------------------------------------------------------------------------------------------
  private void handleDataFile(String dataFile) {
	handleDataFile(dataFile, null);
  }
//-----------------------------------------------------------------------------------------------
  private void handleDataFile(String dataFile, String translator) {
	boolean success = false;
	GeneExpressionFileReader gefr = new GeneExpressionFileReader(dataFile, translator,sc);
	success = gefr.read();
	if (!success) {
	  JOptionPane.showMessageDialog(null, "Unable to Load File", "Alert", JOptionPane.ERROR_MESSAGE);
	  return;
	}else {
	  if (sc == null  && gefr.getSbeamsClient() != null) 
		sc = gefr.getSbeamsClient();
	  conditionNames = gefr.getConditionNames();
	  tempData = gefr.getData();
	  conditionList.setListData(conditionNames);
	  conditionList.setSelectedIndex(0);
	  conditionList.repaint();
	  paintIcon();
	  experimentName = getExperimentName();
	  experimentNameField.setText(experimentName);
	  experimentNameField.repaint();
	}
  }// handleDataFile
//-----------------------------------------------------------------------------------------------
  private void paintIcon () {
	String condition = (String)conditionList.getSelectedValue();
	ExperimentCondition ec = (ExperimentCondition)tempData.get(condition);
	ArrayIcon icon = new ArrayIcon (ec.getIconData());
	JPanel tempPanel = icon.getPanel();
	imagePanel.setVisible(false);
	imagePanel.add(tempPanel, BorderLayout.CENTER);
	imagePanel.setVisible(true);
  }// paintIcon
//-----------------------------------------------------------------------------------------------
  public void valueChanged(ListSelectionEvent e){
	if (e.getValueIsAdjusting()) {
	  paintIcon();
	}
  }// valueChanged
//-----------------------------------------------------------------------------------------------
  public void display() {
  }// display
//-----------------------------------------------------------------------------------------------
  public boolean hasNext() {
	return true;
  }// hasNext
//-----------------------------------------------------------------------------------------------
  public boolean validateNext(List list) {
	boolean valid = true;
	if (dataFile == null) {
	  list.add("Please Select a Data File Before Continuing");
	  valid = false;
	}else if (experimentNameField.getText() == null ||
			  experimentNameField.getText().matches("^\\s*$")){
	  list.add("Please Input an ExperimentName");
	  experimentNameField.requestFocus();
	  valid = false;
	}else {
	  experimentName = experimentNameField.getText();
	  if (sc != null){
		wizardContext.setAttribute(SBEAMS_CLIENT, sc);
	  }
	  if (project_id != null)
		wizardContext.setAttribute(WIZARD_PROJECT_ID, project_id);
	  wizardContext.setAttribute(WIZARD_FILE, dataFile);
	  wizardContext.setAttribute(WIZARD_EXPERIMENT, experimentName);
	  wizardContext.setAttribute(WIZARD_HASH_CONDITIONS, tempData);
	  wizardContext.setAttribute(WIZARD_CONDITIONS, conditionNames);
	}
	return valid;
  }// validateNext
//-----------------------------------------------------------------------------------------------
  public boolean hasHelp() {
	return false;
  }// hasHelp
//-----------------------------------------------------------------------------------------------
  public void help() {
  }// help
//-----------------------------------------------------------------------------------------------
  public WizardPanel next() {
	return new ConditionTreeWizardPanel(getWizardContext());
  }// next
//-----------------------------------------------------------------------------------------------
  public boolean canFinish() {
	return false;
  }// canFinish
//-----------------------------------------------------------------------------------------------
  public boolean canCancel() {
	return true;
  }// canCancel
//-----------------------------------------------------------------------------------------------
  public boolean validateFinish(List list) {
	return false;
  }// validateFinish
//-----------------------------------------------------------------------------------------------
  public void finish() {
  }// finish
//-----------------------------------------------------------------------------------------------
}
