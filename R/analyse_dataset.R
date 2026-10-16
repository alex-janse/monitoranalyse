# =============================================================================
# analyse_dataset.R
# Bouwt het centrale analyseobject als platte tibbles.
#
# Het analyseobject is de enige bron van waarheid voor alle output.
# Tabellen en figuren mogen NOOIT zelf frequenties/percentages herberekenen.
#
# Structuur van het analyseobject (list):
#   $meta            — projectinformatie en timestamps
#   $frequenties     — één rij per variabele × antwoordoptie (categorisch)
#   $descriptives    — één rij per numerieke variabele
#   $multiselect     — één rij per cluster met multiselect-statistieken
#   $kruistabellen   — één rij per variabele × kruiscategorie (%Ja)
#   $kruis_verdeling — één rij per kruisvariabele × categorie (n, % respondenten)
#   $open_antwoorden   — één rij per ingevuld open antwoord
#   $open_samenvatting — één rij per open variabele (descriptives)
#   $niet_meegenomen — variabelen die niet geanalyseerd zijn (documentatie)
#
# AFRONDINGSREGEL: alle numerieke waarden zijn ONAFGEROND.
# Afronding uitsluitend in rapport.qmd, via de vastgelegde conventie in
# R/afronding.R (met config.R::pct_decimalen en config.R::stat_decimalen).
# =============================================================================


#' Bereken kruistabellen voor alle clusters × één kruisvariabele
#'
#' Kruist alleen dichotome (Ja/Nee) variabelen. Per variabele wordt het
#' percentage "Ja" per subgroep van de kruisvariabele berekend.
#'
#' @param data         Dataframe
#' @param clusters     Karaktervector met cluster-IDs
#' @param meta_analyse Metadata tibble (alleen analyseerbare variabelen)
#' @param keep_vars    Karaktervector: variabelen die geanalyseerd worden
#' @param kruis_var    Naam van de kruisvariabele (string)
#' @return Tibble met kruistabel-resultaten, of NULL bij geen resultaten
#' @noRd
analyse_kruistabel <- function(
  data,
  clusters,
  meta_analyse,
  keep_vars,
  kruis_var
) {
  kruis_x <- data[[kruis_var]]

  # Label van de kruisvariabele
  kruis_label <- attr(kruis_x, "label")
  if (is.null(kruis_label) || length(kruis_label) != 1) {
    kruis_label <- kruis_var
  } else {
    kruis_label <- as.character(kruis_label)
  }

  # Categorieën bepalen
  kruis_labs <- attr(kruis_x, "labels")
  if (!is.null(kruis_labs)) {
    kruis_cats <- names(sort(kruis_labs))
  } else {
    kruis_cats <- sort(unique(as.character(kruis_x[!is.na(kruis_x)])))
  }

  # N per categorie voor de hele (geldige) populatie
  n_kruis_per_cat <- setNames(
    vapply(
      kruis_cats,
      function(cat) {
        if (!is.null(kruis_labs)) {
          sum(as.numeric(kruis_x) == as.numeric(kruis_labs[cat]), na.rm = TRUE)
        } else {
          sum(as.character(kruis_x) == cat, na.rm = TRUE)
        }
      },
      integer(1)
    ),
    kruis_cats
  )

  # Alleen rijen met geldige kruisvariabele
  data_kruis <- data[!is.na(kruis_x), ]

  out_lijst <- list()

  for (cl in clusters) {
    vars <- meta_analyse |>
      filter(cluster == cl) |>
      pull(variabele) |>
      intersect(keep_vars)

    if (length(vars) == 0) {
      next
    }

    vraag_tekst <- meta_analyse |>
      filter(cluster == cl) |>
      pull(vraag) |>
      unique() |>
      paste(collapse = " / ")

    # Alleen dichotome variabelen kruisen
    dichotome <- vars[
      vapply(vars, function(v) is_dichotomous(data[[v]]), logical(1))
    ]
    if (length(dichotome) == 0) {
      next
    }

    for (v in dichotome) {
      x <- data_kruis[[v]]
      ja <- max(as.numeric(attr(x, "labels")))

      # Label (gestript)
      raw_label <- attr(x, "label")
      label <- if (is.null(raw_label) || length(raw_label) != 1) {
        v
      } else {
        as.character(raw_label)
      }
      label <- strip_overlap_label(label, vraag_tekst)

      kruis_x_filt <- data_kruis[[kruis_var]]

      for (cat in kruis_cats) {
        # Subset-index (gebruik gefilterde kruisvariabele zodat lengte
        # matcht met x uit data_kruis)
        if (!is.null(kruis_labs)) {
          sub_idx <- as.numeric(kruis_x_filt) == as.numeric(kruis_labs[cat])
        } else {
          sub_idx <- as.character(kruis_x_filt) == cat
        }
        sub_idx <- sub_idx & !is.na(sub_idx)

        x_sub <- as.numeric(x[sub_idx])
        n <- sum(!is.na(x_sub))

        if (n == 0) {
          next
        }

        k <- sum(x_sub == ja, na.rm = TRUE)
        pct <- (k / n) * 100 # 0-100, onafgerond — consistent met analyse_categorisch()

        out_lijst[[paste(cl, v, cat, sep = "_")]] <- tibble(
          cluster_id = cl,
          vraag_tekst = vraag_tekst,
          kruisvariabele = kruis_var,
          kruis_label = kruis_label,
          kruis_categorie = cat,
          n_kruis = as.integer(n_kruis_per_cat[cat]),
          variabele = v,
          label = label,
          n = as.integer(n),
          k = as.integer(k),
          pct = pct
        )
      }
    }
  }

  if (length(out_lijst) == 0) {
    return(NULL)
  }
  bind_rows(out_lijst)
}

