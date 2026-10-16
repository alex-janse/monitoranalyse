# monitoranalyse — technische documentatie

Voor wie modules wil bijwerken, bugs wil fixen of functies wil toevoegen.
Gebruikersinstructies staan in `inst/template/00_handleiding.md` (in elke
projectmap `00_handleiding.md`).

---

## Architectuur

```text
<projectmap>/04_run_project.R
    └─ monitoranalyse::run_project("03_config.R")        R/run_project.R
        ├─ lees_config()          03_config.R in eigen omgeving + defaults
        ├─ controleer_quarto()    Nederlandse melding als Quarto ontbreekt
        ├─ read_data()            R/read_data.R       (.sav laden)
        ├─ read_metadata()        R/read_metadata.R   (metadata + schema-check)
        ├─ validate_input()       R/validate_input.R  (audit_log)
        ├─ stop_bij_blokkerende_fout()                (stopt bij blokkerende FOUT)
        ├─ analyse_dataset()      R/analyse_dataset.R (centrale analysemotor)
        │   ├─ R/analyse_helpers.R      (type-detectie, analysefuncties)
        │   └─ R/analyse_open_vragen.R  (open antwoorden)
        ├─ logging()              R/logging.R         (rds + logs wegschrijven)
        ├─ render_rapport()       inst/rapport/ → tijdelijke map → Quarto
        │   └─ rapport.qmd  (gebruikt monitoranalyse::rond_af/formatteer_pct)
        ├─ clone_project()        projectkopie in datapackage
        └─ archiveer_engine()     R/engine_info.R (engine/ in datapackage)

05_output/
├── analyse-output_<ts>.html      ← rapport
└── datapackage_<ts>/
    ├── logs/                     analyse_object.rds, audit_log.rds,
    │                             run_log.txt, session_info.txt,
    │                             metadata_snapshot.xlsx
    ├── engine/                   ENGINE_VERSIE.txt, rapport/, R/monitoranalyse_functies.R
    ├── 01_data/, 03_config.R, 04_run_project.R, ...   (projectkopie)
    └── 05_output/                (kopie, excl. datapackage_*/)
```

**Gouden regel:**

> Het analyseobject (`analyse_object.rds`) is de enige bron van waarheid.
> Tabellen en figuren in het rapport mogen nooit zelf frequenties, noemers of
> percentages berekenen.

### Package-opbouw

| Pad | Inhoud |
|---|---|
| `R/` | Engine-modules als package-functies (geen `library()`/`source()`; imports in `R/monitoranalyse-package.R`) |
| `inst/rapport/` | `rapport.qmd`, `assets/lkca-theme.scss`, `js/copy-figuur-knop.html` (byte-voor-byte bewaard, CRLF; zie `.gitattributes`) |
| `inst/template/` | Projectsjabloon voor `nieuw_project()` |
| `tests/testthat/` | Unit tests + end-to-end-test met verzonnen fixture |
| `docs/` | Deze documentatie (niet in het package-build) |

---

## Kernprincipes

- SPSS is de opschoonlaag; R valideert, analyseert, rapporteert en archiveert.
- Eén centraal analyseobject: platte tibbles met kolom `cluster_id`.
- `rapport.qmd` leest uitsluitend uit het analyseobject en de audit_log.
- Percentages blijven onafgerond in het analyseobject; afronden alleen in
  `rapport.qmd` via `rond_af()`/`formatteer_pct()` (R/afronding.R).
- Het analyseobject wordt alleen **uitgebreid**, nooit gewijzigd (het
  extern beheerde dashboard kan `analyse_object.rds` lezen).
- Lege onderdelen hebben altijd een stabiel schema.
- Validatietekst zegt nooit "alles in orde"; alleen dat binnen de uitgevoerde
  automatische controles geen fouten/waarschuwingen zijn gevonden.
- Project-specifieke logica blijft beperkt tot `03_config.R`. (Het oude
  `corrections.R` is in v2.0.0 vervallen; correcties horen in SPSS.)

---

## `run_project()` — entry point

