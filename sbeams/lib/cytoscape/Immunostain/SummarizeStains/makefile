jar:
	$JAVA_PATH/bin/jar cvf data.jar \
		cytoscape.props \
		project-jnlp \
		vizmap.props \
		$ALLFILESHERE
	$JAVA_PATH/bin/jarsigner -keystore $KEYSTORE_FILE -storepass $KEYSTORE_PASSWD data.jar $KEYSTORE_ALIAS
