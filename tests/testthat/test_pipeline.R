# =============================================================================
# test_pipeline.R
# End-to-end test: nieuw_project() + run_project() met de VERZONNEN fixture
# uit helper-fixture.R. Vereist Quarto (wordt anders overgeslagen) en een
# geïnstalleerde versie van monitoranalyse (rapport.qmd draait in een eigen
# R-proces en gebruikt monitoranalyse::rond_af()).
#
# Run vanuit de package-map:
#   devtools::test(filter = "pipeline")
# =============================================================================

heeft_quarto <- function() {
  pad <- tryCatch(quarto::quarto_path(), error = function(e) NULL)
  !is.null(pad) && nzchar(pad)
}

test_that("nieuw_project() weigert een bestaande, niet-lege map", {
  map <- withr::local_tempfile()
  dir.create(map)
  writeLines("iets", file.path(map, "bestaand.txt"))
  expect_error(nieuw_project(map), "bestaat al en is niet leeg")
})

test_that("nieuw_project() maakt het sjabloon en vult engine_versie in", {
  map <- file.path(withr::local_tempdir(), "nieuw project")
  suppressMessages(nieuw_project(map))
  expect_true(all(file.exists(file.path(map, c(
    "00_handleiding.md", "02_Analyseproces.Rproj", "03_config.R",
    "04_run_project.R", "01_data", "05_output"
  )))))
  config <- readLines(file.path(map, "03_config.R"), encoding = "UTF-8")
  versie <- as.character(utils::packageVersion("monitoranalyse"))
  expect_true(any(config == paste0('engine_versie <- "', versie, '"')))
})

test_that("volledige pipeline met kloppende resp_id_col geeft rapport en datapackage", {
  skip_on_cran()
  skip_if_not(heeft_quarto(), "Quarto niet gevonden")

  map <- maak_testproject(file.path(withr::local_tempdir(), "project met spaties"))
  res <- suppressMessages(run_project(file.path(map, "03_config.R"), open_rapport = FALSE))

  expect_true(file.exists(res$rapport))
  logs <- file.path(res$datapackage, "logs")
  expect_true(all(file.exists(file.path(logs, c(
    "analyse_object.rds", "audit_log.rds", "run_log.txt", "session_info.txt"
  )))))
  expect_true(file.exists(file.path(res$datapackage, "engine", "ENGINE_VERSIE.txt")))
  expect_true(file.exists(file.path(res$datapackage, "engine", "rapport", "rapport.qmd")))
  expect_true(file.exists(file.path(res$datapackage, "engine", "R", "monitoranalyse_functies.R")))

  obj <- readRDS(file.path(logs, "analyse_object.rds"))
  expect_equal(obj$meta$engine_versie, as.character(utils::packageVersion("monitoranalyse")))
  expect_equal(obj$meta$input_sav, "01_data/testdata_verzonnen.sav")
  expect_true(nrow(obj$kruistabellen) > 0)
  expect_equal(nrow(obj$multiselect), 1)
  expect_equal(nrow(obj$open_samenvatting), 1)

  html <- readLines(res$rapport, encoding = "UTF-8", warn = FALSE)
  expect_true(any(grepl("Testproject (verzonnen data)", html, fixed = TRUE)))
  expect_true(any(grepl("Open antwoorden (ruw)", html, fixed = TRUE)))
})

test_that("pipeline met verkeerde resp_id_col stopt vroeg en duidelijk", {
  skip_if_not(heeft_quarto(), "Quarto niet gevonden")
  map <- maak_testproject(file.path(withr::local_tempdir(), "project"), resp_id_col = "respid")

  fout <- tryCatch(
    suppressMessages(run_project(file.path(map, "03_config.R"), open_rapport = FALSE)),
    error = function(e) conditionMessage(e)
  )
  expect_match(fout, "ANALYSE GESTOPT", fixed = TRUE)
  expect_match(fout, 'Bedoel je resp_id_col <- "ID"?', fixed = TRUE)
  # Gestopt vóór de analyse: geen rapport en geen analyseobject
  expect_length(list.files(file.path(map, "05_output"), pattern = "\\.html$"), 0)
  expect_length(list.files(file.path(map, "05_output"), pattern = "analyse_object\\.rds$",
    recursive = TRUE), 0)
  expect_length(list.files(file.path(map, "05_output"), pattern = "run_log\\.txt$",
    recursive = TRUE), 1)
})
