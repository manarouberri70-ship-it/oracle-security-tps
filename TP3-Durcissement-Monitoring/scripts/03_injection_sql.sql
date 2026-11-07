-- =====================================================================
-- TP Seance 3 - Partie 3 : Injection SQL, de l'attaque a la parade (etapes 8 a 12)
-- CONNECT hr_owner/"HrOwner#2026"@//localhost:1521/secbankpdb.local
-- =====================================================================
SET SERVEROUTPUT ON

-- Etape 8 : procedure volontairement vulnerable (pedagogique uniquement)
CREATE OR REPLACE PROCEDURE search_employee_vulnerable(p_name VARCHAR2) AS
    TYPE emp_cursor IS REF CURSOR;
    v_cur emp_cursor; v_id NUMBER; v_fn VARCHAR2(50); v_ln VARCHAR2(50); v_sal NUMBER;
    v_sql VARCHAR2(1000);
BEGIN
    v_sql := 'SELECT employee_id, first_name, last_name, salary FROM employees ' ||
             'WHERE first_name LIKE ''%' || p_name || '%''';
    DBMS_OUTPUT.PUT_LINE('SQL execute : ' || v_sql);
    OPEN v_cur FOR v_sql;
    LOOP FETCH v_cur INTO v_id, v_fn, v_ln, v_sal; EXIT WHEN v_cur%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE(v_id||' - '||v_fn||' '||v_ln||' - '||v_sal);
    END LOOP; CLOSE v_cur;
END;
/

-- Etape 9 : attaques (une ligne a la fois)
EXEC search_employee_vulnerable('Steven');
EXEC search_employee_vulnerable('x'' OR 1=1 --');
EXEC search_employee_vulnerable('x'' UNION SELECT -1, username, ''--'', 0 FROM all_users --');
-- Corrections par rapport a l'enonce :
--  * les chaines d'origine finissaient par '1'='1%' (toujours faux) -> ajout du commentaire --
--  * dba_users remplace par all_users (hr_owner n'a pas le droit de lire dba_users)

-- Etape 10 : version securisee (bind variable)
CREATE OR REPLACE PROCEDURE search_employee_secure(p_name VARCHAR2) AS
    TYPE emp_cursor IS REF CURSOR;
    v_cur emp_cursor; v_id NUMBER; v_fn VARCHAR2(50); v_ln VARCHAR2(50); v_sal NUMBER;
BEGIN
    OPEN v_cur FOR
        'SELECT employee_id, first_name, last_name, salary FROM employees ' ||
        'WHERE first_name LIKE ''%'' || :1 || ''%'''
        USING p_name;
    LOOP FETCH v_cur INTO v_id, v_fn, v_ln, v_sal; EXIT WHEN v_cur%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE(v_id||' - '||v_fn||' '||v_ln||' - '||v_sal);
    END LOOP; CLOSE v_cur;
END;
/

-- Etape 11 : rejouer les attaques (attendu : aucun resultat)
EXEC search_employee_secure('Steven');
EXEC search_employee_secure('x'' OR 1=1 --');
EXEC search_employee_secure('x'' UNION SELECT -1, username, ''--'', 0 FROM all_users --');

-- Etape 12 : noms d'objets dynamiques -> DBMS_ASSERT
CREATE OR REPLACE PROCEDURE count_rows_secure(p_table VARCHAR2) AS
    v_ok VARCHAR2(128); v_count NUMBER;
BEGIN
    v_ok := DBMS_ASSERT.SIMPLE_SQL_NAME(p_table);
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || v_ok INTO v_count;
    DBMS_OUTPUT.PUT_LINE('Lignes dans ' || v_ok || ' : ' || v_count);
EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Nom de table invalide : ' || SQLERRM);
END;
/
EXEC count_rows_secure('EMPLOYEES');             -- Lignes dans EMPLOYEES : 5
EXEC count_rows_secure('EMPLOYEES WHERE 1=0');   -- ORA-44003 : nom SQL non valide
