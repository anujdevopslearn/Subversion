###################################################################################
# Program       : Makefile                                                        #
# Author        : Robert Hubley <rhubley@systemsbiology.org>                      #
# Date          : 03/09/2003                                                      #
#                                                                                 #
# THE SOFTWARE IS PROVIDED BY THE INSTITUTE FOR SYSTEMS BIOLOGY (ISB)             #
# "AS IS" AND "WITH ALL FAULTS." ISB MAKES NO REPRESENTATIONS OR WARRANTI         #
# ES OF ANY KIND CONCERNING THE QUALITY, SAFETY OR SUITABILITY OF THE             #
# SOFTWARE, EITHER EXPRESSED OR IMPLIED, INCLUDING WITHOUT LIMITATION ANY IM-     #
# PLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE,          #
# OR NON-INFRINGEMENT.                                                            #
#                                                                                 #
# ISB MAKES NO REPRESENTATIONS OR WARRANTIES AS TO THE TRUTH, ACCURACY            #
# OR COMPLETENESS OF ANY STATEMENTS, INFORMATION OR MATERIALS CONCERNING          #
#                                                                                 #
# THE SOFTWARE THAT IS CONTAINED IN ANY DOCUMENTATION INCLUDED WITH THE           #
# SOFTWARE OR ON AND WITHIN ANY OF THE WEBSITES OWNED AND OPERATED BY ISB         #
#                                                                                 #
# IN NO EVENT WILL ISB BE LIABLE FOR ANY INDIRECT, PUNITIVE, SPECIAL,             #
# INCIDENTAL OR CONSEQUENTIAL DAMAGES HOWEVER THEY MAY ARISE AND EVEN IF          #
# ISB HAVE BEEN PREVIOUSLY ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.            #
#                                                                                 #
###################################################################################

###################################################################################
#                                                                                 #
# Edit the ZLIBROOT variable below to point to your installation of zlib.  This   # 
# Makefile requires that libz.a is built.                                         #
#                                                                                 #
###################################################################################


# put here the name of c++ compiler
CC=gcc

ifndef RAMPROOT
RAMPROOT=/tools/bin/Code/jimmy/sashimi-jimmy/trans_proteomic_pipeline/src/Parsers/ramp
endif

# put here the complete path to the RAMP ROOT
RAMPINC= -I. -I${RAMPROOT} 

ZLIBROOT=/tools/bin/Code/jimmy/sashimi-jimmy/zlib-1.2.3/

# here again the name of the c++ compiler
LD=gcc

# handle 2GB+ files
CCOPT= -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64

LDFLAGS= -L/usr/lib -L/usr/local/lib 

OLD = 

######################################################################
#
# do not edit past this point
#
######################################################################

OBJS = getSpectrum.o base64.o ramp.o
EXE = getSpectrum

#
# rules
#
.SUFFIXES:	.o .c 

.c.o:	
		$(CC) $(OLD) $(DEBUG) $(CCOPT) ${RAMPINC} -O3 -c $<

#
# targets
#
all : getSpectrum

getSpectrum:  $(OBJS)
		$(LD) $(DEBUG) $(CCOPT) -O3 -o $(EXE) $(OBJS) $(ZLIBROOT)libz.a $(LDFLAGS)

base64.o:	
		$(CC) $(OLD) $(DEBUG) $(CCOPT) ${RAMPINC} -O3 -c ${RAMPROOT}/base64.c

ramp.o:	
		$(CC) $(OLD) $(DEBUG) $(CCOPT) ${RAMPINC} -O3 -c ${RAMPROOT}/ramp.c

clean:
	rm -f *.o $(EXE) core

debug:
	DEBUG='-g'  make all

#
# dependencies
#
getSpectrum.o : getSpectrum.c
base64.o : ${RAMPROOT}/base64.c
ramp.o : ${RAMPROOT}/ramp.c
