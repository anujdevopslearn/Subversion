/*

This is the SBEAMS - Core set of tables.  Switch to the core database
and use this script to create the tables


SELECT * FROM sysobjects WHERE type='U'
SELECT 'DROP TABLE '+name FROM sysobjects WHERE type='U' ORDER BY crdate DESC

DROP TABLE misc_option
DROP TABLE table_group_security
DROP TABLE usage_log
DROP TABLE sql_command_log

DROP TABLE project

DROP TABLE user_context
DROP TABLE user_work_group
DROP TABLE user_login
DROP TABLE work_group
DROP TABLE record_status
DROP TABLE privilege
DROP TABLE contact
DROP TABLE contact_type
DROP TABLE organization

*/


CREATE TABLE dbo.organization (
	organization_id		int IDENTITY NOT NULL,
	organization		varchar(100) NULL,
	street			varchar(100) NULL,
	city			varchar(50) NULL,
	province_state		varchar(50) NULL,
	country			varchar(50) NULL,
	postal_code		varchar(25) NULL,
	phone			varchar(25) NULL,
	fax			varchar(25) NULL,
	email			varchar(100) NULL,
	uri			varchar(255) NULL,
	comment			varchar(255) NULL,
	sort_order		int NOT NULL DEFAULT 10,
	date_created		datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
	created_by_id		int NOT NULL /*REFERENCES contact(contact_id)*/,
	date_modified		datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
	modified_by_id		int NOT NULL /*REFERENCES contact(contact_id)*/,
	owner_group_id		int NOT NULL DEFAULT 1 /*REFERENCES work_group(work_group_id)*/,
	record_status		char(1) DEFAULT 'N',
	PRIMARY KEY CLUSTERED (organization_id)
)
GO



CREATE TABLE dbo.contact_type (
	contact_type_id		int IDENTITY NOT NULL,
	name			varchar(50),
	is_standard		char(1),
	comment			varchar(255) NULL,
	sort_order		int NOT NULL DEFAULT 10,
	date_created		datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
	created_by_id		int NOT NULL DEFAULT 1 /*REFERENCES contact(contact_id)*/,
	date_modified		datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
	modified_by_id		int NOT NULL DEFAULT 1 /*REFERENCES contact(contact_id)*/,
	owner_group_id		int NOT NULL DEFAULT 1 /*REFERENCES work_group(work_group_id)*/,
	record_status		char(1) DEFAULT 'N',
	PRIMARY KEY CLUSTERED (contact_type_id)
)
GO


CREATE TABLE dbo.contact (
	contact_id		int IDENTITY NOT NULL,
	last_name		varchar(50) NULL,
	first_name		varchar(50) NULL,
	middle_name		varchar(50) NULL,
	contact_type_id		int NOT NULL REFERENCES contact_type (contact_type_id),
	other_type		varchar(50) NULL,
	lab			varchar(50) NULL,
	department		varchar(50) NULL,
	organization_id		int NOT NULL REFERENCES organization (organization_id),
	phone			varchar(25) NULL,
	fax			varchar(25) NULL,
	email			varchar(100) NULL,
	uri			varchar(255) NULL,
	comment			varchar(255) NULL,
	date_created		datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
	created_by_id		int NOT NULL DEFAULT 1 /*REFERENCES contact(contact_id)*/,
	date_modified		datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
	modified_by_id		int NOT NULL DEFAULT 1 /*REFERENCES contact(contact_id)*/,
	owner_group_id		int NOT NULL DEFAULT 1 /*REFERENCES work_group(work_group_id)*/,
	record_status		char(1) DEFAULT 'N',
	PRIMARY KEY CLUSTERED (contact_id)
)
GO


CREATE TABLE dbo.privilege (
	privilege_id		int NOT NULL,
	name			varchar(50),
	comment			varchar(255) NULL,
	sort_order		int,
	date_created		datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
	created_by_id		int NOT NULL DEFAULT 1 /*REFERENCES contact(contact_id)*/,
	date_modified		datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
	modified_by_id		int NOT NULL DEFAULT 1 /*REFERENCES contact(contact_id)*/,
	owner_group_id		int NOT NULL DEFAULT 1 /*REFERENCES work_group(work_group_id)*/,
	record_status		char(1) DEFAULT 'N',
	PRIMARY KEY CLUSTERED (privilege_id)
)
GO


