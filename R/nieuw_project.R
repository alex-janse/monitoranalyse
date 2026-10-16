# =============================================================================
# nieuw_project.R
# Maakt een nieuwe projectmap uit het sjabloon in inst/template/.
# =============================================================================

#' Maak een nieuwe projectmap
#'
#' Kopieert het projectsjabloon (handleiding, `01_data/`, `.Rproj`,
#' `03_config.R`, `04_run_project.R`) naar `pad`. In `03_config.R` wordt
#' `engine_versie` ingevuld met de geïnstalleerde versie van dit package.
#'
#' Een bestaande map die niet leeg is wordt geweigerd, zodat je nooit per
#' ongeluk een bestaand project overschrijft.
#'
#' @param pad Pad van de nieuwe projectmap, bijvoorbeeld
#'   `"C:/Projecten/Monitor Poppodia 2026"`. Bij voorkeur niet in een
#'   OneDrive/SharePoint-map.
#' @return Onzichtbaar het volledige pad van de nieuwe projectmap.
#' @export
#' @examples
#' \dontrun{
#' monitoranalyse::nieuw_project("C:/Projecten/Monitor Poppodia 2026")
#' }
nieuw_project <- function(pad) {
  if (missing(pad) || !is.character(pad) || length(pad) != 1 || !nzchar(pad)) {
    stop(
      "\n[FOUT] Geef het pad van de nieuwe projectmap op, bijvoorbeeld:\n",
      "  monitoranalyse::nieuw_project(\"C:/Projecten/Monitor Poppodia 2026\")",
      call. = FALSE
    )
  }
  if (dir.exists(pad) &&
    length(list.files(pad, all.files = TRUE, no.. = TRUE)) > 0) {
    stop(
      "\n[FOUT] De map '", pad, "' bestaat al en is niet leeg.\n",
      "Kies een nieuwe (of lege) map, zodat er niets wordt overschreven.",
      call. = FALSE
    )
  }
  if (file.exists(pad) && !dir.exists(pad)) {
    stop("\n[FOUT] '", pad, "' is een bestand, geen map.", call. = FALSE)
  }

  dir.create(pad, recursive = TRUE, showWarnings = FALSE)

  # ---- Sjabloon kopiëren -----------------------------------------------------
  bron <- system.file("template", package = "monitoranalyse")
  gelukt <- file.copy(
    list.files(bron, full.names = TRUE, all.files = TRUE, no.. = TRUE),
    pad,
    recursive = TRUE
  )
  if (!all(gelukt)) {
    stop(
      "\n[FOUT] Niet alle sjabloonbestanden konden worden gekopieerd naar '",
      pad, "'. Controleer of je schrijfrechten hebt in die map.",
      call. = FALSE
    )
  }
  dir.create(file.path(pad, "05_output"), showWarnings = FALSE)

  # ---- engine_versie invullen in 03_config.R ----------------------------------
  config_pad <- file.path(pad, "03_config.R")
  config <- readLines(config_pad, encoding = "UTF-8", warn = FALSE)
  config <- sub(
    "^engine_versie <- .*$",
    paste0("engine_versie <- \"", engine_info()$versie, "\""),
    config
  )
  writeLines(config, config_pad, useBytes = TRUE)

  pad <- normalizePath(pad, winslash = "/")
  message(
    "Nieuwe projectmap aangemaakt: ", pad, "\n\n",
    "Volgende stappen:\n",
    "  1. Zet je opgeschoonde .sav-bestand en metadata in 01_data/\n",
    "  2. Open 02_Analyseproces.Rproj (RStudio opent dan in deze map)\n",
    "  3. Vul in 03_config.R de 3 regels in\n",
    "  4. Open 04_run_project.R en klik op Source (Ctrl+Shift+S)\n\n",
    "Meer uitleg: 00_handleiding.md in de projectmap."
  )
  invisible(pad)
}
