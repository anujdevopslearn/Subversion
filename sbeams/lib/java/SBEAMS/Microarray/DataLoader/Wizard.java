package DataLoader;
import java.awt.*;
import java.awt.event.*;
import java.lang.reflect.*;
import java.util.*;
import javax.swing.*;
//-----------------------------------------------------------------------------------------------
public class Wizard extends JPanel implements ActionListener {
//-----------------------------------------------------------------------------------------------
  public static final String BACK_I18N = "BACK_I18N";
  public static final String NEXT_I18N = "NEXT_I18N";
  public static final String FINISH_I18N = "FINISH_I18N";
  public static final String CANCEL_I18N = "CANCEL_I18N";
  public static final String HELP_I18N = "HELP_I18N";
  public static final Dimension WIZARD_WINDOW_SIZE = new Dimension( 800, 600 );
  private final JButton backButton = new JButton("<< back");
  private final JButton nextButton = new JButton("next >>");
  private final JButton finishButton = new JButton("finish");
  private final JButton cancelButton = new JButton("cancel");
  private final JButton helpButton = new JButton("help");
  private final HashMap listeners = new HashMap();
  private Stack previous = null;
  private WizardPanel current = null;
  private WizardContext ctx = null;
  private Map i18n = null;
//-----------------------------------------------------------------------------------------------
  public Wizard( Map i18n ) {
	this.i18n = i18n;
	init();
	this.applyI18N( this.i18n );
  }
//-----------------------------------------------------------------------------------------------
  public Wizard() {
	init();
  }
//-----------------------------------------------------------------------------------------------
  public Wizard(WizardContext wc) {
	init();
	ctx = wc;
  }
//-----------------------------------------------------------------------------------------------
  private void init() {
	nextButton.addActionListener(this);
	backButton.addActionListener(this);
	finishButton.addActionListener(this);
	cancelButton.addActionListener(this);
	helpButton.addActionListener(this);
	nextButton.setEnabled(false);
	backButton.setEnabled(false);
	finishButton.setEnabled(false);
	cancelButton.setEnabled(false);
	helpButton.setEnabled(false);
	setLayout(new BorderLayout());
	JPanel navButtons = new JPanel();
	navButtons.setLayout(new FlowLayout(FlowLayout.RIGHT));
	navButtons.add(backButton);
	navButtons.add(nextButton);
	navButtons.add(finishButton);
	JPanel cancelButtons = new JPanel();
	cancelButtons.setLayout(new FlowLayout(FlowLayout.LEFT));
	cancelButtons.add(cancelButton);
	cancelButtons.add(helpButton);
	JPanel buttons = new JPanel();
	buttons.setLayout(new BorderLayout());
	buttons.add(navButtons, BorderLayout.EAST);
	buttons.add(cancelButtons, BorderLayout.WEST);
	add(buttons, BorderLayout.SOUTH);
	setMinimumSize( WIZARD_WINDOW_SIZE );
	setPreferredSize( WIZARD_WINDOW_SIZE );
  }
//-----------------------------------------------------------------------------------------------
  public void setI18NMap( Map map ) {
	i18n = map;
	applyI18N( i18n );
  }
//-----------------------------------------------------------------------------------------------
  private void applyI18N( Map map ) {
	if ( map.size() > 0 ) {
	  nextButton.setText( (String)map.get( NEXT_I18N ) );
	  backButton.setText( (String)map.get( BACK_I18N ) );
	  finishButton.setText( (String)map.get( FINISH_I18N ) );
	  cancelButton.setText( (String)map.get( CANCEL_I18N ) );
	  helpButton.setText( (String)map.get( HELP_I18N ) );
	  backButton.setActionCommand( "<< back" );
	  nextButton.setActionCommand( "next >>" );
	  finishButton.setActionCommand( "finish" );
	  cancelButton.setActionCommand( "cancel" );
	  helpButton.setActionCommand( "help" );
	}
  }
//-----------------------------------------------------------------------------------------------
  public void addWizardListener(WizardListener listener) {
	listeners.put(listener, listener);
  }
//-----------------------------------------------------------------------------------------------
  public void removeWizardListener(WizardListener listener) {
	listeners.remove(listener);
  }
//-----------------------------------------------------------------------------------------------
  public void start(WizardPanel wp) {
	previous = new Stack();
	if (ctx == null)
	  ctx = new WizardContext();
	wp.setWizardContext(ctx);
	setPanel(wp);
	updateButtons();
  }
//-----------------------------------------------------------------------------------------------
  public void actionPerformed(ActionEvent ae) {
	String ac = ae.getActionCommand();
	if ("<< back".equals(ac)) {
	  back();
	} else if ("next >>".equals(ac)) {
	  next();
	} else if ("finish".equals(ac)) {
	  finish();
	} else if ("cancel".equals(ac)) {
	  cancel();
	} else if ("help".equals(ac)) {
	  help();
	}
  }
//-----------------------------------------------------------------------------------------------
  private void setPanel(WizardPanel wp) {
	if (null != current) {
	  remove(current);
	}
	current = wp;
	if (null == current) {
	  current = new NullWizardPanel();
	}
	add(current, BorderLayout.CENTER);
	Iterator iter = listeners.values().iterator();
	while(iter.hasNext()) {
	  WizardListener listener = (WizardListener)iter.next();
	  listener.wizardPanelChanged(this);
	}
	setVisible(true);
	revalidate();
	updateUI();
	current.display();
  }
//-----------------------------------------------------------------------------------------------
  private void updateButtons() {
	cancelButton.setEnabled(current.canCancel());
	helpButton.setEnabled(current.hasHelp());
	backButton.setEnabled(previous.size() > 0);
	nextButton.setEnabled(current.hasNext());
	finishButton.setEnabled(current.canFinish());
  }
//-----------------------------------------------------------------------------------------------
  private void back() {
	WizardPanel wp = (WizardPanel)previous.pop();
	setPanel(wp);
	updateButtons();
  }
//-----------------------------------------------------------------------------------------------
  private void next() {
	ArrayList list = new ArrayList();
	if (current.validateNext(list)) {
	  previous.push(current);
	  WizardPanel wp = current.next();
	  if (null != wp) {
		wp.setWizardContext(ctx);
	  }
	  setPanel(wp);
	  updateButtons();
	} else {
	  showErrorMessages(list);
	}
  }
//-----------------------------------------------------------------------------------------------
  private void finish() {
	ArrayList list = new ArrayList();
	if (current.validateFinish(list)) {
	  current.finish();
	  Iterator iter = listeners.values().iterator();
	  while(iter.hasNext()) {
		WizardListener listener = (WizardListener)iter.next();
		listener.wizardFinished(this);
	  }
	} else {
	  showErrorMessages(list);
	}
  }
//-----------------------------------------------------------------------------------------------
  private void cancel() {
	Iterator iter = listeners.values().iterator();
	while(iter.hasNext()) {
	  WizardListener listener = (WizardListener)iter.next();
	  listener.wizardCancelled(this);
	}
  }
//-----------------------------------------------------------------------------------------------
  private void help() {
	current.help();
  }
//-----------------------------------------------------------------------------------------------
  private void showErrorMessages(ArrayList list) {
	Object[] errors = (Object[])list.toArray();
	for (int m=0;m<errors.length;m++){
	  if (errors[m] instanceof String)
		JOptionPane.showMessageDialog(this, errors[m], "Data Loader Error", JOptionPane.ERROR_MESSAGE);
	}
  }
//-----------------------------------------------------------------------------------------------
}

