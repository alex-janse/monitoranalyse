# =============================================================================
# validate_input.R
# Valideert het opgeschoonde .sav-bestand tegen de metadata.
#
# Geeft altijd een audit_log tibble terug — ook bij ernstige fouten.
# De beslissing of de workflow doorgaat ligt bij run_project.R / rapport.qmd.
#
# Statussen:
#   FOUT        — kritieke fout; rapport toont geen data-tabs
#   WAARSCHUWING — mogelijk probleem; workflow gaat door, gebruiker moet beoordelen
#   INFO        — informatief; geen actie vereist
# =============================================================================


#' Maak één logrecord aan
#'
#' @param domein    Categorie van de check (bijv. "Variabelen", "Respondenten")
#' @param controle  Omschrijving van de check
#' @param status    "FOUT", "WAARSCHUWING" of "INFO"
#' @param detail    Optionele toelichting (bijv. namen van ontbrekende variabelen)
#' @return Tibble met één rij
#' @noRd
mk_log <- function(domein, controle, status, detail = NA_character_) {
  tibble(
    domein = domein,
    controle = controle,
    status = status,
    detail = as.character(detail)
  )
}

#' Valideer het opgeschoonde .sav-bestand tegen de metadata
#'
#' @param data  Dataframe ingeladen via read_data()
#' @param meta  Metadata tibble ingeladen via read_metadata()
#' @param kleine_n_drempel Minimale n_valid voor een waarschuwing (uit config.R)
#' @param resp_id_col Naam van de kolom met respondent-ID (uit config.R)
#' @return Tibble (audit_log) met alle validatieresultaten
#' @export
validate_input <- function(
  data,
  meta,
  kleine_n_drempel = 10,
  resp_id_col = "ID"
) {
  log <- list()

  sav_vars <- names(data)
  meta_vars <- meta$variabele

  # ---- 1. Variabelen in metadata aanwezig in data? -----------------------
  meta_analyse_vars <- meta |>
    filter(!is.na(cluster), cluster != "") |>
    pull(variabele)

  ontbrekend_in_data <- setdiff(meta_analyse_vars, sav_vars)

  if (length(ontbrekend_in_data) == 0) {
    log[["vars_aanwezig"]] <- mk_log(
      "Variabelen",
      "Alle metadata-variabelen aanwezig in data",
      "INFO"
    )
  } else {
    log[["vars_aanwezig"]] <- mk_log(
      "Variabelen",
      paste0(
        length(ontbrekend_in_data),
        " metadata-variabelen ontbreken in het .sav-bestand"
      ),
      "FOUT",
      paste(ontbrekend_in_data, collapse = ", ")
    )
  }

  # ---- 2. Variabelen in data niet in metadata? ---------------------------
  # Systeemvariabelen van bekende surveyplatforms die nooit metadata
  # nodig hebben. Uitbreiden als een nieuw platform andere kolommen toevoegt.
  sys_vars_patroon <- paste0(
    "^(ID|CODE|STATE|STARTDATE|ENDDATE|EXITQUESTION|",
    "RespondentID|FirstName|LastName|EmailAddress|",
    "IsBlacklisted|RespondentCode|orinr)$"
  )

  niet_in_meta <- setdiff(sav_vars, meta_vars)
  niet_in_meta <- niet_in_meta[!str_detect(niet_in_meta, sys_vars_patroon)]

  if (length(niet_in_meta) == 0) {
    log[["vars_meta_dekking"]] <- mk_log(
      "Variabelen",
      "Alle data-variabelen zijn gedekt door de metadata",
      "INFO"
    )
  } else {
    log[["vars_meta_dekking"]] <- mk_log(
      "Variabelen",
      paste0(
        length(niet_in_meta),
        " data-variabelen hebben geen metadata-regel"
      ),
      "WAARSCHUWING",
      paste(niet_in_meta, collapse = ", ")
    )
  }

  # ---- 3. Minimum N respondenten -----------------------------------------
  n_totaal <- nrow(data)
  if (n_totaal < kleine_n_drempel) {
    log[["min_n"]] <- mk_log(
      "Respondenten",
      paste0(
        "N totaal (",
        n_totaal,
        ") is kleiner dan de drempel (",
        kleine_n_drempel,
        ")"
      ),
      "FOUT"
    )
  } else {
    log[["min_n"]] <- mk_log(
      "Respondenten",
      paste0(
        "N totaal = ",
        n_totaal,
        " (boven drempel van ",
        kleine_n_drempel,
        ")"
      ),
      "INFO"
    )
  }

  # ---- 4. Dubbele respondenten -------------------------------------------
  id_col <- intersect(c("ID", "RespondentID", "orinr"), sav_vars)[1]
  if (!is.na(id_col)) {
    ids <- data[[id_col]]
    n_dubbel <- sum(duplicated(ids, incomparables = NA))
    if (n_dubbel > 0) {
      log[["dubbele_ids"]] <- mk_log(
        "Respondenten",
        paste0(n_dubbel, " dubbele ID's gevonden in kolom '", id_col, "'"),
        "FOUT",
        paste(ids[duplicated(ids, incomparables = NA)], collapse = ", ")
      )
    } else {
      log[["dubbele_ids"]] <- mk_log(
        "Respondenten",
        paste0("Geen dubbele ID's in kolom '", id_col, "'"),
        "INFO"
      )
    }
  } else {
    log[["dubbele_ids"]] <- mk_log(
      "Respondenten",
      "Geen ID-kolom gevonden (ID, RespondentID, orinr) \u2014 dubbele-check overgeslagen",
      "WAARSCHUWING"
    )
  }

  # ---- 5. Clusters zonder variabelen in data -----------------------------
  clusters_meta <- meta |>
    filter(
      !is.na(cluster),
      cluster != "",
      !str_detect(variabele, "_open$|_open_")
    ) |>
    group_by(cluster) |>
    summarise(
      n_in_data = sum(variabele %in% sav_vars),
      .groups = "drop"
    )

  lege_clusters <- clusters_meta |> filter(n_in_data == 0) |> pull(cluster)
  if (length(lege_clusters) > 0) {
    log[["lege_clusters"]] <- mk_log(
      "Clusters",
      paste0(
        length(lege_clusters),
        " cluster(s) hebben geen variabelen in het .sav-bestand"
      ),
      "WAARSCHUWING",
      paste(lege_clusters, collapse = ", ")
    )
  } else {
    log[["lege_clusters"]] <- mk_log(
      "Clusters",
      paste0(
        nrow(clusters_meta),
        " clusters gevonden, allemaal met variabelen in data"
      ),
      "INFO"
    )
  }

  # ---- 6. Value labels aanwezig bij categorische variabelen? -------------
  cat_vars_zonder_labels <- meta_analyse_vars[
    vapply(
      meta_analyse_vars,
      function(v) {
        if (!v %in% sav_vars) {
          return(FALSE)
        }
        x <- data[[v]]
        is.numeric(x) && is.null(attr(x, "labels"))
      },
      logical(1)
    )
  ]

  if (length(cat_vars_zonder_labels) > 0) {
    log[["value_labels"]] <- mk_log(
      "Labels",
      paste0(
        length(cat_vars_zonder_labels),
        " numerieke variabele(n) zonder value labels (worden als numeriek geanalyseerd)"
      ),
      "WAARSCHUWING",
      paste(cat_vars_zonder_labels, collapse = ", ")
    )
  } else {
    log[["value_labels"]] <- mk_log(
      "Labels",
      "Alle categorische variabelen hebben value labels",
      "INFO"
    )
  }

  # ---- 7. Variabelenlabels aanwezig? -------------------------------------
  vars_zonder_varlabel <- meta_analyse_vars[
    vapply(
      meta_analyse_vars,
      function(v) {
        if (!v %in% sav_vars) {
          return(FALSE)
        }
        is.null(attr(data[[v]], "label"))
      },
      logical(1)
    )
  ]

  if (length(vars_zonder_varlabel) > 0) {
    log[["var_labels"]] <- mk_log(
      "Labels",
      paste0(
        length(vars_zonder_varlabel),
        " variabele(n) zonder variabelenlabel"
      ),
      "WAARSCHUWING",
      paste(vars_zonder_varlabel, collapse = ", ")
    )
  } else {
    log[["var_labels"]] <- mk_log(
      "Labels",
      "Alle analyse-variabelen hebben een variabelenlabel",
      "INFO"
    )
  }

  # ---- 8. chart_type validatie -------------------------------------------
  if ("chart_type" %in% names(meta)) {
    ongeldig_chart <- meta |>
      filter(
        !is.na(cluster),
        cluster != "",
        !chart_type %in% c("bar", "stacked")
      ) |>
      distinct(chart_type)
    if (nrow(ongeldig_chart) > 0) {
      log[["chart_type"]] <- mk_log(
        "Metadata",
        paste0("Ongeldige chart_type waarde(n) in metadata"),
        "WAARSCHUWING",
        paste0(
          "Geldige waarden: 'bar', 'stacked'. ",
          "Gevonden: ",
          paste(ongeldig_chart$chart_type, collapse = ", "),
          ". ",
          "Er wordt teruggevallen op 'bar'."
        )
      )
    } else {
      log[["chart_type"]] <- mk_log(
        "Metadata",
        "Alle chart_type waarden geldig ('bar' of 'stacked')",
        "INFO"
      )
    }
  }

  # ---- 9. Respondent-ID kolom aanwezig? ----------------------------------
  if (resp_id_col %in% sav_vars) {
    log[["resp_id_col"]] <- mk_log(
      "Respondenten",
      paste0("Respondent-ID kolom '", resp_id_col, "' aanwezig"),
      "INFO"
    )
  } else {
    log[["resp_id_col"]] <- mk_log(
      "Respondenten",
      paste0("Respondent-ID kolom '", resp_id_col, "' niet gevonden in data"),
      "FOUT",
      paste0(
        "Controleer resp_id_col in 03_config.R. ",
        "Beschikbare kolommen: ",
        paste(head(sav_vars, 10), collapse = ", "),
        "..."
      )
    )
  }

  # ---- Resultaat samenvoegen ---------------------------------------------
  audit_log <- bind_rows(log)

  n_fouten <- sum(audit_log$status == "FOUT")
  n_waarsch <- sum(audit_log$status == "WAARSCHUWING")

  message(
    "Inputvalidatie voltooid: ",
    n_fouten,
    " fout(en), ",
    n_waarsch,
    " waarschuwing(en)"
  )

  if (n_fouten > 0) {
    message(
      "! ",
      n_fouten,
      " KRITIEKE FOUT(EN) gevonden. ",
      "Het rapport toont de fouten op de Overzicht-pagina. ",
      "Controleer het rapport en los de fouten op voordat je de resultaten gebruikt."
    )
  }

  audit_log
}
