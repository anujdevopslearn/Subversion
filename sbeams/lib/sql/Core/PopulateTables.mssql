INSERT INTO contact_type ( name,is_standard,sort_order ) VALUES ( 'other','Y',100 )
GO
INSERT INTO contact_type ( name,is_standard ) VALUES ( 'investigator','Y' )
GO
INSERT INTO contact_type ( name,is_standard ) VALUES ( 'vendor','Y' )
GO
INSERT INTO contact_type ( name,is_standard ) VALUES ( 'academic_lab','Y' )
GO
INSERT INTO contact_type ( name,is_standard ) VALUES ( 'commercial_lab','Y' )
GO
INSERT INTO contact_type ( name,is_standard ) VALUES ( 'sales_rep','Y' )
GO
INSERT INTO contact_type ( name,is_standard ) VALUES ( 'technical_rep','Y' )
GO
INSERT INTO contact_type ( name,is_standard,sort_order ) VALUES ( 'data_producer','N',4 )
GO
INSERT INTO contact_type ( name,is_standard,sort_order ) VALUES ( 'data_curator','N',5 )
GO
INSERT INTO contact_type ( name,is_standard,sort_order ) VALUES ( 'lab_technician','N',5 )
GO



INSERT INTO privilege ( privilege_id,name,sort_order ) VALUES ( 10,'administrator',5 )
GO
INSERT INTO privilege ( privilege_id,name,sort_order ) VALUES ( 20,'data_modifier',4 )
GO
INSERT INTO privilege ( privilege_id,name,sort_order ) VALUES ( 25,'data_groupmodifier',3 )
GO
INSERT INTO privilege ( privilege_id,name,sort_order ) VALUES ( 30,'data_writer',2 )
GO
INSERT INTO privilege ( privilege_id,name,sort_order ) VALUES ( 40,'data_reader',1 )
GO
INSERT INTO privilege ( privilege_id,name,sort_order ) VALUES ( 50,'none',5 )
GO



INSERT INTO record_status ( record_status_id,name,sort_order ) VALUES ( 'N','Normal',1 )
GO
INSERT INTO record_status ( record_status_id,name,sort_order ) VALUES ( 'L','Locked',2 )
GO
INSERT INTO record_status ( record_status_id,name,sort_order ) VALUES ( 'M','Modifiable',3 )
GO
INSERT INTO record_status ( record_status_id,name,sort_order ) VALUES ( 'D','Deleted',4 )
GO


INSERT INTO work_group ( work_group_name,sort_order ) VALUES ( 'Admin',100 )
GO
INSERT INTO work_group ( work_group_name,sort_order ) VALUES ( 'Other',101 )
GO
INSERT INTO work_group ( work_group_name,sort_order ) VALUES ( 'Guest',99 )
GO


INSERT INTO organization ( organization,street,
  city,province_state,country,postal_code,phone,fax,email,
  uri,sort_order,created_by_id,modified_by_id )
  VALUES ( 'Institute for Systems Biology','1441 N 34th St','Seattle','WA',
  'USA','98103-8904','206-732-1200','206-732-1299','webmaster@systemsbiology.org',
  'http://www.systemsbiology.org/',5,1,1 )
GO

INSERT INTO organization ( organization,street,
  city,province_state,country,postal_code,phone,fax,email,
  uri,created_by_id,modified_by_id )
  VALUES ( 'UNKNOWN','','','',
  '','','','','',
  '',1,1 )
GO


INSERT INTO contact ( last_name,first_name,middle_name,contact_type_id,other_type,lab,department,
  organization_id,phone,fax,email,uri,
  created_by_id,modified_by_id )
  VALUES ( 'Administrator','SBEAMS','',8,NULL,NULL,'IT',
  1,NULL,NULL,'edeutsch@systemsbiology.org',
  'http://db.systemsbiology.net/',1,1 )
GO

INSERT INTO contact ( last_name,first_name,middle_name,contact_type_id,other_type,lab,department,
  organization_id,phone,fax,email,uri,
  created_by_id,modified_by_id )
  VALUES ( 'Deutsch','Eric','',8,NULL,NULL,'IT',
  1,'206-732-1397',NULL,'edeutsch@systemsbiology.org',
  'http://db.systemsbiology.net/~edeutsch/',1,1 )
GO



INSERT INTO user_login ( contact_id,username,password,privilege_id,
  created_by_id,modified_by_id )
  VALUES ( 1,'admin','cXFj4pxu1G4qY',10,1,1 )
GO

INSERT INTO user_login ( contact_id,username,password,privilege_id,
  created_by_id,modified_by_id )
  VALUES ( 2,'edeutsch','',20,1,1 )
GO



INSERT INTO user_work_group ( contact_id,work_group_id,privilege_id,created_by_id,modified_by_id )
  VALUES ( 1,1,10,1,1 )
GO
INSERT INTO user_work_group ( contact_id,work_group_id,privilege_id,created_by_id,modified_by_id )
  VALUES ( 2,1,20,1,1 )
GO
INSERT INTO user_work_group ( contact_id,work_group_id,privilege_id,created_by_id,modified_by_id )
  VALUES ( 2,3,20,1,1 )
GO



