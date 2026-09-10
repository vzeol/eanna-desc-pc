# EANNA - Computer Description Tool

Outil PowerShell (avec interface graphique) pour modifier la description des postes dans l'Active Directory EANNA Haute-Vienne, à partir d'un fichier CSV.

## 📦 Contenu du repo

| Fichier | Description |
|---|---|
| `EANNA - Computer Description Tool.exe` | Exécutable prêt à l'emploi |
| `Changer-desc-poste-1.0.ps1` | Script PowerShell — **version actuelle** |
| `archive/` | Anciennes versions de développement, conservées pour référence |

## 🚀 Utilisation

1. Lancer `EANNA - Computer Description Tool.exe` (ou le script `.ps1` directement).
2. Préparer un fichier CSV au format suivant :

   ```
   PC;Description
   PC-00600-EVSJ;S112-PROF
   PC-00601-EVSJ;S112-001
   ```

   **Règles du CSV :**
   - Séparateur : point-virgule (`;`)
   - Première ligne obligatoire (en-tête `PC;Description`)
   - Un poste par ligne

3. Importer le CSV dans l'outil et lancer le traitement.
4. Un rapport des résultats est généré automatiquement (`_RAPPORT_<date>.csv`), indiquant pour chaque poste si le ping et l'accès admin ont réussi.

## 🧩 Fonctionnalités (v1.0)

- Interface graphique (Windows Forms)
- Auto-complétion des noms de PC via l'Active Directory
- Détection automatique de la salle (`Get-SalleFromAD`)
- Traitement par lot via import CSV
- Vérification de la disponibilité du poste (ping + accès `ADMIN$`) avant modification
- Barre de statut et barre de progression pendant le traitement
- Verrouillage de l'interface pendant l'exécution (`Enable-UI` / `Disable-UI`)
- Génération d'un rapport CSV horodaté

## 🕒 Historique des versions

| Version | Nom d'origine | Notes |
|---|---|---|
| 0.7 | `beta.ps1` | Première version fonctionnelle, interface minimale |
| 0.8 | `V1.ps1` | Ajout de l'auto-complétion AD, titre EANNA Haute-Vienne |
| 0.9 | `V1.1 TEST.ps1` | Ajout du bouton d'aide CSV, ajustements des libellés d'état |
| **1.0** | `V1.0 Final.ps1` | Version finale : gestion complète de l'UI (activation/désactivation), statuts, barre de progression |

Les versions antérieures à la 1.0 sont conservées dans `archive/` à titre d'historique et ne sont plus maintenues.

## ⚠️ Prérequis

- Module PowerShell `ActiveDirectory` (RSAT)
- Droits suffisants sur l'AD pour modifier la description des postes
- Accès réseau au domaine (ping + `ADMIN$`)
