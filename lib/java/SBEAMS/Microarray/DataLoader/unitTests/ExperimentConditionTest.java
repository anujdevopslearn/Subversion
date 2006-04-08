/*
 * Created on Jan 6, 2005
 */
package DataLoader.unitTests;
import junit.framework.TestCase;
import junit.framework.TestSuite;
import DataLoader.ExperimentCondition;
//-----------------------------------------------------------------------------------------------
/**
 * @author mjohnson
 */
public class ExperimentConditionTest extends TestCase {
//-----------------------------------------------------------------------------------------------
  private String name = "EC_NAME";
  private String[] genes= {"gene1", "gene2", "gene3"};
  private float[] ratioData = {(float)0.00, (float)1.00, (float)2.00};
  private float[] lambdaData = {(float)100.0, (float)50.0, (float)0.0};
  ExperimentCondition ec;
//-----------------------------------------------------------------------------------------------
  public ExperimentConditionTest (String name) {
	super (name);
	ec = new ExperimentCondition (name, genes, ratioData, lambdaData);
  }
//-----------------------------------------------------------------------------------------------
  public void setUp () throws Exception {
  }
//-----------------------------------------------------------------------------------------------
  public void tearDown () throws Exception {
  }
//-----------------------------------------------------------------------------------------------
  public void testVerification () throws Exception {
	System.out.println("testVerification");
	assertTrue(ec.verify());
  }
//-----------------------------------------------------------------------------------------------
  public void testGets() throws Exception {
	System.out.println ("testGets");
	ec = new ExperimentCondition (name, genes, ratioData, lambdaData);
	assertTrue((ec.getConditionName()).equals(name));
	assertTrue((ec.getConditionAlias()).equals(name));
	assertTrue( (ec.getGenes()).length == 3 );
	assertTrue( (ec.getRatioData()).length == 3 );
	assertTrue( (ec.getLambdaData()).length == 3 );
  }
//-----------------------------------------------------------------------------------------------
  public void testAlias() throws Exception {
	System.out.println ("testAlias");
	String alias = "alias";
	ec = new ExperimentCondition (name, genes, ratioData, lambdaData);
	ec.setAlias (alias);
	assertTrue( (ec.getConditionName()).equals(name) );
	assertTrue( (ec.getConditionAlias()).equals(alias) );
  }
//-----------------------------------------------------------------------------------------------
  public static void main (String[] args) {
	junit.textui.TestRunner.run (new TestSuite(ExperimentConditionTest.class));
  }
//-----------------------------------------------------------------------------------------------
}
