package DataLoader;
import java.util.List;
import javax.swing.border.TitledBorder;
public class NullWizardPanel extends WizardPanel {
    public NullWizardPanel() {
        setBorder(new TitledBorder("null wizard panel"));
    }
    public void display() {
    }
    public boolean hasNext() {
        return false;
    }
    public boolean validateNext(List list) {
        return false;
    }
	public WizardPanel next() {
        return null;
    }
	public boolean canFinish() {
        return false;
    }
    public boolean validateFinish(List list) {
        return false;
    }
    public void finish() {
    }
}
