# =============================================================================
# run_project.R
# Entry point van de pipeline: doet wat 04_run_project.R in v1.x deed.
#
# De pipeline doet automatisch:
# 1. Configuratie inlezen (03_config.R)
# 2. Data en metadata inlezen
# 3. Input controleren (validatie)
# 4. Analyse uitvoeren
# 5. Rapport maken (Quarto)
# 6. Alles archiveren (datapackage_<ts>/)
# =============================================================================

#' Draai de volledige analyse voor een projectmap
#'
#' Leest `03_config.R`, valideert data en metadata, bouwt het analyseobject,
#' maakt het HTML-rapport en archiveert alles in
#' `05_output/datapackage_<tijdstempel>/`. Dit is wat `04_run_project.R` in
#' een projectmap aanroept.
#'
#' Alle relatieve paden in `03_config.R` (zoals `"01_data/..."`) gelden vanaf
#' de map waarin `03_config.R` staat.
#'
#' @param config Pad naar het configuratiebestand. Standaard `"03_config.R"`
#'   in de huidige werkmap (de projectmap als je het `.Rproj`-bestand opent).
#' @param open_rapport Rapport na afloop openen in de browser. Standaard
#'   alleen in een interactieve sessie (dus niet bij `Rscript`).
#' @return Onzichtbaar een lijst met `rapport` (pad naar de HTML),
#'   `datapackage` (pad naar de archiefmap) en `analyseobject`.
#' @export
#' @examples
#' \dontrun{
#' monitoranalyse::run_project()
#' }
run_project <- function(config = "03_config.R", open_rapport = interactive()) {
  # ---- Werkmap-controle -----------------------------------------------------
  if (!file.exists(config)) {
    stop(
      "\n[FOUT] Het bestand '", config, "' is niet gevonden in de werkmap:\n  ",
      getwd(), "\n\n",
      "Open dit project via het .Rproj-bestand (02_Analyseproces.Rproj) in ",
      "RStudio,\nen niet via een los scriptbestand. Daarmee staat de werkmap ",
      "goed.",
      call. = FALSE
    )
  }
  project_map <- normalizePath(dirname(config), winslash = "/")
  oude_werkmap <- setwd(project_map)
  on.exit(setwd(oude_werkmap), add = TRUE)

  # ---- Quarto aanwezig? ------------------------------------------------------
  controleer_quarto()

  # ---- Configuratie inlezen -------------------------------------------------
  cfg <- lees_config(basename(config))
  controleer_engine_versie(cfg$engine_versie)

  # ---- Tijdstempel voor bestandsnamen ---------------------------------------
  time_stempel <- format(Sys.time(), "%Y-%m-%d_%H%M")

  html_bestand <- file.path(
    "05_output",
    paste0("analyse-output_", time_stempel, ".html")
  )
  archief_map <- file.path("05_output", paste0("datapackage_", time_stempel))

  # ---- Logs-directory aanmaken ----------------------------------------------
  dir.create(
    file.path(archief_map, "logs"),
    showWarnings = FALSE,
    recursive = TRUE
  )

  # ---- Session-info vastleggen (vóór alles, voor reproduceerbaarheid) --------
  writeLines(
    capture.output(sessionInfo()),
    file.path(archief_map, "logs", "session_info.txt")
  )
  message("Session-info opgeslagen in ", archief_map, "/logs")

  # ---- Data en metadata laden -----------------------------------------------
  data <- read_data(cfg$input_sav)
  meta <- read_metadata(cfg$metadata_file)

  # ---- Inputvalidatie -------------------------------------------------------
  audit_log <- validate_input(
    data,
    meta,
    kleine_n_drempel = cfg$kleine_n_drempel,
    resp_id_col = cfg$resp_id_col
  )

  # ---- Stoppen bij blokkerende fouten ---------------------------------------
  # Alleen fouten waar de analyse niet zonder kan (zie validate_input.R).
  # Overige fouten verschijnen in het rapport (Overzicht > Validatielog).
  stop_bij_blokkerende_fout(audit_log, file.path(archief_map, "logs"))

  # ---- Analyse --------------------------------------------------------------
  obj <- analyse_dataset(
    data,
    meta,
    sav_pad = cfg$input_sav,
    meta_pad = cfg$metadata_file,
    resp_id_col = cfg$resp_id_col,
    kruis_vars = cfg$kruis_vars
  )

  # ---- Logging --------------------------------------------------------------
  logging(
    obj,
    audit_log,
    archief_pad = file.path(archief_map, "logs"),
    meta_pad = cfg$metadata_file
  )

  # ---- Rapport genereren ----------------------------------------------------
  message("Rapport genereren...")
  render_rapport(
    html_bestand = html_bestand,
    project_naam = cfg$project_naam,
    analyse_object = file.path(archief_map, "logs", "analyse_object.rds"),
    audit_log = file.path(archief_map, "logs", "audit_log.rds"),
    pct_decimalen = cfg$pct_decimalen,
    stat_decimalen = cfg$stat_decimalen,
    resp_id_col = cfg$resp_id_col,
    logo_bestand = cfg$logo_bestand
  )

  # ---- Archief uitbreiden: volledige projectkloon + engine -------------------
  # Clone het hele project, behalve bestaande datapackage-mappen en rommelbestanden
  clone_project(
    ".",
    archief_map,
    "^(datapackage_.*|\\.Rproj\\.user|\\.Rhistory|\\.RData)$"
  )
  archiveer_engine(archief_map)

  message("Projectkloon opgeslagen in ", archief_map)

  # ---- Klaar ----------------------------------------------------------------
  message("\n\n")
  message("============================================================")
  message("  RAPPORT GEGENEREERD")
  message("============================================================")
  message("")
  message("  VOLGENDE STAP: het rapport staat in 05_output/")
  message("  Archiefbestanden staan in ", archief_map)
  message("  (open ", basename(html_bestand), " in Chrome of Edge)")
  message("")
  message("  CONTROLEER NU:")
  message("  1. Overzicht-tab: kloppen de projectgegevens?")
  message("  2. Validatielog: zijn er rode fouten? Die moet je eerst")
  message("     oplossen. Gele waarschuwingen? Beoordeel of ze terecht zijn.")
  message("  3. Rechte tellingen: kloppen de vragen, labels en aantallen?")
  message("  4. Kruisingen (als aangezet): zijn subgroepen logisch?")
  message("  5. Open antwoorden: staat er geen privacygevoelige tekst in?")
  message("")
  message("  Meer uitleg: open 00_handleiding.md bij 'Rapport controleren'.")
  message("============================================================\n\n")

  if (isTRUE(open_rapport)) {
    utils::browseURL(normalizePath(html_bestand))
  }

  invisible(list(
    rapport = normalizePath(html_bestand, winslash = "/"),
    datapackage = normalizePath(archief_map, winslash = "/"),
    analyseobject = obj
  ))
}

