PKG=DataLoader.unitTests.
CP = ../../:..:$(CLASSPATH)
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

