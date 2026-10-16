# =============================================================================
# helper-fixture.R
# Volledig VERZONNEN testfixture (geen echte respondenten of organisaties).
#
# Zelfde dekking als de kleine testset uit v1.x:
#   cluster 1        dichotoom (Ja/Nee)        -> frequenties + kruistabel
#   cluster 8        multiselect (6x Ja/Nee)   -> multiselect + kruistabel
#   cluster 55_open  open antwoord             -> open antwoorden
#   cluster 23       numeriek (4 tellers)      -> descriptives
#   cluster 64/65    de kruisvariabelen zelf   (gemeentegrootte, stedelijkheid)
#   kruis_vars       twee kruisvariabelen      (multi-KV toggle)
#
# De metadata wordt als .csv geschreven (SPSS-route: ";" + UTF-8-BOM).
# =============================================================================

#' Schrijf een verzonnen .sav-bestand en metadata-CSV naar `map`
#'
#' @param map Doelmap (bijv. 01_data/ van een testproject)
#' @param n   Aantal verzonnen respondenten
#' @return Named list met de paden `sav` en `metadata`
#' @noRd
maak_testfixture <- function(map, n = 45) {
  set.seed(20261016)
  ja_nee <- c("Nee" = 0, "Ja" = 1)
  lab <- function(x, label, labels = ja_nee) {
    haven::labelled(x, labels = labels, label = label)
  }
  jn <- function(p) stats::rbinom(n, 1, p)

  activiteiten <- c(
    "Concerten", "Workshops", "Lessen", "Voorstellingen",
    "Tentoonstellingen", "Anders, namelijk"
  )
  data <- tibble::tibble(ID = sprintf("R%03d", seq_len(n)))
  data$Q1 <- lab(jn(0.6), "Werkt u samen met scholen?")
  for (i in seq_along(activiteiten)) {
    data[[paste0("Q8_", i)]] <- lab(
      jn(c(0.7, 0.5, 0.4, 0.3, 0.1, 0.05)[i]),
      paste0("Welke activiteiten organiseert u?... - ", activiteiten[i])
    )
  }
  for (i in 1:4) {
    x <- as.numeric(stats::rpois(n, c(3, 12, 1, 40)[i]))
    x[sample(n, 3)] <- NA
    data[[paste0("Q23_", i)]] <- haven::labelled(
      x,
      label = paste0("Aantal ", c("vaste medewerkers", "vrijwilligers",
        "stagiairs", "activiteiten per jaar")[i])
    )
  }
  antwoorden <- c(
    "Meer subsidie voor nieuwe projecten",
    "+ Extra ondersteuning bij fondsenwerving",
    " - Betere afstemming met de gemeente",
    "Ruimte om te repeteren",
    "#1 prioriteit: zichtbaarheid",
    "Meer vrijwilligers"
  )
  open <- rep(NA_character_, n)
  open[seq(1, n, by = 3)] <- rep_len(antwoorden, length(seq(1, n, by = 3)))
  data$Q55_open <- haven::labelled(open, label = "Wat zou uw organisatie helpen?")
  data$gemeentegrootte_3cat <- lab(
    sample(c(1, 2, 3, NA), n, replace = TRUE, prob = c(0.35, 0.35, 0.25, 0.05)),
    "Gemeentegrootte",
    c("Klein" = 1, "Middel" = 2, "Groot" = 3)
  )
  data$stedelijkheid_3cat <- lab(
    sample(1:3, n, replace = TRUE),
    "Stedelijkheid",
    c("Weinig stedelijk" = 1, "Matig stedelijk" = 2, "Sterk stedelijk" = 3)
  )

  meta <- data.frame(
    variabele = c("Q1", paste0("Q8_", 1:6), paste0("Q23_", 1:4), "Q55_open",
      "gemeentegrootte_3cat", "stedelijkheid_3cat"),
    cluster = c("1", rep("8", 6), rep("23", 4), "55_open", "64", "65"),
    vraag = c(
      "Werkt u samen met scholen?",
      rep("Welke activiteiten organiseert u?", 6),
      rep("Hoeveel mensen en activiteiten telt uw organisatie?", 4),
      "Wat zou uw organisatie helpen?",
      "Gemeentegrootte", "Stedelijkheid"
    ),
    stringsAsFactors = FALSE
  )

  dir.create(map, recursive = TRUE, showWarnings = FALSE)
  sav <- file.path(map, "testdata_verzonnen.sav")
  csv <- file.path(map, "metadata_verzonnen.csv")
  haven::write_sav(data, sav)
  regels <- utils::capture.output(
    utils::write.table(meta, sep = ";", row.names = FALSE, quote = TRUE)
  )
  con <- file(csv, "wb")
  writeBin(c(as.raw(c(0xEF, 0xBB, 0xBF)), charToRaw(enc2utf8(
    paste0(paste(regels, collapse = "\r\n"), "\r\n")
  ))), con)
  close(con)
  list(sav = sav, metadata = csv)
}

#' Maak een testproject met nieuw_project() en de verzonnen fixture
#'
#' @param map          Doelmap (mag nog niet bestaan)
#' @param resp_id_col  In te vullen resp_id_col
#' @return Pad naar de projectmap
#' @noRd
maak_testproject <- function(map, resp_id_col = "ID") {
  suppressMessages(nieuw_project(map))
  maak_testfixture(file.path(map, "01_data"))
  config <- c(
    'project_naam <- "Testproject (verzonnen data)"',
    'input_sav <- "01_data/testdata_verzonnen.sav"',
    'metadata_file <- "01_data/metadata_verzonnen.csv"',
    paste0('resp_id_col <- "', resp_id_col, '"'),
    "kruis_vars <- list(",
    '  gemeentegrootte_3cat = "Gemeentegrootte",',
    '  stedelijkheid_3cat = "Stedelijkheid"',
    ")",
    "pct_decimalen <- 0",
    "stat_decimalen <- 1",
    "kleine_n_drempel <- 10"
  )
  writeLines(config, file.path(map, "03_config.R"))
  map
}
