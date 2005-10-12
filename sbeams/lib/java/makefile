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

default: all

microarray: 
	(cd SBEAMS/Microarray; make all)

oligo:
	(cd SBEAMS/Oligo;make all)

all:
	(cd SBEAMS; make all)
	(cd SBEAMS/Microarray; make all)
	(cd SBEAMS/Oligo; make all)

clean:
	(cd SBEAMS; make clean)
	(cd SBEAMS/Microarray; make clean)
	(cd SBEAMS/Oligo; make clean)