CREATE TABLE dbo.record_status (
	record_status_id	char(1) NOT NULL,
	name			varchar(50),
	comment			varchar(255) NULL,
	sort_order		int NOT NULL DEFAULT 10,
	date_created		datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
	created_by_id		int NOT NULL DEFAULT 1 /*REFERENCES contact(contact_id)*/,
	date_modified		datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
	modified_by_id		int NOT NULL DEFAULT 1 /*REFERENCES contact(contact_id)*/,
	owner_group_id		int NOT NULL DEFAULT 1 /*REFERENCES work_group(work_group_id)*/,
	record_status		char(1) DEFAULT 'N',
	PRIMARY KEY CLUSTERED (record_status_id)
)
GO


CREATE TABLE dbo.work_group (
	work_group_id		int IDENTITY NOT NULL,
	work_group_name		varchar(50) NOT NULL,
	primary_contact_id	int NULL /*REFERENCES contact(contact_id)*/,
	comment			varchar(255) NULL,
	sort_order		int NOT NULL DEFAULT 10,
	date_created		datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
	created_by_id		int NOT NULL DEFAULT 1 /*REFERENCES contact(contact_id)*/,
	date_modified		datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
	modified_by_id		int NOT NULL DEFAULT 1 /*REFERENCES contact(contact_id)*/,
	owner_group_id		int NOT NULL DEFAULT 1 /*REFERENCES work_group(work_group_id)*/,
	record_status		char(1) DEFAULT 'N',
	PRIMARY KEY CLUSTERED (work_group_id)
)
GO


CREATE TABLE dbo.user_login (
	user_login_id		int IDENTITY NOT NULL,
	contact_id		int NOT NULL REFERENCES contact (contact_id),
	username		varchar(50) NULL,
	password		varchar(50) NULL,
	privilege_id		int NOT NULL REFERENCES privilege(privilege_id),
	comment			varchar(255) NULL,
	date_created		datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
	created_by_id		int NOT NULL /*REFERENCES contact(contact_id)*/,
	date_modified		datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
	modified_by_id		int NOT NULL /*REFERENCES contact(contact_id)*/,
	owner_group_id		int NOT NULL DEFAULT 1 /*REFERENCES work_group(work_group_id)*/,
	record_status		char(1) DEFAULT 'N',
	PRIMARY KEY CLUSTERED (user_login_id)
)
GO


CREATE TABLE dbo.user_work_group (
	user_work_group_id	int IDENTITY NOT NULL,
	contact_id		int NOT NULL REFERENCES contact(contact_id),
	work_group_id		int NOT NULL REFERENCES work_group(work_group_id),
	privilege_id		int NOT NULL REFERENCES privilege(privilege_id),
	comment			varchar(255) NULL,
	date_created		datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
	created_by_id		int NOT NULL /*REFERENCES contact(contact_id)*/,
	date_modified		datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
	modified_by_id		int NOT NULL /*REFERENCES contact(contact_id)*/,
	owner_group_id		int NOT NULL DEFAULT 1 /*REFERENCES work_group(work_group_id)*/,
	record_status		char(1) DEFAULT 'N',
	PRIMARY KEY CLUSTERED (user_work_group_id)
)
GO


CREATE TABLE dbo.table_group_security (
	table_group_security_id	int IDENTITY NOT NULL,
	table_group		varchar(50) NOT NULL,
	work_group_id		int NOT NULL REFERENCES work_group(work_group_id),
	privilege_id		int NOT NULL REFERENCES privilege(privilege_id),
	comment			varchar(255) NULL,
	date_created		datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
	created_by_id		int NOT NULL /*REFERENCES contact(contact_id)*/,
	date_modified		datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
	modified_by_id		int NOT NULL /*REFERENCES contact(contact_id)*/,
	owner_group_id		int NOT NULL DEFAULT 1 /*REFERENCES work_group(work_group_id)*/,
	record_status		char(1) DEFAULT 'N'
)
GO


