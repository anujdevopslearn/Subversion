PKG=DataLoader.

KEYSTORE=/net/db/etc/.keystore
KEYPASS=sbeamsDevKey
KEYALIAS=sbeamsDev

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
	(java -jar DataLoader.jar -p "328" -m "sbeamsIndirect://db/sbeams/cgi/Microarray/ViewFile.cgi?action=read&FILE_NAME=matrix_output&project_id=497&SUBDIR=20050119_160105" -r "sbeamsIndirect://db/sbeams/tmp/Microarray/dataLoader/translator.tsv")

jar: objs
	(cd ..;jar cmf DataLoader/MANIFEST.MF DataLoader/DataLoader.jar DataLoader/*.class)

sign: jar
	-jarsigner -keystore $(KEYSTORE) -storepass $(KEYPASS) DataLoader.jar $(KEYALIAS)

update_jar: sign
	(mv DataLoader.jar ../../../../../usr/java/Microarray)

update_sbeams: update_jar
	-jarsigner -keystore $(KEYSTORE) -storepass $(KEYPASS) $(JAR_DIR)experiment.jar $(KEYALIAS)
	-jarsigner -keystore $(KEYSTORE) -storepass $(KEYPASS) $(JAR_DIR)isorelax.jar $(KEYALIAS)
	-jarsigner -keystore $(KEYSTORE) -storepass $(KEYPASS) $(JAR_DIR)java-getopt-1.0.10.jar $(KEYALIAS)
	-jarsigner -keystore $(KEYSTORE) -storepass $(KEYPASS) $(JAR_DIR)jdom.jar $(KEYALIAS)
	-jarsigner -keystore $(KEYSTORE) -storepass $(KEYPASS) $(JAR_DIR)msv.jar $(KEYALIAS)
	-jarsigner -keystore $(KEYSTORE) -storepass $(KEYPASS) $(JAR_DIR)relaxngDatatype.jar $(KEYALIAS)
	-jarsigner -keystore $(KEYSTORE) -storepass $(KEYPASS) $(JAR_DIR)SBEAMS.jar $(KEYALIAS)
	-jarsigner -keystore $(KEYSTORE) -storepass $(KEYPASS) $(JAR_DIR)visad.jar $(KEYALIAS)
	-jarsigner -keystore $(KEYSTORE) -storepass $(KEYPASS) $(JAR_DIR)xercesImpl.jar $(KEYALIAS)
	-jarsigner -keystore $(KEYSTORE) -storepass $(KEYPASS) $(JAR_DIR)xmlParserAPIs.jar $(KEYALIAS)
	-jarsigner -keystore $(KEYSTORE) -storepass $(KEYPASS) $(JAR_DIR)xsdlib.jar $(KEYALIAS)
