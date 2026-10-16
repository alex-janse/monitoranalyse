# =============================================================================
# read_data.R
# Laad het opgeschoonde .sav-bestand in als tibble.
# =============================================================================


#' Laad het opgeschoonde SPSS-bestand
#'
#' @param pad Bestandspad naar het .sav-bestand (relatief aan projectroot)
#' @return Tibble met de volledige dataset (inclusief haven-attributen)
#' @details Stopt met een duidelijke foutmelding als het bestand niet bestaat.
#' @export
read_data <- function(pad) {
  if (!file.exists(pad)) {
    stop(
      "Bronbestand niet gevonden: ",
      pad,
      "\n",
      "Controleer of het .sav-bestand in de juiste map staat en of het ",
      "pad in 03_config.R correct is ingesteld."
    )
  }
  data <- tryCatch(
    haven::read_sav(pad),
    error = function(e) {
      message("Standaard inlezen mislukt, probeer met windows-1252 encoding...")
      haven::read_sav(pad, encoding = "windows-1252")
    }
  )
  message(
    "Databestand geladen: ",
    pad,
    " (",
    nrow(data),
    " respondenten, ",
    ncol(data),
    " variabelen)"
  )
  data
}
