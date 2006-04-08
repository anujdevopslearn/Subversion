package DataLoader;
//-----------------------------------------------------------------------------------------------
import java.util.List;
import java.util.Hashtable;
import java.util.HashMap;
import java.util.Arrays;
import java.awt.*;
import java.awt.event.*;
import javax.swing.*;
import javax.swing.event.*;
import javax.swing.border.*;
import javax.swing.tree.*;
import java.lang.*;
import csplugins.isb.pshannon.experiment.metadata.*;
//-----------------------------------------------------------------------------------------------
public class ConditionTreeWizardPanel extends WizardPanel 
  implements ActionListener {
//-----------------------------------------------------------------------------------------------
  private static String repository = "httpIndirect://db.systemsbiology.net:8080/halo/DataFetcher.py";
  protected MetaDataNavigator experimentNavigator;
  protected JTree tree;
  protected PerturbationNode rootNode;
  protected DefaultTreeModel treeModel;
  private static String INSERT_COMMAND = "Insert";
  private static String REPLACE_COMMAND = "Replace";
  private JTextField currentPerturbation;
  //  private static String REMOVE_COMMAND = "Remove";
//-----------------------------------------------------------------------------------------------
  protected static class PerturbationNode extends DefaultMutableTreeNode{
	private boolean isEditable;
	public PerturbationNode(Object a){
	  super(a);
	}
	public void setEditable(boolean b){
	  isEditable = b;
	}
	public boolean isEditable() {
	  return isEditable;
	}
  }// class PerturbationNode
//-----------------------------------------------------------------------------------------------
  public ConditionTreeWizardPanel(WizardContext wc) {
	setWizardContext(wc);
	setLayout(new BorderLayout());
	setBorder(new TitledBorder("Step 2. Place Experiment Set Within the Condition Tree"));
	add(initTree(), BorderLayout.CENTER);

	JPanel treeStatusPanel = new JPanel(new GridLayout(0,1));
	JPanel perturbationPanel = new JPanel();
	perturbationPanel.add(new JLabel("Perturbation: "));
	currentPerturbation = new JTextField(30);
	currentPerturbation.setEditable(false);
	perturbationPanel.add(currentPerturbation);
	JPanel treeButtonPanel = new JPanel();
	JButton addNodeButton = new JButton(INSERT_COMMAND);
	addNodeButton.setActionCommand(INSERT_COMMAND);
	addNodeButton.addActionListener(this);
	JButton replaceNodeButton = new JButton(REPLACE_COMMAND);
	replaceNodeButton.setActionCommand(REPLACE_COMMAND);
	replaceNodeButton.addActionListener(this);
	/*
	JButton removeNodeButton = new JButton(REMOVE_COMMAND);
	removeNodeButton.setActionCommand(REMOVE_COMMAND);
	removeNodeButton.addActionListener(this);
	*/
	treeButtonPanel.add(addNodeButton);
	treeButtonPanel.add(replaceNodeButton);
	treeStatusPanel.add(treeButtonPanel);
	treeStatusPanel.add(perturbationPanel);
	add(treeStatusPanel, BorderLayout.SOUTH);
  }// constructor
//-----------------------------------------------------------------------------------------------
  public JScrollPane initTree (){
	try{
	  experimentNavigator = new MetaDataNavigator(repository);
	}catch (Exception e) {
	  e.printStackTrace();
	}
	rootNode = new PerturbationNode ("Experiments");
	rootNode.setEditable(false);
	treeModel = new DefaultTreeModel(rootNode);
	treeModel.addTreeModelListener( new ExperimentTreeModelListener());
	tree = new JTree (treeModel);
	tree.getSelectionModel().setSelectionMode(TreeSelectionModel.SINGLE_TREE_SELECTION);
	tree.setShowsRootHandles(true);
	HashMap experimentsTree = experimentNavigator.getTree();
	createTree(rootNode, experimentsTree);
	JScrollPane scrollPane = new JScrollPane(tree);
	return scrollPane;
  }// initTree
//-----------------------------------------------------------------------------------------------
  private void createTree (PerturbationNode root, HashMap e) {
	Object[] a = (e.keySet()).toArray();
	Arrays.sort(a);

	for (int m=0;m<a.length;m++){
	  PerturbationNode newNode = new PerturbationNode(a[m]);
	  newNode.setEditable(false);
	  root.add(newNode);
	  if ((HashMap)e.get(a[m]) != null)
		createTree(newNode, (HashMap)e.get(a[m]));
	}

  }// createTree
//-----------------------------------------------------------------------------------------------
  public void actionPerformed(ActionEvent e) {
	String event = e.getActionCommand();
	if (INSERT_COMMAND.equals(event)){
	  String newName = JOptionPane.showInputDialog("New Category/Perturbation Name?");

	  if (newName != null) {
		PerturbationNode p = addObject(newName);
		Object[] path = ((TreePath)tree.getSelectionPath()).getPath();

		if (INSERT_COMMAND.equals(event)){
		  StringBuffer sb = new StringBuffer();
		  for (int m=1;m<path.length;m++)
			sb.append(((PerturbationNode)path[m]).toString()+":");
		  sb.append(newName);
		  wizardContext.setAttribute(WIZARD_PERTURBATION, sb.toString());
		  this.setVisible(false);
		  currentPerturbation.setText(sb.toString());
		  this.setVisible(true);
		}
		Object[] newPath = new Object[path.length+1];
		for (int m=0;m<path.length;m++)
		  newPath[m] = path[m];
		newPath[path.length] = p;
		tree.setSelectionPath(new TreePath(newPath));
	  }
	} else if (REPLACE_COMMAND.equals(event)) {
	  Object[] path = ((TreePath)tree.getSelectionPath()).getPath();
	  StringBuffer sb = new StringBuffer();
	  for (int m=1;m<path.length;m++) {
		sb.append(((PerturbationNode)path[m]).toString());
		if (m != path.length-1)
		  sb.append(":");
	  }
	  wizardContext.setAttribute(WIZARD_PERTURBATION, sb.toString());
	  this.setVisible(false);
	  currentPerturbation.setText(sb.toString());
	  this.setVisible(true);
	}

	/*
	   else if (REMOVE_COMMAND.equals(event)) {
	  TreePath currentPath = tree.getSelectionPath();
	}
	 */
  }// actionPerformed
//-----------------------------------------------------------------------------------------------
  public PerturbationNode addObject(Object child) {
	PerturbationNode parentNode = null;
	TreePath parentPath = tree.getSelectionPath();
	if (parentPath == null) {
	  parentNode = rootNode;
	}else {
	  parentNode = (PerturbationNode)(parentPath.getLastPathComponent());
	}
	return addObject(parentNode, child, true);
  }// addObject
//-----------------------------------------------------------------------------------------------
  public PerturbationNode addObject(PerturbationNode parent,
										  Object child,
										  boolean visible) {
	PerturbationNode childNode = new PerturbationNode(child);
	if (parent == null) {
	  parent = rootNode;
	}

	treeModel.insertNodeInto(childNode, parent, parent.getChildCount());
	tree.scrollPathToVisible(new TreePath(childNode.getPath()));
	return childNode;
  }// addObject
//-----------------------------------------------------------------------------------------------
  class ExperimentTreeModelListener implements TreeModelListener {
	public void treeNodesChanged(TreeModelEvent e) {
	  PerturbationNode newNode;
	  newNode = (PerturbationNode)(e.getTreePath().getLastPathComponent());
	  try {
		int index = e.getChildIndices()[0];
		newNode = (PerturbationNode)(newNode.getChildAt(index));
	  }catch (NullPointerException npe){
	  }
	}
	public void treeNodesInserted(TreeModelEvent e) {
	}
	public void treeNodesRemoved(TreeModelEvent e) {
	}
	public void treeStructureChanged(TreeModelEvent e){
	}
  }// class ExperimentTreeModelListener
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
	if (wizardContext.getAttribute(WIZARD_PERTURBATION) == null) {
	  list.add("Please Insert a Perturbation Before Continuing");
	  valid = false;
	}
	return valid;
  }// validateNext
//-----------------------------------------------------------------------------------------------
  public WizardPanel next() {
	return new GeneralInfoWizardPanel(getWizardContext());
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
