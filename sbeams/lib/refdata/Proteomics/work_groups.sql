--$Id$
INSERT INTO work_group (record_status,sort_order,created_by_id,date_created,date_modified,primary_contact_id,work_group_name,comment,modified_by_id,owner_group_id)
VALUES ( 'N',10,2,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP,2,'Proteomics_user','Standard Proteomics user has access to some data tables',2,1);
INSERT INTO work_group (record_status,sort_order,created_by_id,date_created,date_modified,primary_contact_id,work_group_name,comment,modified_by_id,owner_group_id)
VALUES ( 'N',10,2,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP,2,'Proteomics_admin','Admin Proteomics user has full control over Proteomics infrastructure tables',2,1);
INSERT INTO work_group (record_status,sort_order,created_by_id,date_created,date_modified,primary_contact_id,work_group_name,comment,modified_by_id,owner_group_id)
VALUES ( 'N',10,2,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP,2,'Proteomics_readonly','Users in this group are permitted to view certain public experiments and possibly other specific experiments in a read-only fashion',2,1);
