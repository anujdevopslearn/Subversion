package DataLoader;
import java.util.*;
import javax.swing.*;
import javax.swing.table.*;
import java.util.regex.*;
import java.awt.event.*;
import java.awt.Point;
import java.awt.Component;

//-----------------------------------------------------------------------------------------------
public class VariableTable extends JTable 
  implements MouseListener, ActionListener{
//-----------------------------------------------------------------------------------------------
  private static String SET_VALUE= "Set Value";
  private Vector selectedCells = new Vector();
  private DefaultTableModel model;
//-----------------------------------------------------------------------------------------------
  public VariableTable(int row, int rowHeight) {
	super ();
	model = new DefaultTableModel();
	this.setModel(model);
	for (int m=0;m<row;m++)
	  model.insertRow(0,new Object[this.getColumnCount()]);
	setRowHeight(rowHeight);
	setCellSelectionEnabled(true);
	this.addMouseListener(this);
	this.setAutoResizeMode(JTable.AUTO_RESIZE_OFF);
  }
//-----------------------------------------------------------------------------------------------
   public void addDataColumn(String header){
	int rows = this.getRowCount();
	String[] values = new String [rows];
	for (int m=0;m<rows;m++) {
	  values[m] = "";
	}
	model.addColumn(header, values);
	packColumn(this.getColumnCount()-1, 5);
	this.repaint();
  }
//-----------------------------------------------------------------------------------------------
  public void removeLastColumn() {
	int cols = model.getColumnCount();
	if (cols>0) 
	  model.setColumnCount( cols-1 );
  }
//-----------------------------------------------------------------------------------------------
  public String getColumnHeader(int index) {
	if (index >= this.getColumnCount()) {
	  return null;
	}else {
	  TableColumn tc = ((TableColumnModel)this.getColumnModel()).getColumn(index);
	  return (String)tc.getHeaderValue();
	}
  }
//-----------------------------------------------------------------------------------------------
  public void mouseClicked(MouseEvent e) {}
//-----------------------------------------------------------------------------------------------
  public void mousePressed(MouseEvent e) {}
//-----------------------------------------------------------------------------------------------
  public void mouseEntered(MouseEvent e) {}
//-----------------------------------------------------------------------------------------------
  public void mouseExited(MouseEvent e) {}
//-----------------------------------------------------------------------------------------------
  public void mouseReleased(MouseEvent e) {
	if (SwingUtilities.isRightMouseButton(e)) {
	  Point p = e.getPoint();
	  int tableRow = this.rowAtPoint(p);
	  int tableCol = this.columnAtPoint(p);
	  if (isCellSelected(tableRow, tableCol)){
		int rowIndexStart = this.getSelectedRow ();
        int rowIndexEnd = this.getSelectionModel().getMaxSelectionIndex();
        int colIndexStart = this.getSelectedColumn();
        int colIndexEnd = this.getColumnModel().getSelectionModel().getMaxSelectionIndex();
		if (colIndexStart != colIndexEnd){
		  JOptionPane.showMessageDialog(this, "Multiple Variables Selected.\n\n"+
										"Please choose only one variable ");
		  return;
		}
		JPopupMenu menu = new JPopupMenu();
		JMenuItem item= new JMenuItem("Set Value...");
		item.setActionCommand(SET_VALUE);
		item.addActionListener(this);
		menu.add(item);
		menu.setLightWeightPopupEnabled(false);
		menu.show(this, e.getX(), e.getY());
	  }
	}
  }
//-----------------------------------------------------------------------------------------------
  public void actionPerformed (ActionEvent e) {
	String command = e.getActionCommand();
	if (SET_VALUE.equals(command)){
	  String newValue = JOptionPane.showInputDialog(this, "Set Value To: ");
	  for (int h=0; h<this.getColumnCount();h++) {
		for (int m=0; m<this.getRowCount(); m++) {
		  if (this.isCellSelected(m,h)) 
			this.setValueAt(newValue,m,h);
		}
		packColumn(h,5);
	  }
	}
	this.repaint();   	
  }
//-----------------------------------------------------------------------------------------------
  public void packColumn(int vColIndex, int margin) {
	TableModel model = this.getModel();
	DefaultTableColumnModel colModel = (DefaultTableColumnModel)this.getColumnModel();
	TableColumn col = colModel.getColumn(vColIndex);
	int width = 0;
	TableCellRenderer renderer = col.getHeaderRenderer();
	if (renderer == null) {
	  renderer = this.getTableHeader().getDefaultRenderer();
	}
	Component comp = renderer.getTableCellRendererComponent(this, col.getHeaderValue(), 
															false, false, 0, 0);
	width = comp.getPreferredSize().width;
	for (int r=0; r<this.getRowCount(); r++) {
	  renderer = this.getCellRenderer(r, vColIndex);
	  comp = renderer.getTableCellRendererComponent(this, this.getValueAt(r, vColIndex), 
													false, false, r, vColIndex);
	  width = Math.max(width, comp.getPreferredSize().width);
	}
	width += 2*margin;
	col.setPreferredWidth(width);
  }
//-----------------------------------------------------------------------------------------------
}
