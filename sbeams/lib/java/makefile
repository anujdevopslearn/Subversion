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

microarray: 
	(cd Microarray; make all)

oligo:
	(cd Oligo;make all)

all:
	(cd Microarray; make all)
	(cd Oligo; make all)

clean:
	(cd Microarray; make clean)
	(cd Oligo; make clean)
