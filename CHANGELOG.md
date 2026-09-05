# Changelog

## 0.2.0 — 2026-09-05

### Ajouté
- **Choix du mode de rafraîchissement** à l'installation (menu interactif) :
  `manual` (défaut, 0 token) · `taskScheduler` (0 token, automatique) ·
  `openclawCron` (flexible)
- `scripts/configure.ps1` : changement de mode à chaud via
  `config.local.json` (jamais committé)
- `scripts/register-task.ps1` / `unregister-task.ps1` : gestion de la tâche
  Windows `AutCLW-TDB-Collect`
- `config.example.json` : modèle documenté de toutes les clés
- **Bouton ⟳ Synchroniser déplacé en haut de la page** (badge de mode actif
  à côté : lu depuis `telemetry/meta.js`)
- **Panneau d'aide intégré en haut de la page** (repliable, état mémorisé) :
  collecte, modes, purge, vie privée, renvois vers la documentation
- `telemetry/meta.js` : mode + intervalle exposés au TDB

### Modifié
- Badge « Collecte auto · 5 min » remplacé par un badge dynamique de mode
- Pied de page allégé (le bouton et l'aide sont montés en haut)

## 0.1.0 — 2026-09-05

### Ajouté
- Tableau de bord HTML autonome : KPI (tokens, coût, cache, contexte), cartes de totaux
  avec filtre de période (1 h / 6 h / 24 h / 7 j / tout), graphiques Chart.js
  (tokens, cache, contexte, répartition par modèle, activité horaire)
- Journal des actions paginé (50 par page) : tâche, action, agent, provider/modèle,
  durée, tokens, état de complétion
- Collecteur déterministe `collect.ps1` (aucune interprétation LLM requise)
  + `collect.bat` double-clic Windows (collecte + ouverture du TDB)
- Statistiques cumulées persistantes (`stats-aggregates.json`) : les totaux globaux
  survivent à la purge des journaux détaillés
- Documentation INSTALL / USAGE / ARCHITECTURE, script d'installation, test de fumée
- Données d'exemple (`sample-data/`) pour prévisualiser sans OpenClaw
