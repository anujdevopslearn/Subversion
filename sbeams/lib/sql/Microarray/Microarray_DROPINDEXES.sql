-- db_links
DROP INDEX dbo.affy_db_links.idx_affy_annotation_id
go
-- affy_db_links affy_db_links_id --
DROP INDEX dbo.affy_db_links.idx_affy_db_links_id
go
-- gene_ontology
DROP INDEX dbo.gene_ontology.idx_affy_annotation_id
go	
-- gene_ontology affy_db_links_id
DROP INDEX dbo.gene_ontology.idx_affy_db_links_id  
go
-- protein_families
DROP INDEX dbo.protein_families.idx_affy_annotation_id
go
-- protein_families affy_db_links_id
DROP INDEX dbo.protein_families.idx_affy_db_links_id
go
-- interpro
DROP INDEX dbo.interpro.idx_affy_annotation_id
go
-- interpro affy_db_links_id
DROP INDEX dbo.interpro.idx_affy_db_links_id
go
-- protein_domain
DROP INDEX dbo.protein_domain.idx_affy_annotation_id
go
-- protein_domain affy_db_links_id
DROP INDEX dbo.protein_domain.idx_affy_db_links_id
go
-- trans_membrane
DROP INDEX dbo.trans_membrane.idx_affy_annotation_id
go
-- alignment
DROP INDEX dbo.alignment.idx_affy_annotation_id
go
-- overlapping_transcript
DROP INDEX dbo.overlapping_transcript.idx_affy_annotation_id
go
-- affy_annotation
DROP INDEX dbo.affy_annotation.idx_affy_annotation_id
go
-- affy_annotation probe_set annotation_set_id
DROP INDEX dbo.affy_annotation.idx_affy_annotation_probe_set_id__annotation_set_id
go
-- affy_gene_intensity
DROP INDEX dbo.affy_gene_intensity.idx_probe_set_id
go
-- affy_gene_intensity_ affy_array_id 
DROP INDEX dbo.affy_gene_intensity.idx_affy_array_id
 
