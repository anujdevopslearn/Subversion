package DataLoader;
import java.util.List;
import java.util.Vector;
import java.util.Hashtable;
import java.util.Enumeration;
import java.util.Arrays;
import java.util.regex.*;
import java.awt.*;
import java.io.*;
import java.awt.event.*;
import javax.swing.*;
import javax.swing.event.*;
import javax.swing.border.*;
import javax.swing.filechooser.FileFilter;
import javax.swing.table.TableColumn;
import javax.swing.table.DefaultTableModel;
import SBEAMS.*;
//-----------------------------------------------------------------------------------------------
public class GeneralInfoWizardPanel extends WizardPanel {
//-----------------------------------------------------------------------------------------------
  private JComboBox organismDropDown;
  private JComboBox constantsDropDown;
  private JTextField strain;
  private JTextField manipulationType;
  private JTextField manipulatedVariable;
  private JTextField constantsFile;
  private JTable constantsTable;
  private JScrollPane constantsScrollPane;
  private BufferedReader bufferedReader;
  private StringBuffer strbuf;
  private SBEAMSClient sc;
  private Hashtable constantsFiles;
  private String[] titles = {"Variable", "Value", "Units"};
  private static String CONSTANTS = "Constants";
  private static String SELECT_ORGANISM="---Select Organism---";
  private static String SELECT_CONSTANTS="---Select Constants---";
  private static String OTHER_ORGANISM= "Other...";

