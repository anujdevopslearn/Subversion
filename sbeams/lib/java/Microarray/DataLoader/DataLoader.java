package DataLoader;
import java.awt.*;
import java.awt.event.*;
import java.awt.event.WindowEvent;
import javax.swing.JFrame;
//-----------------------------------------------------------------------------------------------
public class DataLoader implements WizardListener {
//-----------------------------------------------------------------------------------------------
  private static JFrame frame;
//-----------------------------------------------------------------------------------------------
  public static void main(String args[]) {
	CommandLineReader clr = new CommandLineReader(args);
	frame = new JFrame("Cytoscape Data Loader");
	frame.addWindowListener(createAppCloser());

	WizardContext wc = new WizardContext();
	Wizard wizard = new Wizard(wc);

	wizard.addWizardListener(new DataLoader());
	frame.setContentPane(wizard);
	frame.pack();

    GraphicsConfiguration gc = frame.getGraphicsConfiguration();
	int screenHeight = (int)gc.getBounds().getHeight();
	int	screenWidth = (int)gc.getBounds().getWidth();
    int windowWidth = frame.getWidth();
    int windowHeight = frame.getHeight();
    int x = (int)((screenWidth-windowWidth)/2);
    int y = (int)((screenHeight-windowHeight)/2);

    frame.setLocation (x, y);
	frame.setVisible(true);
	String file = clr.getMatrixFile();
	String expName = clr.getExperimentTitle();
	if (file == null) {
	  wizard.start(new WelcomeWizardPanel());
	} else {
	  wizard.start(new FileChooserWizardPanel(file, expName));
	}
  }// constructor
//-----------------------------------------------------------------------------------------------
  private static WindowListener createAppCloser() {
	return new WindowAdapter() {
		public void windowClosing(WindowEvent we) {
		  System.exit(0);
		}
	  };
  }// createAppCloser
//-----------------------------------------------------------------------------------------------
  public void wizardFinished(Wizard wizard) {
	System.out.println("Good-Bye!");
	System.exit(0);
  }// wizardFinished
//-----------------------------------------------------------------------------------------------
  public void wizardCancelled(Wizard wizard) {
	System.out.println("Cancelled!");
	System.exit(0);
  }// wizardCancelled
//-----------------------------------------------------------------------------------------------
  public void wizardPanelChanged(Wizard wizard) {
  }// wizardPanelChanged
//-----------------------------------------------------------------------------------------------
}// DataLoader