- Zet de werkmap tijdelijk op de map van `03_config.R` (`on.exit` zet hem
  terug). Relatieve paden uit de config (`"01_data/..."`) komen daardoor
  ongewijzigd in `$meta` en in het rapport, net als in v1.x.
- Leest `03_config.R` met `sys.source()` in een eigen omgeving; ontbrekende
  optionele instellingen krijgen de v1.x-defaults (`resp_id_col = "ID"`,
  `kruis_vars = list()`, `pct_decimalen = 0`, `stat_decimalen = 1`,
  `kleine_n_drempel = 10`, `logo_bestand = NULL`, `engine_versie = NULL`).
- `browseURL()` alleen als `open_rapport = TRUE` (standaard: `interactive()`).

### Rapport renderen (`render_rapport()`)

De installatiemap van een package kan alleen-lezen zijn en spaties bevatten.
Daarom:

1. `inst/rapport/` wordt naar een tijdelijke map gekopieerd;
2. Quarto rendert daar, met alle params als **absolute** paden
   (`normalizePath`);
3. `rapport.html` wordt naar `05_output/analyse-output_<ts>.html` gekopieerd.

Les uit v1.0.0: Quarto rendert vanuit de map van het `.qmd`-bestand. Alle
paden in YAML, chunks en `execute_params` moeten dus relatief aan de `.qmd`
óf absoluut zijn.

`rapport.qmd` draait in een **eigen R-proces** en laadt het **geïnstalleerde**
package (`monitoranalyse::rond_af`). Na een wijziging in `R/afronding.R`
moet je dus eerst installeren (`devtools::install()`) voordat een render de
wijziging ziet.

### Stoppen bij blokkerende fouten

`validate_input()` markeert per controle of een FOUT **blokkerend** is
(kolom `blokkerend`). Alleen blokkerende fouten stoppen de run, direct na de
validatie (`stop_bij_blokkerende_fout()`); `audit_log.rds` en `run_log.txt`
worden dan nog wel weggeschreven.

| Controle | Status bij probleem | Blokkerend? | Waarom |
|---|---|---|---|
| 1. metadata-variabelen ontbreken in data | FOUT | nee | analyse kan door; rapport toont fout |
| 3. N onder drempel | FOUT | nee | idem |
| 4. dubbele ID's | FOUT | nee | idem |
| 9. `resp_id_col` niet in data | FOUT | **ja** | open antwoorden/kruisingen kunnen niet gekoppeld worden; analyse crasht anders |

Niet-blokkerende fouten blijven in het rapport zichtbaar (rode banner,
resultaattabbladen verborgen). Zo ziet een collega alle problemen in één
keer in plaats van ze één voor één via een stop te ontdekken.

Extra afweer: `analyse_dataset()` en `analyse_open_vragen()` controleren aan
het begin zelf `resp_id_col` (`controleer_resp_id_col()`), zodat er ook bij
direct gebruik geen cryptische dplyr-fout ontstaat.

---

## Modules

### `analyse_helpers.R`

| Functie | Doel |
|---|---|
| `detect_type(x)` | `"categorical"` (value labels), `"numeric"` of `"skip"` |
| `is_dichotomous(x)` | precies 2 unieke value labels |
| `strip_overlap_label(x, vraag)` | overlappende vraagtekst uit variabelenlabel |
| `strip_overlap_value_label(x, vraag)` | idem voor antwoordlabels; True/False → Ja/Nee |
| `classify_speciaal(x)` | normaal of een van 5 speciale categorieën |
| `analyse_categorisch(x, label, varname, vraag)` | frequentietabel (pct onafgerond) |
| `analyse_numeriek(x, label, varname)` | descriptives (onafgerond) |
| `analyse_var(v, data, vraag)` | dispatcher |
| `analyse_multiselect(vars, data)` | samenvatting multiselectclusters |

`classify_speciaal()` staat ook in de setup-chunk van `rapport.qmd` (voor
de sortering in de rendersessie). Houd beide gelijk.

