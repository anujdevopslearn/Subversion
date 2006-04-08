package DataLoader;
import java.util.Vector;
import javax.swing.JComponent;
//-----------------------------------------------------------------------------------------------
public class ExperimentCondition extends JComponent{
//-----------------------------------------------------------------------------------------------
  private String[] genes;
  private float[] ratioData;
  private float[] lambdaData;
  private String conditionName; // orig., as it was read in from the file
  private String conditionAlias;// whatever you want to call it now.
  private Vector variables = new Vector();
  private String toolTip;
//-----------------------------------------------------------------------------------------------
  public ExperimentCondition(String name) {
	this.conditionName = name;
	this.conditionAlias = name;
	this.toolTip = name;
	setToolTipText(this.toolTip);
  }// constructor
//-----------------------------------------------------------------------------------------------
  public ExperimentCondition (String name, String [] genes, float[] ratioData, float[]lambdaData) {
	this.ratioData = ratioData;
	this.lambdaData = lambdaData;
	this.genes = genes;
	this.conditionName = name;
	this.conditionAlias = name;
	this.toolTip= name;
	setToolTipText(this.toolTip);
  }// constructor
//-----------------------------------------------------------------------------------------------
  public boolean verify (){
	if (genes.length == ratioData.length &&
		ratioData.length == lambdaData.length)
	  return true;
	else 
	  return false;
  }// verify
//-----------------------------------------------------------------------------------------------
  public void changeToolTipText(String toolTip) {
	this.toolTip = toolTip;
  }// changeToolTipText
//-----------------------------------------------------------------------------------------------
  public void setGenes(String[] genes) {
	this.genes = genes;
  }// setGenes
//-----------------------------------------------------------------------------------------------
  public void setRatioData(float[]ratioData) {
	this.ratioData = ratioData;
  }// setRatioData
//-----------------------------------------------------------------------------------------------
  public void setLambdaData(float[]lambdaData) {
	this.lambdaData = lambdaData;
  }// setLambdaData
//-----------------------------------------------------------------------------------------------
  public void setAlias(String alias){
	this.conditionAlias = alias;
  }// setAlias
//-----------------------------------------------------------------------------------------------
  public void addVariable(ConditionVariable cv){
	variables.add(cv);
  }// addVariable
//-----------------------------------------------------------------------------------------------
  public Vector getVariables() {
	return variables;
  }// getVariables
//-----------------------------------------------------------------------------------------------
  public String getConditionName() {
	return conditionName;
  }// getConditionName
//-----------------------------------------------------------------------------------------------
  public String getConditionAlias() {
	return conditionAlias;
  }// getConditionAlias
//-----------------------------------------------------------------------------------------------
  public String[] getGenes() {
	return genes;
  }// getGenes
//-----------------------------------------------------------------------------------------------
  public float[] getRatioData() {
	return ratioData;
  }// getRatioData
//-----------------------------------------------------------------------------------------------
  public float[] getLambdaData() {
	return lambdaData;
  }// getLambdaData
//-----------------------------------------------------------------------------------------------
  public float[][] getIconData() {
	float[][] d = new float[2][ratioData.length];
	d[0] = ratioData;
	d[1] = lambdaData;
	return d;
  }// getIconData
//-----------------------------------------------------------------------------------------------
}
