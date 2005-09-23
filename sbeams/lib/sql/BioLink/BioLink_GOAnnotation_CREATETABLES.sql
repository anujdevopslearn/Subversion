-- $Id$


CREATE TABLE dbo.organism_namespace (
  organism_namespace_id       int IDENTITY NOT NULL,
  organism_namespace_tag      varchar(50) NOT NULL,
  organism_namespace_name     varchar(255) NOT NULL,
  PRIMARY KEY (organism_namespace_id)
)
GO

INSERT INTO organism_namespace (organism_namespace_tag,organism_namespace_name) VALUES ('FB','FlyBase')
INSERT INTO organism_namespace (organism_namespace_tag,organism_namespace_name) VALUES ('SGD','Yeast SGD')
INSERT INTO organism_namespace (organism_namespace_tag,organism_namespace_name) VALUES ('SPTR','SwissProt TRembl')
INSERT INTO organism_namespace (organism_namespace_tag,organism_namespace_name) VALUES ('HuIPI','Human IPI')
INSERT INTO organism_namespace (organism_namespace_tag,organism_namespace_name) VALUES ('UniProt','UniProt')
INSERT INTO organism_namespace (organism_namespace_tag,organism_namespace_name) VALUES ('TAIR','TAIR')
GO


CREATE TABLE dbo.annotated_gene (
  annotated_gene_id     int NOT NULL IDENTITY,
  gene_name             varchar(100) NULL,
  gene_accession        varchar(50) NOT NULL,
  organism_namespace_id    int NOT NULL REFERENCES organism_namespace(organism_namespace_id),
  biosequence_id        int NULL,
  biosequence_name      varchar(100) NULL,
  PRIMARY KEY (annotated_gene_id)
)
GO


CREATE TABLE dbo.external_reference_set (
  external_reference_set_id       int IDENTITY NOT NULL,
  external_reference_set_tag      varchar(50) NOT NULL,
  external_reference_set_name     varchar(255) NOT NULL,
  PRIMARY KEY (external_reference_set_id)
)
GO

INSERT INTO external_reference_set (external_reference_set_tag,external_reference_set_name) VALUES ('GO','Gene Ontology Database')
INSERT INTO external_reference_set (external_reference_set_tag,external_reference_set_name) VALUES ('InterPro','InterPro Protein Domain')
GO


CREATE TABLE dbo.gene_annotation_type (
  gene_annotation_type_id       int IDENTITY NOT NULL,
  gene_annotation_type_tag      varchar(50) NOT NULL,
  gene_annotation_type_code     char(1) NOT NULL,
  gene_annotation_type_name     varchar(255) NOT NULL,
  PRIMARY KEY (gene_annotation_type_id)
)
GO

INSERT INTO gene_annotation_type (gene_annotation_type_tag,gene_annotation_type_code,gene_annotation_type_name) VALUES ('molecular_function','F','Gene Ontology Molecular Function')
INSERT INTO gene_annotation_type (gene_annotation_type_tag,gene_annotation_type_code,gene_annotation_type_name) VALUES ('biological_process','P','Gene Ontology Biological Process')
INSERT INTO gene_annotation_type (gene_annotation_type_tag,gene_annotation_type_code,gene_annotation_type_name) VALUES ('cellular_component','C','Gene Ontology Cellular Component')
INSERT INTO gene_annotation_type (gene_annotation_type_tag,gene_annotation_type_code,gene_annotation_type_name) VALUES ('InterPro','I','InterPro Protein Domain')
GO


CREATE TABLE dbo.gene_annotation (
  gene_annotation_id    int NOT NULL IDENTITY,
  annotated_gene_id     int NOT NULL REFERENCES annotated_gene(annotated_gene_id),
  gene_annotation_type_id    int NOT NULL REFERENCES gene_annotation_type(gene_annotation_type_id),
  idx                   int NULL,
  is_summary            char(1) NOT NULL,
  annotation            varchar(4000) NULL,
  external_reference_set_id int NOT NULL REFERENCES external_reference_set(external_reference_set_id),
  external_accession    varchar(1000) NULL,
  annotation_source     varchar(255) NULL,
  source_string         varchar(1000) NULL,
  all_parent_annotation text NULL,
  all_parent_accession  text NULL,
  is_annotated          char(1),
  PRIMARY KEY (gene_annotation_id)
)
GO

