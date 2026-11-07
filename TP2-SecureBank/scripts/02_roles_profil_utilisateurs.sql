-- =====================================================================
-- TP Seance 2 - Parties 2 et 3 : roles, profil, utilisateurs (etapes 6 a 13)
-- Executer en : sqlplus / as sysdba
-- =====================================================================
ALTER SESSION SET CONTAINER = SECBANKPDB;

-- Etape 7 : role de base
CREATE ROLE bank_employee;
GRANT CREATE SESSION TO bank_employee;
-- NB : "COMMENT ON ROLE" n'existe pas en Oracle (ORA-00905) : la description
--      des roles est documentee dans le rapport.

-- Etape 8 : lecture seule
CREATE ROLE bank_reader;
GRANT bank_employee TO bank_reader;
GRANT SELECT ON bank_owner.customers    TO bank_reader;
GRANT SELECT ON bank_owner.accounts     TO bank_reader;
GRANT SELECT ON bank_owner.transactions TO bank_reader;

-- Etape 9 : operations (pas de DELETE, pas d'UPDATE sur transactions)
CREATE ROLE bank_operator;
GRANT bank_reader TO bank_operator;
GRANT INSERT, UPDATE ON bank_owner.customers TO bank_operator;
GRANT INSERT, UPDATE ON bank_owner.accounts  TO bank_operator;
GRANT INSERT ON bank_owner.transactions      TO bank_operator;

-- Etape 10 : audit
CREATE ROLE bank_auditor;
GRANT bank_employee TO bank_auditor;
GRANT SELECT ANY TABLE TO bank_auditor;
GRANT SELECT_CATALOG_ROLE TO bank_auditor;
GRANT AUDIT_VIEWER TO bank_auditor;   -- acces au journal d'audit unifie
-- (l'enonce propose "GRANT SELECT ON sys.unified_audit_trail" : la vue appartient a AUDSYS)

SELECT grantee, granted_role FROM dba_role_privs
WHERE grantee IN ('BANK_READER','BANK_OPERATOR','BANK_AUDITOR') ORDER BY grantee;
-- (l'enonce filtre sur la colonne "role", qui n'existe pas dans dba_role_privs)

-- Etape 11 : profil de securite bancaire
CREATE PROFILE secbank_user_profile LIMIT
    SESSIONS_PER_USER 2
    FAILED_LOGIN_ATTEMPTS 3
    PASSWORD_LIFE_TIME 60
    PASSWORD_REUSE_TIME 365
    PASSWORD_REUSE_MAX 6
    PASSWORD_LOCK_TIME 2/24
    PASSWORD_GRACE_TIME 5
    IDLE_TIME 30
    CONNECT_TIME 480;
-- IDLE_TIME / CONNECT_TIME ne s'appliquent que si RESOURCE_LIMIT = TRUE (defaut 19c : TRUE)

-- Etape 12 : utilisateurs applicatifs
CREATE USER advisor_paris_01 IDENTIFIED BY "Advisor#Paris01@2024!"
    DEFAULT TABLESPACE users TEMPORARY TABLESPACE temp
    PROFILE secbank_user_profile ACCOUNT UNLOCK PASSWORD EXPIRE;
GRANT bank_reader TO advisor_paris_01;
ALTER USER advisor_paris_01 DEFAULT ROLE bank_reader;

CREATE USER account_mgr_paris_01 IDENTIFIED BY "AcctMgr#Paris01@2024!"
    DEFAULT TABLESPACE users TEMPORARY TABLESPACE temp
    PROFILE secbank_user_profile ACCOUNT UNLOCK PASSWORD EXPIRE;
GRANT bank_operator TO account_mgr_paris_01;
ALTER USER account_mgr_paris_01 DEFAULT ROLE bank_operator;

CREATE USER advisor_lyon_03 IDENTIFIED BY "Advisor#Lyon03@2024!"
    DEFAULT TABLESPACE users TEMPORARY TABLESPACE temp
    PROFILE secbank_user_profile ACCOUNT UNLOCK PASSWORD EXPIRE;
GRANT bank_reader TO advisor_lyon_03;
ALTER USER advisor_lyon_03 DEFAULT ROLE bank_reader;

CREATE USER security_auditor IDENTIFIED BY "SecAuditor#2024!Strong"
    DEFAULT TABLESPACE users TEMPORARY TABLESPACE temp
    PROFILE secbank_user_profile ACCOUNT UNLOCK PASSWORD EXPIRE;
GRANT bank_auditor TO security_auditor;
ALTER USER security_auditor DEFAULT ROLE bank_auditor;

SELECT username, profile, account_status FROM dba_users
WHERE profile = 'SECBANK_USER_PROFILE' ORDER BY username;

-- Etape 13 : mapping utilisateur -> agence (connecte en BANK_OWNER)
-- CONNECT bank_owner/"<mot_de_passe>"@//localhost:1521/secbankpdb.local
INSERT INTO bank_owner.user_branch_mapping (username, branch_id, role_type) VALUES ('ADVISOR_PARIS_01','PARIS_01','ADVISOR');
INSERT INTO bank_owner.user_branch_mapping (username, branch_id, role_type) VALUES ('ACCOUNT_MGR_PARIS_01','PARIS_01','MANAGER');
INSERT INTO bank_owner.user_branch_mapping (username, branch_id, role_type) VALUES ('ADVISOR_LYON_03','LYON_03','ADVISOR');
COMMIT;
SELECT * FROM bank_owner.user_branch_mapping ORDER BY branch_id;