  private static String SBEAMS_SERVER_BASE = "http://db";
  private static String constantsFileURL = SBEAMS_SERVER_BASE+"/sbeams/cgi/Microarray/ViewFile.cgi?action=read&FILE_NAME=";
  private static String organismURL = SBEAMS_SERVER_BASE+"/sbeams/cgi/Microarray/ManageTable.cgi?TABLE_NAME=organism&output_mode=tsv";
  private static String constantsURL = SBEAMS_SERVER_BASE+"/sbeams/cgi/Microarray/ManageTable.cgi?TABLE_NAME=MA_experiment_constants&output_mode=tsv";
//-----------------------------------------------------------------------------------------------
  public GeneralInfoWizardPanel(WizardContext wc) {
	setWizardContext(wc);
	setLayout(new BorderLayout());
	setBorder(new TitledBorder("Step 3.  Describe the General Experiment Information"));
	SpringLayout layout = new SpringLayout();
	JPanel infoPanel = new JPanel(layout);

	JPanel userInputPanel = new JPanel(new GridLayout(0,2));
	userInputPanel.add(new JLabel("Organism"));
	if (wizardContext.getAttribute(SBEAMS_CLIENT) == null) {
	  try{ 
		sc = new SBEAMSClient(true);
	  }catch (Exception e) {
		e.printStackTrace();
	  }
	}else {
	  sc = (SBEAMSClient)wizardContext.getAttribute(SBEAMS_CLIENT);
	}

	Vector orgsFromSbeams = new Vector();
	orgsFromSbeams.add(SELECT_ORGANISM);
	try{
	  String[] tempOrgs = sc.fetchSbeamsResultSetColumn(organismURL,"full_name");
	  //	  String[] tempOrgs = (sc.fetchSbeamsPage(organismURL)).split("\\n");
	  for (int m=0;m<tempOrgs.length;m++) {
		if (tempOrgs[m].equals("Other")) {
		  continue;
		}else {
		  orgsFromSbeams.add(tempOrgs[m]);
		}
	  }
	}catch (Exception e) {
	  e.printStackTrace();
	}
	orgsFromSbeams.add(OTHER_ORGANISM);
	String[] organisms = new String[orgsFromSbeams.size()];
	orgsFromSbeams.toArray(organisms);
	organismDropDown = new JComboBox(organisms);
	organismDropDown.addItemListener(new ItemListener(){ 

  public void itemStateChanged(ItemEvent e) {
	  if (e.getStateChange() == ItemEvent.SELECTED){
		String newOrg = new String("");
		if (!((String)organismDropDown.getSelectedItem()).equals(OTHER_ORGANISM))
		  return;
		else{
		  newOrg = JOptionPane.showInputDialog(null, "What is the name of this organism?");
		  if (newOrg.equals(""))
			return;
		  int s = organismDropDown.getItemCount();
		  for (int m=0;m<s;m++) {
			if (newOrg.equals((String)organismDropDown.getItemAt(m))) {
			  JOptionPane.showMessageDialog(null, "Organism is currently in the list!",
											"Alert", JOptionPane.ERROR_MESSAGE);
			  return;
			}
		  }

		  if (!newOrg.equals("")){
			organismDropDown.addItem(newOrg);
			organismDropDown.setSelectedItem(newOrg);
			organismDropDown.repaint();
		  }
		}
	  }
	}

	  });

	userInputPanel.add(organismDropDown);

	userInputPanel.add(new JLabel("Strain"));
	strain = new JTextField("wild type", 30);
	userInputPanel.add(strain);
	String perturbation = (String)wizardContext.getAttribute(WIZARD_PERTURBATION);
	String[] breakdown = perturbation.split(":");
	String mt = new String();
	String mv = new String();
	if (breakdown.length>=3) {
	  mt = breakdown[0];
	  mv = breakdown[breakdown.length-2];
	}
	userInputPanel.add(new JLabel("Manipulation Type"));
	manipulationType = new JTextField(mt, 30);
	userInputPanel.add(manipulationType);
	userInputPanel.add(new JLabel("Manipulated Variable"));
	manipulatedVariable = new JTextField(mv, 30);
	userInputPanel.add(manipulatedVariable);

	Vector constantsFromSbeams = new Vector();
	constantsFiles = new Hashtable();
	constantsFromSbeams.add(SELECT_CONSTANTS);
	try{
	  constantsFiles = sc.fetchSbeamsResultSetHash(constantsURL, "name", "experiment_constants_id");
	  for (Enumeration enum = constantsFiles.keys(); enum.hasMoreElements();) {
		constantsFromSbeams.add((String)enum.nextElement());
	  }
	}catch (Exception e) {
	  e.printStackTrace();
	}
	String[] constants = new String[constantsFromSbeams.size()];
	constantsFromSbeams.toArray(constants);
	Arrays.sort(constants);
	constantsDropDown = new JComboBox(constants);
	constantsDropDown.addItemListener(new ItemListener() {

  public void itemStateChanged(ItemEvent e) {
	if (e.getStateChange() == ItemEvent.SELECTED ){
	  Integer record_id = new Integer( (String)constantsFiles.get(e.getItem()) );
	  String fileUrl = constantsFileURL+constantsFiles.get(e.getItem())+"_constants_file.dat";
	  try{
		String[][] constants = interpretConstants(record_id, sc.fetchSbeamsPage(fileUrl));
		if (constants != null)
		  ((DefaultTableModel)constantsTable.getModel()).setDataVector(constants,titles);
		constantsScrollPane.getParent().setVisible(false);
		constantsTable.repaint();
		Dimension d = constantsTable.getPreferredSize();
		constantsScrollPane.setPreferredSize(d);
		constantsScrollPane.repaint();
		constantsScrollPane.getParent().setVisible(true);
	  }catch (Exception except) {
		except.printStackTrace();
	  }
	}
  }

	  });

	userInputPanel.add(new JLabel("Constants"));
	userInputPanel.add(constantsDropDown);
	
	infoPanel.add(userInputPanel);
	layout.putConstraint(SpringLayout.WEST, userInputPanel, 10, SpringLayout.WEST, infoPanel);
	add(infoPanel, BorderLayout.CENTER);

	ConstantsTableModel model = new ConstantsTableModel();
	constantsTable = new JTable(model);
	model.setDataVector(new String[5][3], titles);
	Dimension d = constantsTable.getPreferredSize();
	constantsScrollPane = new JScrollPane(constantsTable);
	constantsScrollPane.setPreferredSize(d);
	add(constantsScrollPane, BorderLayout.SOUTH);
  }// constructor
//-----------------------------------------------------------------------------------------------
  class ConstantsTableModel extends DefaultTableModel {
	public boolean isCellEditable(int row, int col){
	  return false;
	}
  }// class ConstantsTableModel
//-----------------------------------------------------------------------------------------------
  public String[][] interpretConstants(Integer sbeamsId, String constantsData){
	wizardContext.setAttribute(WIZARD_CONSTANTS_ID, sbeamsId);
	return interpretConstants(constantsData);
  }// interpretConstants
//-----------------------------------------------------------------------------------------------
  public String[][] interpretConstants(String constantsData) {
	Vector c = new Vector();
	Vector wizardVars = new Vector();
	String [] dataLines = constantsData.split("\\n");
	Pattern n = Pattern.compile(".*?<variable name='(.*?)'.*");
	Pattern v = Pattern.compile(".*?name='.*?'.*?value='(.*?)' .*>");
	Pattern u = Pattern.compile(".*?name.*?units='(.*?)'.*>");
	for (int m=0;m<dataLines.length;m++) { 
	  Matcher nVal = n.matcher(dataLines[m]);
	  Matcher vVal = v.matcher(dataLines[m]);
	  Matcher uVal = u.matcher(dataLines[m]);
	  if (nVal.matches()) {
		String[]constant = new String[3];
		constant[0] = nVal.group(1);
		if (vVal.matches())
		  constant[1] = vVal.group(1);
		else
		  constant[1] = "";
		if (uVal.matches())
		  constant[2] = uVal.group(1);
		else constant[2] = "";
		c.addElement(constant);
		ConditionVariable cv = new ConditionVariable(constant[0],
													 constant[1],
													 constant[2]);  
		wizardVars.addElement(cv);
	  }
	}
	wizardContext.setAttribute(WIZARD_CONSTANTS, wizardVars);
	
	if (c.size() >0){
	  String[][] returnArray = new String[c.size()][3];
	  for (int m=0;m<c.size();m++) {
		String[] constant = (String[])c.elementAt(m);
		returnArray[m] = constant;
	  }
	  return returnArray;
	}else
	  return null;
  }// interpretConstants
//-----------------------------------------------------------------------------------------------
  public String[][] readConstants(String filePath) {
	Vector c = new Vector();
	Vector wizardVars = new Vector();
	try{
	  bufferedReader = new BufferedReader(new FileReader(filePath));
	}catch (IOException e) {
	  e.printStackTrace();
	  return null;
	}
	strbuf = new StringBuffer();
	String newLineOfText;
	int conditionMax = 0;
	try {
	  while ( (newLineOfText = bufferedReader.readLine()) != null ) {
		strbuf.append(newLineOfText +"\n");
	  }
	  String all = strbuf.toString();
	  return interpretConstants(all);
	}catch (IOException e){
	  e.printStackTrace();
	  return null;
	}
  }// readConstants
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
	String org = (String)organismDropDown.getSelectedItem();
	String st = strain.getText();
	String mt = manipulationType.getText();
	String mv = manipulatedVariable.getText();
	if (org.equals(SELECT_ORGANISM)) {
	  list.add("Please Select Organism Before Continuing");
	  valid = false;
	}else {
	  wizardContext.setAttribute(WIZARD_ORGANISM,org);
	}
	if (st == null) {
	  list.add("Please Select Strain Before Continuing");
	  valid = false;
	}else{
	  wizardContext.setAttribute(WIZARD_STRAIN, st);
	}
	if (mt == null) {
	  list.add("Please Select Manipulation Type Before Continuing");
	  valid = false;
	}else {
	  wizardContext.setAttribute(WIZARD_MANIPULATION_TYPE,mt);
	}
	if (mv == null) {
	  list.add("Please Select Manipulated Variable Before Continuing");
	  valid = false;
	}else {
	  wizardContext.setAttribute(WIZARD_MANIPULATED_VARIABLE, mv);
	}
	return valid;
  }// validateNext
//-----------------------------------------------------------------------------------------------
  public WizardPanel next() {
	return new ConditionInfoWizardPanel(getWizardContext());
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
