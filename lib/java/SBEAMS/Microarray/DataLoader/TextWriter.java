// TextWriter.java
//-------------------------------
package DataLoader;
import java.io.*;
import java.util.Vector;

public class TextWriter {
    String filename;
    BufferedWriter bufferedWriter;
    //StringBuffer strbuf;

    public TextWriter (String filename){
	  this.filename = filename;
	  try {
	    bufferedWriter = new BufferedWriter (new FileWriter (filename));
	  }
	  catch (IOException e) {
	    e.printStackTrace ();
	    return;
	  }
	}//end constructor

    public void write(String str){
	try{
	    bufferedWriter.write(str);
	    bufferedWriter.newLine();
	    bufferedWriter.flush();
	}
	catch(IOException e){
	    e.printStackTrace();
	}
    }

    public void close(){
	try {bufferedWriter.close();}
	catch(IOException e){e.printStackTrace();}
    }
}//end TextReader
