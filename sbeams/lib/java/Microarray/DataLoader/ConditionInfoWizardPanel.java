package DataLoader;
//-----------------------------------------------------------------------------------------------
import java.awt.*;
import java.awt.event.*;
import javax.swing.*;
import javax.swing.event.*;
import javax.swing.border.*;
import java.util.regex.*;
import java.text.DecimalFormat;
import java.util.List;
import java.util.Hashtable;
import java.util.Enumeration;
import java.util.Map;
import java.util.TreeMap;
import java.util.Vector;
import java.util.EventListener;
import java.util.Date;
import java.util.Calendar;
import java.util.GregorianCalendar;
import java.io.File;
import javax.swing.table.TableCellRenderer;
import javax.swing.table.TableColumn;
import javax.swing.table.TableColumnModel;
//-----------------------------------------------------------------------------------------------
public class ConditionInfoWizardPanel extends WizardPanel 
  implements ActionListener, KeyListener, MouseListener{
//-----------------------------------------------------------------------------------------------
  private static DecimalFormat twoDigits = new DecimalFormat("00");
  private JComboBox variableNames;
  private JTextField variableUnitsField = new JTextField(7);
  private JList conditionList;
  private JScrollPane variableList;
  private JScrollPane variableSummary;
  private VariableTable variableTable;
  private Hashtable condData;
  private Hashtable varsAndUnits;
  private static String VARIABLE_SELECTED = "variable_selected";
  private static String OTHER = "Other...";
  private static String ADD = "Add";
  private static String POPUP = "Popup";
  private static String REMOVE = "Remove Last";
  private static String RENAME = "Rename Conditions";
  private String[][] variables;
  private int currentVariableIndex;
//-----------------------------------------------------------------------------------------------
  public ConditionInfoWizardPanel(WizardContext wc) {
	setWizardContext(wc);
	condData = (Hashtable)wizardContext.getAttribute(WIZARD_HASH_CONDITIONS);
	setLayout(new BorderLayout());
	setBorder(new TitledBorder("Step 4.  Describe the Variables in this Experiment"));

	//------- Buttons Panel -------//
	JPanel allButtonsPanel = new JPanel(new BorderLayout());
	JButton renameButton = new JButton (RENAME);
	renameButton.setActionCommand(RENAME);
	renameButton.addActionListener(this);
	allButtonsPanel.add(renameButton, BorderLayout.WEST);

	JPanel inputPanel = new JPanel(new FlowLayout());
	JLabel name = new JLabel ("Variable Name: ");
	JLabel units = new JLabel ("Units: ");
	final JButton addButton = new JButton (ADD);
	addButton.setActionCommand(ADD);
	addButton.setMnemonic(KeyEvent.VK_ENTER);
	addButton.addActionListener(this);
	addButton.addKeyListener(this);
	variableUnitsField.addKeyListener(this);

	final JButton removeButton = new JButton(REMOVE);
	removeButton.setActionCommand(REMOVE);
	removeButton.addActionListener(this);

	Vector wizConstants = (Vector)wizardContext.getAttribute(WIZARD_CONSTANTS);
	Vector n;
	varsAndUnits = new Hashtable();
	if (wizConstants != null) {
	  n = new Vector(wizConstants.size()+2);
	  for (int m=0;m<wizConstants.size();m++) {
		String varName =((ConditionVariable)wizConstants.elementAt(m)).getVariableName(); 
		String varUnits = ((ConditionVariable)wizConstants.elementAt(m)).getVariableUnits();
		n.addElement(varName);
		varsAndUnits.put(varName, varUnits);
	  }
	  wizConstants.clear();
	} else {
	  n = new Vector(2);
	}
	n.add(0,"");
	n.addElement(OTHER);

	variableNames = new JComboBox(n);
	variableNames.setActionCommand(VARIABLE_SELECTED);
	variableNames.addActionListener(this);
	inputPanel.add(name);
	inputPanel.add(variableNames);
	inputPanel.add(units);
	inputPanel.add(variableUnitsField);
	inputPanel.add(addButton);
	inputPanel.add(removeButton);
	
	allButtonsPanel.add(inputPanel, BorderLayout.CENTER);

	//------- Split Pane -------//
	JPanel leftPanel = new JPanel(new BorderLayout());
	JPanel rightPanel = new JPanel(new BorderLayout());
	String[] conditions = (String[])wizardContext.getAttribute(WIZARD_CONDITIONS);
	
	variables = new String[conditions.length][5];
	currentVariableIndex = 0;

	ExperimentCondition[] v = new ExperimentCondition[conditions.length];
	for (int m=0;m<conditions.length;m++){
	  v[m] = (ExperimentCondition)condData.get(conditions[m]);
	}
	conditionList = new JList();
	conditionList.setModel(new ConditionListModel(v));
	conditionList.addKeyListener(this);
	conditionList.addMouseListener(this);
	conditionList.setSelectionMode(ListSelectionModel.MULTIPLE_INTERVAL_SELECTION);
	conditionList.setFixedCellHeight(20);
	variableList = new JScrollPane(conditionList);
	variableTable = new VariableTable(conditions.length,
									  conditionList.getFixedCellHeight());

	// Hack to make headers on both panes equal
	String[] choices = {REMOVE};
	JComboBox choiceTitle = new JComboBox(choices);
	double height = (choiceTitle.getPreferredSize()).getHeight();
	JLabel condLabel = new JLabel("Conditions");

	variableTable.addKeyListener(this);
	variableSummary = new JScrollPane(variableTable);
	variableSummary.setHorizontalScrollBarPolicy(JScrollPane.HORIZONTAL_SCROLLBAR_ALWAYS);
	variableSummary.setVerticalScrollBarPolicy(JScrollPane.VERTICAL_SCROLLBAR_ALWAYS);

	leftPanel.add(condLabel, BorderLayout.NORTH);
	leftPanel.add(variableList,BorderLayout.CENTER);
	rightPanel.add(variableSummary, BorderLayout.CENTER);
	JPanel conditionPanel = new JPanel(new BorderLayout());
	JSplitPane splitPane = new JSplitPane(JSplitPane.HORIZONTAL_SPLIT, leftPanel, rightPanel);
	splitPane.setDividerLocation(150);

	//------- Overall Panel -------//
	conditionPanel.add(allButtonsPanel, BorderLayout.NORTH);
	conditionPanel.add(splitPane, BorderLayout.CENTER);
	add(conditionPanel, BorderLayout.CENTER);
  }// constructor
//-----------------------------------------------------------------------------------------------
  public void keyPressed(KeyEvent e){
	if (e.getKeyCode() == KeyEvent.VK_ENTER){
	  registerNewVariable();
	}
  }// keyPressed
//-----------------------------------------------------------------------------------------------
  public void keyTyped(KeyEvent e){}
//-----------------------------------------------------------------------------------------------
  public void keyReleased (KeyEvent e){}
//-----------------------------------------------------------------------------------------------
  public void actionPerformed(ActionEvent e) {
	String command = e.getActionCommand();
	if (ADD.equals(command)) {
	  registerNewVariable();
	}else if (POPUP.equals(command)) {
	  registerAlias();
	}else if (VARIABLE_SELECTED.equals(command)) {
	  String selectedItem = (String)variableNames.getSelectedItem();
	  if (selectedItem.equals(OTHER)) {
	    String newVariable = JOptionPane.showInputDialog(this, "New Variable Name?");
		if (newVariable != null){
		  variableNames.insertItemAt(newVariable, 1);
		  variableNames.setSelectedIndex(1);
		}
	  }else{
		variableUnitsField.setText((String)varsAndUnits.get(selectedItem));
	  }
	}else if (REMOVE.equals(command)){
	  variableTable.removeLastColumn();
	}else if (RENAME.equals(command)) {
	  intelligentlySetAliases();
	}
  }// actionPerformed
//-----------------------------------------------------------------------------------------------
  private void intelligentlySetAliases() {
	String exptName = "unknownExperiment";
	exptName = (String)wizardContext.getAttribute(WIZARD_EXPERIMENT);
	int c = variableTable.getColumnCount();
	int r = variableTable.getRowCount();
	StringBuffer[] vars = new StringBuffer[r];
	for (int m=0;m<vars.length;m++) {
	  vars[m] = new StringBuffer();
	  vars[m].append(exptName+"__");
	}

	for (int m=0;m<c;m++){
	  String v = (String)(variableTable.getColumnHeader(m));
	  Pattern p = Pattern.compile(".*\\(\\s?(.*?)\\s?\\).*");
	  Matcher u = p.matcher(v);
	  String variableUnits = new String();
	  if (u.matches())
		variableUnits = u.group(1);
	  String abbreviatedUnits = translate(variableUnits);
	  for (int h=0;h<r;h++){
		String value = (String)variableTable.getValueAt(h,m);
		vars[h].append(value);
		if (!abbreviatedUnits.equals(""))
		  vars[h].append(abbreviatedUnits);
		if (m != (c-1))
		  vars[h].append("-");
	  }
	}
	for (int m=0;m<vars.length;m++) {
	  registerAlias(m,vars[m].toString());
	}
	this.repaint();
  }// intelligentlySetAliases
//-----------------------------------------------------------------------------------------------
  private String translate(String units) {
	units.toLowerCase();
	if (units.equals("micromolar"))
	  return "uM";
	else if (units.equals("millimolar"))
	  return "mM";
	else if (units.equals("Gy"))
	  return "gy";
	else if (units.equals("minutes"))
	  return "m";
	else if (units.equals("percent"))
	  return ("pct");
	else
	  return units;		 
  }// translate
//-----------------------------------------------------------------------------------------------
  private void registerNewVariable() {
	String columnTitle = new String(variableNames.getSelectedItem()+
									" ( "+variableUnitsField.getText()+" ) ");
	variableTable.addDataColumn(columnTitle);
  }// registerNewVariable
//-----------------------------------------------------------------------------------------------
  private void registerAlias(int index, String alias) {
	ConditionListModel clm = (ConditionListModel)(conditionList.getModel());
	ExperimentCondition ec =(ExperimentCondition)clm.getElementDataAt(index);
	ec.setAlias(alias);
	this.repaint();
  }// registerAlias
//-----------------------------------------------------------------------------------------------
  private void registerAlias() {
	int[] indices = conditionList.getSelectedIndices();
	for (int m=0;m<indices.length;m++) {
	  int index = indices[m];
	  String condName = getConditionName(index);
	  String alias = JOptionPane.showInputDialog(this, "Condition Name: "+condName+"\n\nSet Alias To:");
	  if (alias != null) {
		registerAlias(index,alias);
	  }
	}
  }// registerAlias
//-----------------------------------------------------------------------------------------------
  private void setVariables() {
	int c = variableTable.getColumnCount();
	int r = variableTable.getRowCount();
	for (int m=0;m<c;m++){
	  String variableTitle = (String)(variableTable.getColumnHeader(m));
	  Pattern p = Pattern.compile("(.*)\\s\\((.*?)\\).*");
	  Matcher u = p.matcher(variableTitle);
	  String variableUnits = new String();
	  String variableName = new String();
	  if (u.matches()) {
		variableUnits = u.group(2);
		variableName = u.group(1);
	  }
	  for (int h=0;h<r;h++) {
		String variableValue = (String)variableTable.getValueAt(h,m);
		ConditionVariable cv = new ConditionVariable(variableName.trim(), variableValue.trim(), variableUnits.trim());
		conditionList.setSelectedIndex(h);
		ExperimentCondition ec = (ExperimentCondition)condData.get(getConditionName(h));
		ec.addVariable(cv);
	  }
	}
  }// setVariables
//-----------------------------------------------------------------------------------------------
  private String getConditionName(int index){
	return ((ExperimentCondition)((ConditionListModel)(conditionList.getModel())).getElementDataAt(index)).getConditionName();

  }// getConditionName
//-----------------------------------------------------------------------------------------------
  public void mouseClicked(MouseEvent e) {}
//-----------------------------------------------------------------------------------------------
  public void mousePressed(MouseEvent e) {}
//-----------------------------------------------------------------------------------------------
  public void mouseEntered(MouseEvent e) {}
//-----------------------------------------------------------------------------------------------
  public void mouseExited(MouseEvent e) {}
//-----------------------------------------------------------------------------------------------
  public void mouseReleased(MouseEvent e) {
	if (SwingUtilities.isRightMouseButton(e)) {
	  Point p = e.getPoint();
	  JPopupMenu menu = new JPopupMenu();
	  JMenuItem item = new JMenuItem("Rename...");
	  menu.add(item);
	  item.setActionCommand(POPUP);
	  item.addActionListener(this);
	  menu.setLightWeightPopupEnabled(false);
	  menu.show(variableList, (int)p.getX(), (int)p.getY());
	}
  }// mouseReleased
//-----------------------------------------------------------------------------------------------
class ConditionListModel extends AbstractListModel {
  ExperimentCondition[] ec;
  public ConditionListModel(ExperimentCondition[] ec){
	this.ec = ec;
  }
  public Object getElementAt(int m) {
	return ec[m].getConditionAlias();
  }
  public Object getElementDataAt(int m) {
	return ec[m];
  }
  public int getSize(){return ec.length;}
}// class ConditionListModel
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
	return valid;
  }// validateNext
//-----------------------------------------------------------------------------------------------
  public WizardPanel next() {
	return new DataSaverPanel(getWizardContext());
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
	return true;
  }
//-----------------------------------------------------------------------------------------------
  public void finish() {
  }// finish
//-----------------------------------------------------------------------------------------------
}
