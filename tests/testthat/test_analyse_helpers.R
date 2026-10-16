# =============================================================================
# test_analyse_helpers.R
# Unit tests voor kernfuncties in analyse_helpers.R
#
# Run vanuit de package-map:
#   devtools::test(filter = "analyse_helpers")
#
# Sinds v2.0.0 (package): de functies komen uit het package (testthat laadt
# ook de niet-geëxporteerde functies). Verwachtingen ongewijzigd t.o.v. v1.3.0.
# =============================================================================

# =============================================================================
# TEST: detect_type()
# =============================================================================

test_that("detect_type() herkent numerieke variabelen", {
  expect_equal(detect_type(c(1, 2, 3, 4, 5)), "numeric")
  expect_equal(detect_type(c(1.5, 2.3, 3.1, 4.9)), "numeric")
})

test_that("detect_type() herkent categorische variabelen met labels", {
  x <- haven::labelled(
    c(1, 2, 1, 3, 2),
    labels = c("Ja" = 1, "Nee" = 2, "Weet niet" = 3)
  )
  expect_equal(detect_type(x), "categorical")
})

test_that("detect_type() behandelt gelabelde 0/1-variabele als categorisch", {
  x <- haven::labelled(
    c(0, 1, 0, 1, 1),
    labels = c("Niet aangevinkt" = 0, "Aangevinkt" = 1)
  )
  expect_equal(detect_type(x), "categorical")
})

test_that("detect_type() handelt missing values correct", {
  x <- haven::labelled(c(1, 2, NA, 1, 2), labels = c("Ja" = 1, "Nee" = 2))
  expect_equal(detect_type(x), "categorical")
})

test_that("detect_type() slaat open antwoorden (character) over", {
  expect_equal(detect_type(c("Dit is een antwoord", "En nog een", NA)), "skip")
})

test_that("detect_type() slaat all-NA (logical) vector over", {
  expect_equal(detect_type(c(NA, NA, NA)), "skip")
})

# =============================================================================
# TEST: is_dichotomous()
# =============================================================================

test_that("is_dichotomous() vereist precies 2 value labels", {
  expect_true(is_dichotomous(
    haven::labelled(c(0, 1), labels = c("Nee" = 0, "Ja" = 1))
  ))
  expect_false(is_dichotomous(
    haven::labelled(c(1, 2), labels = c("Ja" = 1, "Nee" = 2, "Weet niet" = 3))
  ))
  expect_false(is_dichotomous(c(0, 1, 1)))  # geen labels
})

# =============================================================================
# TEST: analyse_categorisch()
# =============================================================================

test_that("analyse_categorisch() berekent frequenties correct", {
  x <- haven::labelled(
    c(1, 1, 2, 2, 2, 3),
    labels = c("Ja" = 1, "Nee" = 2, "Weet niet" = 3)
  )
  result <- analyse_categorisch(x, "Bent u tevreden?", "Q1")

  expect_true(is.data.frame(result))
  expect_equal(nrow(result), 3)  # drie antwoordopties
  expect_equal(result$n, c(2L, 3L, 1L))
  expect_equal(sum(result$n), 6)
  expect_equal(sum(result$pct), 100)
  expect_equal(unique(result$variabele), "Q1")
  expect_equal(unique(result$label), "Bent u tevreden?")
})

test_that("analyse_categorisch() handelt missing values correct", {
  x <- haven::labelled(c(1, 2, NA, 1, 2, NA), labels = c("Ja" = 1, "Nee" = 2))
  result <- analyse_categorisch(x, "Vraag", "Q1")

  # n_valid = aantal niet-NA
  expect_equal(unique(result$n_valid), 4L)
})

test_that("analyse_categorisch() houdt antwoordopties met n = 0", {
  x <- haven::labelled(c(1, 1), labels = c("Ja" = 1, "Nee" = 2))
  result <- analyse_categorisch(x, "Vraag", "Q1")

  expect_equal(nrow(result), 2)
  expect_equal(result$n[result$code == 2], 0L)
})

