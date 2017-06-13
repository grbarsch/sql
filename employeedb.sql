IF OBJECT_ID('tempdb..#EMPLOYEE') IS NOT NULL DROP TABLE #EMPLOYEE
IF OBJECT_ID('tempdb..#TITLES') IS NOT NULL DROP TABLE #TITLES
IF OBJECT_ID('tempdb..#CONTACTS') IS NOT NULL DROP TABLE #CONTACTS
IF OBJECT_ID('tempdb..#DEPARTMENT') IS NOT NULL DROP TABLE #DEPARTMENT
IF OBJECT_ID('tempdb..#ENTRIES') IS NOT NULL DROP TABLE #ENTRIES
IF OBJECT_ID('tempdb..#ALIASES') IS NOT NULL DROP TABLE #ALIASES
IF OBJECT_ID('tempdb..#CONTACTTYPES') IS NOT NULL DROP TABLE #CONTACTTYPES

/*Base Employee*/
SELECT
    IDENTITY(INT, 1, 1) as employeeId,
    emp.id oldId,
    emp.LOC_ID locationId,
    emp.MANAGERID managerId,
    CAST(emp.BUSINESSPHONE as bigint) phone, 
    CAST(emp.MOBILE as bigint) mobile, 
    CAST(emp.ONC_ESC_PRIM as bigint) esc1,
    CAST(emp.ONC_ESC_ALT1 as bigint) esc2,
    CAST(emp.ONC_ESC_ALT2 as bigint) esc3,
    UPPER(LEFT(emp.FIRST_NAME,1))+LOWER(SUBSTRING(emp.FIRST_NAME,2,LEN(emp.FIRST_NAME))) firstName,
    UPPER(LEFT(emp.LAST_NAME,1))+LOWER(SUBSTRING(emp.LAST_NAME,2,LEN(emp.LAST_NAME))) lastName,
    UPPER(LEFT(emp.ALIAS,1))+LOWER(SUBSTRING(emp.ALIAS,2,LEN(emp.ALIAS))) alias,
    emp.ANNIVERSARY anniversary,
    LOWER(samaccountname) username,
    emp.TITLE title,
    dept.DPTNMBR departmentNumber,
    dept.NAME departmentName,
    ceridianId ceridianId,
    mail,
    CAST(ad.objectGUID as UNIQUEIDENTIFIER) objectGUID
INTO
    #EMPLOYEE
FROM 
    ORACLE_OLTPPROD_EOSDBA..GRANDEWEB.EMPLOYEE emp
    LEFT OUTER JOIN ORACLE_OLTPPROD_EOSDBA..GRANDEWEB.DEPARTMENT dept on emp.DEPT_ID = dept.ID
    LEFT OUTER JOIN (
        SELECT
            employeeId, 
            samaccountname,
            objectGUID,
            LOWER(mail) mail
        FROM OPENQUERY (ADSI, '<LDAP://SRV-SAM-DC01.lan.thrifty.net/OU=GrandeUsers,DC=lan,DC=thrifty,DC=net>;(&(objectCategory=person)(objectClass=user)(!userAccountControl:1.2.840.113556.1.4.803:=2));employeeid, givenname, sn, sAMAccountName, objectGUID, mail, telephonenumber ;onelevel')
    ) ad on emp.ceridianId = ad.employeeId

WHERE
    emp.status = 'A'
    AND emp.CERIDIANID IS NOT NULL
    AND CHARINDEX('Contractor', emp.TITLE) = 0

SELECT
    IDENTITY(INT, 1, 1) as titleId,
    title
INTO
    #TITLES
FROM (
    SELECT  
        DISTINCT
        title
    FROM 
        #EMPLOYEE
) EMP

SELECT
    IDENTITY(INT, 1, 1) as departmentId,
    departmentNumber, 
    departmentName
INTO
    #DEPARTMENT
FROM
(
    SELECT DISTINCT departmentNumber, departmentName FROM #EMPLOYEE WHERE objectGUID IS NOT NULL
) DEPT

SELECT
    IDENTITY(INT, 1, 1) as contactId,
    EMP.employeeId, 
    AA.contact, 
    AA.contactTypeId
