# M346 Projektauftrag 2025 – FaceRecognition Service (AWS)

## Ziel
Ein FaceRecognition-Service erkennt **bekannte Persoenlichkeiten** auf Fotos, die in ein **S3 In-Bucket** hochgeladen werden. Eine **AWS Lambda** Funktion wird per **S3 Trigger** ausgeloest, ruft **AWS Rekognition (RecognizeCelebrities)** auf und speichert die Analyse als **JSON** in einem **S3 Out-Bucket**. fileciteturn0file0

## Architektur
- **S3 In-Bucket**: Upload von JPG/PNG
- **Lambda (C# / .NET 8)**: Verarbeitung + Rekognition API
- **S3 Out-Bucket**: JSON-Resultat pro Bild

Siehe: `docs/architecture.md`

## Voraussetzungen (Client)
- AWS Learner Lab Credentials in der Shell aktiv (AWS CLI v2 muss funktionieren)
  - Test: `aws sts get-caller-identity`
- **dotnet SDK 8**
- **zip**
- **jq** (nur fuer `test.sh`)

Windows:
- via **WSL** oder **Git Bash** (empfohlen: WSL)

## Quickstart (vollautomatisiert)
```bash
chmod +x Scripts/init.sh Scripts/test.sh
./Scripts/init.sh
./Scripts/test.sh <pfad/zum/bild.jpg>
```

### Konfiguration (optional per ENV)
```bash
export AWS_REGION="eu-central-1"
export PROJECT_PREFIX="m346-facerec"
export IN_BUCKET="m346-facerec-<account>-in"
export OUT_BUCKET="m346-facerec-<account>-out"
export LAMBDA_NAME="m346-facerec-lambda"
```

## Ergebnisformat (JSON)
Die Lambda-Funktion schreibt eine JSON-Datei mit u.a.:
- `SourceImage.Bucket`, `SourceImage.Key`
- `Celebrities[]: Name, MatchConfidence, Id, Urls`
- `UnrecognizedFaces`
- `ProcessedAtUtc`

Beispiel-Ausgabe (gekürzt):
```json
{
  "SourceImage": { "Bucket": "…", "Key": "…" },
  "Celebrities": [
    { "Name": "…", "MatchConfidence": 99.9, "Id": "…", "Urls": ["…"] }
  ],
  "UnrecognizedFaces": 0,
  "ProcessedAtUtc": "2025-12-23T00:00:00Z"
}
```

## Tests und Protokolle
- Testfaelle + Screenshots: `docs/tests.md`
- Ablage Screenshots: `docs/screenshots/`

## Reflexion (Prozess)
- Reflexion pro Teammitglied: `docs/reflection.md`

## Repository-Inhalt (relevant)
- `Function.cs` – Lambda Handler (gegeben, unveraendert)
- `Scripts/init.sh` – vollautomatische Inbetriebnahme (idempotent)
- `Scripts/test.sh` – vollautomatischer Test inkl. JSON Download + Output
- `infra/` – IAM Trust + Policy Template + generiertes S3 Notification JSON
- `docs/` – Dokumentation (Architektur, Tests, Reflexion)
