package DataLoader;
//-----------------------------------------------------------------------------------------------
public interface WizardListener {
	public void wizardFinished(Wizard wizard);
	public void wizardCancelled(Wizard wizard);
	public void wizardPanelChanged(Wizard wizard);
}
