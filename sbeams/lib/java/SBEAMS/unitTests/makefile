# makefile for cytoscape/experiment/connection/unitTests
#-------------------------------------------------------------------------
# $Revision$
# $Date$
# $Author$
#--------------------------------------------------------------------

JC=javac

PKG=SBEAMS.unitTests

.SUFFIXES: .java .class
.java.class: 
	$(JC) $<

OBJS = SBEAMSClientTest.class

objs: $(OBJS)


default: objs run

clean:
	- rm *.class

#------ all
#  run all the tests
#
all: $(OBJS) 0

#------ 0
#  build and run the DataMatrixFileReaderTest
#
0: SBEAMSClientTest.class
	java $(PKG).SBEAMSClientTest

