# TP Séance 3 — Durcissement, Monitoring et Réponse aux Incidents

**Module :** Administration & Sécurité Oracle Database 19c
**Étudiante :** Manar Ouberri — Filière Cybersécurité
**Date de réalisation :** 7 octobre 2026

## Contenu de l'archive

| Fichier | Description |
|---|---|
| `Rapport_TP3_Oracle_Manar_Ouberri.docx` | Rapport complet du TP (déroulé, résultats, difficultés, leçons) |
| `README.md` | Ce fichier |
| `scripts/00_prerequis.sql` | Recréation des comptes de la Séance 2, schéma `sec_admin`, passage en ARCHIVELOG |
| `scripts/01_durcissement.sql` | Partie 1 — inventaire et verrouillage des comptes, révocation des packages PUBLIC |
| `scripts/02_reseau.sh` | Partie 2 — `sqlnet.ora` (AES256 / SHA256), `listener.ora`, vérification |
| `scripts/03_injection_sql.sql` | Partie 3 — procédure vulnérable, attaques, bind variables, DBMS_ASSERT |
| `scripts/04_monitoring.sql` | Partie 4 — audit unifié, alertes, tableau de bord, détection, job |
| `scripts/05_sauvegarde_rman.rman` | Partie 5 — sauvegarde RMAN chiffrée et validation |
| `scripts/06_incident.sql` | Exercice final — exfiltration simulée, détection, confinement, preuves |

## Environnement

- Oracle Database 19c Enterprise Edition 19.3, Oracle Linux
- Hôte : `secbank.local` — CDB : `SECBANK` — PDB : `SECBANKPDB`
- Service réseau de la PDB : `secbankpdb.local` (port 1521)
- Comptes du TP : `hr_owner`, `analyst1`, `sec_admin`

## Ordre d'exécution

1. `00_prerequis.sql` en `sqlplus / as sysdba` (puis passage en ARCHIVELOG et sauvegarde `AVANT_TP3`)
2. `01_durcissement.sql` (dans la PDB)
3. `02_reseau.sh` en tant qu'utilisateur `oracle`
4. `03_injection_sql.sql` connecté en `hr_owner` via TCP
5. `04_monitoring.sql` en SYSDBA dans la PDB
6. `05_sauvegarde_rman.rman` dans `rman target /`
7. `06_incident.sql` (analyst1, puis SYSDBA)

## Adaptations par rapport à l'énoncé

- `audit_admin` → **`sec_admin`** : `AUDIT_ADMIN` est un rôle prédéfini Oracle (ORA-01920).
- `SQLNET.AUTHENTICATION_SERVICES = (BEQ)` au lieu de `(NONE)`, pour conserver l'accès SYSDBA local.
- Attaques SQL corrigées (commentaire `--`, `all_users` au lieu de `dba_users`).
- Dossier de sauvegarde : `/u01/app/oracle/backup/secbank` (droits insuffisants sur `/u01`).
- Ajout d'un bloc `EXCEPTION` dans la boucle de verrouillage (comptes communs d'une PDB).

## État d'avancement

| Partie | Statut |
|---|---|
| 1. Audit et durcissement | ✅ Réalisée |
| 2. Chiffrement réseau | ✅ Réalisée (AES256 + SHA256 vérifiés) |
| 3. Injection SQL | ✅ Réalisée |
| 4. Monitoring et alertes | ✅ Réalisée (alerte BRUTE_FORCE détectée) |
| 5. Sauvegarde RMAN chiffrée | ⚠️ Partielle — wallet TDE fermé (ORA-19836 / ORA-28365) |
| Exercice d'incident | ✅ Détection, confinement, preuves — restauration non exécutée (wallet) |

> Les mots de passe présents dans les scripts sont des valeurs de TP, à ne jamais réutiliser en production.
