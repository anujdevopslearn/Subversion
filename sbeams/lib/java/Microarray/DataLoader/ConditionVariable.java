package DataLoader;
public class ConditionVariable {
//-----------------------------------------------------------------------------------------------
  private String variableName;
  private String variableValue;
  private String variableUnits;
//-----------------------------------------------------------------------------------------------
  public ConditionVariable(){
  }// constructor
//-----------------------------------------------------------------------------------------------
  public ConditionVariable(String varName, String value, String units) {
	this.variableName = varName;
	this.variableValue = value;
	this.variableUnits = units;
  }// constructor
//-----------------------------------------------------------------------------------------------
  public void setVariableName(String name) {
	this.variableName = name;
  }
//-----------------------------------------------------------------------------------------------
  public void setVariableValue(String value) {
	this.variableValue = value;
  }
//-----------------------------------------------------------------------------------------------
  public void setVariableUnits(String units) {
	this.variableUnits = units;
  }
//-----------------------------------------------------------------------------------------------
  public String getVariableUnits() {
	return variableUnits;
  }
//-----------------------------------------------------------------------------------------------
  public String getVariableValue() {
	return variableValue;
  }
//-----------------------------------------------------------------------------------------------
  public String getVariableName() {
	return variableName;
  }
//-----------------------------------------------------------------------------------------------
  public String getVariableTag() {
	StringBuffer sb = new StringBuffer();
	sb.append("<variable ");
	if (variableName != null)
	  sb.append("name='"+variableName+"' ");
	if (variableValue != null)
	  sb.append("value='"+variableValue+"' ");
	if (variableUnits != null)
	  sb.append("units='"+variableUnits+"' ");
	sb.append("/>");
	return sb.toString();
  }
//-----------------------------------------------------------------------------------------------
}
