# Tests und Testprotokoll

## Ziel
Nachweis, dass der Service:
- Trigger korrekt ausgeloest wird
- bekannte Persoenlichkeiten erkennt
- JSON korrekt im Out-Bucket speichert
- mehrfach ohne Fehler laeuft (Idempotenz Init, wiederholbare Tests)

## Testumgebung
- Datum/Zeit: **[eintragen]**
- Testperson: **[eintragen]**
- Region: **[eintragen]**
- In-Bucket / Out-Bucket: **[eintragen]**
- Lambda Name: **[eintragen]**

## Testfaelle (Tabelle)
| TC | Beschreibung | Input | Erwartet | Resultat | Screenshot | Fazit / Massnahmen |
|---:|---|---|---|---|---|---|
| 1 | Init erfolgreich (idempotent) | `./Scripts/init.sh` (2x) | Keine Fehler, Ressourcen vorhanden | [eintragen] | `screenshots/tc1-init.png` | [eintragen] |
| 2 | Celebrity erkannt | `./Scripts/test.sh <celebrity.jpg>` | JSON im Out-Bucket, Name + Confidence | [eintragen] | `screenshots/tc2-celebrity.png` | [eintragen] |
| 3 | Keine Celebrity erkannt | `./Scripts/test.sh <unknown.jpg>` | JSON, Celebrities leer, UnrecognizedFaces > 0 | [eintragen] | `screenshots/tc3-unknown.png` | [eintragen] |
| 4 | Mehrfacher Test | TC2 dreimal | Jedes Mal neues JSON + korrekte Ausgabe | [eintragen] | `screenshots/tc4-repeat.png` | [eintragen] |

## Anleitung: Screenshots erstellen
Pro Testfall mindestens:
- Terminal-Ausgabe (Init/Test)
- AWS Console Nachweis (S3 In Objekt, S3 Out JSON, Lambda Logs)

Ablage:
- `docs/screenshots/` (Dateinamen gemäss Tabelle)

## Beobachtungen / Erkenntnisse
- **[eintragen]**
