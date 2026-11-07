-- =====================================================================
-- TP Seance 2 - Partie 1 : Architecture utilisateurs (etapes 1 a 5)
-- Projet SecureBank - Oracle 19c - CDB SECBANK / PDB SECBANKPDB
-- Auteur : Manar Ouberri - Filiere Cybersecurite
-- Executer en : sqlplus / as sysdba
-- =====================================================================
-- NB : les objets bancaires sont crees dans la PDB SECBANKPDB.
--      "@SECBANK" de l'enonce designe la CDB : on utilise le service
--      //localhost:1521/secbankpdb.local

-- Etape 1 : verifications
SELECT name, open_mode, log_mode FROM v$database;
ALTER SESSION SET CONTAINER = SECBANKPDB;
SELECT tablespace_name FROM dba_tablespaces
WHERE tablespace_name IN ('ACCOUNTS_DATA','TRANSACTIONS_DATA','AUDIT_DATA');

-- Etape 2 : proprietaire des objets bancaires
CREATE USER bank_owner
    IDENTIFIED BY "BankOwner#SecureBank2024!"
    DEFAULT TABLESPACE accounts_data
    TEMPORARY TABLESPACE temp
    QUOTA UNLIMITED ON accounts_data
    QUOTA UNLIMITED ON transactions_data
    QUOTA UNLIMITED ON audit_data
    PROFILE default
    ACCOUNT UNLOCK
    PASSWORD EXPIRE;

GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE PROCEDURE,
      CREATE SEQUENCE, CREATE TRIGGER, CREATE SYNONYM TO bank_owner;

SELECT username, default_tablespace, account_status
FROM dba_users WHERE username = 'BANK_OWNER';
-- Statut attendu : EXPIRED (et non "EXPIRED & LOCKED" comme indique dans l'enonce,
-- puisque le compte est cree avec ACCOUNT UNLOCK)

-- Etape 3 : premiere connexion (changement de mot de passe impose)
-- CONNECT bank_owner/"BankOwner#SecureBank2024!"@//localhost:1521/secbankpdb.local
-- New password : BankOwner#Secure@2024#New!
-- SELECT USER FROM DUAL;

