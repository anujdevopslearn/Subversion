-- affy_db_links
CREATE NONCLUSTERED INDEX idx_affy_annotation_id
   ON dbo.affy_db_links ( affy_annotation_id )
go
-- affy_db_links affy_db_links_id --
CREATE NONCLUSTERED INDEX idx_affy_db_links_id
   ON dbo.affy_db_links ( affy_db_links_id )
go
-- gene_ontology
CREATE NONCLUSTERED INDEX idx_affy_annotation_id
   ON dbo.gene_ontology ( affy_annotation_id )
go	
-- gene_ontology affy_db_links_id
CREATE NONCLUSTERED INDEX idx_affy_db_links_id
   ON dbo.gene_ontology ( affy_db_links_id )
go
-- protein_families
CREATE NONCLUSTERED INDEX idx_affy_annotation_id
   ON dbo.protein_families ( affy_annotation_id )
go	
-- protein_families affy_db_links_id
CREATE NONCLUSTERED INDEX idx_affy_db_links_id
   ON dbo.protein_families ( affy_db_links_id )
go
-- interpro
CREATE NONCLUSTERED INDEX idx_affy_annotation_id
   ON dbo.interpro ( affy_annotation_id )
go	
-- interpro affy_db_links_id
CREATE NONCLUSTERED INDEX idx_affy_db_links_id
   ON dbo.interpro ( affy_db_links_id )
go
-- protein_domain
CREATE NONCLUSTERED INDEX idx_affy_annotation_id
   ON dbo.protein_domain ( affy_annotation_id )
go	
-- protein_domain affy_db_links_id
CREATE NONCLUSTERED INDEX idx_affy_db_links_id
   ON dbo.protein_domain ( affy_db_links_id )
go
-- trans_membrane
CREATE NONCLUSTERED INDEX idx_affy_annotation_id
   ON dbo.trans_membrane ( affy_annotation_id )
go
-- alignment
CREATE NONCLUSTERED INDEX idx_affy_annotation_id
   ON dbo.alignment ( affy_annotation_id )
go
-- overlapping_transcript
CREATE NONCLUSTERED INDEX idx_affy_annotation_id
   ON dbo.overlapping_transcript ( affy_annotation_id )   
go
-- affy_annotation
CREATE NONCLUSTERED INDEX idx_affy_annotation_id
   ON dbo.affy_annotation ( affy_annotation_id )   
go 
-- affy_annotation probe_set_id annotation_set_id
CREATE NONCLUSTERED INDEX idx_affy_annotation_probe_set_id__annotation_set_id
   ON dbo.affy_annotation ( probe_set_id, affy_annotation_set_id)   

-- affy_gene_intensity 
CREATE NONCLUSTERED INDEX idx_probe_set_id
   ON dbo.affy_gene_intensity ( probe_set_id )    
go
-- affy_gene_intensity_ affy_array_id
CREATE NONCLUSTERED INDEX idx_affy_array_id
   ON dbo.affy_gene_intensity ( affy_array_id )     
