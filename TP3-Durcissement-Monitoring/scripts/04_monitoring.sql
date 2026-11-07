-- =====================================================================
-- TP Seance 3 - Partie 4 : Monitoring et alertes (etapes 13 a 16)
-- CONNECT / AS SYSDBA
-- =====================================================================
ALTER SESSION SET CONTAINER = SECBANKPDB;
SET SERVEROUTPUT ON

-- Etape 13 : politiques d'audit unifie
CREATE AUDIT POLICY pol_connexions ACTIONS LOGON, LOGOFF;
AUDIT POLICY pol_connexions WHENEVER NOT SUCCESSFUL;
CREATE AUDIT POLICY pol_employes ACTIONS SELECT, UPDATE, DELETE ON hr_owner.employees;
AUDIT POLICY pol_employes;
CREATE AUDIT POLICY pol_admin PRIVILEGES CREATE USER, DROP USER, ALTER USER, GRANT ANY PRIVILEGE;
AUDIT POLICY pol_admin;

COLUMN policy_name FORMAT A20
COLUMN entity_name FORMAT A15
SELECT policy_name, enabled_opt, entity_name
FROM audit_unified_enabled_policies WHERE policy_name LIKE 'POL_%';

-- Etape 14 : table d'alertes et tableau de bord
CREATE TABLE sec_admin.security_alerts (
    alert_id      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    alert_type    VARCHAR2(100),
    severity      VARCHAR2(20) CHECK (severity IN ('LOW','MEDIUM','HIGH','CRITICAL')),
    alert_message CLOB,
    detected_at   TIMESTAMP DEFAULT SYSTIMESTAMP,
    source_user   VARCHAR2(128),
    source_ip     VARCHAR2(100),
    acknowledged  CHAR(1) DEFAULT 'N'
);
CREATE INDEX sec_admin.idx_alerts_sev ON sec_admin.security_alerts(severity, detected_at);

CREATE OR REPLACE VIEW sec_admin.security_dashboard AS
SELECT 'Echecs de connexion (1h)' AS metric, TO_CHAR(COUNT(*)) AS value,
       CASE WHEN COUNT(*) > 5 THEN 'HIGH' ELSE 'LOW' END AS severity
FROM unified_audit_trail
WHERE action_name = 'LOGON' AND return_code <> 0
  AND event_timestamp > SYSTIMESTAMP - INTERVAL '1' HOUR
UNION ALL
SELECT 'Alertes non traitees', TO_CHAR(COUNT(*)),
       CASE WHEN COUNT(*) > 0 THEN 'CRITICAL' ELSE 'LOW' END
FROM sec_admin.security_alerts WHERE acknowledged = 'N';

-- Etape 15 : procedure de detection des menaces
CREATE OR REPLACE PROCEDURE sec_admin.detect_security_threats AS
    v_msg VARCHAR2(4000);
BEGIN
    -- Regle 1 : force brute (3+ echecs en 1h)
    FOR rec IN (SELECT dbusername, userhost, COUNT(*) nb
                FROM unified_audit_trail
                WHERE action_name = 'LOGON' AND return_code <> 0
                  AND event_timestamp > SYSTIMESTAMP - INTERVAL '1' HOUR
                GROUP BY dbusername, userhost HAVING COUNT(*) >= 3) LOOP
        v_msg := 'Force brute : '||rec.nb||' echecs pour '||rec.dbusername||' depuis '||rec.userhost;
        INSERT INTO sec_admin.security_alerts(alert_type,severity,alert_message,source_user,source_ip)
        VALUES('BRUTE_FORCE','HIGH',v_msg,rec.dbusername,rec.userhost);
    END LOOP;
    -- Regle 2 : acces massif (100+ SELECT en 1h)
    FOR rec IN (SELECT dbusername, object_name, COUNT(*) nb
                FROM unified_audit_trail
                WHERE action_name = 'SELECT'
                  AND event_timestamp > SYSTIMESTAMP - INTERVAL '1' HOUR
                  AND object_schema NOT IN ('SYS','SYSTEM')
                GROUP BY dbusername, object_name HAVING COUNT(*) > 100) LOOP
        v_msg := 'Acces massif : '||rec.dbusername||' a lu '||rec.object_name||' '||rec.nb||' fois en 1h';
        INSERT INTO sec_admin.security_alerts(alert_type,severity,alert_message,source_user)
        VALUES('MASS_DATA_ACCESS','CRITICAL',v_msg,rec.dbusername);
    END LOOP;
    COMMIT;
END;
/

-- Etape 16 : automatisation toutes les 15 minutes
BEGIN
  DBMS_SCHEDULER.CREATE_JOB(
    job_name        => 'SECURITY_MONITORING_JOB',
    job_type        => 'PLSQL_BLOCK',
    job_action      => 'BEGIN sec_admin.detect_security_threats; END;',
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'FREQ=MINUTELY; INTERVAL=15',
    enabled         => TRUE);
END;
/
SELECT job_name, enabled, state FROM dba_scheduler_jobs
WHERE job_name = 'SECURITY_MONITORING_JOB';

-- Test force brute : 3 x (ORA-01017 attendu)
-- CONNECT analyst1/faux@//localhost:1521/secbankpdb.local
-- puis : CONNECT / AS SYSDBA ; ALTER SESSION SET CONTAINER = SECBANKPDB;
EXEC DBMS_AUDIT_MGMT.FLUSH_UNIFIED_AUDIT_TRAIL;
EXEC sec_admin.detect_security_threats;
COLUMN alert_message FORMAT A70
SELECT alert_type, severity, alert_message FROM sec_admin.security_alerts;
SELECT * FROM sec_admin.security_dashboard;
-- Resultat obtenu : BRUTE_FORCE / HIGH - "Force brute : 3 echecs pour ANALYST1 depuis secbank.local"
