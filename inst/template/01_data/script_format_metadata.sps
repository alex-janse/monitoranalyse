* Encoding: UTF-8.
* ============================================================.
* LKCA MONITOR - OVERDRACHT NAAR R-PIPELINE.
* ============================================================.
*
* Zorg dat:
* - het opgeschoonde SPSS-bestand geopend en actief is;
* - alle uitgevoerde opschoonstappen reproduceerbaar zijn vastgelegd
*   in een afzonderlijk SPSS-syntaxbestand.
*
* Voer daarna dit script uit om een metadata-template voor de
* R-pipeline te genereren.
*
* Output:
*   Downloads\metadata_template.csv
*
* Vul vervolgens handmatig de kolom 'cluster' in.
* ============================================================.

BEGIN PROGRAM Python.

import os
import csv
import spssaux

out_file = os.path.join(
    os.environ["USERPROFILE"],
    "Downloads",
    "metadata_template.csv"
)

vardict = spssaux.VariableDict()

rows = []
n_missing_labels = 0

for v in vardict:

    variabele = str(v.VariableName).strip()
    label = v.VariableLabel

    if label is None or str(label).strip() == "":
        vraag = variabele
        n_missing_labels += 1
    else:
        vraag = str(label).strip()

    rows.append({
        "variabele": variabele,
        "cluster": "",
        "vraag": vraag
    })

with open(out_file, "w", newline="", encoding="utf-8-sig") as f:

    writer = csv.DictWriter(
        f,
        fieldnames=["variabele", "cluster", "vraag"],
        delimiter=";"
    )

    writer.writeheader()
    writer.writerows(rows)

print("")
print("Metadata-template geschreven naar:")
print(out_file)
print("")
print("Aantal variabelen:", len(rows))
print("Aantal variabelen zonder SPSS variable label:", n_missing_labels)
print("")
print("Volgende stap:")
print("1. Open metadata_template.csv in Excel.")
print("2. Vul de kolom 'cluster' aan.")
print("3. Controleer/redigeer de kolom 'vraag'.")
print("4. Sla op als metadata_v1_DATUM_.csv.")
print("5. Plaats metadata.csv in de data-map van het R-project.")
print("")

END PROGRAM.