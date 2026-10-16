# =============================================================================
# read_metadata.R
# Laad en normaliseer metadata uit Excel (.xlsx/.xls) of CSV.
#
# Verplicht schema:
#   variabele | cluster | vraag
#
# Voorkeursroute:
#   metadata.xlsx
#
# CSV-route:
#   bedoeld voor SPSS-export metadata_template.csv
#   delimiter = ;
#   encoding  = UTF-8-BOM
#
# Gedrag:
#   - Alle waarden worden als character ingelezen.
#   - Kolomnamen worden getrimd.
#   - Lege strings worden behandeld als NA.
#   - Rijen zonder cluster blijven bewaard voor validatie, maar worden
#     later niet geanalyseerd.
#   - Ontbreekt grafiek_inclusie: default TRUE.
#   - Ontbreekt chart_type: default "bar".
# =============================================================================


#' Laad het metadata-bestand
#'
#' @param pad Bestandspad naar metadata .xlsx, .xls of .csv
#' @return Tibble met minimaal kolommen: variabele, cluster, vraag
#'         Plus optionele/default kolommen: grafiek_inclusie, chart_type
#' @export
read_metadata <- function(pad) {
  # ---- Bestaan bestand ------------------------------------------------------

  if (!file.exists(pad)) {
    stop(
      "Metadata-bestand niet gevonden: ",
      pad,
      "\n",
      "Controleer of het metadata-bestand in de juiste map staat en of het ",
      "pad in 03_config.R correct is ingesteld.",
      call. = FALSE
    )
  }

  ext <- tolower(tools::file_ext(pad))

  # ---- Metadata inlezen -----------------------------------------------------

  if (ext %in% c("xlsx", "xls")) {
    sheets <- readxl::excel_sheets(pad)

    sheet_to_read <- if ("metadata" %in% sheets) {
      "metadata"
    } else {
      sheets[1]
    }

    meta <- readxl::read_excel(
      path = pad,
      sheet = sheet_to_read,
      col_types = "text",
      .name_repair = "minimal"
    )
  } else if (ext == "csv") {
    meta <- read.csv2(
      file = pad,
      stringsAsFactors = FALSE,
      fileEncoding = "UTF-8-BOM",
      check.names = FALSE,
      na.strings = ""
    )
  } else {
    stop(
      "Onbekend metadataformaat: .",
      ext,
      "\n\n",
      "Gebruik een .xlsx-, .xls- of .csv-bestand.",
      call. = FALSE
    )
  }

  meta <- tibble::as_tibble(meta, .name_repair = "minimal")

  # ---- Kolomnamen opschonen -------------------------------------------------

  names(meta) <- names(meta) |>
    stringr::str_trim()

  # ---- Duplicaten in kolomnamen controleren --------------------------------

  dubbel <- names(meta)[duplicated(names(meta))]

  if (length(dubbel) > 0) {
    stop(
      "\n[KRITIEKE FOUT] Metadata bevat dubbele kolomnamen.\n",
      "Dubbele kolom(men): ",
      paste(unique(dubbel), collapse = ", "),
      "\n\n",
      "Controleer het metadata-bestand en zorg dat elke kolomnaam uniek is.",
      call. = FALSE
    )
  }

  # ---- Schema-validatie: verplichte kolommen -------------------------------

  verplicht <- c("variabele", "cluster", "vraag")
  ontbrekend <- setdiff(verplicht, names(meta))

  if (length(ontbrekend) > 0) {
    stop(
      "\n[KRITIEKE FOUT] Metadata-bestand heeft onjuiste kolomnamen.\n",
      "Gevonden kolommen: ",
      paste(names(meta), collapse = ", "),
      "\n\n",
      "Verplicht, exact deze namen:\n",
      "  \u2713 variabele\n",
      "  \u2713 cluster\n",
      "  \u2713 vraag\n\n",
      "Ontbrekend: ",
      paste(ontbrekend, collapse = ", "),
      "\n\n",
      "Tips:\n",
      "  - Check of er spaties in kolomnamen staan, bijvoorbeeld 'variabele '\n",
      "  - Check of kolomnamen correct gespeld zijn\n",
      "  - Hoofdletters tellen mee\n",
      "  - Open het bestand en vergelijk de headerrij",
      call. = FALSE
    )
  }

  # ---- Alles naar character en lege strings naar NA ------------------------

  meta <- meta |>
    mutate(
      across(
        .cols = everything(),
        .fns = ~ as.character(.x)
      )
    ) |>
    mutate(
      across(
        .cols = everything(),
        .fns = ~ stringr::str_trim(.x)
      )
    ) |>
    mutate(
      across(
        .cols = everything(),
        .fns = ~ dplyr::na_if(.x, "")
      )
    )

  # ---- Verplichte kolommen expliciet normaliseren --------------------------

  meta <- meta |>
    mutate(
      variabele = stringr::str_trim(variabele),
      cluster = stringr::str_trim(cluster),
      vraag = stringr::str_trim(vraag)
    )

  # ---- Optionele kolommen met defaults toevoegen ---------------------------

  if (!"grafiek_inclusie" %in% names(meta)) {
    meta <- meta |>
      mutate(grafiek_inclusie = "ja")
  }

  if (!"chart_type" %in% names(meta)) {
    meta <- meta |>
      mutate(chart_type = "bar")
  }

  # ---- grafiek_inclusie normaliseren naar logisch --------------------------

  meta <- meta |>
    mutate(
      grafiek_inclusie = case_when(
        is.na(grafiek_inclusie) ~ TRUE,

        stringr::str_to_lower(stringr::str_trim(grafiek_inclusie)) %in%
          c("ja", "yes", "true", "waar", "1", "x") ~ TRUE,

        stringr::str_to_lower(stringr::str_trim(grafiek_inclusie)) %in%
          c("nee", "no", "false", "onwaar", "0") ~ FALSE,

        TRUE ~ TRUE
      )
    )

  # ---- chart_type normaliseren ---------------------------------------------

  meta <- meta |>
    mutate(
      chart_type = case_when(
        is.na(chart_type) ~ "bar",
        stringr::str_trim(chart_type) == "" ~ "bar",
        TRUE ~ stringr::str_to_lower(stringr::str_trim(chart_type))
      )
    )

  # ---- Dubbele variabelen controleren --------------------------------------

  dubbele_vars <- meta |>
    filter(!is.na(variabele)) |>
    count(variabele) |>
    filter(n > 1)

  if (nrow(dubbele_vars) > 0) {
    stop(
      "\n[KRITIEKE FOUT] Metadata bevat dubbele variabelen.\n",
      "Dubbele variabele(n): ",
      paste(dubbele_vars$variabele, collapse = ", "),
      "\n\n",
      "Elke variabele mag maar \u00E9\u00E9n keer in de metadata staan.",
      call. = FALSE
    )
  }

  # ---- Lege variabelen controleren -----------------------------------------

  lege_variabelen <- meta |>
    filter(is.na(variabele))

  if (nrow(lege_variabelen) > 0) {
    stop(
      "\n[KRITIEKE FOUT] Metadata bevat lege waarden in kolom 'variabele'.\n",
      "Vul deze aan of verwijder de lege rijen.",
      call. = FALSE
    )
  }

  # ---- Informatieve telling -------------------------------------------------

  n_clusters <- meta |>
    filter(!is.na(cluster), cluster != "") |>
    distinct(cluster) |>
    nrow()

  message(
    "Metadata geladen: ",
    pad,
    " (",
    nrow(meta),
    " variabelen, ",
    n_clusters,
    " clusters)"
  )

  meta
}
