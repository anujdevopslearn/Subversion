
/*

SELECT * FROM sysobjects WHERE type='U'
SELECT 'DROP TABLE dbo.'+name FROM sysobjects WHERE type='U' ORDER BY crdate DESC

DROP TABLE dbo.allele_frequency
DROP TABLE dbo.allele_blast_stats
DROP TABLE dbo.allele
DROP TABLE dbo.snp_instance
DROP TABLE dbo.snp

DO NOT:
DROP TABLE dbo.source_version
DROP TABLE dbo.snp_source
DROP TABLE dbo.query_sequence
DROP TABLE dbo.biosequence
DROP TABLE dbo.biosequence_set
DROP TABLE dbo.query_option

*/




CREATE TABLE dbo.biosequence_set (
    biosequence_set_id        int IDENTITY NOT NULL,
    species_id                int NOT NULL REFERENCES organism(organism_id),
    set_name                  varchar(100) NOT NULL,
    set_tag                   varchar(100) NOT NULL,
    set_description           varchar(255) NOT NULL,
    set_version               varchar(255) NOT NULL,
    upload_file               varchar(255) NULL,
    set_path                  varchar(255) NULL,
    uri                       varchar(255) NULL,
    comment                   text NULL,
    sort_order                int NOT NULL DEFAULT 10,
    date_created              datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_id             int NOT NULL DEFAULT 1 REFERENCES dbo.contact(contact_id),
    date_modified             datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    modified_by_id            int NOT NULL DEFAULT 1 REFERENCES dbo.contact(contact_id),
    owner_group_id            int NOT NULL DEFAULT 1 REFERENCES dbo.work_group(work_group_id),
    record_status             char(1) DEFAULT 'N',
    PRIMARY KEY (biosequence_set_id)
)
GO


CREATE TABLE dbo.biosequence (
    biosequence_id            int IDENTITY NOT NULL,
    biosequence_set_id        int NOT NULL REFERENCES dbo.biosequence_set(biosequence_set_id),
    biosequence_name          varchar(255) NOT NULL,
    biosequence_gene_name     varchar(255) NULL,
    biosequence_accession     varchar(255) NULL,
    biosequence_desc          varchar(1024) NOT NULL,
    biosequence_seq           text NULL,
    PRIMARY KEY (biosequence_id)
)
GO

CREATE TABLE dbo.query_sequence (
    query_sequence_id         int IDENTITY NOT NULL,
    query_sequence            varchar(900) NOT NULL,
    PRIMARY KEY (query_sequence_id)
)
GO

CREATE TABLE dbo.snp_source (
    snp_source_id             int IDENTITY NOT NULL,
    source_name               varchar(25),
    orig_source_name          varchar(25),
    uri                       varchar(255) NULL,
    comment                   text NULL,
    sort_order                int NOT NULL DEFAULT 10,
    date_created              datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_id             int NOT NULL DEFAULT 1 REFERENCES dbo.contact(contact_id),
    date_modified             datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    modified_by_id            int NOT NULL DEFAULT 1 REFERENCES dbo.contact(contact_id),
    owner_group_id            int NOT NULL DEFAULT 1 REFERENCES dbo.work_group(work_group_id),
    record_status             char(1) DEFAULT 'N',
    PRIMARY KEY (snp_source_id)
)
GO


CREATE TABLE dbo.source_version (
    source_version_id         int IDENTITY NOT NULL,
    source_version_name       varchar(255),
    uri                       varchar(255) NULL,
    comment                   text NULL,
    sort_order                int NOT NULL DEFAULT 10,
    date_created              datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_id             int NOT NULL DEFAULT 1 /*REFERENCES dbo.contact(contact_id)*/,
    date_modified             datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    modified_by_id            int NOT NULL DEFAULT 1 /*REFERENCES dbo.contact(contact_id)*/,
    owner_group_id            int NOT NULL DEFAULT 1 /*REFERENCES dbo.work_group(work_group_id)*/,
    record_status             char(1) DEFAULT 'N',
    PRIMARY KEY (source_version_id)
)
GO


