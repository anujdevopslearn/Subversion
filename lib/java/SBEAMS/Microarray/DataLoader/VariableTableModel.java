package DataLoader;
import javax.swing.table.*;
//-----------------------------------------------------------------------------------------------
public class VariableTableModel extends DefaultTableModel {
//-----------------------------------------------------------------------------------------------
  public VariableTableModel () {
	super();
  }// constructor
//-----------------------------------------------------------------------------------------------
  public boolean isCellEditable(int row, int column) {
	return false;
  }// isCellEditable
//-----------------------------------------------------------------------------------------------
}
