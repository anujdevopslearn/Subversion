/*
 * Created on Jan 6, 2005
 */
package DataLoader.unitTests;
import junit.framework.TestCase;
import junit.framework.TestSuite;
import DataLoader.CommandLineReader;
//-----------------------------------------------------------------------------------------------
/**
 * @author mjohnson
 */
public class CommandLineReaderTest extends TestCase {
//------------------------------------------------------------------------------
  public CommandLineReaderTest (String name) {
	super (name);
  }
//------------------------------------------------------------------------------
  public void setUp () throws Exception {
  }
//------------------------------------------------------------------------------
  public void tearDown () throws Exception {
  }
//-----------------------------------------------------------------------------------------------
  public void testNoArgs() throws Exception {
	System.out.println ("testNoArgs");
	String[] arguments = {};
	CommandLineReader clr = new CommandLineReader(arguments);
	assertTrue(clr.helpRequested());
  }
//-----------------------------------------------------------------------------------------------
  public void testWithArgs() throws Exception {
	System.out.println ("testWithArgs");
	String[] arguments = {"-m", "MatrixFile", "-p", "328"};
	CommandLineReader clr = new CommandLineReader(arguments);
	assertTrue((clr.getMatrixFile()).equals("MatrixFile"));
	assertTrue((clr.getProjectID().toString()).equals("328"));
  }
//-----------------------------------------------------------------------------------------------
  public static void main (String[] args) {
	junit.textui.TestRunner.run (new TestSuite(CommandLineReaderTest.class));
  }
//-----------------------------------------------------------------------------------------------
}
