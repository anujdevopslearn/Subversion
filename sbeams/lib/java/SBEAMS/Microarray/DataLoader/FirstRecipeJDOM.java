
import java.io.*; 
import org.jdom.*; 
import org.jdom.input.*; 
import org.jdom.output.*; 

public class FirstRecipeJDOM {
  public static void main(String[] args) {
    try {
      Document d = new SAXBuilder().build(new File(args[0])); 
      Namespace ns = Namespace.getNamespace("http://recipes.org");
      Element e = new Element("collection");
      e.addContent(d.getRootElement().getChild("recipe", ns).detach());
      Document n = new Document(e);
      new XMLOutputter().output(n, System.out);
    } catch (Exception e) {e.printStackTrace();}
  }
}
