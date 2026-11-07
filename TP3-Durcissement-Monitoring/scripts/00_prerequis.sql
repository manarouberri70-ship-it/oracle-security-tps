-- =====================================================================
-- TP Seance 3 - 00 : Prerequis (comptes de la Seance 2 + schema sec_admin)
-- Base : SECBANK (CDB) / PDB : SECBANKPDB - Oracle 19c
-- Auteur : Manar Ouberri - Filiere Cybersecurite
-- Executer en : sqlplus / as sysdba
-- =====================================================================

ALTER PLUGGABLE DATABASE SECBANKPDB SAVE STATE;
ALTER SESSION SET CONTAINER = SECBANKPDB;

-- Proprietaire du schema RH
CREATE USER hr_owner IDENTIFIED BY "HrOwner#2026"
  DEFAULT TABLESPACE users QUOTA UNLIMITED ON users;
GRANT CREATE SESSION, CREATE TABLE, CREATE PROCEDURE TO hr_owner;

CREATE TABLE hr_owner.employees (
  employee_id NUMBER PRIMARY KEY,
  first_name  VARCHAR2(50),
  last_name   VARCHAR2(50),
  salary      NUMBER
);
INSERT INTO hr_owner.employees VALUES (100, 'Steven',    'King',    24000);
INSERT INTO hr_owner.employees VALUES (101, 'Neena',     'Kochhar', 17000);
INSERT INTO hr_owner.employees VALUES (102, 'Lex',       'De Haan', 17000);
INSERT INTO hr_owner.employees VALUES (103, 'Alexander', 'Hunold',   9000);
INSERT INTO hr_owner.employees VALUES (104, 'Bruce',     'Ernst',    6000);
COMMIT;

-- Compte analyste (lecture seule)
CREATE USER analyst1 IDENTIFIED BY "Analyst#2026";
GRANT CREATE SESSION TO analyst1;
GRANT SELECT ON hr_owner.employees TO analyst1;

-- Schema d'administration de la securite
-- NB : "AUDIT_ADMIN" est un role predefini Oracle (ORA-01920) -> renomme en SEC_ADMIN
CREATE USER sec_admin IDENTIFIED BY "SecAdm#2026"
  DEFAULT TABLESPACE users QUOTA UNLIMITED ON users;
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE PROCEDURE TO sec_admin;
GRANT SELECT ON audsys.unified_audit_trail TO sec_admin;
GRANT SELECT ANY DICTIONARY TO sec_admin;

-- Verification
SELECT username, account_status FROM dba_users
WHERE username IN ('HR_OWNER','ANALYST1','SEC_ADMIN');
SELECT COUNT(*) FROM hr_owner.employees;

-- Passage en mode ARCHIVELOG (depuis la CDB, connexion propre)
-- CONNECT / AS SYSDBA
-- SHUTDOWN IMMEDIATE
-- STARTUP MOUNT
-- ALTER DATABASE ARCHIVELOG;
-- ALTER DATABASE OPEN;
-- ALTER PLUGGABLE DATABASE ALL OPEN;
-- SELECT log_mode FROM v$database;   -- attendu : ARCHIVELOG
