# =============================================================================
# test_afronding.R
# Bewaakt de VASTGELEGDE afrondingsconventie (zie R/afronding.R).
#
# Faalt een van deze tests, dan veranderen gepubliceerde cijfers (PDF's,
# dashboard). Pas de test dus NIET aan om hem groen te krijgen, tenzij een
# bewuste methodologische wijziging (major-versie) is besloten.
#
# Run vanuit de package-map:
#   devtools::test(filter = "afronding")
#
# Sinds v2.0.0 (package): rond_af()/formatteer_pct() komen uit het package
# en rapport.qmd staat in inst/rapport/. De verwachtingen hieronder zijn
# ongewijzigd ten opzichte van v1.3.0.
# =============================================================================

rapport_pad <- system.file("rapport", "rapport.qmd", package = "monitoranalyse")

# =============================================================================
# Percentages, 0 decimalen (standaard)
# =============================================================================

test_that("halve percentages worden naar het even getal afgerond", {
  # Komt in de praktijk voor bij kleine N: k van 8 respondenten
  expect_equal(
    formatteer_pct((1:7) / 8 * 100, 0),
    c("12%", "25%", "38%", "50%", "62%", "75%", "88%")
  )
  expect_equal(formatteer_pct(c(0.5, 1.5, 2.5), 0), c("0%", "2%", "2%"))
})

test_that("niet-halve percentages worden normaal afgerond", {
  expect_equal(formatteer_pct(100 / 3, 0), "33%")
  expect_equal(formatteer_pct(200 / 3, 0), "67%")
  expect_equal(formatteer_pct(100 / 6, 0), "17%")
  expect_equal(formatteer_pct(c(0, 100), 0), c("0%", "100%"))
})

test_that("afgeronde percentages worden niet gecorrigeerd naar 100", {
  expect_equal(sum(rond_af(rep(100 / 3, 3), 0)), 99)
})

# =============================================================================
# Percentages met decimalen: notatie
# =============================================================================

test_that("decimalen: decimaalpunt en geen opvulnullen", {
  expect_equal(formatteer_pct(42.46, 1), "42.5%")
  expect_equal(formatteer_pct(42, 1), "42%")
})

# =============================================================================
# Statistieken (gemiddelde, mediaan, SD), 1 decimaal (standaard)
# =============================================================================

test_that("statistieken: 1 decimaal, halve naar even", {
  expect_equal(rond_af(c(3.14159, 2.25, 2.75, 1.25), 1), c(3.1, 2.2, 2.8, 1.2))
})

# =============================================================================
# Rapport gebruikt uitsluitend afronding.R
# =============================================================================

test_that("rapport.qmd rondt nergens zelf af met round()", {
  rapport <- readLines(rapport_pad, encoding = "UTF-8", warn = FALSE)
  expect_false(any(grepl("\\bround\\(", rapport)))
  # v1.x: rapport.qmd sourcete R/afronding.R; sinds v2.0.0 haalt het
  # dezelfde functies uit het package.
  expect_true(any(grepl("monitoranalyse::rond_af", rapport, fixed = TRUE)))
  expect_true(any(grepl("monitoranalyse::formatteer_pct", rapport, fixed = TRUE)))
})
