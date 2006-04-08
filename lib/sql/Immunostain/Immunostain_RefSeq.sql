/* The following creates a RefSeq reference table for the antibodies */
/* $Id */


/* SELECT from the LocusLink database to biosequence_refseq_association */
SELECT biosequence_name,biosequence_accession AS "LocusLinkID",
       MAX(protein) AS "best_RefSeqID",
       SUM(CASE WHEN protein IS NOT NULL THEN 1 ELSE 0 END) AS "n_matches"
  INTO biosequence_refseq_association
  FROM biosequence BS
  LEFT JOIN LocusLink.dbo.REFSEQ LLR
    ON ( BS.biosequence_accession = LLR.locus_id )
 GROUP BY biosequence_name,biosequence_accession
 ORDER BY biosequence_name,biosequence_accession

/* For cases where there is no RefSeq identifier, use LocusLink ID */
UPDATE biosequence_refseq_association
   SET best_RefSeqID = LocusLinkID
 WHERE best_RefSeqID IS NULL