# =============================================================================
# Hulpfuncties
# =============================================================================

#' Lees 03_config.R in een eigen omgeving en vul standaardwaarden aan
#'
#' @param pad Pad naar 03_config.R (relatief aan de projectmap)
#' @return Lijst met alle instellingen
#' @noRd
lees_config <- function(pad) {
  env <- new.env(parent = baseenv())
  tryCatch(
    sys.source(pad, envir = env, keep.source = FALSE),
    error = function(e) {
      stop(
        "\n[FOUT] '", pad, "' bevat een fout en kan niet worden gelezen:\n  ",
        conditionMessage(e), "\n\n",
        "Controleer of alle aanhalingstekens en haakjes kloppen.",
        call. = FALSE
      )
    }
  )
  cfg <- as.list(env)

  # ---- Standaardwaarden (zoals in de v1.x-config) ----------------------------
  standaard <- list(
    resp_id_col = "ID",
    kruis_vars = list(),
    pct_decimalen = 0,
    stat_decimalen = 1,
    kleine_n_drempel = 10,
    engine_versie = NULL,
    logo_bestand = NULL
  )
  for (n in names(standaard)) {
    if (is.null(cfg[[n]])) cfg[n] <- list(standaard[[n]])
  }

  # ---- Verplichte instellingen ----------------------------------------------
  if (is.null(cfg$project_naam) || !nzchar(cfg$project_naam)) {
    stop(
      "\n[FOUT] project_naam is niet ingevuld in ", pad, ".\n",
      "Vul bovenaan ", pad, " de naam van je project in, bijvoorbeeld:\n",
      "  project_naam <- \"Monitor Poppodia 2026\"",
      call. = FALSE
    )
  }
  controleer_invoerbestand(cfg$input_sav, "input_sav", "het SPSS-bestand (.sav)", pad)
  controleer_invoerbestand(cfg$metadata_file, "metadata_file", "het metadata-bestand", pad)

  if (!is.null(cfg$logo_bestand) && nzchar(cfg$logo_bestand) &&
    !file.exists(cfg$logo_bestand)) {
    warning(
      "Logo niet gevonden: ", cfg$logo_bestand, " \u2014 het rapport wordt ",
      "zonder logo gemaakt. Controleer logo_bestand in ", pad, ".",
      call. = FALSE,
      immediate. = TRUE
    )
    cfg$logo_bestand <- NULL
  }

  cfg
}

