-- affy_db_links index on affy_annotation id and db_id
CREATE INDEX idx_affy_annotation_id__db_id
   ON affy_db_links ( affy_annotation_id, db_id );

-- affy_db_links affy_db_links_id --
CREATE INDEX idx_affy_db_links_id
   ON affy_db_links ( affy_db_links_id );

-- gene_ontology
CREATE INDEX idx_affy_annotation_id
   ON gene_ontology ( affy_annotation_id );
	
-- gene_ontology affy_db_links_id
CREATE INDEX idx_affy_db_links_id
   ON gene_ontology ( affy_db_links_id );

-- protein_families
CREATE INDEX idx_affy_annotation_id
   ON protein_families ( affy_annotation_id );
	
-- protein_families affy_db_links_id
CREATE INDEX idx_affy_db_links_id
   ON protein_families ( affy_db_links_id );

-- interpro
CREATE INDEX idx_affy_annotation_id
   ON interpro ( affy_annotation_id );
	
-- interpro affy_db_links_id
CREATE INDEX idx_affy_db_links_id
   ON interpro ( affy_db_links_id );

-- protein_domain
CREATE INDEX idx_affy_annotation_id
   ON protein_domain ( affy_annotation_id );
	
-- protein_domain affy_db_links_id
CREATE INDEX idx_affy_db_links_id
   ON protein_domain ( affy_db_links_id );

-- trans_membrane
CREATE INDEX idx_affy_annotation_id
   ON trans_membrane ( affy_annotation_id );

--trans_membrane and number of Domains
CREATE INDEX idx_numberofdomains__affy_annotation_id
   ON trans_membrane ( number_of_domains, affy_annotation_id   );

-- alignment
CREATE INDEX idx_affy_annotation_id
   ON alignment ( affy_annotation_id );

-- overlapping_transcript
CREATE INDEX idx_affy_annotation_id
   ON overlapping_transcript ( affy_annotation_id );

-- affy_annotation
CREATE INDEX idx_affy_annotation_id
   ON affy_annotation ( affy_annotation_id );   
 
-- affy_annotation probe_set_id annotation_set_id
CREATE INDEX idx_affy_annotation_probe_set_id__annotation_set_id
   ON affy_annotation ( probe_set_id, affy_annotation_set_id);   

-- affy_gene_intensity 
CREATE INDEX idx_probe_set_id
   ON affy_gene_intensity ( probe_set_id );

-- affy_gene_intensity_ affy_array_id
CREATE INDEX idx_affy_array_id
   ON affy_gene_intensity ( affy_array_id );     

-- affy_gene_intensity_   affy_array_id,probe_set_id, protocol_id
CREATE INDEX idx_afa_id_probe_set_id_protocol_id
   ON affy_gene_intensity (  affy_array_id,probe_set_id, protocol_id );   

-- condition  condition_id
CREATE INDEX idx_condition_id
   ON gene_expression ( condition_id );

-- condition  gene_name
CREATE INDEX idx_gene_name
   ON gene_expression ( gene_name );    
 
-- condition  biosequence_id
CREATE INDEX idx_biosequence_id
   ON gene_expression ( biosequence_id );    

-- condition  condition_id,false_discovery_rate
CREATE INDEX idx_condition_id_fdr
   ON dbo.gene_expression ( condition_id,false_discovery_rate );

-- condition  condition_id,canonical_name
CREATE INDEX idx_cond_id_canonical
   ON dbo.gene_expression ( condition_id,canonical_name );


