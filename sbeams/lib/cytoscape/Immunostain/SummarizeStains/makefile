jar:
	/tools/java/sdk/bin/jar cvf data.jar \
		cytoscape.props \
		project-jnlp \
		vizmap.props \
		network.sif \
		ExpressionLevel.eda \
		ExpressionLevelLabel.eda \
		commonName.noa \
		NodeType.noa \
		organism.noa
	/tools/java/sdk/bin/jarsigner -keystore /net/db/src/cytoscape/keystore/keystore -storepass gr5jd=ww data.jar EricDeutsch