#' Controleer dat een invoerbestand uit de config is ingevuld en bestaat
#' @noRd
controleer_invoerbestand <- function(pad, naam, omschrijving, config_pad) {
  if (is.null(pad) || !nzchar(pad) || dir.exists(pad)) {
    stop(
      "\n[FOUT] ", naam, " is niet (volledig) ingevuld in ", config_pad, ".\n",
      "Vul de bestandsnaam van ", omschrijving, " in, inclusief de map, ",
      "bijvoorbeeld:\n",
      "  ", naam, " <- \"01_data/mijnbestand", if (naam == "input_sav") ".sav" else ".xlsx",
      "\"",
      call. = FALSE
    )
  }
  if (!file.exists(pad)) {
    in_map <- list.files(dirname(pad))
    stop(
      "\n[FOUT] Het bestand '", pad, "' (", naam, " in ", config_pad,
      ") bestaat niet.\n",
      if (length(in_map) > 0) {
        paste0(
          "In de map '", dirname(pad), "' staan:\n  ",
          paste(in_map, collapse = "\n  "), "\n"
        )
      },
      "Controleer de spelling van de bestandsnaam (inclusief extensie).",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

#' Stop de pipeline als de validatie een blokkerende fout bevat
#'
#' Schrijft eerst audit_log.rds en run_log.txt weg (zodat er een spoor is)
#' en stopt dan met een Nederlandse melding: welke controle faalde en wat de
#' gebruiker moet doen.
#'
#' @param audit_log Audit_log van validate_input()
#' @param logs_map  Map voor de logbestanden van deze run
#' @noRd
stop_bij_blokkerende_fout <- function(audit_log, logs_map) {
  if (!"blokkerend" %in% names(audit_log)) {
    return(invisible(TRUE))
  }
  blok <- audit_log[audit_log$status == "FOUT" & audit_log$blokkerend %in% TRUE, ]
  if (nrow(blok) == 0) {
    return(invisible(TRUE))
  }

  meldingen <- paste0(
    "  \u2716 ", blok$domein, " \u2014 ", blok$controle, "\n",
    "    ", blok$detail,
    collapse = "\n\n"
  )

  saveRDS(audit_log, file.path(logs_map, "audit_log.rds"))
  writeLines(
    c(
      "LKCA Monitor \u2014 Run-log",
      "======================",
      paste0("Aangemaakt op:    ", format(Sys.time(), "%d-%m-%Y %H:%M:%S")),
      "",
      "RUN GESTOPT na de inputvalidatie wegens blokkerende fout(en):",
      "",
      meldingen,
      "",
      "--- Validatiedetails ---",
      capture.output(print(audit_log, n = Inf))
    ),
    file.path(logs_map, "run_log.txt")
  )

  stop(
    "\n\n============================================================\n",
    "  ANALYSE GESTOPT: kritieke fout in de invoer\n",
    "============================================================\n\n",
    meldingen, "\n\n",
    "Wat moet je doen?\n",
    "  1. Los bovenstaande fout op (meestal in 03_config.R).\n",
    "  2. Sla 03_config.R op en draai 04_run_project.R opnieuw\n",
    "     (Source of Ctrl+Shift+S).\n\n",
    "Er is geen rapport gemaakt. De validatiedetails staan in\n  ",
    file.path(logs_map, "run_log.txt"), "\n",
    call. = FALSE
  )
}

#' Controleer of Quarto beschikbaar is
#' @noRd
controleer_quarto <- function() {
  pad <- tryCatch(quarto::quarto_path(), error = function(e) NULL)
  if (is.null(pad) || !nzchar(pad)) {
    stop(
      "\n[FOUT] Quarto is niet gevonden. Quarto is nodig om het rapport te ",
      "maken.\n\n",
      "Oplossing:\n",
      "  - Werk je in RStudio? Installeer dan een recente versie van RStudio\n",
      "    (Quarto wordt daarmee meegeleverd) en start RStudio opnieuw.\n",
      "  - Of installeer Quarto los via https://quarto.org/docs/get-started/\n",
      "    en start RStudio daarna opnieuw.",
      call. = FALSE
    )
  }
  invisible(pad)
}

#' Render rapport.qmd in een tijdelijke map en verplaats het resultaat
#'
#' De installatiemap van het package kan alleen-lezen zijn en spaties
#' bevatten. Daarom wordt inst/rapport/ eerst naar een tijdelijke map
#' gekopieerd. Alle paden gaan als ABSOLUUT pad naar Quarto: Quarto rendert
#' vanuit de map van het .qmd-bestand (zie lessen uit v1.0.0).
#'
#' @noRd
render_rapport <- function(
  html_bestand,
  project_naam,
  analyse_object,
  audit_log,
  pct_decimalen,
  stat_decimalen,
  resp_id_col,
  logo_bestand = NULL
) {
  render_map <- tempfile("monitoranalyse_rapport_")
  dir.create(render_map)
  on.exit(unlink(render_map, recursive = TRUE), add = TRUE)

  rapport_bron <- system.file("rapport", package = "monitoranalyse")
  file.copy(
    list.files(rapport_bron, full.names = TRUE),
    render_map,
    recursive = TRUE
  )

  quarto::quarto_render(
    input = file.path(render_map, "rapport.qmd"),
    execute_params = list(
      project_naam = project_naam,
      analyse_object = normalizePath(analyse_object),
      audit_log = normalizePath(audit_log),
      pct_decimalen = pct_decimalen,
      stat_decimalen = stat_decimalen,
      resp_id_col = resp_id_col,
      logo_bestand = if (is.null(logo_bestand)) "" else normalizePath(logo_bestand)
    ),
    output_file = "rapport.html"
  )

  # Rapport verplaatsen naar 05_output/ (direct, niet in submap)
  rapport_bron <- file.path(render_map, "rapport.html")
  if (!file.exists(rapport_bron)) {
    stop(
      "\n[FOUT] Het rapport is niet aangemaakt. Bekijk de meldingen van ",
      "Quarto hierboven voor de oorzaak.",
      call. = FALSE
    )
  }
  dir.create(dirname(html_bestand), showWarnings = FALSE, recursive = TRUE)
  file.copy(rapport_bron, html_bestand, overwrite = TRUE)
  invisible(html_bestand)
}

#' Kopieer het hele project recursief, met uitsluiting van een patroon
#' @noRd
clone_project <- function(src_dir, dest_dir, exclude_pattern) {
  items <- list.files(src_dir, all.files = TRUE, no.. = TRUE)
  items <- items[!grepl(exclude_pattern, items)]
  for (item in items) {
    src <- file.path(src_dir, item)
    dst <- file.path(dest_dir, item)
    if (dir.exists(src)) {
      dir.create(dst, showWarnings = FALSE, recursive = TRUE)
      clone_project(src, dst, exclude_pattern)
    } else {
      file.copy(src, dst, overwrite = TRUE)
    }
  }
}
