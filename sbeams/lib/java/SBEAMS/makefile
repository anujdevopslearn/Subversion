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

jar: objs
	cd ..;jar -cf SBEAMS.jar SBEAMS/*.class; mv SBEAMS.jar SBEAMS

signed_jar: jar
	jarsigner -keystore /net/db/etc/.keystore -storepass sbeamsDevKey SBEAMS.jar sbeamsDev

update_sbeams: signed_jar
	mv SBEAMS.jar ../../../usr/java/share/util
	make clean

clean:
	- rm *.class