CREATE TABLE dbo.snp (
    snp_id                    int IDENTITY NOT NULL,
    dbSNP_accession           varchar(100),
    celera_accession          varchar(100),
    hgbase_accession          varchar(100),
    hgmd_accession            varchar(100),
    obsoleted_by_snp_id       int NULL REFERENCES dbo.snp(snp_id),
    is_useful                 char(1),
    celera_only               char(1),
    comment                   text NULL,
    date_created              datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by_id             int NOT NULL DEFAULT 1 /*REFERENCES dbo.contact(contact_id)*/,
    date_modified             datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    modified_by_id            int NOT NULL DEFAULT 1 /*REFERENCES dbo.contact(contact_id)*/,
    owner_group_id            int NOT NULL DEFAULT 1 /*REFERENCES dbo.work_group(work_group_id)*/,
    record_status             char(1) DEFAULT 'N',
    PRIMARY KEY (snp_id)
)
GO

CREATE TABLE dbo.snp_instance (
    snp_instance_id                int IDENTITY NOT NULL,				     
    snp_id                         int NOT NULL REFERENCES dbo.snp(snp_id),	     
    snp_accession                  varchar(100),					     
    snp_source_id                  int REFERENCES dbo.snp_source(snp_source_id),	     
    source_version_id              int REFERENCES dbo.source_version(source_version_id),
    snp_instance_source_accession  varchar(100),
    fiveprime_length               int,	     
    threeprime_length              int,	     
    fiveprime_sequence             text NULL,   
    threeprime_sequence            text NULL,   
    trimmed_fiveprime_length       int,	     
    trimmed_threeprime_length      int,	     
    trimmed_fiveprime_sequence     text NULL,   
    trimmed_threeprime_sequence    text NULL,   
    orientation                    int,	     
    allele_string                  varchar(100),
    method	                   varchar(100),
    total_chrom_count	           int,
    validation_status              varchar(100),
    PRIMARY KEY (snp_instance_id)
)
GO

CREATE TABLE dbo.allele (
    allele_id                 int IDENTITY NOT NULL,
    snp_instance_id           int NOT NULL REFERENCES dbo.snp_instance(snp_instance_id),
    query_sequence_id         int REFERENCES dbo.query_sequence(query_sequence_id),
    allele                    varchar(25),
    PRIMARY KEY (allele_id)
)
GO

CREATE TABLE dbo.allele_frequency (
    allele_id                 int NOT NULL REFERENCES dbo.allele(allele_id),
    population_tag            varchar(100),
    frequency                 real,
    chromosome_count          int,
    idx                       int
)
GO

CREATE TABLE dbo.allele_blast_stats (
    query_sequence_id         int NOT NULL REFERENCES dbo.query_sequence(query_sequence_id),
    matched_biosequence_id    int NOT NULL REFERENCES dbo.biosequence(biosequence_id),
    score                     int,
    identified_percent        float,
    evalue                    float,
    match_length              int,
    positives                 int,
    hsp_length                int,
    query_length              int,
    query_sequence            text,
    matched_sequence          text,
    query_start               int,
    query_end                 int,
    match_start               int,
    match_end                 int,
    strand                    int,
    end_fiveprime_position    int
)
GO


----------------------------------------------------------------------------

--DROP TABLE dbo.query_option
CREATE TABLE dbo.query_option (
	query_option_id		int IDENTITY NOT NULL,
	option_type		varchar(255) NOT NULL,
	option_key		varchar(255) NOT NULL,
	option_value		varchar(255) NOT NULL,
	sort_order		int NOT NULL DEFAULT 10,
	date_created		datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
	created_by_id		int NOT NULL DEFAULT 1 /*REFERENCES contact(contact_id)*/,
	date_modified		datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
	modified_by_id		int NOT NULL DEFAULT 1 /*REFERENCES contact(contact_id)*/,
	owner_group_id		int NOT NULL DEFAULT 1 /*REFERENCES work_group(work_group_id)*/,
	record_status		char(1) DEFAULT 'N',
	PRIMARY KEY CLUSTERED (query_option_id)
)
GO


INSERT INTO query_option ( option_type,option_key,option_value,sort_order )
VALUES ( 'BBS_display_options','MaxSeqWidth','Limit Sequence Width',50 )
INSERT INTO query_option ( option_type,option_key,option_value,sort_order )
VALUES ( 'BBS_display_options','ShowSQL','Show SQL Query',60 )

INSERT INTO query_option ( option_type,option_key,option_value,sort_order )
VALUES ( 'BBS_sort_options','biosequence_name','biosequence_name',10 )



----------------------------------------------------------------------------

/*
DROP INDEX biosequence.idx_biosequence_name

CREATE NONCLUSTERED INDEX idx_biosequence_name ON dbo.biosequence ( biosequence_set_id,biosequence_name )
*/

