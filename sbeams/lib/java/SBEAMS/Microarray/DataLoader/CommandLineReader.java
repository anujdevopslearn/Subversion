package DataLoader;
import java.io.*;
import java.util.*;
import gnu.getopt.Getopt;
//-----------------------------------------------------------------------------------------------
public class CommandLineReader {
  private String    validArguments         = "m:t:hv";
  private String[]  commandLineArguments;
  private String    matrixFile;
  private String    experimentTitle;
  private boolean   verbose                = false;
  private boolean   inputError             = false;
  private boolean   helpRequested          = false;
//-----------------------------------------------------------------------------------------------
  public CommandLineReader (String [] args){
    commandLineArguments = args;
    parseArgs();
  }// constructor
//-----------------------------------------------------------------------------------------------
  private void parseArgs(){
	helpRequested      = false;
	boolean argsError  = false;
	String currentArg;

	if (commandLineArguments == null || commandLineArguments.length == 0){
	  helpRequested =true;
	  return;
	}

	Getopt options = new Getopt ("DataLoader",commandLineArguments,validArguments);

	int counter;
	String optionDetail;
	while( (counter = options.getopt()) != -1 ){
	  switch (counter){
	  case 'm':
	    matrixFile = options.getOptarg();
	    break;
	  case 'h':
	    helpRequested = true;
	    break;
	  case 't':
		experimentTitle = options.getOptarg();
		break;
	  case 'v':
		verbose = true;
		break;
	  case '?':
		System.out.println("The option '"+(char)options.getOptopt()+
						   "' is not understood");
		helpRequested = true;
		return; 
	  default:
		System.err.println("unexpected argument: "+counter);
		inputError = true;
		break;
	  }
	}
	if (verbose)
	  printVerbose();
  }// parseArgs
//-----------------------------------------------------------------------------------------------
  protected void printVerbose() {
	StringBuffer sb = new StringBuffer("Command Line Arguments:\n");
	sb.append("Matrix File: ");
	if (matrixFile.equals(""))
	  sb.append ("None\n");
	else
	  sb.append (matrixFile+"\n");

	sb.append("\n");
	System.out.println(sb.toString());
  }
//-----------------------------------------------------------------------------------------------
  protected String getUsage(){
    StringBuffer usage = new StringBuffer();
    usage.append("DataLoader Usage:\n");
    usage.append("\tjava DataLoader [PARAMETERS]\n");
    usage.append("\t-m <file> matrix file name\n");
	usage.append("\t-t <title> experiment name\n");
    usage.append("\t-h display help\n");
    return usage.toString();
  }// getUsage
//-----------------------------------------------------------------------------------------------
  public boolean helpRequested(){
    return helpRequested;
  }// helpRequested
//-----------------------------------------------------------------------------------------------
  public boolean inputError(){
    return inputError;
  }// inputError
//-----------------------------------------------------------------------------------------------
  public String getMatrixFile() {
	return matrixFile;
  }// getMatrixFile
//-----------------------------------------------------------------------------------------------
  public String getExperimentTitle() {
	return experimentTitle;
  }
//-----------------------------------------------------------------------------------------------
}//end CommandLineReader