#' Bouw het centrale analyseobject
#'
#' @param data         Dataframe ingeladen via read_data() (na corrections.R)
#' @param meta         Metadata tibble ingeladen via read_metadata()
#' @param sav_pad      Pad naar het .sav-bestand (voor opslaan in meta)
#' @param meta_pad     Pad naar het metadata-bestand (voor opslaan in meta)
#' @param resp_id_col  Naam van de kolom met respondent-ID (voor open vragen)
#' @param kruis_vars    Named list van kruisvariabelen (uit config.R), default list()
#' @return Named list met $meta, $frequenties, $descriptives,
#'         $multiselect, $kruistabellen, $kruis_verdeling, $open_antwoorden,
#'         $open_samenvatting en $niet_meegenomen
#' @export
analyse_dataset <- function(
  data,
  meta,
  sav_pad,
  meta_pad,
  resp_id_col,
  kruis_vars = list()
) {
  # ---- Respondent-ID aanwezig? (afweer, ook zonder validate_input) -------
  controleer_resp_id_col(data, resp_id_col)

  # ---- Identificeer open clusters ----------------------------------------
  open_clusters <- meta |>
    filter(str_detect(cluster, "_open$")) |>
    pull(cluster) |>
    unique()

  # ---- Variabelen selecteren voor analyse --------------------------------
  meta_analyse <- meta |>
    filter(
      !is.na(cluster),
      cluster != "",
      !(cluster %in% open_clusters)
    )

  # Let op: vapply over data (kolommen), NIET over names(data) (strings)
  var_types <- vapply(data, detect_type, character(1))
  keep_vars <- names(data)[var_types != "skip"]

  vars_niet_meegenomen <- union(
    setdiff(names(data), meta$variabele),
    meta |>
      filter(
        is.na(cluster) |
          cluster == "" |
          # Variabelen met _open in naam die NIET in een _open-cluster zitten
          (str_detect(variabele, "_open$|_open_") &
            !(cluster %in% open_clusters))
      ) |>
      pull(variabele)
  ) |>
    intersect(names(data))

  # ---- Clusters sorteren (numeriek waar mogelijk) ------------------------
  # Clusters met een numeriek prefix (bijv. "3", "12b") worden numeriek
  # gesorteerd. Clusters zonder numeriek prefix (bijv. "_open"-clusters)
  # komen alfabetisch na de genummerde clusters.
  clusters <- meta_analyse |>
    filter(variabele %in% keep_vars) |>
    distinct(cluster) |>
    mutate(
      num = suppressWarnings(as.numeric(str_extract(cluster, "^\\d+"))),
      num = if_else(is.na(num), Inf, num)
    ) |>
    arrange(num, cluster) |>
    pull(cluster)

  message("Analyse starten: ", length(clusters), " clusters...")

  # ---- Frequenties en descriptives per cluster ---------------------------
  freq_lijst <- list()
  desc_lijst <- list()
  multi_lijst <- list()
  kruis_lijst <- list()

  for (cl in clusters) {
    vars <- meta_analyse |>
      filter(cluster == cl) |>
      pull(variabele) |>
      intersect(keep_vars)

    vraag_tekst <- meta_analyse |>
      filter(cluster == cl) |>
      pull(vraag) |>
      unique() |>
      paste(collapse = " / ")

    grafiek_inclusie <- meta_analyse |>
      filter(cluster == cl) |>
      pull(grafiek_inclusie) |>
      first() %||%
      TRUE

    chart_type <- meta_analyse |>
      filter(cluster == cl) |>
      pull(chart_type) |>
      first() %||%
      "bar"

    if (length(vars) == 0) {
      next
    }

    for (v in vars) {
      res <- analyse_var(v, data, vraag_tekst)
      if (is.null(res)) {
        next
      }

      # Clusterinformatie toevoegen
      res <- res |>
        mutate(
          cluster_id = cl,
          vraag_tekst = vraag_tekst,
          grafiek_inclusie = grafiek_inclusie,
          chart_type = chart_type,
          .before = 1
        )

      if ("pct" %in% names(res)) {
        freq_lijst[[paste(cl, v, sep = "_")]] <- res
      } else {
        desc_lijst[[paste(cl, v, sep = "_")]] <- res
      }
    }

    # Multiselect-statistieken
    # Alleen berekenen als een cluster uit meerdere analysevariabelen bestaat.
    # Dit voorkomt dat enkelvoudige ja/nee-vragen onterecht als multiselect
    # worden behandeld.
    if (length(vars) > 1) {
      multi <- analyse_multiselect(vars, data)

      if (!is.null(multi)) {
        multi_lijst[[cl]] <- multi |>
          mutate(
            cluster_id = cl,
            vraag_tekst = vraag_tekst,
            .before = 1
          )
      }
    }
  }

  # ---- Kruistabellen -----------------------------------------------------
  # Berekent voor elke kruisvariabele uit config.R per cluster het %Ja
  # per subgroep. Alleen dichotome (Ja/Nee) analysevariabelen worden gekruist.
  if (length(kruis_vars) > 0) {
    for (kv in names(kruis_vars)) {
      if (!kv %in% names(data)) {
        warning(
          "Kruisvariabele '",
          kv,
          "' niet gevonden in data \u2014 overgeslagen.",
          call. = FALSE
        )
        next
      }
      kt <- analyse_kruistabel(data, clusters, meta_analyse, keep_vars, kv)
      if (!is.null(kt)) {
        # Hernoem kruisvariabele naar weergavenaam uit config
        kt <- kt |>
          mutate(kruis_label = kruis_vars[[kv]], .after = kruisvariabele)
        kruis_lijst[[kv]] <- kt
      }
    }
  }

  # ---- KV-mapping: resp_id → KV-categorieën (nodig voor rapport) --------
  if (length(kruis_vars) > 0) {
    kv_resp <- data |>
      select(resp_id = !!sym(resp_id_col), all_of(names(kruis_vars))) |>
      mutate(across(
        all_of(names(kruis_vars)),
        ~ as.character(haven::as_factor(.))
      ))

    # KV-sorteercodes: label → numerieke code (voor sortering op
    # oorspronkelijke waarde in rapport)
    kv_codes <- lapply(names(kruis_vars), function(kv) {
      labs <- attr(data[[kv]], "labels")
      if (is.null(labs)) {
        return(NULL)
      }
      tibble(
        label = as.character(haven::as_factor(setNames(
          names(labs),
          names(labs)
        ))),
        code = as.numeric(labs)
      )
    })
    names(kv_codes) <- names(kruis_vars)
  } else {
    kv_resp <- tibble(resp_id = character())
    kv_codes <- setNames(list(), character())
  }

  # ---- Open vragen -------------------------------------------------------
  ov <- analyse_open_vragen(data, meta, resp_id_col)

  # ---- Platte tibbles samenvoegen ----------------------------------------
  # Belangrijk: ook bij 0 rijen moeten deze objecten een stabiel schema hebben.
  # Anders crasht rapport.qmd bij bv. filter(cluster_id == cl).

  frequenties <- if (length(freq_lijst) > 0) {
    bind_rows(freq_lijst)
  } else {
    tibble(
      cluster_id = character(),
      vraag_tekst = character(),
      grafiek_inclusie = logical(),
      chart_type = character(),
      variabele = character(),
      label = character(),
      n_valid = integer(),
      code = numeric(),
      antwoord_label = character(),
      n = integer(),
      pct = numeric()
    )
  }

  descriptives <- if (length(desc_lijst) > 0) {
    bind_rows(desc_lijst)
  } else {
    tibble(
      cluster_id = character(),
      vraag_tekst = character(),
      grafiek_inclusie = logical(),
      chart_type = character(),
      variabele = character(),
      label = character(),
      n_valid = integer(),
      gem = numeric(),
      mediaan = numeric(),
      sd = numeric(),
      min = numeric(),
      max = numeric()
    )
  }

  multiselect <- if (length(multi_lijst) > 0) {
    bind_rows(multi_lijst)
  } else {
    tibble(
      cluster_id = character(),
      vraag_tekst = character(),
      gem_aangevinkt = numeric(),
      mediaan_aangevinkt = numeric(),
      min_aangevinkt = integer(),
      max_aangevinkt = integer(),
      n_heeft_ingevuld = integer(),
      n_items = integer(),
      n_nul_items = integer()
    )
  }

  kruistabellen <- if (length(kruis_lijst) > 0) {
    bind_rows(kruis_lijst)
  } else {
    tibble(
      cluster_id = character(),
      vraag_tekst = character(),
      kruisvariabele = character(),
      kruis_label = character(),
      kruis_categorie = character(),
      n_kruis = integer(),
      variabele = character(),
      label = character(),
      n = integer(),
      k = integer(),
      pct = numeric()
    )
  }

  # ---- Verdeling van respondenten over de kruiscategorieën ---------------
  # Eén rij per kruisvariabele × categorie: n_kruis en het aandeel daarvan
  # binnen de kruisvariabele (0-100, ONAFGEROND). Afgeleid van
  # $kruistabellen, zodat het exact aansluit bij de gekruiste cijfers.
  # Leeg schema volgt vanzelf uit de lege $kruistabellen.
  kruis_verdeling <- kruistabellen |>
    distinct(kruisvariabele, kruis_label, kruis_categorie, n_kruis) |>
    group_by(kruisvariabele) |>
    mutate(pct = n_kruis / sum(n_kruis) * 100) |>
    ungroup()

  # ---- Output-sanity checks -----------------------------------------------
  # Drie lichtgewicht controles na de analyse, vóór opslaan.
  # Geven een waarschuwing (geen fout) zodat de pipeline altijd afmaakt.

  if (nrow(frequenties) > 0) {
    # 1. Percentages: per variabele moet sum(pct) ≈ 100%
    #    Variabelen met n_valid = 0 (volledig leeg) worden overgeslagen.
    #    Tolerantie 0.5 vangt kleine floating-point afwijkingen op.
    pct_sommen <- frequenties |>
      group_by(cluster_id, variabele) |>
      summarise(
        som = sum(pct, na.rm = TRUE),
        n_valid = first(n_valid),
        .groups = "drop"
      ) |>
      filter(n_valid > 0, abs(som - 100) > 0.5)

    if (nrow(pct_sommen) > 0) {
      warning(
        nrow(pct_sommen),
        " variabele(n) waarbij pct niet optelt tot ~100%:\n",
        paste(
          pct_sommen$variabele,
          "(som =",
          round(pct_sommen$som, 1),
          ")",
          collapse = "\n"
        ),
        call. = FALSE
      )
    }

    # 2. N-grens: geen enkele n mag groter zijn dan het totaal aantal rijen
    n_te_groot <- frequenties |>
      filter(n > nrow(data))

    if (nrow(n_te_groot) > 0) {
      warning(
        nrow(n_te_groot),
        " rij(en) met n > nrow(data) (",
        nrow(data),
        "):\n",
        paste(unique(n_te_groot$variabele), collapse = ", "),
        call. = FALSE
      )
    }

    # 3. Interne consistentie: n_valid moet gelijk zijn aan sum(n) per variabele
    n_inconsistent <- frequenties |>
      group_by(cluster_id, variabele, n_valid) |>
      summarise(n_som = sum(n, na.rm = TRUE), .groups = "drop") |>
      filter(n_valid != n_som)

    if (nrow(n_inconsistent) > 0) {
      warning(
        nrow(n_inconsistent),
        " variabele(n) waarbij n_valid \u2260 sum(n):\n",
        paste(n_inconsistent$variabele, collapse = ", "),
        call. = FALSE
      )
    }

    # 4. Afrondingsbewaking: pct mag NOOIT al afgerond zijn bij opslaan.
    pct_vals <- frequenties$pct[!is.na(frequenties$pct)]
    if (length(pct_vals) > 5 && !any(pct_vals != floor(pct_vals))) {
      message(
        "CONTROLE: Alle pct-waarden zijn gehele getallen. ",
        "Controleer of afronding niet al plaatsvond in analyse_helpers.R."
      )
    }
  }

  # ---- Niet-meegenomen variabelen documenteren ---------------------------
  niet_meegenomen <- map_dfr(vars_niet_meegenomen, function(v) {
    x <- data[[v]]
    labs <- attr(x, "labels")

    vals <- suppressWarnings(sort(unique(as.numeric(x[!is.na(x)]))))
    vals_str <- if (length(vals) == 0) {
      NA_character_
    } else if (length(vals) > 10) {
      paste0(
        min(vals),
        " - ",
        max(vals),
        " (",
        length(vals),
        " unieke waarden)"
      )
    } else {
      paste(vals, collapse = ", ")
    }

    labs_str <- if (!is.null(labs)) {
      paste(paste0(labs, " = ", names(labs)), collapse = "; ")
    } else {
      NA_character_
    }

    reden <- if (str_detect(v, "_open$|_open_")) {
      "Open tekstvraag"
    } else if (v %in% meta$variabele) {
      "Geen cluster opgegeven in metadata"
    } else {
      "Niet in metadata"
    }

    # Robuust label ophalen: SPSS round-trip geeft soms een numeric vector
    raw_lab <- attr(x, "label")
    label_str <- if (is.null(raw_lab) || length(raw_lab) != 1) {
      NA_character_
    } else {
      as.character(raw_lab)
    }

    tibble(
      variabele = v,
      label = label_str,
      reden = reden,
      waarden = vals_str,
      value_labels = labs_str
    )
  })

  # ---- Analyseobject samenstellen ----------------------------------------
  obj <- list(
    meta = list(
      n_totaal = nrow(data),
      input_sav = sav_pad,
      sav_mtime = file.info(sav_pad)$mtime,
      metadata_file = meta_pad,
      aangemaakt_op = Sys.time(),
      r_version = R.version.string,
      n_clusters = length(clusters),
      clusters_volgorde = clusters,
      # Sinds v2.0.0 (alleen toegevoegd, bestaande velden ongewijzigd):
      engine_versie = engine_info()$versie,
      engine_commit = engine_info()$commit
    ),
    frequenties = frequenties,
    descriptives = descriptives,
    multiselect = multiselect,
    kruistabellen = kruistabellen,
    kruis_verdeling = kruis_verdeling,
    open_antwoorden = ov$open_antwoorden,
    open_samenvatting = ov$open_samenvatting,
    kv_resp = kv_resp,
    kv_codes = kv_codes,
    niet_meegenomen = niet_meegenomen
  )

  message(
    "Analyseobject gebouwd: ",
    nrow(frequenties),
    " frequentierijen, ",
    nrow(descriptives),
    " descriptive-rijen, ",
    nrow(multiselect),
    " multiselect-clusters, ",
    nrow(kruistabellen),
    " kruistabel-rijen, ",
    nrow(ov$open_antwoorden),
    " open antwoorden (",
    nrow(ov$open_samenvatting),
    " vragen)"
  )

  obj
}
