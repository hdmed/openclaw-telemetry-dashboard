@echo off
rem ============================================
rem  TDB - Collecte manuelle + ouverture du TDB
rem  Double-clic : collecte puis navigateur
rem ============================================
cd /d "%~dp0"
echo [TDB] Collecte en cours...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0collect.ps1"
echo [TDB] Ouverture du tableau de bord...
start "" "%~dp0index.html"
