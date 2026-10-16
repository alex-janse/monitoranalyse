# =============================================================================
# test_validate_input.R
# Unit tests voor de respondent-ID-controles in validate_input.R en de
# afweer in analyse_dataset() / analyse_open_vragen() (sinds v2.0.0).
#
# Aanleiding: bij een monitor heette de ID-kolom "respid" terwijl
# 03_config.R de standaardwaarde resp_id_col <- "ID" had. De validatie gaf een
# FOUT, maar de pipeline liep door en crashte later met een onduidelijke
# melding ("Can't select columns that don't exist").
#
# Run vanuit de package-map:
#   devtools::test(filter = "validate_input")
# =============================================================================

# Kleine, volledig verzonnen dataset + bijpassende metadata
maak_data <- function(id_naam = "ID", ids = 1:12) {
  ja_nee <- c("Nee" = 0, "Ja" = 1)
  data <- tibble::tibble(
    id = ids,
    Q1 = haven::labelled(rep(c(0, 1, 1), length.out = length(ids)), labels = ja_nee,
      label = "Organiseert u activiteiten?")
  )
  names(data)[1] <- id_naam
  data
}

meta_test <- tibble::tibble(
  variabele = "Q1",
  cluster = "1",
  vraag = "Organiseert u activiteiten?",
  grafiek_inclusie = TRUE,
  chart_type = "bar"
)

log_rij <- function(audit_log, patroon) {
  audit_log[grepl(patroon, audit_log$controle), ]
}

# =============================================================================
# TEST: controle 9 — respondent-ID kolom aanwezig?
# =============================================================================

test_that("(a) ID-kolom aanwezig: INFO en niet blokkerend", {
  audit_log <- suppressMessages(validate_input(maak_data("ID"), meta_test, resp_id_col = "ID"))
  rij <- log_rij(audit_log, "^Respondent-ID kolom")

  expect_equal(rij$status, "INFO")
  expect_false(rij$blokkerend)
  expect_false(any(audit_log$blokkerend))
})

test_that("(b) ID-kolom ontbreekt, vergelijkbare kolom: FOUT met suggestie", {
  audit_log <- suppressMessages(validate_input(maak_data("respid"), meta_test, resp_id_col = "ID"))
  rij <- log_rij(audit_log, "^Respondent-ID kolom")

  expect_equal(rij$status, "FOUT")
  expect_true(rij$blokkerend)
  expect_match(rij$detail, 'Bedoel je resp_id_col <- "respid"?', fixed = TRUE)
  expect_match(rij$detail, "hoofdletters", fixed = TRUE)
})

test_that("(b) suggesties werken zonder hoofdlettergevoeligheid en leestekens", {
  expect_equal(zoek_id_kolommen(c("Q1", "RespID", "Q2")), "RespID")
  expect_equal(zoek_id_kolommen(c("resp_id", "Q1")), "resp_id")
  expect_equal(zoek_id_kolommen(c("Q1", "ORINR")), "ORINR")
  expect_equal(zoek_id_kolommen(c("RespondentID", "Q1")), "RespondentID")
  # Geen false positives op namen die toevallig op "id" eindigen
  expect_length(zoek_id_kolommen(c("covid", "valid", "Q1")), 0)
})

test_that("(b) zonder vergelijkbare kolom: alle kolomnamen, niet alleen de eerste 10", {
  data <- maak_data("volgnummer")
  for (i in 1:15) data[[paste0("V", i)]] <- 1
  audit_log <- suppressMessages(validate_input(data, meta_test, resp_id_col = "ID"))
  rij <- log_rij(audit_log, "^Respondent-ID kolom")

  expect_true(rij$blokkerend)
  expect_match(rij$detail, "geen kolom gevonden die op een respondent-ID lijkt", fixed = TRUE)
  expect_match(rij$detail, "V15", fixed = TRUE)
  expect_match(rij$detail, "volgnummer", fixed = TRUE)
})

# =============================================================================
# TEST: controle 4 — dubbele respondenten
# =============================================================================

test_that("(c) dubbele ID's in een kolom met een andere naam dan ID", {
  data <- maak_data("respid", ids = c(1:10, 3, 7))
  audit_log <- suppressMessages(validate_input(data, meta_test, resp_id_col = "respid"))
  rij <- log_rij(audit_log, "dubbele ID")

  expect_equal(rij$status, "FOUT")
  expect_match(rij$controle, "2 dubbele ID's gevonden in kolom 'respid'", fixed = TRUE)
  expect_equal(rij$detail, "3, 7")
  expect_false(rij$blokkerend)
})

test_that("dubbele-check gebruikt resp_id_col ook als er een kolom ID bestaat", {
  data <- maak_data("respid", ids = c(1:11, 1))
  data$ID <- 1:12  # uniek, maar niet de ingestelde kolom
  audit_log <- suppressMessages(validate_input(data, meta_test, resp_id_col = "respid"))

  expect_match(log_rij(audit_log, "dubbele ID")$controle, "kolom 'respid'", fixed = TRUE)
})

test_that("dubbele-check valt terug op standaardnamen als resp_id_col ontbreekt", {
  data <- maak_data("ID", ids = c(1:11, 5))
  audit_log <- suppressMessages(validate_input(data, meta_test, resp_id_col = "respid"))

  expect_match(log_rij(audit_log, "dubbele ID")$controle, "kolom 'ID'", fixed = TRUE)
})

# =============================================================================
# TEST: controle 2 — resp_id_col telt als systeemkolom
# =============================================================================

test_that("resp_id_col geeft geen waarschuwing 'geen metadata-regel'", {
  audit_log <- suppressMessages(validate_input(maak_data("respid"), meta_test, resp_id_col = "respid"))
  rij <- log_rij(audit_log, "gedekt door de metadata|geen metadata-regel")

  expect_equal(rij$status, "INFO")
})

# =============================================================================
# TEST: afweer in de analyse zelf
# =============================================================================

test_that("analyse_dataset() stopt met duidelijke melding bij ontbrekende ID-kolom", {
  expect_error(
    suppressMessages(analyse_dataset(
      maak_data("respid"), meta_test,
      sav_pad = "x.sav", meta_pad = "x.xlsx",
      resp_id_col = "ID",
      kruis_vars = list(Q1 = "Q1")
    )),
    'Bedoel je resp_id_col <- "respid"?',
    fixed = TRUE
  )
})

test_that("analyse_open_vragen() stopt met duidelijke melding bij ontbrekende ID-kolom", {
  expect_error(
    analyse_open_vragen(maak_data("respid"), meta_test, resp_id_col = "ID"),
    "Respondent-ID kolom 'ID' niet gevonden",
    fixed = TRUE
  )
})

test_that("analyse_dataset() werkt gewoon bij een kloppende resp_id_col", {
  obj <- suppressMessages(analyse_dataset(
    maak_data("respid"), meta_test,
    sav_pad = "x.sav", meta_pad = "x.xlsx",
    resp_id_col = "respid"
  ))
  expect_equal(nrow(obj$frequenties), 2)
})
