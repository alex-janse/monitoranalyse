# Handleiding LKCA Monitor Analyseproces

## Snelstart — in 3 stappen

**STAP 1 — Bestanden klaarzetten**
Zet je opgeschoonde `.sav`-bestand en je metadata-bestand in de map `01_data/`. Dat is alles.

**STAP 2 — Project openen in RStudio**
Open `02_Analyseproces.Rproj`. Dit is het startpunt — hierdoor weet RStudio waar alle bestanden staan.

**STAP 3 — Configureren en starten**
1. Pas `03_config.R` aan: vul projectnaam, .sav-bestand en metadata-bestand in (3 regels bovenaan)
2. Open `04_run_project.R` en klik op **Source** (of druk Ctrl+Shift+S)
3. Wacht tot het rapport verschijnt in `05_output/` (het rapport krijgt automatisch een datum- en tijdstempel in de bestandsnaam)

Het analyseproces doet de rest: controleren, analyseren, rapport maken, archiveren.

> ⚠ Open het project altijd via het `.Rproj`-bestand (02_), niet via losse scripts.  
> ⚠ Zet de map op een lokale schijf, niet op OneDrive of SharePoint.  
> ⚙ De eerste keer installeert het analyseproces automatisch ontbrekende packages.

---

Deze handleiding is bedoeld voor collega’s die een monitorproject willen voorbereiden en analyseren met het LKCA Monitor Analyseproces.

De basisworkflow is:

1. Data opschonen in **SPSS**.
2. Metadata-bestand maken en invullen.
3. `.sav` en metadata in de map `01_data/` zetten.
4. Instellingen invullen in `03_config.R`.
5. `04_run_project.R` openen en op **Source** klikken.
6. Rapport en validatielog controleren.

Belangrijk uitgangspunt:

> SPSS is de plek voor opschoning.  
> R controleert daarna of het bestand analyse-klaar is, voert de analyse uit en maakt het rapport.

---

## Inhoud

1. #data-opschonen-in-spss
2. #respondenten-controleren
3. #variabelen-en-labels-controleren
4. #cbs-data-of-andere-externe-data-koppelen
5. #open-anders-namelijk-antwoorden-beoordelen
6. #versies-van-opgeschoonde-bestanden-bewaren
7. #metadata-bestand-maken
8. #metadata-template-genereren-vanuit-spss
9. #metadata-invullen
10. #labels-op-clusterniveau-controleren
11. #open-antwoorden-in-metadata
12. #kruisingen-instellen
13. #bestanden-in-de-projectmap-zetten
14. #configuratie-invullen
15. #analyseproces-uitvoeren
16. #rapport-controleren
17. #veelvoorkomende-problemen
18. #checklist-voor-definitieve-run

---

## Data opschonen in SPSS

Maak eerst een opgeschoond `.sav`-bestand. Leg iedere stap vast met **SPSS-syntax**, zodat keuzes reproduceerbaar zijn.

Leg opschoningskeuzes vast in de syntax met comments, vooral als ze niet vanzelf duidelijk zijn.

Denk aan:

- waarom respondenten zijn verwijderd;
- hoe dubbele respondenten of dubbele organisaties zijn behandeld;
- welke variabelen zijn hercodeerd;
- waarom bepaalde open antwoorden zijn omgezet naar gesloten categorieën;
- welke externe data, zoals CBS-data, zijn gekoppeld.

Gebruik eventueel daarnaast een kort logboek.

Voorbeeld:

```text
2026-07-10
- Respondenten met invulduur < 2 minuten verwijderd.
- Testrespondenten verwijderd.
- Gemeentegrootte toegevoegd op basis van CBS-koppeling.
- Antwoord "anders, namelijk: zzp" bij Q4 omgezet naar categorie "zzp'er".
```

---

## Respondenten controleren

Verwijder vóór de analyse respondenten die niet meegenomen moeten worden.

Voorbeelden:

- respondenten die niet ver genoeg zijn gekomen;
- testrespondenten;
- dubbele organisaties of dubbele respondenten;
- respondenten met verdachte invulpatronen;
- extreem korte invulduur;
- volledig lege of vrijwel lege vragenlijsten.

Leg vast **welke regel** je gebruikt.

Voorbeeld:

```spss
* Respondenten verwijderen die minder dan 30% van de vragenlijst hebben ingevuld.
SELECT IF voortgang >= 30.
EXECUTE.
```

---

## Variabelen en labels controleren

De pipeline gebruikt SPSS-variable labels en value labels voor tabellen en figuren. Controleer daarom goed of deze labels bruikbaar zijn.