test_that("analyse_categorisch() berekent percentages onafgerond", {
  x <- haven::labelled(c(1, 2, 2, 2, 2, 2), labels = c("Ja" = 1, "Nee" = 2))
  result <- analyse_categorisch(x, "Vraag", "Q1")

  # 1/6 = 16.666...% — mag niet afgerond zijn
  expect_equal(result$pct[result$code == 1], 100 / 6)
})

test_that("analyse_categorisch() retourneert juiste kolommen", {
  x <- haven::labelled(c(1, 2, 1), labels = c("Ja" = 1, "Nee" = 2))
  result <- analyse_categorisch(x, "Vraag", "Q1")

  expect_named(
    result,
    c("variabele", "label", "n_valid", "code", "antwoord_label", "n", "pct")
  )
})

test_that("analyse_categorisch() zet True/False om naar Ja/Nee", {
  x <- haven::labelled(c(0, 1), labels = c("False" = 0, "True" = 1))
  result <- analyse_categorisch(x, "Vraag", "Q1")

  expect_equal(result$antwoord_label, c("Nee", "Ja"))
})

test_that("analyse_categorisch() bij lege vector: alle n = 0", {
  x <- haven::labelled(integer(), labels = c("Ja" = 1L, "Nee" = 2L))
  result <- analyse_categorisch(x, "Vraag", "Q1")

  # Geeft wel rijen terug (één per label), maar zonder waarnemingen;
  # het rapport filtert zulke clusters weg op n > 0.
  expect_equal(sum(result$n), 0)
  expect_equal(unique(result$n_valid), 0L)
})

# =============================================================================
# TEST: analyse_numeriek()
# =============================================================================

test_that("analyse_numeriek() berekent descriptives correct", {
  result <- analyse_numeriek(c(1, 2, 3, 4, 5), "Leeftijd", "Age")

  expect_true(is.data.frame(result))
  expect_equal(nrow(result), 1)
  expect_equal(result$gem, 3)
  expect_equal(result$mediaan, 3)
  expect_equal(result$min, 1)
  expect_equal(result$max, 5)
  expect_equal(result$sd, sqrt(2.5))  # steekproef-SD (n - 1)
})

test_that("analyse_numeriek() handelt missing values", {
  result <- analyse_numeriek(c(1, 2, NA, 4, 5), "Leeftijd", "Age")

  expect_equal(result$n_valid, 4L)
  expect_equal(result$gem, 3)  # (1+2+4+5)/4 = 3
})

test_that("analyse_numeriek() geeft NA voor SD bij n = 1", {
  result <- analyse_numeriek(5, "Leeftijd", "Age")

  expect_equal(result$n_valid, 1L)
  expect_true(is.na(result$sd))
})

test_that("analyse_numeriek() handelt all-NA", {
  result <- analyse_numeriek(c(NA, NA, NA), "Vraag", "Q1")

  expect_equal(result$n_valid, 0L)
  expect_true(all(is.na(unlist(result[, c("gem", "mediaan", "sd", "min", "max")]))))
})

test_that("analyse_numeriek() retourneert juiste kolommen", {
  result <- analyse_numeriek(c(1, 2, 3), "Vraag", "Q1")

  expect_named(
    result,
    c("variabele", "label", "n_valid", "gem", "mediaan", "sd", "min", "max")
  )
})

# =============================================================================
# TEST: analyse_var() — inclusief Haven 2.5.5 label-bug
# =============================================================================

test_that("analyse_var() kiest analyse op basis van type", {
  data <- data.frame(num = c(1, 2, 3), tekst = c("a", "b", "c"))
  data$cat <- haven::labelled(c(1, 2, 1), labels = c("Ja" = 1, "Nee" = 2))

  expect_named(analyse_var("num", data), c(
    "variabele", "label", "n_valid", "gem", "mediaan", "sd", "min", "max"
  ))
  expect_equal(nrow(analyse_var("cat", data)), 2)
  expect_null(analyse_var("tekst", data))
})

test_that("analyse_var() is robuust tegen Haven 2.5.5 vector-label bug", {
  data <- data.frame(Q1 = c(1, 2, 3))
  attr(data$Q1, "label") <- c(1, 2, 3)  # numerieke vector i.p.v. string

  result <- analyse_var("Q1", data)
  expect_equal(result$label, "Q1")  # valt terug op variabelenaam
})

