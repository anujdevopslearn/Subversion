
TRUNCATE TABLE Genotyping..query_option

SELECT * FROM SNP..query_option

INSERT INTO Genotyping..query_option ( option_type,option_key,option_value,sort_order,date_created,created_by_id,date_modified,modified_by_id,owner_group_id,record_status  )
SELECT option_type,option_key,option_value,sort_order,date_created,created_by_id,date_modified,modified_by_id,owner_group_id,record_status FROM SNP..query_option

INSERT INTO Genotyping..query_option ( option_type,option_key,option_value,sort_order )
VALUES ( 'approval_status','Pending','Pending',50 )

INSERT INTO Genotyping..query_option ( option_type,option_key,option_value,sort_order )
VALUES ( 'approval_status','Approved','Approved',60 )

INSERT INTO Genotyping..query_option ( option_type,option_key,option_value,sort_order )
VALUES ( 'approval_status','Failed','Failed',70 )


-- The below is wrong.

INSERT INTO query_option ( option_type,option_key,option_value,sort_order )
VALUES ( 'GG_display_options','PlainView','Plain View',50 )

INSERT INTO query_option ( option_type,option_key,option_value,sort_order )
VALUES ( 'GG_display_options','SampleVsAssay','Sample vs Assay',60 )

INSERT INTO query_option ( option_type,option_key,option_value,sort_order )
VALUES ( 'GG_display_options','AssayVsSample','Assay vs Sample',70 )

INSERT INTO query_option ( option_type,option_key,option_value,sort_order )
VALUES ( 'GG_display_options','SampleVsRepeat','Sample vs Repeat',80 )

INSERT INTO query_option ( option_type,option_key,option_value,sort_order )
VALUES ( 'GG_display_options','ConcannonReorder','Concannon Reordering',90 )

INSERT INTO query_option ( option_type,option_key,option_value,sort_order )
VALUES ( 'GG_display_options','ShowSQL','Show SQL Query',100 )