### Variable labels

Controleer:

- alle analysevariabelen hebben een duidelijk variable label;
- labels zijn niet onnodig lang;
- labels zijn begrijpelijk zonder extra context;
- labels zijn geschikt voor gebruik in tabellen en figuren.

Kort labels waar nodig iets in voor leesbaarheid.

Voorbeeld:

```text
Te lang:
"Welke van de onderstaande activiteiten heeft uw organisatie in het afgelopen kalenderjaar georganiseerd of ondersteund?"

Beter:
"Georganiseerde of ondersteunde activiteiten"
```

### Value labels

Controleer:

- categorische variabelen hebben value labels;
- ja/nee-vragen zijn consequent gecodeerd;
- missende waarden staan niet per ongeluk als gewone antwoordcategorie in de analyse.

Voorbeeld:

```text
0 = Nee
1 = Ja
```

Bij nieuw berekende categorische variabelen geldt:

> Geef altijd zowel een **variable label** als **value labels**.

Voorbeeld:

```spss
VARIABLE LABELS gemeentegrootte_3cat "Gemeentegrootte".
VALUE LABELS gemeentegrootte_3cat
  1 "Klein"
  2 "Middelgroot"
  3 "Groot".
```

Vergeet nieuwe analysevariabelen daarna niet toe te voegen aan het metadata-bestand.

---

## CBS-data of andere externe data koppelen

Als externe data nodig zijn, koppel deze voorlopig in SPSS als onderdeel van de opschoning.

Voorbeelden:

- gemeentegrootte;
- provincie;
- stedelijkheid;
- regio;
- inwonertal;
- andere achtergrondkenmerken.

Controleer na koppeling:

- zijn alle respondenten correct gekoppeld?
- zijn er onverwachte missende waarden?
- zijn gemeentennamen of codes consistent?
- hebben nieuwe variabelen labels en value labels?
- moeten gekoppelde variabelen ook in de metadata worden opgenomen?

Als een gekoppelde variabele alleen als achtergrondvariabele wordt gebruikt en niet geanalyseerd hoeft te worden, hoeft deze geen cluster te krijgen in de metadata.

---

## Open “anders, namelijk”-antwoorden beoordelen

Bekijk open “anders, namelijk”-antwoorden vóór de definitieve run.

Soms hoort een open antwoord eigenlijk bij een bestaande gesloten categorie. In dat geval mag je het gesloten antwoord corrigeren, mits je dit documenteert.

Voorbeeld:

```text
Vraag: Type organisatie
Gesloten antwoord: Anders
Open antwoord: "bibliotheek"

Correctie:
Respondent wordt gecodeerd als "Bibliotheek".
```

Leg zulke keuzes vast in de syntax of het logboek.

Let op:

> Maak geen nieuwe inhoudelijke analysecategorieën zonder dit duidelijk te documenteren.

---

## Versies van opgeschoonde bestanden bewaren

Bewaar bij elke nieuwe versie een kopie met datumstempel.

Aanbevolen naamgeving:

```text
opgeschoond_def_2026-07-10.sav
opgeschoond_def_2026-07-15.sav
```

Overschrijf oude versies niet zomaar.

Noteer in het logboek wat er is gewijzigd sinds de vorige versie.

Voorbeeld:

```text
2026-07-15
Nieuwe versie opgeschoond bestand:
opgeschoond_def_2026-07-15.sav

Wijzigingen:
- 3 testrespondenten verwijderd.
- Gemeentegrootte gecorrigeerd voor 2 respondenten.
- Variable labels Q12A1 t/m Q12A6 ingekort.
```

---

## Metadata-bestand maken

De metadata bepaalt welke variabelen worden geanalyseerd en hoe ze in het rapport worden gegroepeerd.

De pipeline ondersteunt:

```text
metadata.xlsx
metadata.xls
metadata_template.csv
```

Voor definitieve projecten heeft `metadata.xlsx` de voorkeur.

---

## Metadata-template genereren vanuit SPSS

Na het opschonen kan vanuit SPSS een metadata-template worden gegenereerd:

```text
metadata_template.csv
```

Dit bestand bevat minimaal:

```text
variabele;cluster;vraag
```

Betekenis:

| Kolom | Betekenis |
|---|---|
| `variabele` | exacte SPSS-variabelenaam |
| `cluster` | groep/vraagblok waarin de variabele in het rapport komt |
| `vraag` | vraagtekst of label voor rapportage |

Alleen variabelen met een ingevulde `cluster` worden geanalyseerd.

