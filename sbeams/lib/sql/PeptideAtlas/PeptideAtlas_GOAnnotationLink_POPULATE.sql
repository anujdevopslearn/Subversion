
DROP INDEX biosequence_annotated_gene.idx_biosequence_id
DROP INDEX biosequence_annotated_gene.idx_annotated_gene_id

TRUNCATE TABLE biosequence_annotated_gene

-- Yeast
SELECT * from biosequence_set WHERE set_tag LIKE 'SGD%'
INSERT INTO biosequence_annotated_gene
SELECT BS.biosequence_id,AG.annotated_gene_id
  FROM biosequence BS
  JOIN biosequence_set BSS ON ( BS.biosequence_set_id = BSS.biosequence_set_id )
  JOIN BioLink..annotated_gene AG
       ON ( BS.biosequence_accession = AG.gene_accession
         OR BS.biosequence_gene_name = AG.gene_accession )
 WHERE BSS.set_tag LIKE 'SGD%'
   AND AG.organism_namespace_id=2


-- Human ENSP biosequence_sets
SELECT * from biosequence_set WHERE set_tag LIKE 'Hs_ENSP%'
INSERT INTO biosequence_annotated_gene
SELECT DISTINCT BS.biosequence_id,AG.annotated_gene_id
  FROM biosequence BS
  JOIN biosequence_set BSS ON ( BS.biosequence_set_id = BSS.biosequence_set_id )
  JOIN BioLink..goa_xref GOAX ON ( BS.biosequence_name = LEFT(GOAX.embl_ids,15) )
  JOIN BioLink..goa_association GOAA ON ( GOAX.ipi_accession = GOAA.ipi_accession AND GOAA.ref_db_tag = 'UniProt' )
  JOIN BioLink..annotated_gene AG ON ( GOAA.ref_db_symbol = AG.gene_accession )
 WHERE set_tag LIKE 'Hs_ENSP%'
   AND AG.organism_namespace_id=5
--   AND BS.biosequence_name like 'ENSP000003457%'


-------

CREATE INDEX idx_biosequence_id ON dbo.biosequence_annotated_gene ( biosequence_id )
CREATE INDEX idx_annotated_gene_id ON dbo.biosequence_annotated_gene ( annotated_gene_id )

-------

-- Testing queries:

SELECT COUNT(*) FROM biosequence_annotated_gene

SELECT TOP 100 * FROM biosequence_set

SELECT TOP 100 * FROM biosequence WHERE biosequence_set_id=2

SELECT * FRom BioLink..organism_namespace

SELECT TOP 100 * FROM BioLink..annotated_gene WHERE organism_namespace_id=2

SELECT TOP 100 * FROM BioLink..goa_association 

SELECT TOP 100 * FROM BioLink..goa_xref

-----

SELECT TOP 100 *
  FROM biosequence BS
  JOIN biosequence_set BSS ON ( BS.biosequence_set_id = BSS.biosequence_set_id )
  JOIN BioLink..goa_association GOAA ON ( BS.biosequence_gene_name = GOAA.ipi_accession AND GOAA.ref_db_tag = 'UniProt' )
  JOIN BioLink..annotated_gene AG ON ( GOAA.ref_db_symbol = AG.gene_accession )
 WHERE set_tag LIKE 'Hs_ENSP%'
   AND AG.organism_namespace_id=5
   AND BS.biosequence_name like 'ENSP000003457%'

SELECT TOP 1000 *
  FROM biosequence BS
  JOIN biosequence_set BSS ON ( BS.biosequence_set_id = BSS.biosequence_set_id )
  JOIN BioLink..goa_xref GOAX ON ( BS.biosequence_name = LEFT(GOAX.embl_ids,15) )
  JOIN BioLink..goa_association GOAA ON ( GOAX.ipi_accession = GOAA.ipi_accession AND GOAA.ref_db_tag = 'UniProt' )
 WHERE set_tag LIKE 'Hs_ENSP%'
   AND biosequence_name like 'ENSP000003457%'

SELECT TOP 1000 * FROM BioLink..goa_xref WHERE embl_ids like 'ENSP000003457%'

SELECT TOP 100 LEFT(embl_ids,15),* FROM BioLink..goa_xref WHERE embl_ids like 'ENSP0000034578%'
