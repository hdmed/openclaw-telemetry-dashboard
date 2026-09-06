# Usage

<div align="center">

[![🇫🇷 Français](https://img.shields.io/badge/langue-Fran%C3%A7ais-ff7a45)](USAGE.md)
[![🇬🇧 English](https://img.shields.io/badge/lang-English-38bdf8)](en/USAGE.md)

</div>

## Les 3 modes de rafraîchissement

Le TDB est **passeur de fichiers** : `collect.ps1` écrit `telemetry/`, la page
relit ces fichiers toutes les 60 s tant qu'elle est ouverte. Seul le
**déclencheur** de la collecte change selon le mode :

| Mode | Déclencheur | Tokens LLM | Pour qui |
|---|---|---|---|
| `manual` (défaut) | double-clic `collect.bat` | 0 | Contrôle total |
| `taskScheduler` | Planificateur Windows, toutes les N min | 0 | Transparence totale |
| `openclawCron` | cron OpenClaw `agentTurn` | ~24k/cycle (0 $ sur modèle gratuit) | Écosystème OpenClaw |

### Changer de mode à chaud

```powershell
# dans TDB\scripts\
powershell -ExecutionPolicy Bypass -File configure.ps1 -Mode manual
powershell -ExecutionPolicy Bypass -File configure.ps1 -Mode taskScheduler -IntervalMinutes 10
powershell -ExecutionPolicy Bypass -File configure.ps1 -Mode openclawCron
powershell -ExecutionPolicy Bypass -File configure.ps1 -Show        # état actuel
```

`configure.ps1` écrit `openclaw-tdb\config.local.json` (jamais committé).
La collecte suivante applique le mode et le badge en haut du TDB l'affiche.

### Mode taskScheduler

```powershell
powershell -ExecutionPolicy Bypass -File scripts\register-task.ps1 -IntervalMinutes 5
powershell -ExecutionPolicy Bypass -File scripts\unregister-task.ps1   # suppression
```
Tâche créée : `AutCLW-TDB-Collect` (visible dans le Planificateur Windows).

### Mode cron OpenClaw

Créer un job `sessionTarget: "isolated"`, `schedule` = every N min,
`delivery: { mode: "none" }`, et un `payload.message` du type :

```
Exécute via exec exactement cette commande :
powershell -NoProfile -ExecutionPolicy Bypass -File "<chemin>\collect.ps1"
Réponds uniquement : TDB OK <ts> (ou TDB PARTIEL <sortie>).
```

Un `payload.model` peut cibler un modèle local Ollama (ex.
`ollama/qwen3.5:0.8b` avec `params.thinking: false` et `num_ctx` aligné —
les petits modèles Qwen « thinking » dépensent leur budget en raisonnement
caché sinon). Voir la doc OpenClaw (`automation/cron-jobs`,
`providers/ollama`) et `gateway/local-models.md`.

## Collecte manuelle

Double-cliquer **`openclaw-tdb\collect.bat`** : collecte puis ouverture du TDB.
Le bouton **⟳ Synchroniser** (en haut de la page) relit les fichiers
`telemetry/` immédiatement et surveille l'arrivée d'un nouveau snapshot
(60 s) si une collecte est en cours ailleurs.

## Lecture du tableau de bord

- **Panneau d'aide** (en haut) : rappel des modes, purge et vie privée —
  repliable, l'état est mémorisé.
- **Filtre de période** (1 h / 6 h / 24 h / 7 j / tout) : s'applique aux cartes
  de totaux, aux graphiques « par modèle » et « par heure », et au journal.
  En mode « tout », les cartes affichent les **statistiques cumulées**
  (`stats-aggregates.json`), qui survivent à la purge des journaux.
- **Journal des actions** : navigation par lots de 50 (⏮ ◀ ▶ ⏭). Chaque ligne
  décrit une réponse de modèle : tâche d'origine, outils appelés, agent,
  provider/modèle, durée, tokens, état (✅ terminé · 🔧 outils · ⛔ interrompu ·
  ❌ erreur).

## Règles de purge (appliquées à chaque collecte)

| Donnée | Rétention | Effet d'une purge |
|---|---|---|
| `journal.js` (actions détaillées) | 7 jours glissants, plafond 400 actions | Seule la liste détaillée rétrécit |
| `history.jsonl` (snapshots session) | 30 jours | Historique fin des tokens session |
| `stats-aggregates.json` | **jamais purgée** | Totaux globaux intacts (tokens, requêtes, événements, par modèle) |

Les valeurs agrégées sont incrémentées **avant** toute purge : les totaux
globaux ne baissent jamais. Réglages : clés `journalMax`, `journalDays`,
`historyMaxDays` de `config.local.json`.

## Désinstallation

Mode `taskScheduler` : `scripts\unregister-task.ps1`, puis supprimer le
dossier du projet. OpenClaw et ses données ne sont pas modifiés.

## Comptabilité des tokens

Le TDB distingue désormais :

- **Tokens rapportés** : `usage.totalTokens` fourni par le provider ;
- **Tokens inconnus** : requêtes dont le provider ne transmet pas d'usage (affichées comme `—`, jamais comme `0`) ;
- **Tokens cumulés** : somme historique des tokens rapportés uniquement.

Les providers peuvent ne pas exposer les métriques d'usage. Ces requêtes restent comptées dans les requêtes/événements, mais ne sont pas ajoutées au total de tokens. La carte « Tokens inconnus » permet de les identifier.
