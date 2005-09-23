
CREATE NONCLUSTERED INDEX idx_annotated_gene_gene_accession ON dbo.annotated_gene ( gene_accession )
CREATE NONCLUSTERED INDEX idx_gene_annotation_annotated_gene_id ON dbo.gene_annotation ( annotated_gene_id )
CREATE NONCLUSTERED INDEX idx_gene_annotation_annotation ON dbo.gene_annotation ( gene_annotation_type_id,idx,annotation )






