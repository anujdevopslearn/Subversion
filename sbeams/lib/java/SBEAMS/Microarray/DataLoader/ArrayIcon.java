package DataLoader;
import javax.swing.*;
import java.rmi.RemoteException;
import java.awt.*;
import java.awt.image.BufferedImage;
import java.io.*;
import java.util.Vector;
import visad.*;
import visad.java2d.DisplayImplJ2D;


public class ArrayIcon extends ImageIcon {
  private String conditionName = new String();
  private Float lambdaMin = new Float(0);
  private Float lambdaMax = new Float(0);
  private Float ratioMin = new Float(0); 
  private Float ratioMax = new Float(0);
  private float[][] data;
  private JPanel graphPanel;

  public ArrayIcon(float[][] data) {
	super();
	this.data = data;
	this.conditionName = "Variable Plot";
	for (int m=0;m<data[0].length;m++) {
	  if (data[1][m] > lambdaMax.floatValue())
		lambdaMax = new Float(data[1][m]);
	  if (data[1][m] < lambdaMin.floatValue())
		lambdaMin = new Float(data[1][m]);

	  if (data[0][m] > ratioMax.floatValue())
		ratioMax = new Float(data[0][m]);
	  if (data[0][m] < ratioMin.floatValue())
		ratioMin = new Float(data[0][m]);
	}
	//System.out.println("lam"+lambdaMin.toString()+":"+lambdaMax.toString());
	//System.out.println("rat"+ratioMin.toString()+":"+ratioMax.toString());
	//	System.out.println("Icon Initialized");
  }

  public JPanel getPanel(){
	graphPanel = new JPanel();
	DisplayImplJ2D display = null;
	try{
	  display = new DisplayImplJ2D(this.conditionName);
	  RealType lambda = RealType.getRealType("lambda");
	  RealType ratio = RealType.getRealType("ratio");
	  RealType index = RealType.Generic;
	  ScalarMap lambdaMap = new ScalarMap( lambda, Display.YAxis );
	  ScalarMap ratioMap  = new ScalarMap( ratio, Display.XAxis );

	  RealTupleType ratio_lambda_tuple = new RealTupleType( ratio, lambda );
	  FunctionType plotTuple          = new FunctionType( index, ratio_lambda_tuple );

	  ConstantMap[] pointsMap = new ConstantMap[4];
	  pointsMap[0] = new ConstantMap( 1.0f, Display.Red );
	  pointsMap[1] = new ConstantMap( 0.0f, Display.Green );
	  pointsMap[2] = new ConstantMap( 0.0f, Display.Blue );
	  pointsMap[3] = new ConstantMap( 2.0f, Display.PointSize );
	  
	  GraphicsModeControl dispGMC = (GraphicsModeControl) display.getGraphicsModeControl();
	  dispGMC.setScaleEnable(true);
	  DataReferenceImpl data_ref = new DataReferenceImpl("data_ref");

	  display.removeAllReferences();
	  display.clearMaps();
	  display.addMap( lambdaMap );
	  display.addMap( ratioMap );
	  display.addReference( data_ref, pointsMap );
	  Integer1DSet index_set = new Integer1DSet(index, data[0].length);

	  FlatField vals_ff   = new FlatField( plotTuple, index_set);
	  vals_ff.setSamples( data );
	  lambdaMap.setRange( (1.1*lambdaMin.floatValue()), (1.1*lambdaMax.floatValue()) );
	  ratioMap.setRange( (1.1*ratioMin.floatValue()), (1.1*ratioMax.floatValue()) );
	  data_ref.setData( vals_ff );
	  display.reDisplayAll();
	  graphPanel = (JPanel)display.getComponent();
	  graphPanel.setPreferredSize(new Dimension(300,300));

	  }
	  catch(RemoteException r){
	    r.printStackTrace();
	  }
	  catch(VisADException e){
	    e.printStackTrace();
	  }
	return graphPanel;
  }

}
