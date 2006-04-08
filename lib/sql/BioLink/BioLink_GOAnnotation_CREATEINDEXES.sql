
CREATE NONCLUSTERED INDEX idx_annotated_gene_gene_accession ON dbo.annotated_gene ( gene_accession )
GO

CREATE NONCLUSTERED INDEX idx_gene_annotation_annotated_gene_id ON dbo.gene_annotation ( annotated_gene_id )
GO

CREATE NONCLUSTERED INDEX idx_gene_annotation_typeidxlevel ON dbo.gene_annotation ( annotated_gene_id,gene_annotation_type_id,idx,hierarchy_level )
GO

-- CREATE NONCLUSTERED INDEX idx_gene_annotation_annotation ON dbo.gene_annotation ( annotated_gene_id,gene_annotation_type_id,idx,hierarchy_level,annotation )
-- GO


-- select * from sysindexes where name like 'idx%'






