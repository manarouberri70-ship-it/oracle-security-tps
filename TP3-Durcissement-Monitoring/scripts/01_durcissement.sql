-- =====================================================================
-- TP Seance 3 - Partie 1 : Audit et durcissement (etapes 1 a 4)
-- Executer en : sqlplus / as sysdba, puis dans la PDB
-- =====================================================================
ALTER SESSION SET CONTAINER = SECBANKPDB;
SET SERVEROUTPUT ON
SET LINESIZE 200
SET PAGESIZE 100
COLUMN username FORMAT A25
COLUMN account_status FORMAT A20

-- Etape 1 : inventaire des comptes
SELECT username, account_status, created, profile
FROM dba_users ORDER BY created DESC;

SELECT username, account_status
FROM dba_users
WHERE oracle_maintained = 'Y'
   OR username IN ('SCOTT','HR','OE','PM','SH','IX','BI','OUTLN','ANONYMOUS')
ORDER BY account_status, username;

-- Etape 2 : verrouillage journalise
CREATE TABLE sec_admin.hardening_log (
    action_date   TIMESTAMP DEFAULT SYSTIMESTAMP,
    action_type   VARCHAR2(100),
    action_detail VARCHAR2(4000),
    performed_by  VARCHAR2(100) DEFAULT USER
);

DECLARE
    v_count NUMBER := 0;
BEGIN
    FOR rec IN (SELECT username FROM dba_users
                WHERE (oracle_maintained = 'Y'
                       OR username IN ('SCOTT','HR','OE','PM','SH','IX','BI','OUTLN'))
                  AND username NOT IN ('SYS','SYSTEM')
                  AND account_status LIKE '%OPEN%') LOOP
        BEGIN
            EXECUTE IMMEDIATE 'ALTER USER ' || rec.username || ' ACCOUNT LOCK';
            INSERT INTO sec_admin.hardening_log (action_type, action_detail)
            VALUES ('ACCOUNT_LOCK', 'Compte verrouille : ' || rec.username);
            v_count := v_count + 1;
            DBMS_OUTPUT.PUT_LINE('Verrouille : ' || rec.username);
        EXCEPTION WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Ignore (' || rec.username || ') : ' || SQLERRM);
        END;
    END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Total verrouilles : ' || v_count);
END;
/
-- Resultat obtenu : Total verrouilles : 0 (comptes Oracle deja LOCKED par defaut en 19c)

ALTER USER ANONYMOUS ACCOUNT LOCK;
REVOKE ALL PRIVILEGES FROM ANONYMOUS;   -- ORA-01952 : aucun privilege a retirer
INSERT INTO sec_admin.hardening_log (action_type, action_detail)
VALUES ('CRITICAL', 'ANONYMOUS verrouille (aucun privilege systeme a revoquer)');
COMMIT;

-- Point de controle
SELECT username, account_status FROM dba_users
WHERE username IN ('SCOTT','HR','ANONYMOUS','DBSNMP') ORDER BY username;

-- Etape 3 : packages exposes a PUBLIC
COLUMN owner FORMAT A10
COLUMN table_name FORMAT A25
SELECT owner, table_name, privilege, grantable
FROM dba_tab_privs
WHERE grantee = 'PUBLIC' AND privilege = 'EXECUTE'
  AND table_name IN ('UTL_FILE','UTL_TCP','UTL_HTTP','UTL_SMTP',
                     'DBMS_SQL','DBMS_SCHEDULER','DBMS_JAVA','DBMS_LDAP');

CREATE TABLE sec_admin.dangerous_packages AS
SELECT CAST('UTL_FILE' AS VARCHAR2(30)) AS package_name,
       CAST('Acces fichiers' AS VARCHAR2(50)) AS risk FROM DUAL
UNION ALL SELECT 'UTL_TCP','Connexions TCP' FROM DUAL
UNION ALL SELECT 'UTL_HTTP','Requetes HTTP' FROM DUAL
UNION ALL SELECT 'UTL_SMTP','Envoi de mails' FROM DUAL
UNION ALL SELECT 'DBMS_SQL','SQL dynamique' FROM DUAL
UNION ALL SELECT 'DBMS_SCHEDULER','Planification' FROM DUAL
UNION ALL SELECT 'DBMS_JAVA','Execution Java' FROM DUAL
UNION ALL SELECT 'DBMS_LDAP','Operations LDAP' FROM DUAL;

-- Etape 4 : revocation
DECLARE
    v_count NUMBER := 0;
BEGIN
    FOR rec IN (SELECT package_name FROM sec_admin.dangerous_packages) LOOP
        BEGIN
            EXECUTE IMMEDIATE 'REVOKE EXECUTE ON ' || rec.package_name || ' FROM PUBLIC';
            INSERT INTO sec_admin.hardening_log (action_type, action_detail)
            VALUES ('PACKAGE_REVOKE', 'EXECUTE revoque sur ' || rec.package_name);
            v_count := v_count + 1;
            DBMS_OUTPUT.PUT_LINE('Revoque : ' || rec.package_name);
        EXCEPTION WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Ignore (' || rec.package_name || ') : ' || SQLERRM);
        END;
    END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Total revoques : ' || v_count);
END;
/
-- Resultat obtenu : Total revoques : 8

-- Point de controle (attendu : aucune ligne)
SELECT table_name FROM dba_tab_privs
WHERE grantee = 'PUBLIC' AND privilege = 'EXECUTE'
  AND table_name IN (SELECT package_name FROM sec_admin.dangerous_packages);

-- Objets eventuellement invalides apres revocation
SELECT COUNT(*) FROM dba_objects WHERE status = 'INVALID';
