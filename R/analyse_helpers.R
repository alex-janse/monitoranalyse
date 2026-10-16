# =============================================================================
# analyse_helpers.R
# Gedeelde analysefuncties voor de LKCA monitor workflow.
#
# BELANGRIJK:
# - Deze functies worden door alle andere modules via source() geladen.
# - Definieer deze functies NERGENS ANDERS opnieuw.
# - De afrondingslogica is conform tabellenboek_poppodia_v5.R (zie §Afronding).
# - Afronding wordt UITSLUITEND toegepast in de exportlaag (rapport.qmd).
#   Alle berekende waarden die hier worden teruggegeven zijn ONAFGEROND.
# =============================================================================


# =============================================================================
# TYPE-DETECTIE
# Conform: tabellenboek_poppodia_v5.R :: detect_type()
# =============================================================================

#' Detecteer het analytische type van een variabele
#'
#' @param x Een kolom uit het .sav-dataframe (haven_labelled of numeric)
#' @return "categorical" als de variabele value labels heeft,
#'         "numeric" als het een numerieke variabele zonder labels is,
#'         "skip" in alle andere gevallen (tekst, datum, etc.)
#' @noRd
detect_type <- function(x) {
  if (!is.null(attr(x, "labels"))) {
    return("categorical")
  }
  if (is.numeric(x)) {
    return("numeric")
  }
  "skip"
}

# =============================================================================
# DICHOTOMIE-DETECTIE
# Conform: tabellenboek_poppodia_v5.R :: analyze_cluster_multiselect() intern
# =============================================================================

#' Detecteer of een variabele dichotoom is (precies 2 unieke numerieke labels)
#'
#' @param x Een kolom uit het .sav-dataframe
#' @return TRUE als de variabele precies 2 unieke waarden in de labels heeft
#' @noRd
is_dichotomous <- function(x) {
  labs <- attr(x, "labels")
  if (is.null(labs)) {
    return(FALSE)
  }
  length(unique(as.numeric(labs))) == 2
}

# =============================================================================
# LABEL-STRIPPING: VARIABELENLABEL
# Conform: tabellenboek_poppodia_v5.R :: analyze_var() — inline logica
#
# Patroon: "<prefix>...- <rest>"
# Als <prefix> (≥10 tekens) overeenkomt met het begin van de vraagtekst
# (hoofdletterongevoelig), wordt alleen <rest> teruggegeven.
# =============================================================================

#' Strip het overlappende prefix uit een variabelenlabel
#'
#' @param label     Het ruwe variabelenlabel (string)
#' @param vraag_tekst De vraagtekst van het cluster (string of NULL)
#' @return Het ingekorte label, of het originele label als geen match
#' @noRd
strip_overlap_label <- function(label, vraag_tekst = NULL) {
  if (is.null(vraag_tekst) || is.na(vraag_tekst) || nchar(vraag_tekst) < 10) {
    return(label)
  }
  m <- str_match(label, "^(.+?)[.]{2,}\\s*-\\s*(.+)$")
  if (is.na(m[1])) {
    return(label)
  }

  prefix_c <- str_to_lower(str_trim(m[2]))
  ref_c <- str_to_lower(str_trim(vraag_tekst))

  if (
    nchar(prefix_c) >= 10 &&
      prefix_c == substr(ref_c, 1, nchar(prefix_c))
  ) {
    return(str_trim(m[3]))
  }
  label
}

# =============================================================================
# LABEL-STRIPPING: ANTWOORDLABELS (VALUE LABELS)
# Conform: tabellenboek_poppodia_v5.R :: analyze_categorical() — strip_overlap intern
#
# Zelfde patroon als strip_overlap_label maar toegepast op antwoordopties.
# Aanvullend: "True"/"False" worden omgezet naar "Ja"/"Nee".
# =============================================================================

#' Strip het overlappende prefix uit een antwoordlabel (value label)
#'
#' @param antwoord_label  Het ruwe antwoordlabel (string)
#' @param vraag_tekst     De vraagtekst van het cluster (string of NULL)
#' @return Het ingekorte antwoordlabel, of het originele als geen match
#' @noRd
strip_overlap_value_label <- function(antwoord_label, vraag_tekst = NULL) {
  # True/False -> Ja/Nee
  ln <- str_replace_all(antwoord_label, "^True$", "Ja")
  ln <- str_replace_all(ln, "^False$", "Nee")

  if (is.null(vraag_tekst) || is.na(vraag_tekst)) {
    return(ln)
  }

  m <- str_match(ln, "^(.+?)\\.{2,}\\s*[-]\\s*(.+)$")
  if (is.na(m[1])) {
    return(ln)
  }

  prefix <- str_trim(m[2])
  antwoord <- str_trim(m[3])

  if (nchar(vraag_tekst) >= 10 && nchar(prefix) >= 10) {
    ref_c <- str_to_lower(str_trim(vraag_tekst))
    prefix_c <- str_to_lower(prefix)
    overlap <- substr(ref_c, 1, nchar(prefix_c))
    if (prefix_c == overlap) return(antwoord)
  }
  ln
}

