package DataLoader;
import java.util.HashMap;
public class WizardContext {
    private final HashMap attributes = new HashMap();
    public void setAttribute(Object key, Object value) {
        attributes.put(key, value);
    }
    public Object getAttribute(Object key) {
        return attributes.get(key);
    }
}
