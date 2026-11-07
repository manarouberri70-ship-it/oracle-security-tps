-- =====================================================================
-- TP Seance 2 - Exercice final : investigation d'une transaction suspecte
-- Connecte en security_auditor (ou SYSDBA dans la PDB)
-- =====================================================================

-- Mise en place du scenario (simulation) :
-- CONNECT account_mgr_paris_01/"<mdp>"@//localhost:1521/secbankpdb.local
-- INSERT INTO bank_owner.transactions (account_id,transaction_type,amount,description,reference_number,branch_id,created_by)
-- VALUES (1,'TRANSFER',10000,'Virement','TRX_SUSPECT_001','PARIS_01',USER);
-- COMMIT;

EXEC DBMS_AUDIT_MGMT.FLUSH_UNIFIED_AUDIT_TRAIL;

-- 1. Identifier la transaction
SELECT transaction_id, transaction_type, amount, transaction_date,
       description, reference_number, created_by
FROM bank_owner.transactions
WHERE account_id = 1 AND amount = 10000
ORDER BY transaction_date DESC;

-- 2. Retrouver l'auteur dans l'audit
SELECT event_timestamp, dbusername, userhost, client_program_name, os_username, sql_text
FROM unified_audit_trail
WHERE action_name = 'INSERT' AND object_name = 'TRANSACTIONS'
  AND sql_text LIKE '%10000%'
ORDER BY event_timestamp DESC;

-- 3. Toutes ses actions sur 24 h (remplacer le nom trouve)
DEFINE suspect = 'ACCOUNT_MGR_PARIS_01'
SELECT event_timestamp, action_name, object_name, return_code, sql_text
FROM unified_audit_trail
WHERE dbusername = '&suspect' AND event_timestamp > SYSTIMESTAMP - INTERVAL '24' HOUR
ORDER BY event_timestamp;

-- 4. Privileges
SELECT grantee, granted_role FROM dba_role_privs WHERE grantee = '&suspect';
SELECT grantee, privilege, admin_option FROM dba_sys_privs WHERE grantee = '&suspect';

-- 5. Agence assignee vs agence du compte
SELECT * FROM bank_owner.user_branch_mapping WHERE username = '&suspect';
SELECT account_id, branch_id FROM bank_owner.accounts WHERE account_id = 1;

-- 6. Actions correctives
-- ALTER USER &suspect ACCOUNT LOCK;
-- SELECT 'ALTER SYSTEM KILL SESSION '''||sid||','||serial#||''' IMMEDIATE;'
--   FROM v$session WHERE username = '&suspect';
-- REVOKE bank_operator FROM &suspect;
-- Annulation : pas de DELETE (historique immuable) -> transaction de compensation
--   ou statut 'CANCELLED' apres validation compliance.
