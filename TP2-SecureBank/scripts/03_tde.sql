-- =====================================================================
-- TP Seance 2 - Partie 4 : TDE (etapes 14 a 18)
-- Executer en : sqlplus / as sysdba (depuis la CDB)
-- =====================================================================
-- sqlnet.ora (deja present sur le serveur) :
-- ENCRYPTION_WALLET_LOCATION=(SOURCE=(METHOD=FILE)(METHOD_DATA=(DIRECTORY=/u01/app/oracle/admin/SECBANK/wallet)))
-- $ mkdir -p /u01/app/oracle/admin/SECBANK/wallet && chmod 700 /u01/app/oracle/admin/SECBANK/wallet

-- Etape 14 : etat du wallet
COLUMN wrl_parameter FORMAT A45
SELECT con_id, wrl_parameter, status, wallet_type FROM v$encryption_wallet;

-- Creation du keystore (une seule fois, dans la CDB)
ADMINISTER KEY MANAGEMENT CREATE KEYSTORE '/u01/app/oracle/admin/SECBANK/wallet'
    IDENTIFIED BY "WalletSecure#2024!";

-- Etape 15 : ouverture et cle maitre
-- En multitenant : ouvrir pour tous les conteneurs, puis creer une cle par conteneur
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN IDENTIFIED BY "WalletSecure#2024!" CONTAINER = ALL;
ADMINISTER KEY MANAGEMENT SET KEY IDENTIFIED BY "WalletSecure#2024!" WITH BACKUP;          -- CDB$ROOT
ALTER SESSION SET CONTAINER = SECBANKPDB;
ADMINISTER KEY MANAGEMENT SET KEY IDENTIFIED BY "WalletSecure#2024!" WITH BACKUP;          -- PDB
SELECT con_id, status, wallet_type FROM v$encryption_wallet;    -- attendu : OPEN

-- Etape 16 : chiffrement des tablespaces
-- L'enonce melange les deux methodes (OFFLINE puis ENCRYPTION ONLINE), ce qui echoue.
-- Methode retenue : chiffrement EN LIGNE (tablespace laisse ONLINE)
ALTER TABLESPACE accounts_data     ENCRYPTION ONLINE USING 'AES256' ENCRYPT;
ALTER TABLESPACE transactions_data ENCRYPTION ONLINE USING 'AES256' ENCRYPT;
ALTER TABLESPACE audit_data        ENCRYPTION ONLINE USING 'AES256' ENCRYPT;  -- optionnel
-- Alternative hors ligne :
--   ALTER TABLESPACE accounts_data OFFLINE NORMAL;
--   ALTER TABLESPACE accounts_data ENCRYPTION OFFLINE ENCRYPT;
--   ALTER TABLESPACE accounts_data ONLINE;

SELECT tablespace_name, encrypted, status FROM dba_tablespaces
WHERE tablespace_name IN ('ACCOUNTS_DATA','TRANSACTIONS_DATA','AUDIT_DATA');

-- Etape 17 : chiffrement de la colonne SSN
-- Plus simple et sans perte des contraintes que la recreation de table de l'enonce
-- (DROP ... CASCADE CONSTRAINTS supprimait la FK de ACCOUNTS et l'IDENTITY) :
ALTER TABLE bank_owner.customers MODIFY (ssn ENCRYPT USING 'AES256' NO SALT);
SELECT owner, table_name, column_name, encryption_alg, salt
FROM dba_encrypted_columns WHERE table_name = 'CUSTOMERS';

-- Etape 18 : tests
SELECT first_name, last_name, ssn FROM bank_owner.customers WHERE customer_id = 1;  -- SSN lisible
-- Sur le serveur (chemins OMF de la PDB) :
-- $ SELECT file_name FROM dba_data_files WHERE tablespace_name='ACCOUNTS_DATA';
-- $ strings <fichier .dbf> | grep 177056789012     -> aucune sortie attendue
