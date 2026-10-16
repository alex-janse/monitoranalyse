# ============================================================
# 03_config.R — PROJECTCONFIGURATIE
#
# Dit is het enige bestand dat je hoeft aan te passen.
# Vul hieronder je projectgegevens in. Open daarna
# "04_run_project.R" en klik op
# Source (of Ctrl+Shift+S).
# ============================================================

# ============================================================
# DIT MOET JE AANPASSEN (3 regels)
# ============================================================

# De naam van je project — verschijnt bovenaan het rapport
project_naam <- ""

# De bestandsnaam van je opgeschoonde SPSS-bestand
# (zet het bestand in de map "01_data")
input_sav <- "01_data/"

# De bestandsnaam van je metadata-bestand
# (mag .xlsx, .xls of .csv zijn)
metadata_file <- "01_data/"


# ============================================================
# DIT MAG JE LATEN STAAN (of aanpassen als je weet wat je doet)
# ============================================================

# Kolomnaam van het respondent-ID in je data
# (wordt gebruikt in de Open antwoorden-tab en de kruisingen van het rapport)
# LET OP: dit moet PRECIES gelijk zijn aan de kolomnaam in het .sav-bestand,
# inclusief hoofdletters en kleine letters. Heet de kolom bijvoorbeeld
# "respid", vul dan in: resp_id_col <- "respid"
# Staat de kolom niet in de data, dan stopt de analyse met een melding en
# een suggestie voor de juiste naam.
resp_id_col <- "ID"

# Achtergrondvariabelen voor kruisingen
# Voorbeeld met één kruisvariabele:
#   kruis_vars <- list(gemeentegrootte_3cat = "Gemeentegrootte")
# Wil je geen kruisingen? Laat de lijst leeg:
kruis_vars <- list()

# Percentage decimalen in het rapport
# 0 = hele getallen (bijv. "43%"), 1 = één decimaal (bijv. "42.5%")
# LET OP: laat dit op 0 en 1 staan voor monitoren met eerder gepubliceerde
# cijfers (PDF's, dashboard), anders sluiten nieuwe meetjaren niet aan.
pct_decimalen <- 0

# Decimalen voor beschrijvende statistieken (gemiddelde, mediaan)
stat_decimalen <- 1

# Drempel voor kleine-N waarschuwing
# Bij minder dan dit aantal respondenten krijg je een waarschuwing
kleine_n_drempel <- 10

# Logo onderaan het rapport (optioneel). Het logo zit niet in het package;
# zet het logobestand bijvoorbeeld in 01_data/ en vul het pad in:
#   logo_bestand <- "01_data/LKCA_logo.jpg"
# Laat op NULL staan voor een rapport zonder logo.
logo_bestand <- NULL

# Engineversie waarmee dit project is gemaakt (automatisch ingevuld door
# monitoranalyse::nieuw_project()). Wijkt de geïnstalleerde versie af, dan
# krijg je een waarschuwing. Zo weet je dat cijfers kunnen afwijken van
# eerdere runs. Zet op NULL om de controle uit te zetten.
engine_versie <- NULL