---

## Metadata invullen

Open het metadata-bestand in Excel en vul vooral de kolom `cluster` aan.

### Wat is een cluster?

Een cluster is een groep variabelen die samen in het rapport horen.

| Soort vraag | Clusterlogica |
|---|---|
| Enkelvoudige vraag | één variabele in één cluster |
| Multiselectvraag | meerdere ja/nee-items in hetzelfde cluster |
| Numerieke vraag | één of meer numerieke variabelen in een cluster |
| Open vraag | cluster eindigt op `_open` |

Voorbeeld:

```text
Q3A1, Q3A2 en Q3A3 horen bij dezelfde multiselectvraag.
Deze krijgen dus hetzelfde cluster, bijvoorbeeld: 3.
```

Verplichte kolommen:

```text
variabele
cluster
vraag
```

Let op:

- kolomnamen moeten exact kloppen;
- geen hoofdletters;
- geen extra spaties;
- geen typfouten;
- geen dubbele kolomnamen.

---

## Labels op clusterniveau controleren

De kolom `vraag` wordt gebruikt als vraagtekst in het rapport. Controleer daarom of deze tekst op clusterniveau klopt.

Soms zijn SPSS-variable labels te specifiek per item. Dan moet de vraagtekst in de metadata worden aangepast.

Voorbeeld multiselectvraag:

| variabele | cluster | vraag |
|---|---|---|
| `Q3A1` | `3` | Welke activiteiten organiseert uw organisatie? |
| `Q3A2` | `3` | Welke activiteiten organiseert uw organisatie? |
| `Q3A3` | `3` | Welke activiteiten organiseert uw organisatie? |

De itemlabels zelf komen uit de SPSS-variable labels.

Gebruik waar nodig de survey-export of vragenlijst om goede clustervragen te formuleren, vooral bij geneste vragen of samengestelde vraagblokken.

---

## Open antwoorden in metadata

Open vragen worden herkend via een cluster dat eindigt op:

```text
_open
```

Voorbeeld:

| variabele | cluster | vraag |
|---|---|---|
| `Q12_open` | `12_open` | Kunt u uw antwoord toelichten? |
| `Q18_anders` | `18_open` | Anders, namelijk |

Open antwoorden verschijnen in het rapport onder de tab **Open antwoorden**.

Controleer vóór publicatie of er geen testdata of privacygevoelige tekst in het rapport staat.

---

## Kruisingen instellen

Als je rechte tellingen wilt uitsplitsen naar een achtergrondvariabele, stel je dat in via `03_config.R`.

Voorbeeld:

```r
kruis_vars <- list(
  gemeentegrootte_3cat = "Gemeentegrootte"
)
```

Betekenis:

```text
naam_in_data = "Naam in rapport"
```

Als je geen kruisingen wilt:

```r
kruis_vars <- list()
```

Let op:

> Kruisingen werken alleen voor dichotome ja/nee-variabelen. Het rapport toont dan het percentage “Ja” per subgroep.

---

## Bestanden in de projectmap zetten

Zet de benodigde bestanden in de map:

```text
01_data/
```

Minimaal nodig:

```text
01_data/opgeschoond_def_YYYY-MM-DD.sav
01_data/metadata.xlsx
```

Of voor een snelle test:

```text
01_data/metadata_template.csv
```

---

## Configuratie invullen

Open:

```text
03_config.R
```

Pas minimaal deze regels aan:

```r
project_naam  <- "Monitor Poppodia 2026"
input_sav     <- "01_data/opgeschoond_def_2026-07-10.sav"
metadata_file <- "01_data/metadata.xlsx"
```

Controleer eventueel ook:

```r
resp_id_col <- "ID"

kruis_vars <- list(
  gemeentegrootte_3cat = "Gemeentegrootte"
)
```

Gebruik altijd paden relatief aan de projectmap, dus meestal beginnend met:

```text
01_data/
```

---

## Analyseproces uitvoeren

Open:

```text
04_run_project.R
```

Klik in RStudio op:

```text
Source
```

De pipeline doet daarna automatisch:

1. data inlezen;
2. metadata inlezen;
3. input controleren;
4. analyseobject maken;
5. rapport renderen;
6. logs en snapshots opslaan.

Het rapport en alle archiefbestanden komen in `05_output/`:

```text
05_output/
├── analyse-output_<datum-tijd>.html        ← rapport, direct te openen
└── datapackage_<datum-tijd>/               ← archiefmap
    ├── analyse_object.rds
    ├── audit_log.rds
    ├── run_log.txt
    ├── session_info.txt
    ├── metadata_snapshot.xlsx
    ├── renv.lock
    ├── engine/                             ← engine-snapshot
    └── input/                              ← ruwe data + config snapshot
```

