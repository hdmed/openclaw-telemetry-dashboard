/* TDB - Traduction francaise (source / fallback)
 * Cles = data-i18n="KEY" dans index.html, ou t("KEY") dans le JS.
 * Charge via <script src="i18n/fr.js"> puis window.TDB_I18N = {...}
 * Ne JAMAIS modifier les cles, uniquement les valeurs (additif uniquement).
 */
window.TDB_I18N = {
  meta: { lang: "fr", name: "Français", dir: "ltr" },

  // Header / selecteur
  "header.title": "OpenClaw · TDB Télémétrie",
  "header.subtitle": "agents · tokens · coût · activité",
  "header.refresh.unknown": "⏱ rafraîchissement : —",
  "header.lastCollection": "🕐 dernière collecte : —",
  "header.freshness.ok": "temps réel",
  "header.freshness.warn": "données anciennes",
  "header.freshness.bad": "⚠️ collecte bloquée",
  "header.freshness.init": "initialisation…",
  "header.refreshMode.manual": "manuel",
  "header.refreshMode.taskScheduler": "Task Scheduler",
  "header.refreshMode.openclawCron": "cron OpenClaw",
  "header.lang.label": "🌐",

  // Bouton sync
  "btn.sync": "⟳ Synchroniser",
  "btn.sync.now": "⟳ Synchroniser (collecte immédiate)",
  "btn.sync.busy": "⟳ …",
  "btn.sync.collecting": "⏳ collecte…",
  "btn.sync.upToDate": "✓ à jour",

  // Panneau d'aide
  "help.title": "📖 Aide — rafraîchissement & données",
  "help.toggle.hide": "masquer",
  "help.toggle.show": "afficher",
  "help.line1": "▶ <b>Collecter</b> : double-cliquez <span style=\"font-family:var(--mono)\">collect.bat</span> (collecte + ouverture du TDB). La page relit les données toutes les 60 s tant qu'elle est ouverte.",
  "help.line2": "🔁 <b>Rafraîchissement</b> — 3 modes au choix (modifiable à chaud via <span style=\"font-family:var(--mono)\">scripts\\configure.ps1</span>) : <b>manuel</b> (0 token, défaut) · <b>Task Scheduler</b> (0 token, automatique) · <b>cron OpenClaw</b> (flexible). Le badge en haut affiche le mode actif.",
  "help.line3": "🧮 <b>Statistiques cumulées</b> : en filtre « tout », les cartes affichent les totaux depuis la première utilisation (<span style=\"font-family:var(--mono)\">stats-aggregates.json</span>) — ils survivent à la purge (journal 7 j / 400 actions, history 30 j).",
  "help.line4": "🔒 <b>Vie privée</b> : <span style=\"font-family:var(--mono)\">telemetry/</span> reste local et hors dépôt (gitignore). Les données de démonstration sont dans <span style=\"font-family:var(--mono)\">sample-data/</span>.",
  "help.line5": "📚 <b>Docs complètes</b> : <span style=\"font-family:var(--mono)\">README.md</span> · <span style=\"font-family:var(--mono)\">docs/INSTALL.md</span> · <span style=\"font-family:var(--mono)\">docs/USAGE.md</span> · <span style=\"font-family:var(--mono)\">docs/ARCHITECTURE.md</span>",

  // Section totaux
  "period.title": "Totaux de la période",
  "period.chip.1h": "1 h",
  "period.chip.6h": "6 h",
  "period.chip.24h": "24 h",
  "period.chip.7j": "7 j",
  "period.chip.tout": "Tout",
  "period.cumul.since": "cumulés depuis le {date}",

  // KPI cards de totaux
  "kpi.totals.events": "⚡ Événements",
  "kpi.totals.events.sub": "messages traités",
  "kpi.totals.requests": "🔑 Requêtes",
  "kpi.totals.requests.sub": "appels aux modèles",
  "kpi.totals.tokens": "🧮 Tokens",
  "kpi.totals.tokens.sub": "total période",
  "kpi.totals.models": "🧠 Modèles",
  "kpi.totals.models.sub": "distincts utilisés",
  "kpi.totals.unknown": "❔ Tokens inconnus",
  "kpi.totals.unknown.sub": "requêtes sans usage provider",
  "kpi.totals.hours": "🕐 Heures enregistrées",
  "kpi.totals.hours.sub": "historique horaire immortel",

  // KPI cards de session
  "kpi.session.tokens": "Tokens cumulés",
  "kpi.session.tokens.sub": "+{n} tokens au dernier tour",
  "kpi.session.cost": "Coût cumulé",
  "kpi.session.cost.sub": "n/d si modèle gratuit / interne",
  "kpi.session.cache": "Cache hit",
  "kpi.session.cache.sub": "{n} tokens cachés",
  "kpi.session.context": "Contexte utilisé",
  "kpi.session.context.sub": "{used} / {limit}",
  "kpi.session.sessions": "Sessions actives",
  "kpi.session.sessions.sub": "{n} session(s) au total",
  "kpi.session.uptime": "Uptime gateway",
  "kpi.session.uptime.sub": "processus local",
  "kpi.session.agents": "👥 Agents configurés",
  "kpi.session.crons": "⏰ Tâches planifiées",
  "kpi.session.subagents": "🧩 Sous-agents actifs",
  "kpi.session.model": "🧠 Modèle courant",
  "kpi.session.compactions": "🧹 Compactions",
  "kpi.session.channels": "📡 Canaux",

  // Graphiques
  "chart.tokensTime": "Tokens dans le temps — cumul & dernier tour",
  "chart.cache": "Cache hit",
  "chart.context": "Contexte / fenêtre modèle",
  "chart.hourly": "Événements, requêtes & tokens par heure",
  "chart.model": "Répartition des tokens par modèle",
  "chart.fallback": "📊 Graphique indisponible (Chart.js CDN hors ligne) — les KPI et tableaux restent actifs.",
  "chart.fallback.short": "Graphique indisponible.",
  "center.cache": "cache hit",
  "center.context": "du contexte",

  // Tables
  "table.agents": "Agents configurés",
  "table.agents.id": "ID",
  "table.agents.name": "Nom",
  "table.agents.model": "Modèle",
  "table.agents.status": "Statut",
  "table.agents.active": "● actif",
  "table.agents.idle": "prêt",
  "table.sessions": "Sessions",
  "table.sessions.key": "Session",
  "table.sessions.channel": "Canal",
  "table.sessions.tokens": "Tokens",
  "table.sessions.cost": "Coût",
  "table.sessions.status": "Statut",

  // Journal
  "journal.title": "📜 Journal des actions",
  "journal.col.num": "#",
  "journal.col.time": "Heure",
  "journal.col.task": "Tâche (demande utilisateur)",
  "journal.col.action": "Action",
  "journal.col.agent": "Agent",
  "journal.col.model": "Provider / Modèle",
  "journal.col.duration": "Durée",
  "journal.col.tokens": "Tokens",
  "journal.col.state": "État",
  "journal.empty": "Aucune action enregistrée pour cette période.",
  "journal.total": "{n} action(s) au total · par lot de {batch}",
  "journal.pager.first": "⏮",
  "journal.pager.prev": "◀",
  "journal.pager.next": "▶",
  "journal.pager.last": "⏭",
  "journal.pager.info": "Page {p} / {n}",
  "journal.state.ok": "✅ terminé",
  "journal.state.tool": "🔧 outils",
  "journal.state.abort": "⛔ interrompu",
  "journal.state.error": "❌ erreur",

  // Toasts / messages
  "toast.noNew": "Pas de nouvelle collecte. Prochain cycle auto dans ≤ 5 min (ou demandez « sync TDB » dans le chat).",
  "toast.newLoad": "✅ Nouvelle collecte chargée — {time}",
  "toast.requested": "Demande envoyée : dites « sync TDB » dans le chat pour déclencher la collecte. Le bouton passera au vert dès le nouveau snapshot reçu.",
  "toast.timeout": "Aucune nouvelle collecte reçue en 60 s. Ré-essayez ou attendez le prochain cycle auto (≤ 5 min).",
  "toast.noData": "Aucune télémétrie disque trouvée (telemetry/latest.js).",
  "toast.applied": "✅ Nouvelle collecte appliquée ({time}).",
  "toast.fromLocal": "Données rechargées depuis l'historique local ({n} points). Collecte auto toutes les 5 min — ou demandez « sync TDB » dans le chat pour un rafraîchissement immédiat.",
  "toast.noDataYet": "Aucune donnée encore collectée.",

  // Overlay empty
  "empty.waiting": "⏳ En attente de la première collecte de télémétrie…",

  // Footer
  "footer.credit": "🦞 TDB v0.2.4 · données 100 % locales · <span style=\"font-family:var(--mono)\">telemetry/</span> hors dépôt Git · docs : README + docs\\",

  // Formattage dates
  "hero.liveTag": "temps réel",

  "chart.series.cumul": "Cumul session",

  "chart.series.turn": "Sortie / tour",

  "chart.series.events": "Événements",

  "chart.series.requests": "Requêtes",

  "chart.series.tokens": "Tokens",

  "fmt.age.now": "à l'instant",

  "fmt.age.min": "il y a {n} min",

  "table.sessions.active": "actif",

  "table.sessions.repos": "repos",

  "header.lastCollection.full": "🕐 dernière collecte : {time} ({age})",

  "kpi.totals.consumption": "🎯 Consommation",

  "kpi.totals.consumption.sub": "input + output (cache exclu)",

  "fmt.date.unknown": "—"
};
