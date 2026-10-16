# monitoranalyse 2.0.1

Alleen de installatie is veranderd. De cijfers en het rapport zijn ongewijzigd.

- `pak::pak("alex-janse/monitoranalyse")` werkte op Windows alleen met
  Rtools, en dat hebben de meeste collega's niet. De handleiding, de README
  en de melding in `04_run_project.R` gebruiken nu `install.packages()` met
  de GitHub-link van een versie. Daar is geen Rtools voor nodig.
- De installatielijst bevat nu ook `ggpattern`. Zonder dit package tekent het
  rapport de staven bij kleine aantallen effen in plaats van gestreept. Met de
  oude pak-opdracht werd `ggpattern` niet geïnstalleerd.
- De herinstallatieopdracht in `engine/ENGINE_VERSIE.txt` en in de
  versiewaarschuwing gebruikt dezelfde methode.

# monitoranalyse 2.0.0

Eerste versie als R-package. De zip-brontemplate (v1.x) wordt vervangen door
een package dat je vanaf GitHub installeert (zie de README).

## Geen wijziging in de cijfers

- Getest met de kleine testset van v1.3.0: alle onderdelen van het
  analyseobject zijn `identical()` aan v1.3.0, en het rapport is identiek
  (na het weghalen van ingebedde afbeeldingen en het gelijktrekken van
  tijdstempels en interne widget-ID's).
- De afrondingsconventie is ongewijzigd: bij precies een halve wordt naar het
  even getal afgerond (12,5% → 12%, 37,5% → 38%).

## Nieuwe werkwijze

- `nieuw_project(pad)` maakt een projectmap uit het sjabloon. Daarna werkt
  alles als voorheen: bestanden in `01_data/`, drie regels in `03_config.R`
  en Source van `04_run_project.R`.
- `04_run_project.R` roept nu `monitoranalyse::run_project()` aan. De
  automatische `install.packages()`-stap is vervallen, want pak installeert
  alles wat nodig is.
- Draaien zonder RStudio kan ook (`Rscript 04_run_project.R`). Het rapport
  opent dan niet automatisch in de browser.
- Duidelijke Nederlandse melding als Quarto ontbreekt, of als
  `project_naam`, `input_sav` of `metadata_file` niet (goed) is ingevuld.

## Reproduceerbaarheid

- Het datapackage bevat een map `engine/` met de rapportbestanden, alle
  functies van het package en `ENGINE_VERSIE.txt`. Daarin staat ook de opdracht
  om exact die versie opnieuw te installeren.
- **Nieuw in het analyseobject** (alleen toegevoegd, bestaande velden
  ongewijzigd): `$meta$engine_versie` en `$meta$engine_commit` (GitHub-commit,
  of `NA` bij een lokale installatie). Beide staan ook in `run_log.txt`.
- Nieuw in `03_config.R`: `engine_versie` (automatisch ingevuld). Bij afwijking
  van de geïnstalleerde versie geeft de run een waarschuwing.

## Bugfix: verkeerde naam van de respondent-ID-kolom

Stond `resp_id_col` in `03_config.R` niet als kolom in het `.sav`-bestand
(bijvoorbeeld `"ID"` terwijl de kolom `respid` heet), dan meldde de validatie een
fout, maar liep de pipeline toch door. Daarna crashte hij met een onduidelijke
melding (`Can't select columns that don't exist`).

- De run stopt nu direct na de validatie met een duidelijke melding, inclusief
  een suggestie: `Bedoel je resp_id_col <- "respid"?`. Er is dan geen rapport.
- Alleen fouten waar de analyse niet zonder kan stoppen de run. Nu is dat de
  ontbrekende ID-kolom. Andere fouten (bijvoorbeeld metadata-variabelen die in
  de data ontbreken) verschijnen zoals voorheen in het rapport, zodat je alle
  problemen in één keer ziet.
- De audit_log heeft daarvoor een extra kolom `blokkerend`. Dat is alleen een
  uitbreiding.
- De controle op dubbele respondenten gebruikt nu `resp_id_col` in plaats van
  een vaste lijst kolomnamen.
- De ingestelde ID-kolom geeft geen onterechte waarschuwing meer dat er een
  metadata-regel ontbreekt.
- `03_config.R` en de handleiding leggen uit dat `resp_id_col` precies gelijk
  moet zijn aan de kolomnaam, inclusief hoofdletters.

## Overige wijzigingen

- Het LKCA-logo zit niet meer in de engine. Je stelt het in met `logo_bestand` in
  `03_config.R`. Zonder logo bevat het rapport alleen de tekstregel.
- `corrections.R` is vervallen: correcties horen in SPSS.
- Licentie: EUPL-1.2.

# monitoranalyse 1.3.0

Eerdere versies (1.0.0 t/m 1.3.0) zijn als zip-brontemplate verspreid. De
changelog daarvan is bewaard bij die brontemplate. Kort samengevat:

- **1.3.0**: afrondingsconventie vastgelegd en getest; `$kruis_verdeling`
  toegevoegd.
- **1.2.1**: oplossing voor een vastloper bij grote datasets en voor het
  tabblad Open antwoorden dat soms verdween.
- **1.2.0**: tab Kruisingen met tabellen en figuren.
- **1.1.x**: speciale antwoordcategorieën onderaan, datapackage als volledige
  projectkopie, oplossing voor NA in kruisvariabelen.
- **1.0.0**: eerste deploybare versie.
