/*
 * Created on Jan 6, 2005
 */
package DataLoader.unitTests;
import junit.framework.TestCase;
import junit.framework.TestSuite;
import DataLoader.ConditionVariable;
//-----------------------------------------------------------------------------------------------
/**
 * @author mjohnson
 */
public class ConditionVariableTest extends TestCase {
//------------------------------------------------------------------------------
  public ConditionVariableTest (String name) {
	super (name);
  }
//------------------------------------------------------------------------------
  public void setUp () throws Exception {
  }
//------------------------------------------------------------------------------
  public void tearDown () throws Exception {
  }
//-----------------------------------------------------------------------------------------------
  public void testGetsAndSets() throws Exception {
	System.out.println ("testGetsAndSets");
	String name = "VARIABLE_NAME";
	String value = "VARIABLE_VALUE";
	String units = "VARIABLE_UNITS";
	ConditionVariable cv = new ConditionVariable(name, value, units);
	assertTrue((cv.getVariableName()).equals(name));
	assertTrue((cv.getVariableValue()).equals(value));
	assertTrue((cv.getVariableUnits()).equals(units));
	cv.setVariableName(name+"2");
	cv.setVariableValue(value+"2");
	cv.setVariableUnits(units+"2");
	assertTrue((cv.getVariableName()).equals(name+"2"));
	assertTrue((cv.getVariableValue()).equals(value+"2"));
	assertTrue((cv.getVariableUnits()).equals(units+"2"));
  }
//-----------------------------------------------------------------------------------------------
  public void testVariableTag() throws Exception {
	System.out.println ("testVariableTag");
	String name = "NAME";
	String value = "VALUE";
	String units = "UNITS";
	ConditionVariable cv = new ConditionVariable(name, value, units);
	String tag = "<variable name='NAME' value='VALUE' units='UNITS' />";
	assertTrue((cv.getVariableTag()).equals(tag));
  }
//-----------------------------------------------------------------------------------------------
  public static void main (String[] args) {
	junit.textui.TestRunner.run (new TestSuite(ConditionVariableTest.class));
  }
//-----------------------------------------------------------------------------------------------
}
