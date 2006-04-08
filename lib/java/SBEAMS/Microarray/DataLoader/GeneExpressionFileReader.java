package DataLoader;
import SBEAMS.*;
import java.io.*;
import java.awt.*;
import java.awt.event.*;
import java.util.regex.*;
import java.util.Hashtable;
import javax.swing.Timer;
//-----------------------------------------------------------------------------------------------
public class GeneExpressionFileReader {
//-----------------------------------------------------------------------------------------------
  private String dataFileURI;
  private SBEAMSClient sc;
  private BufferedReader br;
  private StringBuffer sb;
  private static String MRNA = "MRNA";
  private static String MERGECONDS = "MERGECONDS";
  private static String UNKNOWN = "UNKNOWN";
  private Hashtable data;
  private String[] conditionNames;
  private Hashtable rosetta;
//-----------------------------------------------------------------------------------------------
  public GeneExpressionFileReader(String dataFileURI, String translatorFile, SBEAMSClient sc){
	this.sc = sc;
	rosetta = readTranslator(translatorFile);
	this.dataFileURI = dataFileURI;
	data = new Hashtable();
  }// FileReader
//-----------------------------------------------------------------------------------------------
  public GeneExpressionFileReader(String dataFileURI, String translatorFile){
 	rosetta = readTranslator(translatorFile);
 	this.dataFileURI = dataFileURI;
 	data = new Hashtable();
  }// FileReader
//-----------------------------------------------------------------------------------------------
  public GeneExpressionFileReader(String dataFileURI){
 	rosetta = new Hashtable();
 	this.dataFileURI = dataFileURI;
 	data = new Hashtable();
  }// FileReader
//-----------------------------------------------------------------------------------------------
  public boolean read() {
	String[] dataLines  = getFile(dataFileURI);
	String filetype = determineFileType(dataLines[0]);
	boolean successfulRead = false;
	if (filetype.equals(MRNA)){
	  successfulRead = readMrnaFile(dataLines);
	}else if (filetype.equals(MERGECONDS)) {
	  successfulRead = readMergeCondsFile(dataLines);
	}else if (filetype.equals(UNKNOWN)) {
	  // do nothing, so far
	}
	return successfulRead;
  }// read
//-----------------------------------------------------------------------------------------------
  private String[] getFile(String file){
	if (file.startsWith("sbeamsIndirect://")) {
	  try {
		String[] pieces = file.split("://");
		if (sc != null)
		  sc = new SBEAMSClient(true);
		String bigLine = sc.fetchSbeamsPage("http://"+pieces[1]);
		return bigLine.split("\\n");
	  }catch (IOException e) {
		System.err.println("Page Not Found");
	  }catch (Exception t) {
		t.printStackTrace();
	  }
	}else {
	  try{
		br = new BufferedReader(new FileReader(file));
		sb = new StringBuffer();
		String newLineOfText;
		while ((newLineOfText = br.readLine()) != null)
		  sb.append(newLineOfText+"\n");
		String all = sb.toString();
		return all.split("\\n");
	  } catch (IOException e) {
		e.printStackTrace();
	  }
	}
	return null;
  }// getFile
//-----------------------------------------------------------------------------------------------
  private String determineFileType(String header){
	String currentFileType = UNKNOWN;
	String nameFileType = fileTypeUsingFileName();
	String headerDeterminedFileType = UNKNOWN;
	String [] elements = header.split("\\s");

	Pattern mergePattern = Pattern.compile(".*RATIOS\\s*LAMBDAS.*");
	Pattern mrnaPattern = Pattern.compile("sequence_name\\s+gene_name.*");
	Matcher mergeMatch = mergePattern.matcher(header);
	Matcher mrnaMatch = mrnaPattern.matcher(header);
	if (mergeMatch.matches()) {
	  headerDeterminedFileType = MERGECONDS;
	}else if (mrnaMatch.matches()) {
	  headerDeterminedFileType = MRNA;
	}
	if (!nameFileType.equals(headerDeterminedFileType)) {
	  System.out.println("File Name ("+nameFileType+")and Header ("+
						 headerDeterminedFileType+") don't match.");
	  if (nameFileType.equals(UNKNOWN)) {
		currentFileType = headerDeterminedFileType;
	  }else {
		currentFileType = nameFileType;
	  }
	}else {
	  currentFileType = nameFileType;
	}
	System.out.println("Using Type: "+currentFileType);
	return currentFileType;
  }// determineFileType
//-----------------------------------------------------------------------------------------------
  private String fileTypeUsingFileName() {
	if (dataFileURI.endsWith(".mrna")) {
	  return MRNA;
	}else if (dataFileURI.equals("matrix_output") ||
			  dataFileURI.endsWith(".merge")) {
	  return MERGECONDS;
	}else {
	  return UNKNOWN;
	}
  }// fileTypeUsingFileName
//-----------------------------------------------------------------------------------------------
  private boolean readMrnaFile(String[] dataLines){
	/* Sample Header (1 line)
sequence_name   gene_name       G0a_vs_NRC-1c.sig       G10a_vs_NRC-1c.sig      G20a_vs_NRC-1c.sig     G0a_vs_NRC-1c.sig       G10a_vs_NRC-1c.sig      G20a_vs_NRC-1c.sig
	*/
	int headerRows = 1;
	int tailRows = 0;
	int prependedColumns = 2;
	int appendedColumns = 0;
	String delimiter = "\\s";

	return readDelimitedFile(dataLines, delimiter, headerRows, tailRows,
							 prependedColumns, appendedColumns);

}
//-----------------------------------------------------------------------------------------------
  private boolean readMergeCondsFile(String[] dataLines){
	/* Sample Header (2 lines)
                 RATIOS                          LAMBDAS
GENE    DESCRIPT        1296_HO_D_vs_NRC-1.sig  1296_HO_L_vs_NRC-1.sig  1296_LO_D_vs_NRC-1.sig  1296_LO_L_vs_NRC-1.sig  1296_HO_D_vs_NRC-1.sig  1296_HO_L_vs_NRC-1.sig  1296_LO_D_vs_NRC-1.sig  1296_LO_L_vs_NRC-1.sig  NumSigConds
	*/
	int headerRows = 2;
	int tailRows = 1;
	int prependedColumns = 2;
	int appendedColumns = 1;
	String delimiter = "\\t";

	return readDelimitedFile (dataLines, delimiter, headerRows, tailRows,
							  prependedColumns, appendedColumns);
  }
//-----------------------------------------------------------------------------------------------
  private boolean readDelimitedFile(String[] dataLines, String delimiter, int headerRows, 
									int tailRows,int prependedColumns, int appendedColumns){
	int extraneousColumns = prependedColumns + appendedColumns;

	// Look at the first data line
	String[] line = (dataLines[headerRows-1]).split(delimiter);
	int conditions = (int)(line.length-extraneousColumns)/2;
	conditionNames = new String[conditions];
	for (int m=0;m<conditions;m++){
	  conditionNames[m] = line[m+prependedColumns];
	}
	//Handle rest of lines
	int size = dataLines.length -(headerRows + tailRows);
	String[] genes = new String[size];
	float[][] ratioValues = new float[conditions][size];
	float[][] lambdaValues = new float[conditions][size];

	for (int m=headerRows;m<dataLines.length-tailRows;m++) {
	  line = dataLines[m].split(delimiter);
	  if (line.length != (2*conditions) + extraneousColumns) {
		return false;
	  }

	  //translate the name, if possible
	  if (rosetta.containsKey(line[0].trim().toLowerCase())){
		genes[m-headerRows] = (String)rosetta.get(line[0].trim().toLowerCase());
	  } else
		genes[m-headerRows] = line[0].trim();

	  for (int h=0;h<conditions;h++){
		ratioValues[h][m-headerRows] = (new Float(line[h+prependedColumns])).floatValue();
		lambdaValues[h][m-headerRows] = (new Float(line[h+prependedColumns+conditions])).floatValue();
	  }
	}

	for (int m=0;m<conditionNames.length;m++) {
	  ExperimentCondition e =  new ExperimentCondition(conditionNames[m],
													   genes,
													   ratioValues[m],
													   lambdaValues[m]);
	  data.put(conditionNames[m], e);
	}
	return true;
  }// readDelimitedFile
//-----------------------------------------------------------------------------------------------
  private Hashtable readTranslator(String rosettaFile) {
	Hashtable translator = new Hashtable();
	String[] dataLines = getFile(rosettaFile);
	for (int m=0;m<dataLines.length;m++) {
	  String[] entry = dataLines[m].trim().split("\\t");
	  if (entry.length == 2)
		translator.put(entry[0].trim().toLowerCase(), entry[1].trim());
	}
	return translator;
  }// readTranslator
//-----------------------------------------------------------------------------------------------
  public Hashtable getData(){
	return data;
  }// getData
//-----------------------------------------------------------------------------------------------
  public String[] getConditionNames(){
	return conditionNames;
  }// getData
//-----------------------------------------------------------------------------------------------
  public SBEAMSClient getSbeamsClient() {
	return sc;
  }
//-----------------------------------------------------------------------------------------------
}// FileReader
