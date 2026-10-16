# =============================================================================
# logging.R
# Schrijft het analyseobject, de audit_log en logtekstbestanden weg.
# =============================================================================


#' Sla het analyseobject, audit_log en logtekstbestanden op
#'
#' @param obj          Het analyseobject (lijst) van analyse_dataset()
#' @param audit_log    De audit_log tibble van validate_input()
#' @param archief_pad  Map voor archiefbestanden (default: "05_output/archief/logs")
#' @param meta_pad     Pad naar het metadata-bestand (voor snapshot)
#' @noRd
logging <- function(
  obj,
  audit_log,
  archief_pad = file.path("05_output", "archief"),
  meta_pad = NULL
) {
  if (!dir.exists(archief_pad)) {
    dir.create(archief_pad, recursive = TRUE)
  }

  # ---- Analyseobject ----------------------------------------------------
  rds_pad <- file.path(archief_pad, "analyse_object.rds")
  saveRDS(obj, rds_pad)
  message("Analyseobject opgeslagen: ", rds_pad)

  # ---- Audit_log --------------------------------------------------------
  log_rds_pad <- file.path(archief_pad, "audit_log.rds")
  saveRDS(audit_log, log_rds_pad)
  message("Audit-log opgeslagen: ", log_rds_pad)

  # ---- Run-log (tekst) --------------------------------------------------
  run_log_pad <- file.path(archief_pad, "run_log.txt")
  n_fouten <- sum(audit_log$status == "FOUT")
  n_waarsch <- sum(audit_log$status == "WAARSCHUWING")

  run_log_tekst <- c(
    paste0("LKCA Monitor \u2014 Run-log"),
    paste0("======================"),
    paste0(
      "Aangemaakt op:    ",
      format(obj$meta$aangemaakt_op, "%d-%m-%Y %H:%M:%S")
    ),
    paste0("R-versie:         ", obj$meta$r_version),
    paste0("Engineversie:     monitoranalyse ", obj$meta$engine_versie %||% "onbekend"),
    paste0("Engine-commit:    ", obj$meta$engine_commit %||% "onbekend"),
    "",
    paste0("Bronbestand:      ", obj$meta$input_sav),
    paste0(
      "Bestandsdatum:    ",
      format(obj$meta$sav_mtime, "%d-%m-%Y %H:%M:%S")
    ),
    paste0("Metadata:         ", obj$meta$metadata_file),
    "",
    paste0("N respondenten:   ", obj$meta$n_totaal),
    paste0("Clusters:         ", obj$meta$n_clusters),
    paste0("Frequentierijen:  ", nrow(obj$frequenties)),
    paste0("Descriptive-rijen:", nrow(obj$descriptives)),
    "",
    paste0(
      "Validatie:        ",
      n_fouten,
      " fout(en), ",
      n_waarsch,
      " waarschuwing(en)"
    ),
    "",
    "--- Validatiedetails ---",
    capture.output(print(audit_log, n = Inf))
  )

  writeLines(run_log_tekst, run_log_pad)
  message("Run-log opgeslagen: ", run_log_pad)

  # ---- Session-info (tekst) ---------------------------------------------
  session_pad <- file.path(archief_pad, "session_info.txt")
  writeLines(capture.output(sessionInfo()), session_pad)
  message("Session-info opgeslagen: ", session_pad)

  # ---- Metadata-snapshot ------------------------------------------------
  if (!is.null(meta_pad) && file.exists(meta_pad)) {
    snap_pad <- file.path(archief_pad, "metadata_snapshot.xlsx")
    file.copy(meta_pad, snap_pad, overwrite = TRUE)
    message("Metadata-snapshot opgeslagen: ", snap_pad)
  }

  invisible(NULL)
}
