// ExperimentRepositoryTest.java
//--------------------------------------------------------------------------------------
package SBEAMS.unitTests;
//--------------------------------------------------------------------------------------
import junit.framework.TestCase;
import junit.framework.TestSuite;
import java.io.*;
import java.util.*;
import java.util.regex.*;
import SBEAMS.SBEAMSClient; 

//--------------------------------------------------------------------------------------
public class SBEAMSClientTest extends TestCase {

  private String testUser = "cytoscape";
  private String testPassword = "cytoscape";
  private String testBaseURL = "http://db.systemsbiology.net/sbeams";
  private SBEAMSClient client;

//------------------------------------------------------------------------------
public SBEAMSClientTest (String name) 
{
  super (name);
}
//------------------------------------------------------------------------------
public void setUp () throws Exception
{
  }
//------------------------------------------------------------------------------
public void tearDown () throws Exception
{
}
//--------------------------------------------------------------------------------------
public void testSBEAMSClientSetup () throws Exception
{
  System.out.println ("testSBEAMSClientSetup");
  client = new SBEAMSClient(testUser, testPassword);
  client.fetchSbeamsPage ( testBaseURL + "/cgi/main.cgi");
  assertTrue (client.getCookie() != null);
} // testFileRepository
//--------------------------------------------------------------------------------------
public void testSecureSBEAMSClientSetup () throws Exception
{
  System.out.println ("testSecureSBEAMSClientSetup");
  client = new SBEAMSClient(testUser, testPassword);
  client.fetchSbeamsPage ( testBaseURL + "/cgi/main.cgi");
  assertTrue (client.getCookie() != null);
} // testFileRepository
//--------------------------------------------------------------------------------------
public static void main (String [] args) 
{
  junit.textui.TestRunner.run (new TestSuite (SBEAMSClientTest.class));
}
//--------------------------------------------------------------------------------------
} // ExperimentRepositoryTest