# =============================================================================
# FREQUENTIEANALYSE — CATEGORISCH
# Conform: tabellenboek_poppodia_v5.R :: analyze_categorical()
#
# AFRONDING: pct wordt ONAFGEROND teruggegeven (prop.table * 100).
# Afronding uitsluitend in rapport.qmd via config.R::pct_decimalen.
# =============================================================================

#' Bereken frequenties en percentages voor een categorische variabele
#'
#' @param x          De variabele (haven_labelled)
#' @param label      Het al-gestripte variabelenlabel
#' @param varname    De variabelenaam
#' @param vraag_tekst De vraagtekst (voor antwoordlabel-stripping)
#' @return Tibble met kolommen: variabele, label, n_valid, code,
#'         antwoord_label (gestript), n (integer), pct (ONAFGEROND, 0-100)
#' @noRd
analyse_categorisch <- function(x, label, varname, vraag_tekst = NULL) {
  labs <- sort(attr(x, "labels"))
  fx <- factor(as.numeric(x), levels = unname(labs))

  freq <- table(fx)
  # pct: prop.table * 100 — GEEN afronding hier
  pct <- prop.table(freq) * 100

  lab_names <- vapply(
    names(labs),
    strip_overlap_value_label,
    character(1),
    vraag_tekst = vraag_tekst,
    USE.NAMES = FALSE
  )

  tibble(
    variabele = varname,
    label = label,
    n_valid = as.integer(sum(freq)),
    code = as.numeric(unname(labs)),
    antwoord_label = lab_names,
    n = as.integer(as.numeric(freq)),
    pct = as.numeric(pct) # ONAFGEROND — zie bestandskop
  )
}

# =============================================================================
# DESCRIPTIVES — NUMERISCH
# Conform: tabellenboek_poppodia_v5.R :: analyze_numeric()
#
# AFRONDING: gem/mediaan/sd worden ONAFGEROND teruggegeven.
# Afronding uitsluitend in rapport.qmd via config.R::stat_decimalen.
# =============================================================================

#' Bereken descriptieve statistieken voor een numerieke variabele
#'
#' @param x       De variabele (numeric)
#' @param label   Het al-gestripte variabelenlabel
#' @param varname De variabelenaam
#' @return Tibble met kolommen: variabele, label, n_valid,
#'         gem, mediaan, sd, min, max (allen ONAFGEROND)
#' @noRd
analyse_numeriek <- function(x, label, varname) {
  xn <- as.numeric(x)
  n_val <- sum(!is.na(xn))

  tibble(
    variabele = varname,
    label = label,
    n_valid = as.integer(n_val),
    gem = if (n_val > 0) mean(xn, na.rm = TRUE) else NA_real_,
    mediaan = if (n_val > 0) median(xn, na.rm = TRUE) else NA_real_,
    sd = if (n_val > 1) sd(xn, na.rm = TRUE) else NA_real_,
    min = if (n_val > 0) min(xn, na.rm = TRUE) else NA_real_,
    max = if (n_val > 0) max(xn, na.rm = TRUE) else NA_real_
  )
}

# =============================================================================
# VARIABELE ANALYSEREN (dispatcher)
# Conform: tabellenboek_poppodia_v5.R :: analyze_var()
#
# Past strip_overlap_label toe op het variabelenlabel vóór de analyse,
# zodat het analyseobject al-gestripte labels bevat.
# =============================================================================

