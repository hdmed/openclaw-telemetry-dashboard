# Installation

<div align="center">

[![🇫🇷 Français](https://img.shields.io/badge/langue-Fran%C3%A7ais-ff7a45)](INSTALL.md)
[![🇬🇧 English](https://img.shields.io/badge/lang-English-38bdf8)](en/INSTALL.md)

</div>

## Prérequis

| Composant | Obligatoire ? | Rôle |
|---|---|---|
| Windows 10/11 + PowerShell 5.1+ | Oui | Exécuter `collect.ps1` |
| Navigateur moderne | Oui | Afficher `index.html` |
| [OpenClaw / AutoClaw](https://docs.openclaw.ai) installé | Recommandé | Fournit les métriques réelles (`status --json`, transcripts) |
| Node.js ≥ 18 | Recommandé | Utilisé par la CLI OpenClaw (déjà fourni avec AutoClaw) |
| Connexion Internet | Ponctuelle | Charger Chart.js depuis CDN (sinon les KPI restent lisibles, sans graphiques) |

## Étapes

1. **Récupérer le projet** : cloner le dépôt (ou copier le dossier `TDB/`)
   ```powershell
   git clone https://github.com/hdmed/openclaw-telemetry-dashboard.git
   cd AutCLW\TDB
   ```

2. **Lancer l'installateur interactif** (copie les fichiers, crée
   `telemetry/`, demande le mode de rafraîchissement, écrit
   `config.local.json`) :
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\install.ps1 -Destination "C:\Tools\AutCLW-TDB"
   ```
   Menu proposé :
   ```text
   Mode de rafraichissement :
     1. Manuel uniquement (recommande, 0 token LLM)      ← défaut
     2. Task Scheduler Windows (0 token, automatique)
     3. Cron OpenClaw (flexible, ~24k tokens/cycle)
   ```
   Le mode est modifiable à tout moment ensuite :
   `scripts\configure.ps1 -Mode manual|taskScheduler|openclawCron`
   (détails dans [USAGE.md](USAGE.md)).

3. **Vérifier l'installation** :
   ```powershell
   powershell -ExecutionPolicy Bypass -File tests\smoke-test.ps1
   ```
   Tous les tests doivent afficher `PASS`.

4. **Première collecte** : double-cliquer `openclaw-tdb\collect.bat`.
   - Avec OpenClaw installé → métriques réelles
   - Sans OpenClaw → le TDB reste vide ; passez en mode démo (ci-dessous)

## Mode démonstration (sans OpenClaw)

```powershell
Copy-Item openclaw-tdb\sample-data\* openclaw-tdb\telemetry\ -Force
```
Puis ouvrir `openclaw-tdb\index.html`. Les données affichées sont fictives.

## Chemins non standards

Si votre installation OpenClaw n'est pas à l'emplacement par défaut,
renseignez `openclaw-tdb\config.local.json` (jamais committé) — voir
`config.example.json` pour toutes les clés :

```json
{
  "cliPath": "D:\\Outils\\openclaw\\openclaw.mjs",
  "cfgPath": "C:\\Users\\moi\\.openclaw-autoclaw\\openclaw.json",
  "agentsRoot": "C:\\Users\\moi\\.openclaw-autoclaw\\agents"
}
```

Sur macOS/Linux, adaptez `collect.ps1` (la logique est identique ; les
chemins de la CLI changent) et remplacez Task Scheduler par launchd/systemd
(non fourni en v0.2).
