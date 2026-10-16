# ============================================================
# LKCA Monitor Analyseproces
#
# ⚠ JE HOEFT IN DIT BESTAND NIETS AAN TE PASSEN.
#   Het enige bestand dat je aanpast is
#   "03_config.R".
#
# Klik hierboven op Source of druk Ctrl+Shift+S
# om de analyse te starten.
#
# De pipeline doet automatisch:
# 1. Data en metadata inlezen
# 2. Input controleren (validatie)
# 3. Analyse uitvoeren
# 4. Rapport maken
# 5. Alles archiveren
#
# ⚠ Niet draaien vanuit OneDrive/SharePoint/SURFdrive-sync.
# ⚠ Open dit project altijd via het .Rproj-bestand (02_).
# ============================================================

if (!requireNamespace("monitoranalyse", quietly = TRUE)) {
  stop(
    "Het package 'monitoranalyse' is nog niet geïnstalleerd.\n",
    "Installeer het eenmalig met de twee opdrachten in 00_handleiding.md,\n",
    "sectie 'Installatie (eenmalig)'. Die staan ook op\n",
    "  https://github.com/alex-janse/monitoranalyse"
  )
}

monitoranalyse::run_project("03_config.R")