#' Analyseer één variabele en geef het resultaat terug als tibble
#'
#' @param v          Variabelenaam (character)
#' @param data       Het volledige dataframe
#' @param vraag_tekst De vraagtekst van het cluster
#' @return Tibble (frequenties of descriptives), of NULL bij type "skip"
#' @noRd
analyse_var <- function(v, data, vraag_tekst = NULL) {
  x <- data[[v]]
  raw_label <- attr(x, "label")
  # Robuust: SPSS round-trip geeft soms numeric vector als label
  label <- if (is.null(raw_label) || length(raw_label) != 1) {
    v
  } else {
    as.character(raw_label)
  }

  # Label inkorten vóór analyse — resultaat wordt opgeslagen in analyseobject
  label <- strip_overlap_label(label, vraag_tekst)

  switch(
    detect_type(x),
    categorical = analyse_categorisch(x, label, v, vraag_tekst),
    numeric = analyse_numeriek(x, label, v),
    NULL
  )
}

# =============================================================================
# SPECIALE ANTWOORDCATEGORIEËN — CLASSIFICATIE
#
# Detecteert vijf typen "speciale" antwoordcategorieën die in rapportages
# altijd onderaan horen, ongeacht frequentie of oorspronkelijke volgorde.
#
# Prioriteit (eerste match wint):
#   1. Anders, namelijk          — regex: (?i)anders
#   2. Nee / Geen / Geen van bovenstaande — regex: (?i)(\\bnee\\b|geen)
#   3. Weet ik niet              — regex: (?i)weet.*niet
#   4. Wil ik niet zeggen        — regex: (?i)wil.*niet.*zeggen|wil.*liever.*niet
#   5. Niet van toepassing       — regex: (?i)niet van toepassing|n\.v\.t\.
#
# Wordt toegepast op zowel variabelelabels (multi-select clusters)
# als antwoordlabels (single-select vragen).
# =============================================================================

#' Classificeer antwoordcategorieën als normaal of speciaal
#'
#' @param x Karaktervector met labels (variabelelabels of value labels)
#' @return Karaktervector: "anders_namelijk", "geen_bovenstaande", "weet_niet",
#'         "wil_niet_zeggen", "niet_toepassing", of "normaal"
#' @noRd
classify_speciaal <- function(x) {
  case_when(
    str_detect(
      x,
      regex("^(open:\\s*)?ander", ignore_case = TRUE)
    ) ~ "anders_namelijk",
    str_detect(x, regex("(\\bnee\\b|geen)", ignore_case = TRUE)) ~ "nee_geen",
    str_detect(x, regex("weet.*niet", ignore_case = TRUE)) ~ "weet_niet",
    str_detect(
      x,
      regex("wil.*niet.*zeggen|wil.*liever.*niet", ignore_case = TRUE)
    ) ~ "wil_niet_zeggen",
    str_detect(
      x,
      regex("niet van toepassing|n\\.v\\.t\\.", ignore_case = TRUE)
    ) ~ "niet_toepassing",
    .default = "normaal"
  )
}

# =============================================================================
# MULTISELECT-STATISTIEKEN
# Conform: tabellenboek_poppodia_v5.R :: analyze_cluster_multiselect()
#
# AFRONDING: gem_aangevinkt wordt ONAFGEROND teruggegeven.
# Afronding uitsluitend in rapport.qmd via config.R::stat_decimalen.
# =============================================================================

#' Bereken multiselect-statistieken voor een cluster van dichotome variabelen
#'
#' @param vars  Karaktervector met variabelenamen in dit cluster
#' @param data  Het volledige dataframe
#' @return Tibble met multiselect-statistieken, of NULL als geen dichotome vars
#' @noRd
analyse_multiselect <- function(vars, data) {
  dichotome_vars <- vars[
    vapply(vars, function(v) is_dichotomous(data[[v]]), logical(1))
  ]

  if (length(dichotome_vars) == 0) {
    return(NULL)
  }

  mat <- data |>
    select(all_of(dichotome_vars)) |>
    mutate(across(everything(), ~ as.numeric(.) == 1)) |>
    as.matrix()

  heeft_ingevuld <- rowSums(!is.na(mat)) > 0
  mat <- mat[heeft_ingevuld, , drop = FALSE]

  if (nrow(mat) == 0) {
    return(NULL)
  }

  counts <- rowSums(mat, na.rm = TRUE)
  n_zero_items <- sum(colSums(mat, na.rm = TRUE) == 0)

  tibble(
    gem_aangevinkt = mean(counts), # ONAFGEROND — zie bestandskop
    mediaan_aangevinkt = median(counts),
    min_aangevinkt = min(counts),
    max_aangevinkt = max(counts),
    n_heeft_ingevuld = as.integer(nrow(mat)),
    n_items = as.integer(length(dichotome_vars)),
    n_nul_items = as.integer(n_zero_items)
  )
}
