# =============================================================================
# engine_info.R
# Versie-informatie van de engine (dit package) en archivering van de engine
# in het datapackage, voor reproduceerbaarheid.
#
# In v1.x zat de volledige engine/ in elke projectmap en dus in elk
# datapackage. Sinds v2.0.0 is de engine een geïnstalleerd package; daarom
# legt elke run vast welke versie (en GitHub-commit) is gebruikt, en wordt
# een kopie van de engine in het datapackage gezet.
# =============================================================================

#' Versie en GitHub-commit van het geïnstalleerde package
#'
#' @return Lijst met `versie` (character) en `commit` (character of NA als
#'   het package niet vanaf GitHub is geïnstalleerd)
#' @noRd
engine_info <- function() {
  beschrijving <- utils::packageDescription("monitoranalyse")
  commit <- beschrijving$RemoteSha
  list(
    versie = as.character(utils::packageVersion("monitoranalyse")),
    commit = if (is.null(commit) || !nzchar(commit)) NA_character_ else commit,
    bron = beschrijving$RemoteRepo %||% NA_character_,
    gebruiker = beschrijving$RemoteUsername %||% NA_character_
  )
}

#' Waarschuw als de geïnstalleerde engine afwijkt van engine_versie in de config
#'
#' @param gewenst Versie uit 03_config.R (of NULL)
#' @noRd
controleer_engine_versie <- function(gewenst) {
  if (is.null(gewenst) || length(gewenst) != 1 || is.na(gewenst) ||
    !nzchar(gewenst)) {
    return(invisible(TRUE))
  }
  huidig <- engine_info()$versie
  if (!identical(as.character(gewenst), huidig)) {
    warning(
      "\n[LET OP] Dit project hoort bij engineversie ", gewenst,
      ", maar geïnstalleerd is versie ", huidig, ".\n",
      "De cijfers kunnen daardoor afwijken van eerdere runs van dit project.\n",
      "Wil je exact dezelfde versie gebruiken? Installeer die dan met:\n",
      "  pak::pak(\"alex-janse/monitoranalyse@v", gewenst, "\")\n",
      "Gebruik je bewust de nieuwe versie? Pas dan engine_versie aan in ",
      "03_config.R.",
      call. = FALSE,
      immediate. = TRUE
    )
    return(invisible(FALSE))
  }
  invisible(TRUE)
}

#' Zet een kopie van de engine in het datapackage
#'
#' Schrijft naar `<archief_map>/engine/`:
#' - `rapport/`: de rapportbestanden (rapport.qmd, assets/, js/)
#' - `R/monitoranalyse_functies.R`: alle functies van het package als
#'   broncode (functioneel exact; commentaar zit niet in een geïnstalleerd
#'   package)
#' - `ENGINE_VERSIE.txt`: versie, commit en de installatieopdracht om exact
#'   deze versie terug te zetten
#'
#' @param archief_map Map van het datapackage
#' @noRd
archiveer_engine <- function(archief_map) {
  engine_map <- file.path(archief_map, "engine")
  dir.create(file.path(engine_map, "R"), recursive = TRUE, showWarnings = FALSE)

  # ---- Rapportbestanden ---------------------------------------------------
  rapport_bron <- system.file("rapport", package = "monitoranalyse")
  file.copy(rapport_bron, engine_map, recursive = TRUE)

  # ---- Functies als broncode ---------------------------------------------
  ns <- asNamespace("monitoranalyse")
  namen <- sort(ls(ns, all.names = TRUE))
  namen <- namen[vapply(namen, function(n) is.function(get(n, ns)), logical(1))]
  info <- engine_info()
  regels <- c(
    "# =============================================================================",
    paste0("# monitoranalyse ", info$versie, " — alle functies van de engine"),
    "# Automatisch gegenereerd bij deze run (ter archivering, niet sourcen).",
    "# Herinstalleren van exact deze versie: zie ENGINE_VERSIE.txt",
    "# =============================================================================",
    ""
  )
  for (n in namen) {
    regels <- c(
      regels,
      paste0("`", n, "` <- ", paste(deparse(get(n, ns), control = "useSource"),
        collapse = "\n")),
      ""
    )
  }
  writeLines(enc2utf8(regels), file.path(engine_map, "R", "monitoranalyse_functies.R"),
    useBytes = TRUE)

  # ---- Versiebestand -----------------------------------------------------
  installatie <- if (!is.na(info$commit)) {
    paste0('pak::pak("', info$gebruiker %|na|% "alex-janse", "/",
      info$bron %|na|% "monitoranalyse", "@", info$commit, '")')
  } else {
    paste0('pak::pak("alex-janse/monitoranalyse@v', info$versie, '")')
  }
  writeLines(
    c(
      "monitoranalyse — gebruikte engine",
      "=====================================",
      paste0("Versie:        ", info$versie),
      paste0("GitHub-commit: ", info$commit %|na|% "onbekend (niet vanaf GitHub geïnstalleerd)"),
      "",
      "Exact deze versie opnieuw installeren:",
      paste0("  ", installatie)
    ),
    file.path(engine_map, "ENGINE_VERSIE.txt"),
    useBytes = FALSE
  )
  invisible(engine_map)
}

# NA-variant van %||%: rechterkant als links NULL of NA is
`%|na|%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || is.na(x)) y else x
}
