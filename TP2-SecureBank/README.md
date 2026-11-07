# TP Séance 2 — Gestion des Accès Bancaires et Chiffrement des Données

**Projet :** SecureBank — Administration & Sécurité Oracle Database 19c
**Étudiante :** Manar Ouberri — Filière Cybersécurité

## Contenu de l'archive

| Fichier | Description |
|---|---|
| `Rapport_TP2_SecureBank_Manar_Ouberri.docx` | Rapport complet du TP |
| `README.md` | Ce fichier |
| `scripts/01_bank_owner_tables.sql` | Partie 1 — BANK_OWNER, tables bancaires, données de test |
| `scripts/02_roles_profil_utilisateurs.sql` | Parties 2-3 — hiérarchie de rôles, profil, utilisateurs, mapping agences |
| `scripts/03_tde.sql` | Partie 4 — wallet, clé maître, chiffrement des tablespaces et de la colonne SSN |
| `scripts/04_vpd.sql` | Partie 5 — fonction de politique et politiques VPD par agence |
| `scripts/05_audit_unifie.sql` | Partie 6 — 5 politiques d'audit, génération et analyse d'événements |
| `scripts/06_investigation_incident.sql` | Exercice final — investigation d'une transaction suspecte |

## Environnement

- Oracle Database 19c EE (19.3), Oracle Linux, hôte `secbank.local`
- CDB `SECBANK`, PDB `SECBANKPDB` — service `secbankpdb.local:1521`
- Wallet TDE : `/u01/app/oracle/admin/SECBANK/wallet`

## Ordre d'exécution

1. `01_bank_owner_tables.sql` (SYSDBA puis BANK_OWNER)
2. `02_roles_profil_utilisateurs.sql` (SYSDBA, mapping en BANK_OWNER)
3. `03_tde.sql` (SYSDBA, depuis la CDB)
4. `04_vpd.sql` (BANK_OWNER pour la fonction, SYSDBA pour DBMS_RLS)
5. `05_audit_unifie.sql` (SYSDBA, tests avec les comptes applicatifs)
6. `06_investigation_incident.sql` (security_auditor)

## Corrections apportées à l'énoncé

Les scripts fournis sont corrigés ; chaque correction est commentée dans le code et expliquée dans le rapport (section « Écarts avec l'énoncé ») :

- connexions sur le service de la PDB (`secbankpdb.local`) au lieu de `@SECBANK` (CDB) ;
- tailles de colonnes `ssn` et `account_number` trop courtes pour les données de test ;
- `COMMENT ON ROLE` (inexistant en Oracle) retiré ;
- chiffrement TDE : mélange OFFLINE / ONLINE corrigé, clé maître créée aussi dans la PDB ;
- colonne SSN chiffrée par `ALTER TABLE … MODIFY … ENCRYPT` (sans perte des contraintes) ;
- fonction VPD : variable BOOLEAN incorrecte, propriétaire auto-bloqué, `update_check` ajouté ;
- audit : conditions `WHEN` invalides remplacées, vue de vérification corrigée ;
- résultat attendu du test VPD Paris (Marie Martin PARIS_08 ne doit pas apparaître).

## Remarque sur les résultats

Les traces d'exécution de cette séance n'ont pas été conservées. L'état de la base observé lors de la Séance 3 confirme que le TP a été réalisé le 30/09/2026 : comptes `BANK_OWNER`, `ADVISOR_PARIS_01`, `ADVISOR_LYON_03`, `ACCOUNT_MGR_PARIS_01`, `SECURITY_AUDITOR` présents avec le profil `SECBANK_USER_PROFILE`, et tablespaces `ACCOUNTS_DATA`, `TRANSACTIONS_DATA`, `AUDIT_DATA` chiffrés par TDE. Les captures d'écran sont à insérer aux emplacements prévus du rapport.

> Les mots de passe présents dans les scripts sont des valeurs de TP, à ne jamais réutiliser en production.
