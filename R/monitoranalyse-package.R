# =============================================================================
# monitoranalyse-package.R
# Package-documentatie, imports en globale variabelen.
#
# De engine-modules gebruiken tidyverse-functies zonder pkg::-prefix (zoals in
# v1.x, waar ze via library() werden geladen). Die functies worden hier
# expliciet geïmporteerd, zodat de modulecode ongewijzigd kan blijven.
# =============================================================================

#' @keywords internal
"_PACKAGE"

#' @importFrom dplyr across all_of arrange bind_rows case_when count distinct
#' @importFrom dplyr everything filter first group_by if_else mutate pull
#' @importFrom dplyr select summarise ungroup
#' @importFrom purrr map_dfr
#' @importFrom rlang %||% sym
#' @importFrom stats median sd setNames
#' @importFrom stringr regex str_count str_detect str_extract str_match
#' @importFrom stringr str_replace_all str_squish str_to_lower str_trim
#' @importFrom tibble tibble
#' @importFrom utils capture.output head read.csv2 sessionInfo
NULL

# Kolomnamen die in dplyr-code als "kale" namen worden gebruikt (data masking).
# Voorkomt R CMD check-notes "no visible binding for global variable".
utils::globalVariables(c(
  "chart_type", "cluster", "cluster_id", "kruis_categorie", "kruis_label",
  "kruisvariabele", "n", "n_in_data", "n_kruis", "n_som", "n_valid", "num",
  "pct", "som", "variabele", "vraag"
))
