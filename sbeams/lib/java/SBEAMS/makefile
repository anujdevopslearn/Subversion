#-------------------------------------------------------------------------
# $Revision$
# $Date$
# $Author$
#--------------------------------------------------------------------

JC=javac -source 1.4
PKG=SBEAMS

.SUFFIXES: .java .class
.java.class: 
	$(JC) $<

OBJS =  SBEAMSClient.class \
	PasswordDialog.class


default: objs

objs: $(OBJS)

all: objs

client: objs
	java $(PKG).SBEAMSClient

clean:
	- rm *.class
