jar:
	/tools/java/sdk/bin/jar cvf data.jar \
		cytoscape.props \
		project-jnlp \
		vizmap.props \
		network.sif \
		biosequence_name.noa \
		reporter_name.noa \
		common_name.noa \
		external_identifier.noa\
		gene_name.noa \
		second_name.noa \
		full_name.noa \
		NodeType.noa \
		Expression_edges.eda \
		Significance_edges.eda 
	#/tools/java/sdk/bin/jarsigner -keystore /net/db/src/cytoscape/keystore/keystore -storepass gr5jd=ww data.jar EricDeutsch
	/tools/java/j2sdk1.4.2/bin/jarsigner -keystore /users/pshannon/.keystore -storepass cytokey data.jar cytoscape
