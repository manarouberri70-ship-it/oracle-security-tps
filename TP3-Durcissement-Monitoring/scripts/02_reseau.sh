#!/bin/bash
# =====================================================================
# TP Seance 3 - Partie 2 : Securisation du reseau (etapes 5 a 7)
# Executer en tant que : oracle
# =====================================================================
cd $ORACLE_HOME/network/admin

# --- Etape 5 : sqlnet.ora ---
cp sqlnet.ora sqlnet.ora.backup 2>/dev/null
cat >> sqlnet.ora <<'EOF'
SQLNET.ENCRYPTION_SERVER = REQUIRED
SQLNET.ENCRYPTION_TYPES_SERVER = (AES256, AES192, AES128)
SQLNET.CRYPTO_CHECKSUM_SERVER = REQUIRED
SQLNET.CRYPTO_CHECKSUM_TYPES_SERVER = (SHA256, SHA384, SHA512)
SQLNET.AUTHENTICATION_SERVICES = (BEQ)
SQLNET.EXPIRE_TIME = 10
EOF
# (BEQ) au lieu de (NONE) : conserve "sqlplus / as sysdba" et "rman target /"
# en local, tout en interdisant l'authentification OS a distance.

# Suppression de l'ancien parametre en doublon
sed -i '/SQLNET.EXPIRE_TIME = 30/d' sqlnet.ora
grep EXPIRE sqlnet.ora

# --- Etape 6 : listener.ora ---
cp listener.ora listener.ora.backup
cat >> listener.ora <<'EOF'
ADMIN_RESTRICTIONS_LISTENER = ON
SECURE_REGISTER_LISTENER = TCP
LOGGING_LISTENER = ON
EOF
lsnrctl stop
lsnrctl start
sleep 30
lsnrctl status     # service PDB : secbankpdb.local

# --- Etape 7 : verification (connexion via TCP) ---
# sqlplus sec_admin/"SecAdm#2026"@//localhost:1521/secbankpdb.local
# SELECT network_service_banner FROM v$session_connect_info
# WHERE sid = (SELECT sid FROM v$mystat WHERE ROWNUM = 1);
# Attendu : "AES256 Encryption service adapter" et
#           "SHA256 Crypto-checksumming service adapter"
