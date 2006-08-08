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

  /*  infoFile should be (for example):

 user=sampleUser
 password=samplePassword
 url=http://sampleUrl

  */
  private String infoFile = "unitTests/.infoFile";
  private SBEAMSClient client;
  private String testUser;
  private String testPassword;
  private String testBaseURL;

//------------------------------------------------------------------------------
public SBEAMSClientTest (String name) 
{
  super (name);
  assertTrue(configure());
  if (testUser.equals("setUser"))
	System.out.println("WARNING: CHANCES ARE YOU DID NOT UPDATE THE USERNAME");
  if (testPassword.equals("setMe"))
	System.out.println("WARNING: CHANCES ARE YOU DID NOT SPECIFY THE PASSWORD");
  if (testBaseURL.equals("none specified"))
	System.out.println("WARNGING: YOU NEED TO SPECIFY THE BASE SBEAMS URL");
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
  System.out.println("Using "+testUser+":"+testPassword);
  client = new SBEAMSClient(testUser, testPassword);
  client.fetchSbeamsPage ( testBaseURL + "/cgi/main.cgi");
  assertTrue (client.getCookie() != null);
} // testFileRepository
//--------------------------------------------------------------------------------------
public void testSecureSBEAMSClientSetup () throws Exception
{
  System.out.println ("testSecureSBEAMSClientSetup");
  System.out.println("Using "+testUser+":"+testPassword);
  client = new SBEAMSClient(testUser, testPassword);
  client.fetchSbeamsPage ( testBaseURL + "/cgi/main.cgi");
  assertTrue (client.getCookie() != null);
} // testFileRepository
//--------------------------------------------------------------------------------------
private boolean configure() {
  File file = new File (infoFile);
  if (!file.canRead ())
	System.out.println("ERROR: Unable to read config file "+infoFile);

  try{
	BufferedReader br = new BufferedReader(new FileReader(infoFile));
	StringBuffer sb = new StringBuffer();
	String newLineOfText;
	while ((newLineOfText = br.readLine()) != null) {
	  newLineOfText.trim();
	  if ((newLineOfText.toLowerCase()).startsWith("user")) {
		String[] pieces = newLineOfText.split("=");
		if (pieces[1] != null) {
		  testUser = pieces[1].trim();
		}
	  }

	  else if ((newLineOfText.toLowerCase()).startsWith("password")) {
		String[] pieces = newLineOfText.split("=");
		if (pieces[1] != null) {
		  testPassword = pieces[1].trim();
		}
	  }


	  else if ((newLineOfText.toLowerCase()).startsWith("url")) {
		String[] pieces = newLineOfText.split("=");
		if (pieces[1] != null) {
		  testBaseURL = pieces[1].trim();
		}
	  }

	}

  } catch (IOException e) {
	e.printStackTrace();
  }

  if (testUser != null && testPassword != null && testBaseURL != null)
	return true;
  else
	return false;

}// configure
//--------------------------------------------------------------------------------------
public static void main (String [] args) 
{
  junit.textui.TestRunner.run (new TestSuite (SBEAMSClientTest.class));
}
//--------------------------------------------------------------------------------------
} // ExperimentRepositoryTest
