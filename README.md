# monitoranalyse

R-package voor de analyse en rapportage van LKCA-monitordata.

Invoer: een opgeschoond SPSS-bestand (`.sav`) en een metadata-bestand
(`.xlsx`, `.xls` of `.csv`). Uitvoer per run: één zelfstandig HTML-rapport
(Quarto) en een datapackage met analyseobject, logs en een kopie van het
project en de gebruikte engine.

```text
SPSS (opschonen) → 01_data/ → validatie → analyseobject → HTML-rapport + datapackage
```

> Het analyseobject is de enige bron van waarheid: het rapport rekent zelf
> niets uit en rondt alleen af volgens een vastgelegde conventie.

## Installatie (eenmalig)

Nodig: R (≥ 4.1) en RStudio. RStudio levert Quarto mee, en Quarto is nodig voor het
rapport.

```r
install.packages("pak")
pak::pak("alex-janse/monitoranalyse")
```

## Snelstart

1. Maak een projectmap:

   ```r
   monitoranalyse::nieuw_project("C:/Projecten/Monitor Poppodia 2026")
   ```

2. Zet je opgeschoonde `.sav` en metadata in `01_data/`.
3. Open `02_Analyseproces.Rproj` in RStudio.
4. Vul in `03_config.R` de drie regels bovenaan in (`project_naam`,
   `input_sav`, `metadata_file`).
5. Open `04_run_project.R` en klik op **Source** (Ctrl+Shift+S).

Het rapport verschijnt als `05_output/analyse-output_<datum-tijd>.html`, het
archief als `05_output/datapackage_<datum-tijd>/`. Uitgebreide uitleg staat in
`00_handleiding.md` in elke projectmap.

Zonder RStudio (bijvoorbeeld om te testen):

```sh
cd "C:/Projecten/Monitor Poppodia 2026"
Rscript 04_run_project.R
```

## Bijwerken en specifieke versies

```r
pak::pak("alex-janse/monitoranalyse")          # nieuwste versie
pak::pak("alex-janse/monitoranalyse@v2.0.0")   # exact versie 2.0.0
packageVersion("monitoranalyse")               # welke versie heb ik?
```

Elke run legt de engineversie (en de GitHub-commit) vast in
`logs/run_log.txt`, in `$meta` van het analyseobject en in
`engine/ENGINE_VERSIE.txt` in het datapackage. In `03_config.R` staat
`engine_versie`: wijkt de geïnstalleerde versie daarvan af, dan geeft de run
een waarschuwing.

## Geëxporteerde functies

| Functie | Doel |
|---|---|
| `nieuw_project(pad)` | Projectmap maken uit het sjabloon |
| `run_project(config = "03_config.R")` | Volledige pipeline (dit roept `04_run_project.R` aan) |
| `read_data()`, `read_metadata()` | Invoer inlezen |
| `validate_input()` | Inputcontroles (audit_log) |
| `analyse_dataset()` | Analyseobject bouwen |
| `rond_af()`, `formatteer_pct()` | De vastgelegde afrondingsconventie |

## Ontwikkelen

- Technische documentatie: [`docs/technisch.md`](docs/technisch.md)
- Ontwikkelafspraken en principes: [`CLAUDE.md`](CLAUDE.md)
- Wijzigingen per versie: [`NEWS.md`](NEWS.md)

```r
devtools::test()      # unit tests + end-to-end-test met verzonnen data
devtools::install()   # nodig vóór een rapport-render: rapport.qmd draait in
                      # een eigen R-proces en laadt het geïnstalleerde package
```

Deze repository bevat **geen data**: de tests gebruiken een volledig
verzonnen fixture (`tests/testthat/helper-fixture.R`). Het LKCA-logo zit
niet in de repository; zie `logo_bestand` in `03_config.R`.

Versie 1.x (de zip-brontemplate) blijft bestaan als referentie voor projecten
en rapporten die daarmee zijn gemaakt. Versie 2.0.0 geeft voor dezelfde invoer
identieke cijfers en een identiek rapport.

## Licentie

© Alex Janse. Uitgebracht onder de
[European Union Public Licence v1.2 (EUPL-1.2)](LICENSE.md). Het LKCA-logo
valt niet onder deze licentie en zit niet in de repository.
