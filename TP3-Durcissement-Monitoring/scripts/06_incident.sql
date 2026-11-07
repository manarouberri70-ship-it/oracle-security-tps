-- =====================================================================
-- TP Seance 3 - Exercice final : simulation et traitement d'un incident
-- =====================================================================

-- 1. Simuler l'exfiltration (en tant qu'analyst1)
-- CONNECT analyst1/"Analyst#2026"@//localhost:1521/secbankpdb.local
BEGIN
  FOR i IN 1..150 LOOP
    FOR r IN (SELECT * FROM hr_owner.employees WHERE ROWNUM = 1) LOOP NULL; END LOOP;
  END LOOP;
END;
/

-- 2. Detecter (en SYSDBA)
-- CONNECT / AS SYSDBA
ALTER SESSION SET CONTAINER = SECBANKPDB;
EXEC DBMS_AUDIT_MGMT.FLUSH_UNIFIED_AUDIT_TRAIL;
EXEC sec_admin.detect_security_threats;
COLUMN alert_message FORMAT A70
SELECT alert_type, severity, alert_message
FROM sec_admin.security_alerts WHERE source_user = 'ANALYST1';

-- Synthese lisible de l'activite d'analyst1
SELECT action_name, object_name, COUNT(*) AS nb,
       MIN(TO_CHAR(event_timestamp,'HH24:MI:SS')) AS debut
FROM unified_audit_trail WHERE dbusername = 'ANALYST1'
GROUP BY action_name, object_name;
-- Observe : 150 SELECT sur EMPLOYEES a 13:31:39 (154 lignes d'audit au total)

-- 3. Confiner
ALTER USER analyst1 ACCOUNT LOCK;
SELECT 'ALTER SYSTEM KILL SESSION '''||sid||','||serial#||''' IMMEDIATE;'
FROM v$session WHERE username = 'ANALYST1';

-- 4. Consigner et conserver les preuves (AVANT toute restauration)
UPDATE sec_admin.security_alerts SET acknowledged = 'Y' WHERE source_user = 'ANALYST1';
COMMIT;
SPOOL /u01/app/oracle/backup/secbank/preuves_incident.txt
SELECT TO_CHAR(event_timestamp,'HH24:MI:SS') t, action_name, object_name, return_code
FROM unified_audit_trail WHERE dbusername = 'ANALYST1' ORDER BY event_timestamp;
SPOOL OFF
SELECT * FROM sec_admin.security_dashboard;
SELECT username, account_status FROM dba_users WHERE username = 'ANALYST1';

-- 5. Restauration point-in-time (NON executee : wallet TDE ferme)
-- RMAN> SHUTDOWN IMMEDIATE;
-- RMAN> STARTUP MOUNT;
-- RMAN> SET DECRYPTION IDENTIFIED BY "Rman#Backup2026!";
-- RMAN> RUN {
--         SET UNTIL TIME "TO_DATE('2026-10-07 13:30:00','YYYY-MM-DD HH24:MI:SS')";
--         RESTORE DATABASE;
--         RECOVER DATABASE;
--       }
-- RMAN> ALTER DATABASE OPEN RESETLOGS;
-- Puis : ALTER PLUGGABLE DATABASE ALL OPEN; reverrouiller analyst1; nouvelle sauvegarde complete.
