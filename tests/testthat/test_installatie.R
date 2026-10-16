# =============================================================================
# test_installatie.R
# De installatie-instructies (README en 00_handleiding.md) bevatten een
# expliciete lijst afhankelijkheden en een versienummer. Deze tests bewaken
# dat die gelijk blijven aan DESCRIPTION.
# =============================================================================

# ---- Hulpfuncties ------------------------------------------------------------
verwachte_packages <- function() {
  imports <- utils::packageDescription("monitoranalyse")$Imports
  namen <- trimws(sub("\\(.*\\)", "", strsplit(imports, ",")[[1]]))
  basis <- rownames(utils::installed.packages(priority = "base"))
  # ggpattern staat in Suggests, maar is nodig voor identieke output
  sort(c(setdiff(namen[nzchar(namen)], basis), "ggpattern"))
}

packages_in_instructie <- function(tekst) {
  tekst <- paste(tekst, collapse = "\n")
  blok <- regmatches(tekst, regexpr("install\\.packages\\(c\\([^)]*\\)\\)", tekst))
  expect_length(blok, 1)
  sort(gsub('"', "", regmatches(blok, gregexpr('"[^"]+"', blok))[[1]]))
}

versies_in_instructie <- function(tekst) {
  m <- regmatches(tekst, gregexpr("refs/tags/v[0-9.]+[0-9]\\.tar\\.gz", tekst))
  unique(sub("refs/tags/v(.*)\\.tar\\.gz", "\\1", unlist(m)))
}

# ---- Handleiding -------------------------------------------------------------
test_that("handleiding: lijst afhankelijkheden gelijk aan DESCRIPTION", {
  tekst <- readLines(system.file("template", "00_handleiding.md",
    package = "monitoranalyse"), encoding = "UTF-8", warn = FALSE)
  expect_identical(packages_in_instructie(tekst), verwachte_packages())
})

test_that("handleiding: installatie-URL gebruikt de huidige versie", {
  tekst <- readLines(system.file("template", "00_handleiding.md",
    package = "monitoranalyse"), encoding = "UTF-8", warn = FALSE)
  expect_identical(versies_in_instructie(tekst),
    as.character(utils::packageVersion("monitoranalyse")))
})

# ---- README (alleen in de broncode, niet in het geïnstalleerde package) -----
test_that("README: lijst afhankelijkheden en huidige versie", {
  readme <- testthat::test_path("..", "..", "README.md")
  skip_if_not(file.exists(readme), "README.md niet beschikbaar")
  tekst <- readLines(readme, encoding = "UTF-8", warn = FALSE)
  expect_identical(packages_in_instructie(tekst), verwachte_packages())
  expect_true(as.character(utils::packageVersion("monitoranalyse")) %in%
    versies_in_instructie(tekst))
})

# ---- Installatieopdracht in meldingen en ENGINE_VERSIE.txt -------------------
test_that("installatie_regel geeft een tarball-URL zonder pak", {
  regel <- monitoranalyse:::installatie_regel("refs/tags/v2.0.1")
  expect_identical(regel, paste0(
    'install.packages("https://github.com/alex-janse/monitoranalyse/archive/',
    'refs/tags/v2.0.1.tar.gz", repos = NULL, type = "source")'))
  expect_false(grepl("pak", regel))
})
