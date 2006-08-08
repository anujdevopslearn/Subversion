#-------------------------------------------------------------------------
# $Revision$
# $Date$
# $Author$
#--------------------------------------------------------------------

JC=javac -source 1.4
PKG=SBEAMS

KEYSTORE=/net/db/etc/.keystore
KEYPASS=sbeamsDevKey
KEYALIAS=sbeamsDev

.SUFFIXES: .java .class
.java.class: 
	$(JC) $<

OBJS =  SBEAMSClient.class \
	PasswordDialog.class


default: objs

objs: $(OBJS)
	(cd unitTests; make)

test: objs
	(cd unitTests; make test)

all: objs
	
client: objs
	java $(PKG).SBEAMSClient

jar: objs
	cd ..;jar -cf SBEAMS.jar SBEAMS/*.class; mv SBEAMS.jar SBEAMS

signed_jar: jar
	jarsigner -keystore $(KEYSTORE) -storepass $(KEYPASS) SBEAMS.jar $(KEYALIAS)

update_sbeams: signed_jar
	mv SBEAMS.jar ../../../usr/java/share/util
	make clean

clean:
	- rm *.class
	(cd unitTests; make clean)
