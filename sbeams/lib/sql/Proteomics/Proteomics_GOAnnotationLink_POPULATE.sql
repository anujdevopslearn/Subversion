
DROP INDEX biosequence_annotated_gene.idx_biosequence_id
DROP INDEX biosequence_annotated_gene.idx_annotated_gene_id

TRUNCATE TABLE biosequence_annotated_gene


-- Yeast
INSERT INTO biosequence_annotated_gene
SELECT BS.biosequence_id,AG.annotated_gene_id
  FROM biosequence BS
  JOIN biosequence_set BSS ON ( BS.biosequence_set_id = BSS.biosequence_set_id )
  JOIN BioLink..annotated_gene AG ON ( BS.biosequence_gene_name = AG.gene_name )
 WHERE BSS.set_tag LIKE 'YeastORF%'
   AND AG.organism_namespace_id=2


-- Drosophila
INSERT INTO biosequence_annotated_gene
SELECT BS.biosequence_id,AG.annotated_gene_id
  FROM biosequence BS
  JOIN biosequence_set BSS ON ( BS.biosequence_set_id = BSS.biosequence_set_id )
  JOIN BioLink..annotated_gene AG ON ( BS.biosequence_accession = AG.gene_accession )
 WHERE BSS.set_tag LIKE 'Dros%'
   AND AG.organism_namespace_id=1


-- Arabidopsis
INSERT INTO biosequence_annotated_gene
SELECT BS.biosequence_id,AG.annotated_gene_id
  FROM biosequence BS
  JOIN biosequence_set BSS ON ( BS.biosequence_set_id = BSS.biosequence_set_id )
  JOIN BioLink..annotated_gene AG ON ( BS.biosequence_accession = AG.gene_accession )
 WHERE BSS.set_tag LIKE 'ATH%'
   AND AG.organism_namespace_id=6


-- Human NCI biosequence_sets
INSERT INTO biosequence_annotated_gene
SELECT BS.biosequence_id,AG.annotated_gene_id
  FROM biosequence BS
  JOIN biosequence_set BSS ON ( BS.biosequence_set_id = BSS.biosequence_set_id )
  JOIN BioLink..annotated_gene AG ON ( BS.biosequence_accession = AG.gene_accession )
 WHERE BSS.set_tag LIKE 'HuNCI%'
    OR BSS.set_tag LIKE 'HsNCI%'
   AND AG.organism_namespace_id=3


-- Human IPI biosequence_sets
INSERT INTO biosequence_annotated_gene
SELECT DISTINCT BS.biosequence_id,AG.annotated_gene_id
  FROM biosequence BS
  JOIN biosequence_set BSS ON ( BS.biosequence_set_id = BSS.biosequence_set_id )
  JOIN BioLink..goa_association GOAA ON ( BS.biosequence_gene_name = GOAA.ipi_accession AND GOAA.ref_db_tag = 'UniProt' )
  JOIN BioLink..annotated_gene AG ON ( GOAA.ref_db_symbol = AG.gene_accession )
 WHERE BSS.set_tag IN ( 'HuIPI','HepC','OldHuIPI','HIVHepCHuIPI200308' )
    OR BSS.set_tag LIKE 'HsIPI_v%'
   AND AG.organism_namespace_id=4


INSERT INTO biosequence_annotated_gene
SELECT DISTINCT BS.biosequence_id,AG.annotated_gene_id
  FROM biosequence BS
  JOIN biosequence_set BSS ON ( BS.biosequence_set_id = BSS.biosequence_set_id )
  JOIN BioLink..goa_association GOAA ON ( BS.biosequence_gene_name = GOAA.ipi_accession AND GOAA.ref_db_tag = 'UniProt' )
  JOIN BioLink..annotated_gene AG ON ( GOAA.ref_db_symbol = AG.gene_accession )
 WHERE BSS.set_tag LIKE 'MmIPI%'
   AND AG.organism_namespace_id=5



CREATE NONCLUSTERED INDEX idx_biosequence_id ON dbo.biosequence_annotated_gene ( biosequence_id )
CREATE NONCLUSTERED INDEX idx_annotated_gene_id ON dbo.biosequence_annotated_gene ( annotated_gene_id )

-------

For PeptideAtlas we use:

INSERT INTO biosequence_annotated_gene
SELECT BS.biosequence_id,AG.annotated_gene_id
  FROM biosequence BS
  JOIN biosequence_set BSS ON ( BS.biosequence_set_id = BSS.biosequence_set_id )
  JOIN BioLink..annotated_gene AG ON ( BS.biosequence_gene_name = AG.gene_accession )
 WHERE BSS.set_tag LIKE 'SGD%'
   AND AG.organism_namespace_id=2

SELECT TOP 100 * FROM biosequence_set

SELECT TOP 100 * FROM biosequence WHERE biosequence_set_id=10

SELECT * FRom BioLink..organism_namespace

SELECT TOP 100 * FROM BioLink..annotated_gene WHERE organism_namespace_id=2