| Prio | Categorie | Regex |
|---|---|---|
| 1 | `anders_namelijk` | `(?i)^(open:\s*)?ander` |
| 2 | `nee_geen` | `(?i)(\bnee\b\|geen)` |
| 3 | `weet_niet` | `(?i)weet.*niet` |
| 4 | `wil_niet_zeggen` | `(?i)wil.*niet.*zeggen\|wil.*liever.*niet` |
| 5 | `niet_toepassing` | `(?i)niet van toepassing\|n\.v\.t\.` |

### `read_data.R`

`haven::read_sav(pad)`; bij een fout een tweede poging met
`encoding = "windows-1252"`. Geen geforceerde UTF-8 (gaf eerder een
encoding-error).

### `read_metadata.R`

`.xlsx`/`.xls` (werkblad `metadata` of anders het eerste, alles als tekst)
of `.csv` (SPSS-export: `;`, UTF-8-BOM). Verplicht: `variabele`, `cluster`,
`vraag` (exact). Optioneel: `grafiek_inclusie` (default TRUE), `chart_type`
(default `"bar"`). Stopt bij dubbele kolomnamen, ontbrekende verplichte
kolommen, lege of dubbele variabelen.

### `validate_input.R`

Bouwt de `audit_log`:

| Kolom | Betekenis |
|---|---|
| `domein` | onderdeel |
| `controle` | beschrijving |
| `status` | `INFO`, `WAARSCHUWING` of `FOUT` |
| `detail` | bevinding |
| `blokkerend` | (sinds 2.0.0) TRUE = analyse kan niet door |

Respondent-ID (sinds 2.0.0):

- controle 2 telt `resp_id_col` als systeemkolom (geen onterechte
  waarschuwing "geen metadata-regel");
