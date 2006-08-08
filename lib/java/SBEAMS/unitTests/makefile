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

default: objs

objs: $(OBJS)

test: objs 0

all: objs

#------ 0
#  build and run the SBEAMSClientTest
#
0: SBEAMSClientTest.class
	java $(PKG).SBEAMSClientTest

clean:
	- rm *.class
