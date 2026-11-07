-- =====================================================================
-- TP Seance 2 - Partie 5 : Virtual Private Database (etapes 19 a 22)
-- =====================================================================

-- Etape 19 : fonction de politique (connecte en BANK_OWNER)
-- Corrections par rapport a l'enonce :
--  * "SELECT 1 INTO v_has_exempt" sur une variable BOOLEAN -> erreur de compilation PLS
--  * bank_owner ne peut pas lire dba_sys_privs sans grant ; inutile de toute facon :
--    un utilisateur ayant EXEMPT ACCESS POLICY n'appelle jamais la fonction
--  * le proprietaire BANK_OWNER n'est pas dans le mapping -> il se serait bloque lui-meme (1=0)
CREATE OR REPLACE FUNCTION branch_security_policy(
    schema_var IN VARCHAR2,
    table_var  IN VARCHAR2
) RETURN VARCHAR2 AS
    v_user      VARCHAR2(128) := SYS_CONTEXT('USERENV', 'SESSION_USER');
    v_branch_id VARCHAR2(20);
BEGIN
    IF v_user = 'BANK_OWNER' THEN
        RETURN NULL;                         -- proprietaire : pas de filtre
    END IF;

    SELECT branch_id INTO v_branch_id
    FROM bank_owner.user_branch_mapping
    WHERE username = v_user;

    RETURN 'branch_id = ''' || v_branch_id || '''';
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN '1=0';                        -- utilisateur inconnu : aucun acces
END;
/
SELECT object_name, object_type, status FROM user_objects
WHERE object_name = 'BRANCH_SECURITY_POLICY';     -- VALID

-- Etape 20 : application des politiques (en SYSDBA, dans la PDB)
-- CONNECT / AS SYSDBA
-- ALTER SESSION SET CONTAINER = SECBANKPDB;
BEGIN
    DBMS_RLS.ADD_POLICY(object_schema => 'BANK_OWNER', object_name => 'CUSTOMERS',
        policy_name => 'BRANCH_ISOLATION_CUSTOMERS', function_schema => 'BANK_OWNER',
        policy_function => 'BRANCH_SECURITY_POLICY',
        statement_types => 'SELECT, INSERT, UPDATE, DELETE', update_check => TRUE, enable => TRUE);
    DBMS_RLS.ADD_POLICY(object_schema => 'BANK_OWNER', object_name => 'ACCOUNTS',
        policy_name => 'BRANCH_ISOLATION_ACCOUNTS', function_schema => 'BANK_OWNER',
        policy_function => 'BRANCH_SECURITY_POLICY',
        statement_types => 'SELECT, INSERT, UPDATE, DELETE', update_check => TRUE, enable => TRUE);
    DBMS_RLS.ADD_POLICY(object_schema => 'BANK_OWNER', object_name => 'TRANSACTIONS',
        policy_name => 'BRANCH_ISOLATION_TRANSACTIONS', function_schema => 'BANK_OWNER',
        policy_function => 'BRANCH_SECURITY_POLICY',
        statement_types => 'SELECT, INSERT, UPDATE, DELETE', update_check => TRUE, enable => TRUE);
END;
/
-- update_check => TRUE : empeche d'inserer/modifier une ligne vers une autre agence

SELECT object_owner, object_name, policy_name, enable
FROM dba_policies WHERE object_owner = 'BANK_OWNER' ORDER BY object_name;

-- Etape 21 : exemption de l'auditeur
GRANT EXEMPT ACCESS POLICY TO security_auditor;

-- Etape 22 : tests d'isolation
-- sqlplus advisor_paris_01/"<mdp>"@//localhost:1521/secbankpdb.local
--   SELECT first_name, last_name, branch_id FROM bank_owner.customers;
--   attendu : Jean Dupont (PARIS_01) uniquement
--   (l'enonce affiche aussi Marie Martin PARIS_08 : c'est une erreur, PARIS_08 est filtree)
-- sqlplus advisor_lyon_03/"<mdp>"@//localhost:1521/secbankpdb.local
--   attendu : Pierre Bernard (LYON_03) uniquement
-- sqlplus security_auditor/"<mdp>"@//localhost:1521/secbankpdb.local
--   attendu : les 4 clients