- controle 4 (dubbele ID's) gebruikt `resp_id_col`, met terugval op
  `ID`/`RespondentID`/`orinr` als die kolom niet bestaat;
- controle 9 zoekt bij een ontbrekende kolom kandidaten
  (`zoek_id_kolommen()`: niet hoofdlettergevoelig, zonder leestekens; bekende
  namen als `id`, `respid`, `respondentid`, `orinr`, of eindigend op `_id`)
  en stelt die voor: `Bedoel je resp_id_col <- "respid"?`. Zonder kandidaat
  toont de melding alle kolomnamen (tot 100).

### `analyse_dataset.R`

Bouwt het analyseobject; voert sanity checks uit (pct ≈ 100, n ≤ N,
`n_valid == sum(n)`, waarschuwing bij alleen gehele pct). Multiselect alleen
bij clusters met meer dan één analysevariabele. Kruistabellen alleen voor
dichotome variabelen.

### `logging.R`

Schrijft `analyse_object.rds`, `audit_log.rds`, `run_log.txt` (met
engineversie en -commit), `session_info.txt` en `metadata_snapshot.xlsx`.

### `engine_info.R`

- `engine_info()`: versie (`packageVersion`) en GitHub-commit
  (`packageDescription()$RemoteSha`, gezet door pak/remotes; anders `NA`).
  Bij de aanbevolen installatie via de tarball-URL is de commit `NA`; de
  versie (= tag) legt de engine dan vast.
- `controleer_engine_versie()`: waarschuwing als `engine_versie` uit de
  config afwijkt.
- `archiveer_engine()`: `engine/` in het datapackage. Een geïnstalleerd
  package bevat geen R-bronbestanden; daarom worden de functies gedeparsed
  (functioneel exact, zonder commentaar). Exacte herinstallatie via
  `installatie_regel()`: `install.packages("<github>/archive/<commit of
  refs/tags/v-tag>.tar.gz", repos = NULL, type = "source")`.

### Installatie zonder Rtools

`pak::pak("alex-janse/monitoranalyse")` faalt op Windows zonder Rtools
(getest met pak 0.11.1). pak markeert een GitHub-package als
`needscompilation = TRUE`, en ook met `NeedsCompilation: no` in
`DESCRIPTION` eist het daarna Rtools. `install.packages()` met de
tarball-URL van een tag werkt wel, maar installeert de afhankelijkheden niet.
Die staan daarom als expliciete lijst in de README en in de handleiding:
Imports zonder basispackages, plus `ggpattern`. `ggpattern` staat in
Suggests, maar zonder dit package tekent het rapport kleine-N-staven effen in
plaats van gestreept, dus het hoort erbij voor identieke output.
`tests/testthat/test_installatie.R` bewaakt dat die lijst gelijk blijft aan
`DESCRIPTION`. Een duurzamere optie is r-universe (Windows-binaries,
afhankelijkheden automatisch).

---

## Analyseobject — contract

```text
obj
├── meta              n_totaal, input_sav, sav_mtime, metadata_file,
│                     aangemaakt_op, r_version, n_clusters, clusters_volgorde,
│                     engine_versie (2.0.0), engine_commit (2.0.0)
├── frequenties       één rij per variabele × antwoordoptie
├── descriptives      één rij per numerieke variabele
├── multiselect       één rij per multiselectcluster
├── kruistabellen     één rij per variabele × kruiscategorie (%Ja)
├── kruis_verdeling   één rij per kruisvariabele × categorie (1.3.0)
├── open_antwoorden   één rij per ingevuld open antwoord
├── open_samenvatting één rij per open variabele
├── kv_resp           resp_id → KV-categorieën (labels)
├── kv_codes          per KV: label → numerieke code (sortering)
└── niet_meegenomen   niet-geanalyseerde variabelen
```

**Alleen uitbreiden.** Nieuwe velden/componenten achteraan toevoegen;
bestaande componenten, kolommen, types en volgorde nooit wijzigen. Pas bij
nieuwe kolommen ook de lege schema's in `analyse_dataset.R` aan.

---

## Afrondingsconventie ligt vast

| Wat | Regel |
|---|---|
| Methode | R `round()`: een halve naar het **even** getal (IEC 60559) |
| Percentages | `pct_decimalen` (standaard 0) |
| Statistieken | `stat_decimalen` (standaard 1) |
| Notatie | decimaalpunt, geen opvulnullen (`42.5%`, `42%`) |
| Som | niet naar 100 gecorrigeerd |

```text
12.5% → 12%    37.5% → 38%    62.5% → 62%    87.5% → 88%
```

SPSS en Excel (`ROUND()`) ronden een halve van nul af (12.5 → 13). Wie
buiten de pipeline afrondt (bijv. het dashboard op basis van
`analyse_object.rds`) moet dezelfde regel volgen.

- `rapport.qmd` gebruikt nooit zelf `round()`; de test controleert dit.
- Afronding wijzigen = gepubliceerde cijfers wijzigen = **major-versie**.
  Pas `tests/testthat/test_afronding.R` nooit aan om groen te krijgen.

---

## Rapport (`inst/rapport/rapport.qmd`)

Tabbladen: Overzicht, Rechte tellingen, Kruisingen, Open antwoorden (ruw).
Params: `project_naam`, `analyse_object`, `audit_log`, `pct_decimalen`,
`stat_decimalen`, `resp_id_col`, `logo_bestand`.

### DT-tabellen en htmlwidgets

> In chunks met DT/htmlwidgets geen `cat()`/`print()`/`results: asis`.
> Bouw HTML met `htmltools::tags` en retourneer een `htmltools::tagList()`.

DT-widgets in een inactieve Bootstrap-tab initialiseren op breedte 0. Bij de
eerste `shown.bs.tab` van Rechte tellingen wordt `columns.adjust()` op alle
tabellen gedaan, en pas daarna worden de niet-actieve divs verborgen.

### Markdown-veilige tekst (`md_veilig()`)

Pandoc herparseert de inhoud van ruwe `<div>`s als markdown. Tekst die begint
met `+`, `-`, `*` of `#` (ook na spaties) kan de div-structuur en zelfs de
tab-indeling laten ontsporen. Daarom:

- `md_veilig()`/`md_veilig_tabel()` vervangen een leidend teken door een
  HTML-entity; bijbehorende `knitr::kable()`-aanroepen gebruiken
  `escape = FALSE`;
- Open antwoorden (Op vraag, Overzicht) worden client-side uit JSON
  opgebouwd (`oaBouwVraagTabel()`, `oaBouwOverzichtTabel()`), ook om een
  pandoc-geheugenprobleem bij brede tabellen te voorkomen.

### Validatielog

Rood (fouten) → geel (waarschuwingen) → groen ("OK — automatische controles
uitgevoerd"). Groen betekent níét dat alles inhoudelijk klopt.

### Bekende cosmetische pandoc-meldingen

`Unable to parse table from raw html block` (door `kable(format = "html")`)
is onschadelijk.

---

## Waar voorzichtig mee

1. **Haven-labelbug.** `attr(x, "label")` kan een vector zijn. Gebruik het
   robuuste patroon (`is.null(raw) || length(raw) != 1 → varname`); staat
   in `analyse_helpers.R`, `analyse_dataset.R` en `analyse_open_vragen.R`.
2. **Niet-ASCII in R-code.** R CMD check eist ASCII buiten commentaar:
   gebruik in strings `\u` gevolgd door de hexcode (bijv. `2014` voor een
   em-dash).
3. **Byte-exacte rapportbestanden.** `inst/rapport/**` staat als `-text` in
   `.gitattributes` (CRLF blijft behouden), zodat de HTML identiek blijft.

---

## Testen

```r
devtools::test()      # alles
devtools::test(filter = "afronding")
```

| Bestand | Dekt |
|---|---|
| `test_afronding.R` | vastgelegde afrondingsconventie + rapport rondt niet zelf af |
| `test_analyse_helpers.R` | analysefuncties |
| `test_validate_input.R` | respondent-ID-controles, afweer in analyse |
| `test_pipeline.R` | `nieuw_project()`, end-to-end-run (vereist Quarto + geïnstalleerd package), vroege stop bij verkeerde `resp_id_col` |
| `helper-fixture.R` | volledig verzonnen fixture (dichotoom, multiselect, open, numeriek, twee kruisvariabelen) |

De end-to-end-test wordt overgeslagen zonder Quarto en onder CRAN
(`skip_on_cran`; zet `NOT_CRAN=true` bij `R CMD check`).

**R CMD check zonder Rtools:** `devtools::check()` weigert zonder Rtools,
ook voor een package zonder gecompileerde code. Gebruik dan:

```sh
R CMD build .
NOT_CRAN=true R CMD check --no-manual monitoranalyse_<versie>.tar.gz
```

Verwachte NOTE: "Namespaces in Imports field not imported from: DT, forcats,
ggplot2, htmltools, jsonlite, knitr, rmarkdown, tidyr". Die packages
gebruikt `rapport.qmd` (in een eigen R-proces), niet de R-code zelf. Ze staan
bewust in Imports: zo staan alle afhankelijkheden op één plek en installeren
pak en remotes ze mee.

### Vergelijking met een referentieversie

Bij elke wijziging die de output kan raken: draai een referentie-run en
vergelijk alle componenten van het analyseobject met `identical()`, en de
HTML na het weghalen van base64-afbeeldingen en het normaliseren van
tijdstempels en `htmlwidget-<id>`'s.

---

## Versienummering

```text
major.minor.patch
│      │     └── patch: bugfix, geen bedoelde outputwijziging
│      └──────── minor: nieuwe functie, bestaande output compatibel
└─────────────── major: brekende of methodologische wijziging
```

Release: versie in `DESCRIPTION`, sectie bovenaan `NEWS.md`, commit, tag
`v<versie>`, push. Pas bij een nieuwe versie ook het versienummer in de
installatie-URL aan in de README en in `inst/template/00_handleiding.md`;
`test_installatie.R` controleert dat. Collega's installeren een specifieke
versie met de tarball-URL van de tag (zie de README).

---

## Roadmap (uit v1.x overgenomen)

- Render-only en validate-only workflow.
- Metadata-gedreven multiselectdetectie (`analyse_type`).
- Metadata-kolom `cluster_vraag`.
- "Anders, namelijk"-detectie en KV-filtering in open antwoorden.
- `kable`-tabellen in Kruisingen client-side opbouwen (zelfde risicoklasse
  als de opgeloste open-antwoorden-tabellen).