INTO #CONTACTS
FROM (
SELECT oldId, phone contact, 1 contactTypeId FROM #EMPLOYEE WHERE phone is not null and phone !=0
UNION ALL
SELECT oldId, mobile contact, 2 contactTypeId FROM #EMPLOYEE WHERE mobile IS NOT NULL AND mobile !=0
UNION ALL
SELECT oldId, esc1 contact, 3 contactTypeId FROM #EMPLOYEE WHERE esc1 IS NOT NULL AND esc1 !=0
UNION ALL
SELECT oldId, esc2 contact, 4 contactTypeId FROM #EMPLOYEE WHERE esc2 IS NOT NULL AND esc2 !=0
UNION ALL
SELECT oldId, esc3 contact, 5 contactTypeId FROM #EMPLOYEE WHERE esc3 IS NOT NULL AND esc3 !=0
) AA  
INNER JOIN #EMPLOYEE EMP on AA.oldId = EMP.oldId
WHERE LEN(CAST(contact as VARCHAR(10))) = 10

SELECT
    IDENTITY(INT, 1, 1) as contactTypeId,
    contactType
INTO
    #CONTACTTYPES
FROM (
    SELECT 1 contactTypeId, 'Primary Phone' contactType
    UNION ALL
    SELECT 2 contactTypeId, 'Mobile Phone' contactType
    UNION ALL
    SELECT 3 contactTypeId, 'Escalation 1' contactType
    UNION ALL
    SELECT 4 contactTypeId, 'Escalation 2' contactType
    UNION ALL
    SELECT 5 contactTypeId, 'Escalation 3' contactType
) AA  

SELECT
    IDENTITY(INT, 1, 1) as entryId,
    empId employeeId,
    anniversary entryDate, 
    1 entryType
INTO
    #ENTRIES
    
