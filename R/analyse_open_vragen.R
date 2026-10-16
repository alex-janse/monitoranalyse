# =============================================================================
# analyse_open_vragen.R
# Analyseert open tekstvragen en bouwt twee platte tibbles voor het
# centrale analyseobject.
#
# Identificatie: metadata-clusters die eindigen op "_open".
#
# Output-componenten:
#   $open_antwoorden   — één rij per ingevuld antwoord (lang formaat)
#   $open_samenvatting — één rij per open variabele (descriptives)
# =============================================================================


#' Analyseer open vragen
#'
#' Identificeert open vragen via metadata-clusters die eindigen op "_open".
#' Bouwt twee tibbles: lange antwoorden-tibble en samenvattende statistieken.
#'
#' @param data         Dataframe
#' @param meta         Metadata tibble
#' @param resp_id_col  Naam van de kolom met respondent-ID
#' @return Named list met $open_antwoorden en $open_samenvatting
#' @noRd
analyse_open_vragen <- function(data, meta, resp_id_col) {
  open_clusters <- meta |>
    filter(str_detect(cluster, "_open$")) |>
    pull(cluster) |>
    unique()

  # Lege schema's voor beide output-componenten
  empty_antw <- tibble(
    cluster_id = character(),
    variabele = character(),
    vraag_tekst = character(),
    var_label = character(),
    resp_id = character(),
    antwoord = character(),
    n_woorden = integer()
  )
  empty_samenv <- tibble(
    cluster_id = character(),
    variabele = character(),
    vraag_tekst = character(),
    var_label = character(),
    n_invullers = integer(),
    gem_woorden = numeric(),
    mediaan_woorden = numeric(),
    min_woorden = integer(),
    max_woorden = integer()
  )

  if (length(open_clusters) == 0) {
    return(list(open_antwoorden = empty_antw, open_samenvatting = empty_samenv))
  }

  meta_open <- meta |>
    filter(cluster %in% open_clusters, variabele %in% names(data))

  if (nrow(meta_open) == 0) {
    return(list(open_antwoorden = empty_antw, open_samenvatting = empty_samenv))
  }

  antw_lijst <- list()
  samenv_lijst <- list()

  for (i in seq_len(nrow(meta_open))) {
    cl     <- meta_open$cluster[i]
    v      <- meta_open$variabele[i]
    vraag  <- meta_open$vraag[i]

    # Variable label (robust)
    raw_label <- attr(data[[v]], "label")
    var_label <- if (is.null(raw_label) || length(raw_label) != 1) {
      NA_character_
    } else {
      as.character(raw_label)
    }

    # Haal niet-lege antwoorden
    x <- as.character(data[[v]])
    resp_ids <- as.character(data[[resp_id_col]])
    ingevuld <- !is.na(x) & str_squish(x) != ""

    if (!any(ingevuld)) {
      samenv_lijst[[paste(cl, v, sep = "_")]] <- tibble(
        cluster_id = cl,
        variabele = v,
        vraag_tekst = vraag,
        var_label = var_label,
        n_invullers = 0L,
        gem_woorden = NA_real_,
        mediaan_woorden = NA_real_,
        min_woorden = NA_integer_,
        max_woorden = NA_integer_
      )
      next
    }

    antwoorden <- str_squish(x[ingevuld])
    rids       <- resp_ids[ingevuld]
    n_woorden  <- str_count(antwoorden, "\\S+")

    antw_lijst[[paste(cl, v, sep = "_")]] <- tibble(
      cluster_id = cl,
      variabele = v,
      vraag_tekst = vraag,
      var_label = var_label,
      resp_id = rids,
      antwoord = antwoorden,
      n_woorden = as.integer(n_woorden)
    )

    n_inv <- length(antwoorden)
    samenv_lijst[[paste(cl, v, sep = "_")]] <- tibble(
      cluster_id = cl,
      variabele = v,
      vraag_tekst = vraag,
      var_label = var_label,
      n_invullers = as.integer(n_inv),
      gem_woorden = mean(n_woorden),
      mediaan_woorden = median(n_woorden),
      min_woorden = as.integer(min(n_woorden)),
      max_woorden = as.integer(max(n_woorden))
    )
  }

  list(
    open_antwoorden = if (length(antw_lijst) > 0) {
      bind_rows(antw_lijst)
    } else {
      empty_antw
    },
    open_samenvatting = bind_rows(samenv_lijst)
  )
}
