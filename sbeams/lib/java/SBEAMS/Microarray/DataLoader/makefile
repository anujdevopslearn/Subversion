PKG=DataLoader.
JAR_DIR=/net/dblocal/www/html/dev7/sbeams/usr/java/share/util/
CP = .:..:$(JAR_DIR)java-getopt-1.0.10.jar:$(JAR_DIR)visad.jar:$(JAR_DIR)experiment.jar:$(JAR_DIR)jdom.jar:$(JAR_DIR)SBEAMS.jar:$(JAR_DIR)msv.jar:$(JAR_DIR)isorelax.jar:$(JAR_DIR)relaxngDatatype.jar:$(JAR_DIR)xercesImpl.jar:$(JAR_DIR)xmlParserAPIs.jar:$(JAR_DIR)xsdlib.jar

JC = javac
JC+= -classpath $(CP)

.SUFFIXES: .java .class
.java.class: 
	$(JC) $<

OBJS =	DataLoader.class\
	ArrayIcon.class\
	CommandLineReader.class\
	ConditionInfoWizardPanel.class\
	ConditionTreeWizardPanel.class\
	ConditionVariable.class\
	DataSaverPanel.class\
	ExperimentCondition.class\
	FileChooserWizardPanel.class\
	GeneExpressionFileReader.class\
	GeneralInfoWizardPanel.class\
	IncludeFileFilter.class\
	NullWizardPanel.class\
	TextWriter.class\
	VariableTable.class\
	WelcomeWizardPanel.class\
	WizardAdapter.class\
	WizardContext.class\
	WizardFrame.class\
	WizardListener.class\
	WizardPanel.class

objs: $(OBJS)

test: objs
	(cd unitTests; make test)

default: objs

clean:
	(rm *.class)
	(cd unitTests; make clean)

basic: objs
	-java ${PKG}DataLoader

sbeams: jar
	(java -jar DataLoader.jar -t "test" -m "sbeamsIndirect://db/dev7/sbeams/cgi/Microarray/ViewFile.cgi?action=read&FILE_NAME=matrix_output&project_id=497&SUBDIR=20050119_160105")

jar: objs
	(cd ..;jar cmf DataLoader/MANIFEST.MF DataLoader/DataLoader.jar DataLoader/*.class)

update_jar: sign
	(mv DataLoader.jar ../../../../usr/java/Microarray)

sign: jar
	-jarsigner -keystore /users/mjohnson/.keystore -storepass cytokey DataLoader.jar cytoscape