Het rapport staat direct in `05_output/` met een datum- en tijdstempel in de bestandsnaam (bijv. `analyse-output_2026-07-16_1815.html`). De archiefbestanden staan in een map met dezelfde tijdstempel (`datapackage_2026-07-16_1815/`).

Open het `.html`-bestand bij voorkeur in Chrome of Edge.

---

## Rapport controleren

Controleer minimaal onderstaande onderdelen.

### Overzicht

Controleer:

- klopt de projectnaam?
- klopt het gebruikte databestand?
- klopt het gebruikte metadata-bestand?
- zijn er clusters zonder data?
- staan er fouten of waarschuwingen in de validatielog?

### Validatielog

| Kleur | Betekenis |
|---|---|
| Rood | eerst oplossen |
| Geel | beoordelen |
| Groen | automatische controles uitgevoerd zonder fout/waarschuwing binnen die controles |

Belangrijk:

> Groen betekent niet dat alles inhoudelijk klopt.  
> Controleer altijd zelf of data, metadata en rapport logisch zijn.

### Rechte tellingen

Controleer:

- worden de juiste vragen getoond?
- zijn figuren en tabellen logisch?
- kloppen de labels?
- zijn lange labels nog leesbaar?
- worden multiselectvragen goed gegroepeerd?

### Kruisingen

Controleer:

- verschijnen de juiste kruisvariabelen?
- zijn subgroepen logisch?
- zijn kleine aantallen herkenbaar gemarkeerd?
- ontbreken er geen belangrijke vragen?

### Open antwoorden

Controleer:

- worden de juiste open vragen getoond?
- staat er geen testdata of privacygevoelige tekst in?
- zijn respondent-ID’s correct?
- zijn “anders, namelijk”-antwoorden waar nodig al verwerkt in gesloten categorieën?

---

## Veelvoorkomende problemen

### Bestand niet gevonden

Controleer:

- staat het bestand in `01_data/`?
- klopt de bestandsnaam exact?
- klopt het pad in `03_config.R`?

Voorbeeld:

```r
input_sav <- "01_data/opgeschoond_def_2026-07-10.sav"
```

---

### Metadata-kolommen kloppen niet

De verplichte kolommen zijn exact:

```text
variabele
cluster
vraag
```

Let op:

- geen hoofdletters;
- geen extra spaties;
- geen typfouten;
- geen dubbele kolomnamen.

---

### Variabele staat niet in rapport

Controleer:

- staat de variabele in de metadata?
- is de variabelenaam exact gelijk aan de naam in SPSS?
- is `cluster` ingevuld?
- heeft de variabele data?
- is het cluster misschien leeg en daarom verborgen?

---

### Kruisingen verschijnen niet

Controleer:

- staat de kruisvariabele in `kruis_vars`?
- bestaat deze variabele in het `.sav`-bestand?
- heeft de kruisvariabele value labels?
- zijn er ja/nee-variabelen om te kruisen?

---

### Open antwoorden verschijnen niet

Controleer:

- eindigt het cluster op `_open`?
- is `resp_id_col` goed ingesteld?
- bevatten de open vragen daadwerkelijk tekst?
- staan de open variabelen in de metadata?

---

### Rapport opent niet goed

Open het rapport bij voorkeur in:

```text
Chrome
Edge
```

Als tabellen of figuren niet goed zichtbaar zijn:

- ververs de browser;
- open het `.html`-bestand in `05_output/` opnieuw;
- draai `04_run_project.R` opnieuw;
- controleer of de run zonder rode foutmelding is afgerond.

---

## Checklist voor definitieve run

Voor je een definitief rapport gebruikt of deelt:

- [ ] opschoning in SPSS-syntax vastgelegd;
- [ ] verwijderde respondenten gedocumenteerd;
- [ ] CBS-/externe koppelingen gecontroleerd;
- [ ] nieuwe variabelen hebben variable labels en value labels;
- [ ] metadata is gecontroleerd;
- [ ] clusters kloppen;
- [ ] open vragen hebben `_open`-clusters;
- [ ] `03_config.R` klopt;
- [ ] validatielog bevat geen rode fouten;
- [ ] gele waarschuwingen zijn beoordeeld;
- [ ] rapport visueel gecontroleerd;
- [ ] oude versies van opgeschoonde bestanden zijn bewaard;
- [ ] logboek is bijgewerkt.