-- Etape 4 : tables bancaires (connecte en BANK_OWNER)
CREATE TABLE customers (
    customer_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR2(50) NOT NULL,
    last_name VARCHAR2(50) NOT NULL,
    email VARCHAR2(100) UNIQUE,
    phone VARCHAR2(20),
    address VARCHAR2(200),
    city VARCHAR2(50),
    postal_code VARCHAR2(10),
    ssn VARCHAR2(12),            -- les SSN de test font 12 caracteres (VARCHAR2(11) dans l'enonce -> ORA-12899)
    date_of_birth DATE,
    created_date TIMESTAMP DEFAULT SYSTIMESTAMP,
    modified_date TIMESTAMP,
    branch_id VARCHAR2(20) NOT NULL,
    CONSTRAINT chk_email CHECK (email LIKE '%@%')
) TABLESPACE accounts_data;

CREATE TABLE accounts (
    account_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_number VARCHAR2(30) UNIQUE NOT NULL,   -- IBAN de test = 24 caracteres
    customer_id NUMBER NOT NULL,
    account_type VARCHAR2(20) NOT NULL,
    balance NUMBER(15,2) DEFAULT 0 NOT NULL,
    currency VARCHAR2(3) DEFAULT 'EUR',
    status VARCHAR2(20) DEFAULT 'ACTIVE',
    opened_date DATE DEFAULT SYSDATE,
    closed_date DATE,
    branch_id VARCHAR2(20) NOT NULL,
    created_date TIMESTAMP DEFAULT SYSTIMESTAMP,
    modified_date TIMESTAMP,
    CONSTRAINT fk_accounts_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT chk_account_type CHECK (account_type IN ('CHECKING','SAVINGS','BUSINESS')),
    CONSTRAINT chk_balance CHECK (balance >= -1000),
    CONSTRAINT chk_status CHECK (status IN ('ACTIVE','FROZEN','CLOSED'))
) TABLESPACE accounts_data;

CREATE TABLE transactions (
    transaction_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id NUMBER NOT NULL,
    transaction_type VARCHAR2(20) NOT NULL,
    amount NUMBER(15,2) NOT NULL,
    transaction_date TIMESTAMP DEFAULT SYSTIMESTAMP,
    description VARCHAR2(200),
    reference_number VARCHAR2(50) UNIQUE,
    status VARCHAR2(20) DEFAULT 'COMPLETED',
    branch_id VARCHAR2(20) NOT NULL,
    created_by VARCHAR2(100),
    CONSTRAINT fk_trans_account FOREIGN KEY (account_id) REFERENCES accounts(account_id),
    CONSTRAINT chk_trans_type CHECK (transaction_type IN ('DEPOSIT','WITHDRAWAL','TRANSFER','FEE','INTEREST')),
    CONSTRAINT chk_trans_status CHECK (status IN ('PENDING','COMPLETED','FAILED','CANCELLED'))
) TABLESPACE transactions_data;

CREATE TABLE user_branch_mapping (
    username VARCHAR2(128) PRIMARY KEY,
    branch_id VARCHAR2(20) NOT NULL,
    role_type VARCHAR2(50),
    assigned_date DATE DEFAULT SYSDATE
) TABLESPACE accounts_data;

SELECT table_name, tablespace_name FROM user_tables ORDER BY table_name;

-- Etape 5 : donnees de test
INSERT INTO customers (first_name,last_name,email,phone,address,city,postal_code,ssn,date_of_birth,branch_id)
VALUES ('Jean','Dupont','jean.dupont@email.fr','0601020304','123 Rue de Rivoli','Paris','75001','177056789012',DATE '1977-05-15','PARIS_01');
INSERT INTO customers (first_name,last_name,email,phone,address,city,postal_code,ssn,date_of_birth,branch_id)
VALUES ('Marie','Martin','marie.martin@email.fr','0602030405','45 Avenue des Champs','Paris','75008','285037812034',DATE '1985-03-22','PARIS_08');
INSERT INTO customers (first_name,last_name,email,phone,address,city,postal_code,ssn,date_of_birth,branch_id)
VALUES ('Pierre','Bernard','pierre.bernard@email.fr','0603040506','78 Cours Lafayette','Lyon','69003','390018923045',DATE '1990-01-10','LYON_03');
INSERT INTO customers (first_name,last_name,email,phone,address,city,postal_code,ssn,date_of_birth,branch_id)
VALUES ('Sophie','Dubois','sophie.dubois@email.fr','0604050607','12 Boulevard de la Croisette','Cannes','06400','478119034056',DATE '1978-11-28','CANNES_01');
COMMIT;

INSERT INTO accounts (account_number,customer_id,account_type,balance,branch_id) VALUES ('FR7612345000012345678901',1,'CHECKING',5420.50,'PARIS_01');
INSERT INTO accounts (account_number,customer_id,account_type,balance,branch_id) VALUES ('FR7612345000012345678902',1,'SAVINGS',15000.00,'PARIS_01');
INSERT INTO accounts (account_number,customer_id,account_type,balance,branch_id) VALUES ('FR7612345000012345678903',2,'CHECKING',3210.75,'PARIS_08');
INSERT INTO accounts (account_number,customer_id,account_type,balance,branch_id) VALUES ('FR7612345000012345678904',3,'CHECKING',8750.00,'LYON_03');
INSERT INTO accounts (account_number,customer_id,account_type,balance,branch_id) VALUES ('FR7612345000012345678905',4,'BUSINESS',45600.25,'CANNES_01');
COMMIT;

INSERT INTO transactions (account_id,transaction_type,amount,description,reference_number,branch_id,created_by)
VALUES (1,'DEPOSIT',1000.00,'Depot especes','TRX20241225001','PARIS_01','SYS');
INSERT INTO transactions (account_id,transaction_type,amount,description,reference_number,branch_id,created_by)
VALUES (1,'WITHDRAWAL',-200.00,'Retrait DAB','TRX20241225002','PARIS_01','ATM_PARIS_01');
INSERT INTO transactions (account_id,transaction_type,amount,description,reference_number,branch_id,created_by)
VALUES (3,'TRANSFER',500.00,'Virement entrant','TRX20241225003','PARIS_08','SYS');
INSERT INTO transactions (account_id,transaction_type,amount,description,reference_number,branch_id,created_by)
VALUES (4,'DEPOSIT',2500.00,'Depot cheque','TRX20241225004','LYON_03','SYS');
COMMIT;

SELECT c.first_name, c.last_name, c.branch_id, a.account_number, a.balance
FROM customers c JOIN accounts a ON c.customer_id = a.customer_id
ORDER BY c.branch_id;
