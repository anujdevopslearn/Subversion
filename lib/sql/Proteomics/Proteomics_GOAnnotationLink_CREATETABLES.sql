
CREATE TABLE dbo.biosequence_annotated_gene (
  biosequence_id        int,
  annotated_gene_id     int,
  PRIMARY KEY (biosequence_id,annotated_gene_id)
)
GO


CREATE NONCLUSTERED INDEX idx_biosequence_id ON dbo.biosequence_annotated_gene ( biosequence_id )
CREATE NONCLUSTERED INDEX idx_annotated_gene_id ON dbo.biosequence_annotated_gene ( annotated_gene_id )

