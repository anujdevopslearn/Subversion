# put here the name of c compiler
CC=gcc
CPP=g++

# put here the complete path to the RAMP ROOT
RAMPROOT= ramp
RAMPINC= -I . -I ${RAMPROOT} -I ../common

EXE=getSpectrum getSpectrumHeader

# handle 2GB+ files
CCOPT= -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64

#
# targets
#
all : $(EXE)


getSpectrum: getSpectrum.o ramp_base64.o ramp.o
	$(CPP) $(CCOPT) ${RAMPINC} -O3 -o getSpectrum getSpectrum.o ramp_base64.o ramp.o $(LDFLAGS) -lz

getSpectrumHeader: getSpectrumHeader.o ramp_base64.o ramp.o
	$(CPP) $(CCOPT) ${RAMPINC} -O3 -o getSpectrumHeader getSpectrumHeader.o ramp_base64.o ramp.o $(LDFLAGS) -lz

getSpectrum.o:
	$(CPP) $(CCOPT) ${RAMPINC} -O3 -c getSpectrum.cpp

getSpectrumHeader.o:
	$(CPP) $(CCOPT) ${RAMPINC} -O3 -c getSpectrumHeader.cpp

ramp_base64.o:
	$(CPP) $(CCOPT) ${RAMPINC} -O3 -c ${RAMPROOT}/ramp_base64.cpp

ramp.o:
	$(CPP) $(CCOPT) ${RAMPINC} -O3 -c ${RAMPROOT}/ramp.cpp

clean:
	rm -f *.o $(EXE) core

debug:
	DEBUG='-g'  make all

#
# dependencies
#
getSpectrum.o : getSpectrum.cpp
getSpectrumHeader.o : getSpectrumHeader.cpp
ramp_base64.o : ${RAMPROOT}/ramp_base64.cpp ${RAMPROOT}/ramp_base64.h
ramp.o : ${RAMPROOT}/ramp.cpp ${RAMPROOT}/ramp.h