FROM
    (SELECT CAST(employeeId as bigint) empId, anniversary FROM #EMPLOYEE) AA

SELECT
    IDENTITY(INT, 1, 1) as userId,
    empId employeeId, 
    username, 
    objectGUID
INTO
    #USERS
FROM
(
    SELECT
        CAST (employeeId as BIGINT) empid, 
        username, 
        objectGUID
    FROM
        #EMPLOYEE
    WHERE
        username IS NOT NULL
) AA

SELECT IDENTITY(INT, 1, 1) as aliasId, alias, oldId INTO #ALIASES FROM #EMPLOYEE WHERE alias IS NOT NULL


SELECT EMP.employeeId, EMP.oldId 
INTO #MANAGERS
FROM (
    SELECT 
        DISTINCT 
        managerId
    FROM 
        #EMPLOYEE
) AA
INNER JOIN #EMPLOYEE EMP on AA.managerId = EMP.oldId

SELECT
    EMP.employeeId,
    ALI.alias,
    EMP.firstName,
    EMP.lastName,
    EMP.mail,
    1 organizationId,
    TTL.titleId,
    TTL.title,
    DPT.departmentId, 
    DPT.departmentNumber,
    DPT.departmentName,
    PHN.contact primaryPhone,
    MOB.contact cellphone,
    ES1.contact escalation1,
    ES2.contact escalation2,
    ES3.contact escalation3,
    USR.username,   
    USR.objectGUID,
    MGR.employeeId managerId,
    CASE WHEN MGRD.employeeId IS NULL THEN NULL ELSE CONCAT(MGRD.lastName, ', ', MGRD.firstName) END managerName,
    ENT.entryDate hireDate
FROM
    #EMPLOYEE EMP
    INNER JOIN #TITLES TTL ON EMP.title = TTL.title
    INNER JOIN #DEPARTMENT DPT ON EMP.departmentNumber = DPT.departmentNumber
    LEFT OUTER JOIN #USERS USR ON EMP.employeeId = USR.employeeId
    LEFT OUTER JOIN #MANAGERS MGR on EMP.managerId = MGR.oldId
    LEFT OUTER JOIN #EMPLOYEE MGRD on MGR.employeeId = MGRD.employeeId
    LEFT OUTER JOIN #ALIASES ALI ON EMP.oldId = ALI.oldId
    LEFT OUTER JOIN #CONTACTS PHN on EMP.employeeId = PHN.employeeId AND PHN.contactTypeId = 1
    LEFT OUTER JOIN #CONTACTS MOB on EMP.employeeId = MOB.employeeId AND MOB.contactTypeId = 2
    LEFT OUTER JOIN #CONTACTS ES1 on EMP.employeeId = ES1.employeeId AND ES1.contactTypeId = 3
    LEFT OUTER JOIN #CONTACTS ES2 on EMP.employeeId = ES2.employeeId AND ES2.contactTypeId = 4
    LEFT OUTER JOIN #CONTACTS ES3 on EMP.employeeId = ES3.employeeId AND ES3.contactTypeId = 5
    LEFT OUTER JOIN #ENTRIES ENT on EMP.employeeId = ENT.employeeId AND ENT.entryType = 1
WHERE
    EMP.objectGUID IS NOT NULL

SELECT
    EMP.employeeId,
    EMP.firstName,
    EMP.lastName,
    EMP.mail,
    1 organizationId,
    TTL.titleId,
    DPT.departmentId, 
    MGR.employeeId managerId
FROM
    #EMPLOYEE EMP
    INNER JOIN #TITLES TTL ON EMP.title = TTL.title
    INNER JOIN #DEPARTMENT DPT ON EMP.departmentNumber = DPT.departmentNumber
    LEFT OUTER JOIN #USERS USR ON EMP.employeeId = USR.employeeId
    LEFT OUTER JOIN #MANAGERS MGR on EMP.managerId = MGR.oldId
    LEFT OUTER JOIN #EMPLOYEE MGRD on MGR.employeeId = MGRD.employeeId
    LEFT OUTER JOIN #ALIASES ALI ON EMP.oldId = ALI.oldId
    LEFT OUTER JOIN #CONTACTS PHN on EMP.employeeId = PHN.employeeId AND PHN.contactTypeId = 1
    LEFT OUTER JOIN #CONTACTS MOB on EMP.employeeId = MOB.employeeId AND MOB.contactTypeId = 2
    LEFT OUTER JOIN #CONTACTS ES1 on EMP.employeeId = ES1.employeeId AND ES1.contactTypeId = 3
    LEFT OUTER JOIN #CONTACTS ES2 on EMP.employeeId = ES2.employeeId AND ES2.contactTypeId = 4
    LEFT OUTER JOIN #CONTACTS ES3 on EMP.employeeId = ES3.employeeId AND ES3.contactTypeId = 5
    LEFT OUTER JOIN #ENTRIES ENT on EMP.employeeId = ENT.employeeId AND ENT.entryType = 1
WHERE
    EMP.objectGUID IS NOT NULL








//-------------------------------


DROP TABLE EMPDB.T_EMPLOYEE
DROP TABLE EMPDB.T_TITLE
DROP TABLE EMPDB.T_USER
DROP TABLE EMPDB.T_DEPARTMENT
DROP TABLE EMPDB.T_ALIAS
DROP TABLE EMPDB.T_CONTACT
DROP TABLE EMPDB.T_ENTRY


CREATE TABLE [EMPDB].[T_EMPLOYEE]  ( 
	[employeeId]    	bigint NOT NULL IDENTITY(1,1),
	[firstName]     	varchar(21) NULL,
	[lastName]      	varchar(21) NULL,
	[mail]          	nvarchar(4000) NULL,
	[organizationId]	int NOT NULL,
	[titleId]       	int NOT NULL,
	[departmentId]  	int NOT NULL,
	[managerId]     	int NULL,
    CONSTRAINT [PK_EMPLOYEE#employeeId] PRIMARY KEY NONCLUSTERED([employeeId])
)
GO



CREATE TABLE [EMPDB].[T_TITLE]  ( 
	[titleId]	bigint NOT NULL IDENTITY(1,1),
	[title]  	varchar(50) NULL ,
    CONSTRAINT [PK_TITLE#titleId] PRIMARY KEY NONCLUSTERED([titleId])
)
GO



CREATE TABLE [EMPDB].[T_USER]  ( 
	[userId]    	bigint IDENTITY(1,1) NOT NULL,
	[employeeId]	bigint NULL,
	[username]  	nvarchar(4000) NULL,
	[objectGUID]	uniqueidentifier NULL,
    CONSTRAINT [PK_USER#userId] PRIMARY KEY NONCLUSTERED([userId]) 
)
GO



CREATE TABLE [EMPDB].[T_DEPARTMENT]  ( 
	[departmentId]    	int IDENTITY(1,1) NOT NULL,
	[departmentNumber]	varchar(7) NULL,
	[departmentName]  	varchar(40) NULL,
    CONSTRAINT [PK_DEPARTMENT#departmentId] PRIMARY KEY NONCLUSTERED([departmentId])  
)
GO



CREATE TABLE [EMPDB].[T_ALIAS]  ( 
	[aliasId]	int IDENTITY(1,1) NOT NULL,
    [employeeId] bigint NOT NULL,
	[alias]  	varchar(1000) NULL,
    CONSTRAINT [PK_ALIAS#aliasId] PRIMARY KEY NONCLUSTERED([aliasId])  
)
GO



CREATE TABLE [EMPDB].[T_CONTACT]  ( 
	[contactId]    	bigint IDENTITY(1,1) NOT NULL,
	[employeeId]   	bigint NOT NULL,
	[contact]      	varchar(10) NULL,
	[contactTypeId]	bigint NOT NULL,
    CONSTRAINT [PK_CONTACT#contactId] PRIMARY KEY NONCLUSTERED([contactId])  
)
GO

CREATE TABLE [EMPDB].[T_ENTRY]  ( 
	[entryId]   	int IDENTITY(1,1) NOT NULL,
	[employeeId]	bigint NULL,
	[entryDate] 	datetime NULL,
	[entryType] 	int NOT NULL,
    CONSTRAINT [PK_ENTRY#entryId] PRIMARY KEY NONCLUSTERED([entryId])   
)
GO

CREATE TABLE [EMPDB].[T_ORGANIZATION]  ( 
	[organizationId]   	int IDENTITY(1,1) NOT NULL,
	[organization] 	varchar(1000) NOT NULL,
    CONSTRAINT [PK_ORGANIZATION#organizationId] PRIMARY KEY NONCLUSTERED([organizationId])   
)
GO

SET IDENTITY_INSERT EMPDB.T_EMPLOYEE ON

INSERT INTO [EMPDB].[T_EMPLOYEE]([employeeId], [firstName], [lastName], [mail], [organizationId], [titleId], [departmentId], [managerId]) 
SELECT
    EMP.employeeId,
    EMP.firstName,
    EMP.lastName,
    EMP.mail,
    1 organizationId,
    TTL.titleId,
    DPT.departmentId, 
    MGR.employeeId managerId
FROM
    #EMPLOYEE EMP
    INNER JOIN #TITLES TTL ON EMP.title = TTL.title
    INNER JOIN #DEPARTMENT DPT ON EMP.departmentNumber = DPT.departmentNumber
    LEFT OUTER JOIN #USERS USR ON EMP.employeeId = USR.employeeId
    LEFT OUTER JOIN #MANAGERS MGR on EMP.managerId = MGR.oldId
    LEFT OUTER JOIN #EMPLOYEE MGRD on MGR.employeeId = MGRD.employeeId
    LEFT OUTER JOIN #ALIASES ALI ON EMP.oldId = ALI.oldId
    LEFT OUTER JOIN #CONTACTS PHN on EMP.employeeId = PHN.employeeId AND PHN.contactTypeId = 1
    LEFT OUTER JOIN #CONTACTS MOB on EMP.employeeId = MOB.employeeId AND MOB.contactTypeId = 2
    LEFT OUTER JOIN #CONTACTS ES1 on EMP.employeeId = ES1.employeeId AND ES1.contactTypeId = 3
    LEFT OUTER JOIN #CONTACTS ES2 on EMP.employeeId = ES2.employeeId AND ES2.contactTypeId = 4
    LEFT OUTER JOIN #CONTACTS ES3 on EMP.employeeId = ES3.employeeId AND ES3.contactTypeId = 5
    LEFT OUTER JOIN #ENTRIES ENT on EMP.employeeId = ENT.employeeId AND ENT.entryType = 1
WHERE
    EMP.objectGUID IS NOT NULL
SET IDENTITY_INSERT EMPDB.T_EMPLOYEE OFF

SET IDENTITY_INSERT EMPDB.T_DEPARTMENT ON
INSERT INTO [EMPDB].[T_DEPARTMENT]([departmentId], [departmentNumber], [departmentName]) 
SELECT * 
FROM 
    #DEPARTMENT
SET IDENTITY_INSERT EMPDB.T_DEPARTMENT OFF


SET IDENTITY_INSERT EMPDB.T_TITLE ON
INSERT INTO [EMPDB].[T_TITLE]([titleId], [title]) 

SELECT * 
FROM 
    #TITLES
SET IDENTITY_INSERT EMPDB.T_TITLE OFF

SET IDENTITY_INSERT EMPDB.T_USER ON
INSERT INTO [EMPDB].[T_USER]([userId], [employeeId], [username], [objectGUID]) 

SELECT * 
FROM 
    #USERS

SET IDENTITY_INSERT EMPDB.T_USER OFF

SET IDENTITY_INSERT EMPDB.T_ALIAS ON
INSERT INTO [EMPDB].[T_ALIAS]([aliasId], [employeeId], [alias]) 

SELECT 
    ALI.aliasId, 
    EMP.employeeId,
    ALI.alias
FROM 
    #ALIASES ALI
    INNER JOIN #EMPLOYEE EMP on ALI.oldId = EMP.oldId
SET IDENTITY_INSERT EMPDB.T_ALIAS OFF

SET IDENTITY_INSERT EMPDB.T_ENTRY ON

INSERT INTO [EMPDB].[T_ENTRY]([entryId], [employeeId], [entryDate], [entryType]) 
SELECT * 
FROM 
    #ENTRIES

SET IDENTITY_INSERT EMPDB.T_ENTRY OFF


SET IDENTITY_INSERT EMPDB.T_CONTACT ON

INSERT INTO [EMPDB].[T_CONTACT]([contactId], [employeeId], [contact], [contactTypeId]) 
SELECT 
    *
FROM 
    #CONTACTS
SET IDENTITY_INSERT EMPDB.T_CONTACT OFF

SELECT
    EMP.employeeId,
    ISNULL(DR.directReportCount, 0) directReportCount,
    ALI.alias,
    EMP.firstName,
    EMP.lastName,
    EMP.mail,
    EMP.organizationId,
    ORG.organization,
    TTL.titleId,
    TTL.title,
    DPT.departmentId, 
    DPT.departmentNumber,
    DPT.departmentName,
    PHN.contact primaryPhone,
    MOB.contact cellphone,
    ES1.contact escalation1,
    ES2.contact escalation2,
    ES3.contact escalation3,
    USR.username,   
    USR.objectGUID,
    MGR.employeeId managerId,
    CASE WHEN MGR.employeeId IS NULL THEN NULL ELSE CONCAT(MGR.lastName, ', ', MGR.firstName) END managerName,
    ENT.entryDate hireDate
FROM 
    EMPDB.T_EMPLOYEE EMP
    INNER JOIN EMPDB.T_TITLE TTL ON EMP.titleId = TTL.titleId
    INNER JOIN EMPDB.T_DEPARTMENT DPT on EMP.departmentId = DPT.departmentId
    LEFT OUTER JOIN EMPDB.T_EMPLOYEE MGR on EMP.managerId = MGR.employeeId
    LEFT OUTER JOIN (
        SELECT
            managerId,
            COUNT(*) directReportCount
        FROM
           EMPDB.T_EMPLOYEE MGR 
        GROUP BY
            managerId
            
    ) DR on EMP.employeeId = DR.managerId
    LEFT OUTER JOIN EMPDB.T_ALIAS ALI ON EMP.employeeId = ALI.employeeId
    LEFT OUTER JOIN EMPDB.T_CONTACT PHN on EMP.employeeId = PHN.employeeId AND PHN.contactTypeId = 1
    LEFT OUTER JOIN EMPDB.T_CONTACT MOB on EMP.employeeId = MOB.employeeId AND MOB.contactTypeId = 2
    LEFT OUTER JOIN EMPDB.T_CONTACT ES1 on EMP.employeeId = ES1.employeeId AND ES1.contactTypeId = 3
    LEFT OUTER JOIN EMPDB.T_CONTACT ES2 on EMP.employeeId = ES2.employeeId AND ES2.contactTypeId = 4
    LEFT OUTER JOIN EMPDB.T_CONTACT ES3 on EMP.employeeId = ES3.employeeId AND ES3.contactTypeId = 5
    LEFT OUTER JOIN EMPDB.T_USER USR ON EMP.employeeId = USR.employeeId
    LEFT OUTER JOIN EMPDB.T_ENTRY ENT on EMP.employeeId = ENT.employeeId AND ENT.entryType = 1
    LEFT OUTER JOIN EMPDB.T_ORGANIZATION ORG on EMP.organizationId = ORG.organizationId




SELECT * FROM EMPDB.T_EMPLOYEE
SELECT * FROM EMPDB.T_TITLE
SELECT * FROM EMPDB.T_USER
SELECT * FROM EMPDB.T_DEPARTMENT
SELECT * FROM EMPDB.T_ALIAS
SELECT * FROM EMPDB.T_CONTACT
SELECT * FROM EMPDB.T_ENTRY
SELECT * FROM EMPDB.T_CONTACT_TYPE






















