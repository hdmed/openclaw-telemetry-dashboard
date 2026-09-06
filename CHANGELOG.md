# Changelog

## 0.2.1 — 2026-09-06

### Corrigé
- **`eventsTotal`** : le compteur d'événements cumulés était gonflé à chaque
  collecte (logique delta s'appuyant sur `hours`, jamais persisté dans
  `stats-aggregates.json`). Il est désormais recalculé comme la somme de
  l'historique horaire immortel (auto-réparation au premier run).
- **`journalMax`** redevient effectif (plafond de publication du journal,
  défaut 400) ; l'agrégation des totaux reste calculée sur le journal complet.
- **Session principale** : sélection restreinte aux sessions à compteurs frais
  (`totalTokensFresh`) — plus de KPI à `null` selon la session sondée.
- **`channels`** : itération sur les éléments de `channelSummary` au lieu des
  propriétés du tableau (qui auraient affiché `Count, Length, …`).
- **`cronsTotal`** : compté sur toutes les sessions récentes (avant exclusion
  des sessions cron), au lieu de rester à 0.
- **i18n** : les attributs `data-i18n-html`, ignorés par le moteur, sont
  convertis en `data-i18n` (titre, sous-titre, aide, 2 graphiques) ;
  nettoyage de `tApply` (badge de rafraîchissement via `renderMeta()`),
  fusion des deux blocs d'initialisation langue, `tSetLang` sans re-render
  risqué quand l'historique navigateur est vide.
- Garde anti-boucle infinie sur le retrait des `<system-reminder>` non fermés.

### Ajouté
- `runtimeVersion` dans le snapshot ; le badge Gateway de l'UI est alimenté
  par la donnée (plus de version codée en dur).
- Toasts d'attente adaptés au mode de rafraîchissement (`telemetry/meta.js`).

### Modifié
- Clé localStorage `***` → `tdb_hist_v1` (l'ancien historique navigateur est
  abandonné) ; version affichée : v0.2.1.

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
