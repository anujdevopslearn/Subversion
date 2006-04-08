package DataLoader;
//-----------------------------------------------------------------------------------------------
import java.util.List;
import javax.swing.JPanel;
//-----------------------------------------------------------------------------------------------
public abstract class WizardPanel extends JPanel {
//-----------------------------------------------------------------------------------------------
  protected static String WIZARD_PERTURBATION = "WIZARD_perturbation";
  protected static String WIZARD_CONDITIONS = "WIZARD_conditions";
  protected static String WIZARD_FILE = "WIZARD_file";
  protected static String WIZARD_ORGANISM = "WIZARD_organism";
  protected static String WIZARD_STRAIN = "WIZARD_strain";
  protected static String WIZARD_MANIPULATION_TYPE = "WIZARD_manipulationType";
  protected static String WIZARD_MANIPULATED_VARIABLE = "WIZARD_manipulatedVariable";
  protected static String WIZARD_HASH_CONDITIONS = "WIZARD_hash_conditions";
  protected static String WIZARD_EXPERIMENT = "WIZARD_experiment";
  protected static String WIZARD_CONSTANTS = "WIZARD_constants";
  protected static String WIZARD_CONSTANTS_ID = "WIZARD_constants_file";
  protected static String WIZARD_PROJECT_ID = "WIZARD_project_id";
  protected static Boolean USE_SBEAMS = Boolean.FALSE;
  protected static String SBEAMS_CLIENT = "SBEAMS_CLIENT";
  protected WizardContext wizardContext;
//-----------------------------------------------------------------------------------------------
  public WizardPanel() {
  }
//-----------------------------------------------------------------------------------------------
  protected final void setWizardContext(WizardContext wizardContext) {
	this.wizardContext = wizardContext;
  }
//-----------------------------------------------------------------------------------------------
  public abstract void display();
//-----------------------------------------------------------------------------------------------
  public abstract boolean hasNext();
//-----------------------------------------------------------------------------------------------
  public abstract boolean validateNext(List list);
//-----------------------------------------------------------------------------------------------
  public abstract WizardPanel next();
//-----------------------------------------------------------------------------------------------
  public abstract boolean canFinish();
//-----------------------------------------------------------------------------------------------
  public abstract boolean canCancel();
//-----------------------------------------------------------------------------------------------
  public abstract boolean validateFinish(List list);
//-----------------------------------------------------------------------------------------------
  public abstract void finish();
//-----------------------------------------------------------------------------------------------
  public boolean hasHelp() {
	return false;
  }
//-----------------------------------------------------------------------------------------------
  public void help() {
    }
//-----------------------------------------------------------------------------------------------
  public final WizardContext getWizardContext() {
	return wizardContext;
  }
//-----------------------------------------------------------------------------------------------
}
