###############################################################################
#
# Program     : makefile
# Author      : Michael Johnson <mjohnson@systemsbiology.org>
# Description : makefile for java applets
#
###############################################################################

JC=javac

.SUFFIXES: .java .class
.java.class:
	$(JC) $<

OBJS = TestApplet.class

default: objs

all: objs

objs: $(OBJS)
	(cp *.class ../../../applets/Microarray)

clean:
	- rm *.class

