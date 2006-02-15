# put here the name of c compiler
CC=gcc
LD=gcc

EXE= digestdb


#
# targets
#
all : digestdb


digestdb: digestdb1.o
	$(LD) $(DEBUG) -O3 -o digestdb digestdb1.o $(LDFLAGS)

digestdb1.o:	
		$(CC) $(DEBUG) $(CCOPT) -O3 -c digestdb1.c

clean:
	rm -f *.o $(EXE) core

debug:
	DEBUG='-g'  make all

#
# dependencies
#
digestdb1.o : digestdb1.c
