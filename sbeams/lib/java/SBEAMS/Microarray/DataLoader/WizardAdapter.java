package DataLoader;
//-----------------------------------------------------------------------------------------------
public abstract class WizardAdapter implements WizardListener {
  public WizardAdapter() {}
  public void wizardCancelled(Wizard wizard) {}
  public void wizardFinished(Wizard wizard) {}
  public void wizardPanelChanged(Wizard wizard) {}
}