test_that("analyse_var() gebruikt het variabelelabel", {
  data <- data.frame(Q1 = c(1, 2, 3))
  attr(data$Q1, "label") <- "Aantal medewerkers"

  expect_equal(analyse_var("Q1", data)$label, "Aantal medewerkers")
})

# =============================================================================
# TEST: strip_overlap_label()
# =============================================================================

test_that("strip_overlap_label() verwijdert prefix dat overeenkomt met vraag", {
  vraag <- "Welke activiteiten organiseert u?"
  expect_equal(
    strip_overlap_label("Welke activiteiten... - Concerten", vraag),
    "Concerten"
  )
  # Geen overlap → origineel label
  expect_equal(
    strip_overlap_label("Iets heel anders... - Concerten", vraag),
    "Iets heel anders... - Concerten"
  )
  # Geen vraagtekst → origineel label
  expect_equal(strip_overlap_label("Concerten", NULL), "Concerten")
})

# =============================================================================
# TEST: analyse_multiselect()
# =============================================================================

test_that("analyse_multiselect() berekent aanvinkstatistieken", {
  ja_nee <- c("Nee" = 0, "Ja" = 1)
  data <- data.frame(
    Q2_1 = haven::labelled(c(1, 0, 1, 1), labels = ja_nee),  # 3 van 4
    Q2_2 = haven::labelled(c(0, 1, 1, 0), labels = ja_nee)   # 2 van 4
  )
  result <- analyse_multiselect(c("Q2_1", "Q2_2"), data)

  expect_true(is.data.frame(result))
  expect_equal(result$gem_aangevinkt, 1.25)  # (3+2)/4
  expect_equal(result$mediaan_aangevinkt, 1)
  expect_equal(result$n_heeft_ingevuld, 4L)
  expect_equal(result$n_items, 2L)
  expect_equal(result$n_nul_items, 0L)
})

test_that("analyse_multiselect() telt items die niemand aanvinkte", {
  ja_nee <- c("Nee" = 0, "Ja" = 1)
  data <- data.frame(
    Q2_1 = haven::labelled(c(1, 1), labels = ja_nee),
    Q2_2 = haven::labelled(c(0, 0), labels = ja_nee)
  )
  expect_equal(analyse_multiselect(c("Q2_1", "Q2_2"), data)$n_nul_items, 1L)
})

test_that("analyse_multiselect() negeert respondenten zonder antwoorden", {
  ja_nee <- c("Nee" = 0, "Ja" = 1)
  data <- data.frame(
    Q2_1 = haven::labelled(c(1, NA, 0), labels = ja_nee),
    Q2_2 = haven::labelled(c(1, NA, 1), labels = ja_nee)
  )
  result <- analyse_multiselect(c("Q2_1", "Q2_2"), data)

  expect_equal(result$n_heeft_ingevuld, 2L)
  expect_equal(result$gem_aangevinkt, 1.5)
})

test_that("analyse_multiselect() geeft NULL zonder dichotome variabelen", {
  data <- data.frame(Q1 = c(1, 2, 3))  # geen labels
  expect_null(analyse_multiselect("Q1", data))
  expect_null(analyse_multiselect(character(), data))
})

# =============================================================================
# TEST: classify_speciaal()
# =============================================================================

test_that("classify_speciaal() herkent speciale categorieën", {
  expect_equal(
    classify_speciaal(c(
      "Anders, namelijk", "OPEN: Anders", "Nee", "Geen van bovenstaande",
      "Weet ik niet", "Wil ik niet zeggen", "Niet van toepassing", "N.v.t."
    )),
    c(
      "anders_namelijk", "anders_namelijk", "nee_geen", "nee_geen",
      "weet_niet", "wil_niet_zeggen", "niet_toepassing", "niet_toepassing"
    )
  )
})

test_that("classify_speciaal() geeft geen false positives", {
  expect_equal(
    classify_speciaal(c("Toneel", "Personeel", "Geen andere functies", "Ja")),
    c("normaal", "normaal", "nee_geen", "normaal")
  )
})

test_that("classify_speciaal() prioriteit: eerste match wint", {
  expect_equal(classify_speciaal("Weet ik niet / wil ik niet zeggen"), "weet_niet")
})
