package DataLoader;
//-----------------------------------------------------------------------------------------------
import java.util.List;
import java.awt.BorderLayout;
import javax.swing.*;
import javax.swing.border.TitledBorder;
//-----------------------------------------------------------------------------------------------
public class WelcomeWizardPanel extends WizardPanel {
//-----------------------------------------------------------------------------------------------
  private String welcome = "\nThis wizard will allow you to investigate "
	+"and annotate your experimental data.\n\n Click 'next' to begin!";
  private final WizardPanel fileChooser = new FileChooserWizardPanel();
//-----------------------------------------------------------------------------------------------
  public WelcomeWizardPanel() {
	setLayout(new BorderLayout());
	setBorder(new TitledBorder("Welcome to Cytoscape's Data Loader"));
	JTextPane pane = new JTextPane();
	pane.setEditable(false);
	pane.setText(welcome);
	add(new JScrollPane(pane), BorderLayout.CENTER);
  }// constructor
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
	return fileChooser;
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
