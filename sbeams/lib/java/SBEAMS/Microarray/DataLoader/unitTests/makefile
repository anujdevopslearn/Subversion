PKG=DataLoader.unitTests.
JAR_DIR=/net/dblocal/www/html/dev7/sbeams/usr/java/share/util/
CP = ../../:..:$(CLASSPATH):$(JAR_DIR)junit.jar
JC = javac
JC += -classpath $(CP)

.SUFFIXES: .java .class
.java.class: 
	$(JC) $<

OBJS =	CommandLineReaderTest.class\
	ConditionVariableTest.class\
	ExperimentConditionTest.class

objs: $(OBJS)

default: test

clean:
	(rm *.class)

test: objs
	-java -cp $(CP) ${PKG}CommandLineReaderTest
	-java -cp $(CP) ${PKG}ConditionVariableTest
	-java -cp $(CP) ${PKG}ExperimentConditionTest

