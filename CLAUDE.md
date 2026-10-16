# CLAUDE.md — ontwikkelgeheugen monitoranalyse

R-package (v2.x) dat LKCA-monitordata analyseert: opgeschoond `.sav` +
metadata → validatie → analyseobject → Quarto-HTML-rapport + datapackage.
Opvolger van de zip-brontemplate v1.x. Technische details staan in
`docs/technisch.md`; dit bestand bevat de afspraken.

**Communiceer met de eigenaar in het Nederlands.** Code-commentaar,
meldingen en documentatie zijn Nederlands, in de stijl van de bestaande code
(sectiekoppen `# ---- Titel ----`, tidyverse, `|>`).

Lokale, niet-publieke context (paden naar de v1.x-bronrepo, de
referentie-output en de echte testdata) staat in `CLAUDE.local.md`. Dat
bestand staat in `.gitignore` en mag nooit worden gecommit.

## Harde regels

1. **Identieke output.** Er hangt een extern beheerd dashboard aan en er zijn
   PDF's gepubliceerd. Een wijziging mag de cijfers of het rapport niet
   ongemerkt veranderen. Bij elke wijziging die de output kan raken:
   vergelijk met de vorige versie (alle analyseobject-componenten
   `identical()`; HTML na normalisatie van base64, tijdstempels en
   `htmlwidget-<id>`).
2. **Afronding ligt vast** (`R/afronding.R`): R `round()`, halve naar even;
   `pct_decimalen` 0, `stat_decimalen` 1. Alle afronding loopt via
   `rond_af()`/`formatteer_pct()`. `tests/testthat/test_afronding.R` **nooit**
   aanpassen om groen te krijgen. Een wijziging hier is een major-versie en vraagt
   een expliciet besluit van de eigenaar.
3. **Analyseobject alleen uitbreiden.** Nooit componenten, kolommen, types of
   volgorde wijzigen of hernoemen. Nieuwe velden komen achteraan. Meld nieuwe velden in
   `NEWS.md`.
4. **Geen data in de repo (publiek).** Geen `.sav`, `.rds`, `.xlsx`, `.csv`,
   output, logo's, namen van organisaties of respondenten, of interne paden.
   Tests gebruiken alleen de verzonnen fixture (`tests/testthat/helper-fixture.R`).
   Controleer vóór elke commit of push:
   `git diff --cached --name-only | grep -iE '\.(sav|rds|xlsx|xls|csv|jpg|png)$'`
   en zoek op interne paden en gebruikersnamen (zie `CLAUDE.local.md`).
5. **Collega-ervaring blijft eenvoudig:** projectmap met `01_data/`, drie
   regels in `03_config.R` en Source van `04_run_project.R`. Foutmeldingen zijn
   begrijpelijk Nederlands en zeggen wat de gebruiker moet doen.
6. Geen methodologische keuzes wijzigen zonder expliciete opdracht.

## Kernprincipes (uit v1.x, blijven gelden)

- Het analyseobject is de enige bron van waarheid. Het rapport rekent niets zelf
  uit (geen frequenties, noemers of percentages in `rapport.qmd`).
- Percentages blijven onafgerond in het analyseobject.
- Lege onderdelen hebben altijd een stabiel schema.
- Validatietekst nooit "alles in orde". Wel: "binnen de uitgevoerde
  automatische controles geen fouten/waarschuwingen".
- DT/htmlwidgets: geen `cat()`/`print()`/`results: asis`. Gebruik in plaats daarvan
  `htmltools::tagList()`.
- Vrije tekst/labels in ruwe HTML: `md_veilig()`/`md_veilig_tabel()`, of
  client-side opbouwen uit JSON (pandoc herparseert div-inhoud als markdown).
- SPSS is de opschoonlaag. Er is geen `corrections.R` meer (vervallen in 2.0.0).
- Alleen blokkerende validatiefouten stoppen de run (kolom `blokkerend` in
  audit_log). Overige fouten verschijnen in het rapport.

## Werkwijze

- Kleine stappen, commit per afgeronde stap. Commit niet zonder dat de tests
  groen zijn.
- `devtools::test()` moet groen zijn. Na een wijziging in `R/` die het rapport
  raakt, eerst `devtools::install()`: `rapport.qmd` draait in een eigen
  R-proces met het geïnstalleerde package.
- R CMD check: er is geen Rtools op de ontwikkelmachine, dus
  `devtools::check()` weigert. Gebruik `R CMD build .` en
  `NOT_CRAN=true R CMD check --no-manual <tar.gz>`. Verwacht: 0 errors en 0
  warnings, plus 1 NOTE over Imports die alleen `rapport.qmd` gebruikt (bewust).
- Niet-ASCII in R-strings schrijven als `\uXXXX` (R CMD check). Let op:
  sommige schrijftools zetten `\uXXXX` om naar het echte teken; controleer met
  `tools::showNonASCIIfile()`.
- `inst/rapport/**` is byte-exact (CRLF, `-text` in `.gitattributes`). Behoud bij
  het bewerken de regeleinden.
- Release: versie in `DESCRIPTION` + sectie bovenaan `NEWS.md` → commit →
  tag `v<versie>` → push. Patch = bugfix zonder outputwijziging, minor = nieuwe
  functie, major = brekende of methodologische wijziging.
- Push en tags alleen met expliciete toestemming van de eigenaar.
- Licentie: EUPL-1.2 (sluit aan bij het open-sourcebeleid van de overheid).
  De volledige tekst staat in `LICENSE.md`. Auteursrechthouder is Alex Janse
  (`cph` in `DESCRIPTION`). Het LKCA-logo valt hier niet onder en blijft
  buiten de repo.

## Open punten

- Navragen bij de dashboardpartij of zij de onafgeronde `pct` uit
  `analyse_object.rds` gebruiken. Dan moeten zij ook halve-naar-even
  afronden (Excel `ROUND()` doet dat niet).
- Roadmap: zie `docs/technisch.md`.
