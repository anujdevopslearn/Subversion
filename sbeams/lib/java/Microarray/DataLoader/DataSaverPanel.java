package DataLoader;
import javax.swing.*;
import javax.swing.border.TitledBorder;
import java.awt.*;
import java.awt.event.*;
import java.util.List;
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
//-----------------------------------------------------------------------------------------------
  public DataSaverPanel(WizardContext wc) {
	setWizardContext(wc);
	setLayout(new BorderLayout());
	setBorder(new TitledBorder("Step 5.  Save Data and Exit"));

	JPanel instructionPanel = new JPanel();
	instructionPanel.add(new JLabel("Method(s) for Saving These Data:"));

	JPanel filePanel = new JPanel();
	fileCheck = new JCheckBox("Save To Directory");
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
  }
//-----------------------------------------------------------------------------------------------
  public void actionPerformed(ActionEvent e) {
	String command = e.getActionCommand();
	if (CHOOSE_DIRECTORY.equals(command)) {
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
	
  }
//-----------------------------------------------------------------------------------------------
 public void display() {
  }
//-----------------------------------------------------------------------------------------------
  public boolean hasNext() {
	return false;
  }
//-----------------------------------------------------------------------------------------------
  public boolean validateNext(List list) {
	boolean valid = true;
	return valid;
  }
//-----------------------------------------------------------------------------------------------
  public WizardPanel next() {
	return new NullWizardPanel();
  }
//-----------------------------------------------------------------------------------------------
  public boolean canFinish() {
	return true;
  }
//-----------------------------------------------------------------------------------------------
  public boolean validateFinish(List list) {
	return false;
  }
//-----------------------------------------------------------------------------------------------
  public void finish() {
  }
//-----------------------------------------------------------------------------------------------
}
