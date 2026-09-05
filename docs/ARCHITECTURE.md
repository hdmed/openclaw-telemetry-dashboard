# Architecture

## Vue d'ensemble

```text
┌────────────────────────────┐
│  OpenClaw Gateway (local)  │
│  - CLI status --json       │
│  - transcripts sessions    │
└──────────┬─────────────────┘
           │ (lecture seule)
           ▼
┌────────────────────────────┐        toutes les 5 min (cron) ou
│  collect.ps1 (déterministe)│        double-clic collect.bat
│  1. status --json          │
│  2. parse transcripts      │
│  3. agrège les stats       │
│  4. purge l'ancien         │
└──────────┬─────────────────┘
           │ écrit
           ▼
┌────────────────────────────┐
│  openclaw-tdb/telemetry/   │
│  latest.js                 │  snapshot session (tokens, cache…)
│  journal.js                │  actions détaillées + buckets horaires
│  aggregates.js             │  totaux cumulés (purge-proof)
│  history.jsonl             │  historique fin (30 j)
│  stats-aggregates.json     │  même objet, format JSON brut
└──────────┬─────────────────┘
           │ <script src> rechargé
           ▼
┌────────────────────────────┐
│  index.html (TDB)          │
│  - localStorage (tendance) │
│  - relecture toutes les 60s│
└────────────────────────────┘
```

## Pourquoi des fichiers `.js` ?

La page est ouverte en `file://` : le navigateur interdit `fetch()` sur des
fichiers locaux (CORS). En revanche, injecter dynamiquement des balises
`<script src="telemetry/latest.js?ts=…">` fonctionne : chaque fichier de
données est un simple assignement global (`window.TDB_REMOTE = {…}`). Le
cache-busting (`?ts=`) force la relecture disque.

## Comptabilité des statistiques cumulées

Les totaux « depuis toujours » doivent survivre à la purge. Principe :

- le journal est **reconstruit** à chaque collecte depuis les transcripts
  (fenêtre 7 jours, plafond 400 actions) → les mêmes entrées réapparaissent ;
- `stats-aggregates.json` garde `lastAggregatedTs` : à chaque collecte, seules
  les entrées **strictement postérieures** sont ajoutées aux totaux
  (tokens, requêtes, répartition par modèle, première/dernière action) ;
- pour les « événements » (messages transcript, y compris utilisateur/outils),
  les buckets horaires sont comparés à la valeur déjà comptabilisée pour le
  même bucket → seuls les **deltas positifs** sont ajoutés
  (`eventsTotal` monotone).

Résultat : purger `journal.js` / `history.jsonl` ne fait jamais baisser les
totaux globaux.

## Compatibilité petits modèles locaux

Le collecteur ne fait **aucun** appel LLM : c'est un script pur. Si vous
automatisez via un cron OpenClaw `agentTurn`, le modèle choisi ne sert qu'à
« exécuter le script et répondre TDB OK ». Les petits modèles locaux
(Ollama type qwen3.5:0.8b) conviennent, avec `params.thinking: false` et
`num_ctx` aligné sur la fenêtre du prompt cron (~24k tokens de contexte
système + overhead). La doc OpenClaw recommande également
`agents.defaults.experimental.localModelLean: true` pour les petits modèles.

## Fichiers

| Fichier | Rôle |
|---|---|
| `openclaw-tdb/index.html` | Le tableau de bord (autonome, Chart.js via CDN) |
| `openclaw-tdb/collect.ps1` | Collecteur déterministe |
| `openclaw-tdb/collect.bat` | Lanceur double-clic (collecte + ouverture) |
| `openclaw-tdb/telemetry/` | Données d'exécution (gitignore) |
| `openclaw-tdb/sample-data/` | Jeu de démonstration fictif |
| `scripts/install.ps1` | Installation sur une nouvelle machine |
| `tests/smoke-test.ps1` | Vérification post-installation |
