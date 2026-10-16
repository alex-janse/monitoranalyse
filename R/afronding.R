# =============================================================================
# afronding.R
# Afrondingsconventie voor alle getallen in het rapport — VASTGELEGD.
#
# Gebruikt door rapport.qmd (setup-chunk). Het analyseobject zelf blijft
# altijd onafgerond; afronden gebeurt uitsluitend via deze functies.
#
# CONVENTIE (sinds v1.0.0, vastgelegd in v1.3.0):
#   - R base::round(): bij precies een halve wordt naar het EVEN getal
#     afgerond (IEC 60559). Dus 12.5 -> 12, 37.5 -> 38, 62.5 -> 62.
#     Dit wijkt af van SPSS/Excel (halve altijd van nul af: 12.5 -> 13).
#   - Percentages: config.R::pct_decimalen (standaard 0).
#   - Statistieken: config.R::stat_decimalen (standaard 1).
#   - Weergave: decimaalpunt, geen opvulnullen ("42.5%", "42%").
#
# WAAROM VAST: gepubliceerde rapporten (PDF) en het extern beheerde
# dashboard zijn met deze conventie gemaakt. Bij toevoeging van nieuwe
# meetjaren moeten oude en nieuwe cijfers op dezelfde manier afgerond zijn.
# Een wijziging hier verandert gepubliceerde cijfers en is daarom een
# MAJOR-versie (methodologische wijziging). De tests in
# test_afronding.R bewaken dit gedrag.
# =============================================================================

#' Rond een getal af volgens de vastgelegde conventie
#'
#' @param x         Numerieke vector (onafgerond)
#' @param decimalen Aantal decimalen
#' @return Afgeronde numerieke vector
#' @export
rond_af <- function(x, decimalen) {
  round(x, decimalen)
}

#' Formatteer een percentage (0-100) als tekst met %-teken
#'
#' @param x         Numerieke vector, percentages op 0-100 schaal
#' @param decimalen Aantal decimalen (config.R::pct_decimalen)
#' @return Karaktervector, bijv. "43%"
#' @export
formatteer_pct <- function(x, decimalen) {
  paste0(rond_af(x, decimalen), "%")
}
