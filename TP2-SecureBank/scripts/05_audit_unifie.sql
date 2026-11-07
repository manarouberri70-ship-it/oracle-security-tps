-- =====================================================================
-- TP Seance 2 - Partie 6 : Audit unifie (etapes 23 a 25)
-- CONNECT / AS SYSDBA ; ALTER SESSION SET CONTAINER = SECBANKPDB;
-- =====================================================================

-- Etape 23 : politiques d'audit
CREATE AUDIT POLICY secbank_account_access
    ACTIONS SELECT, INSERT, UPDATE, DELETE ON bank_owner.accounts;
AUDIT POLICY secbank_account_access;

-- L'enonce filtre sur SYS_CONTEXT('USERENV','CURRENT_SQL') : non fiable dans une
-- condition WHEN. On audite tous les UPDATE de ACCOUNTS ; le filtre "balance" se fait
-- a l'analyse sur sql_text (requete 3).
CREATE AUDIT POLICY secbank_balance_changes
    ACTIONS UPDATE ON bank_owner.accounts;
AUDIT POLICY secbank_balance_changes;

CREATE AUDIT POLICY secbank_transactions
    ACTIONS INSERT, UPDATE, DELETE ON bank_owner.transactions;
AUDIT POLICY secbank_transactions;

-- 'RETURNCODE' n'est pas un attribut de USERENV : on utilise WHENEVER NOT SUCCESSFUL
CREATE AUDIT POLICY secbank_failed_logins ACTIONS LOGON;
AUDIT POLICY secbank_failed_logins WHENEVER NOT SUCCESSFUL;

CREATE AUDIT POLICY secbank_privilege_changes
    ACTIONS GRANT, REVOKE, CREATE USER, DROP USER, ALTER USER;
AUDIT POLICY secbank_privilege_changes;

-- Verification (la colonne enabled_opt est dans AUDIT_UNIFIED_ENABLED_POLICIES)
SELECT policy_name, enabled_opt, success, failure
FROM audit_unified_enabled_policies
WHERE policy_name LIKE 'SECBANK%' ORDER BY policy_name;

-- Etape 24 : generation d'evenements
-- CONNECT advisor_paris_01/"<mdp>"@//localhost:1521/secbankpdb.local
--   SELECT * FROM bank_owner.accounts WHERE account_id = 1;
--   UPDATE bank_owner.accounts SET balance = 10000 WHERE account_id = 1;   -- ORA-01031
-- CONNECT account_mgr_paris_01/"<mdp>"@//localhost:1521/secbankpdb.local
--   UPDATE bank_owner.accounts SET balance = balance + 100, modified_date = SYSTIMESTAMP WHERE account_id = 1;
--   COMMIT;
-- CONNECT advisor_paris_01/mauvais_mdp@//localhost:1521/secbankpdb.local  -- ORA-01017
--   (3 echecs -> compte verrouille 2 h par le profil : ORA-28000)
-- CONNECT account_mgr_paris_01/"<mdp>"@//localhost:1521/secbankpdb.local
--   INSERT INTO bank_owner.transactions (account_id,transaction_type,amount,description,reference_number,branch_id,created_by)
--   VALUES (1,'DEPOSIT',500,'Depot test audit','TRX_TEST_001','PARIS_01',USER);
--   COMMIT;

-- Etape 25 : analyse (en security_auditor, ou SYSDBA)
EXEC DBMS_AUDIT_MGMT.FLUSH_UNIFIED_AUDIT_TRAIL;

SELECT TO_CHAR(event_timestamp,'HH24:MI:SS') heure, dbusername, action_name, object_name, return_code
FROM unified_audit_trail
WHERE event_timestamp > SYSTIMESTAMP - INTERVAL '2' HOUR AND object_schema = 'BANK_OWNER'
ORDER BY event_timestamp DESC;

SELECT event_timestamp, dbusername, action_name, object_name, return_code, sql_text
FROM unified_audit_trail
WHERE return_code <> 0 AND event_timestamp > SYSTIMESTAMP - INTERVAL '24' HOUR
  AND object_schema = 'BANK_OWNER'
ORDER BY event_timestamp DESC;

SELECT TO_CHAR(event_timestamp,'YYYY-MM-DD HH24:MI:SS') quand, dbusername qui, sql_text
FROM unified_audit_trail
WHERE action_name = 'UPDATE' AND object_name = 'ACCOUNTS' AND UPPER(sql_text) LIKE '%BALANCE%'
ORDER BY event_timestamp DESC;

SELECT dbusername, userhost, COUNT(*) nb_echecs, MAX(event_timestamp) derniere_tentative
FROM unified_audit_trail
WHERE action_name = 'LOGON' AND return_code <> 0
  AND event_timestamp > SYSTIMESTAMP - INTERVAL '24' HOUR
GROUP BY dbusername, userhost HAVING COUNT(*) >= 3
ORDER BY nb_echecs DESC;