CREATE TABLE dbo.user_context (
	user_context_id		int IDENTITY NOT NULL,
	contact_id		int NOT NULL REFERENCES contact (contact_id),
	project_id		int NULL /*REFERENCES project (project_id)*/,
	work_group_id		int NULL /*REFERENCES work_group(work_group_id)*/,
	privilege_id		int NULL /*REFERENCES privilege(privilege_id)*/,
	comment			varchar(255) NULL,
	date_created		datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
	created_by_id		int NOT NULL /*REFERENCES contact(contact_id)*/,
	date_modified		datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
	modified_by_id		int NOT NULL /*REFERENCES contact(contact_id)*/,
	owner_group_id		int NOT NULL DEFAULT 1 /*REFERENCES work_group(work_group_id)*/,
	record_status		char(1) DEFAULT 'N',
	PRIMARY KEY CLUSTERED (user_context_id)
)
GO


CREATE TABLE dbo.sql_command_log (
	command_id		int IDENTITY NOT NULL,
	date_created		datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
	created_by_id		int NOT NULL /*REFERENCES contact(contact_id)*/,
	result			varchar(25) NOT NULL ,
	sql_command		varchar(7000) NOT NULL
)
GO


CREATE TABLE dbo.usage_log (
	usage_id		int IDENTITY NOT NULL,
	date_created		datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
	username		varchar(50) NULL,
	usage_action		varchar(50) NOT NULL,
	result			varchar(25) NOT NULL
)
GO


CREATE TABLE dbo.misc_option (
	misc_option_id		int IDENTITY NOT NULL,
	option_type		varchar(25),
	option_key		varchar(25),
	option_value		varchar(255),
	sort_order		int NOT NULL DEFAULT 10,
	date_created		datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
	PRIMARY KEY CLUSTERED (misc_option_id)
)
GO


CREATE TABLE dbo.project (
	project_id		int IDENTITY(101,1) NOT NULL,
	name			varchar(100) NOT NULL,
	PI_contact_id		int NOT NULL REFERENCES contact(contact_id),
	description		text NULL,
	budget			varchar(25) NOT NULL,
	project_status		varchar(100) NOT NULL,
	uri			varchar(255) NOT NULL,
	comment			varchar(255) NULL,
	date_created		datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
	created_by_id		int NOT NULL /*REFERENCES contact(contact_id)*/,
	date_modified		datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
	modified_by_id		int NOT NULL /*REFERENCES contact(contact_id)*/,
	owner_group_id		int NOT NULL DEFAULT 1 /*REFERENCES work_group(work_group_id)*/,
	record_status		char(1) NOT NULL DEFAULT 'N',
	PRIMARY KEY CLUSTERED (project_id)
)
GO


CREATE TABLE dbo.help_text (
	help_text_id		int IDENTITY NOT NULL,
	title			varchar(255) NULL,
	help_text		text NULL,
	date_created		datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
	created_by_id		int NOT NULL /*REFERENCES contact(contact_id)*/,
	date_modified		datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
	modified_by_id		int NOT NULL /*REFERENCES contact(contact_id)*/,
	owner_group_id		int NOT NULL DEFAULT 1 /*REFERENCES work_group(work_group_id)*/,
	record_status		char(1) DEFAULT 'N',
	PRIMARY KEY CLUSTERED (help_text_id)
)
GO




--======================================================================

/*

To ADD all the constraints:

ALTER TABLE dbo.organization ADD CONSTRAINT fk_organization_created_by_id FOREIGN KEY (created_by_id) REFERENCES dbo.contact(contact_id)
ALTER TABLE dbo.organization ADD CONSTRAINT fk_organization_modified_by_id FOREIGN KEY (modified_by_id) REFERENCES dbo.contact(contact_id)


To DROP all the CONSTRAINTS:

ALTER TABLE dbo.organization DROP CONSTRAINT fk_organization_created_by_id
ALTER TABLE dbo.organization DROP CONSTRAINT fk_organization_modified_by_id

*/


