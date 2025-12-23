# Architektur und Komponenten

## Komponenten
1. **S3 In-Bucket**
   - Zweck: Upload von Foto-Dateien (JPG/PNG)
   - Event: `s3:ObjectCreated:*`

2. **AWS Lambda (C# / .NET 8)**
   - Handler: `FaceRecognitionLambda::FaceRecognitionLambda.Function::FunctionHandler`
   - Trigger: S3 In-Bucket
   - Aufgabe:
     - Objektmetadaten aus Event lesen (Bucket, Key)
     - Bild via S3 referenzieren
     - `RecognizeCelebrities` in AWS Rekognition ausfuehren
     - JSON Resultat erzeugen und im Out-Bucket speichern
   - ENV:
     - `OUTPUT_BUCKET` = Name des Out-Buckets

3. **S3 Out-Bucket**
   - Zweck: Ablage der JSON-Dateien
   - Naming: `<basename-des-bildes>.json` (im Code) bzw. im Test bewusst `<name>-<timestamp>.json`

## Datenfluss
```mermaid
flowchart LR
  A[Client Upload] -->|PUT Object| B[S3 In-Bucket]
  B -->|S3 ObjectCreated Event| C[Lambda (.NET 8)]
  C -->|RecognizeCelebrities| D[AWS Rekognition]
  C -->|PutObject JSON| E[S3 Out-Bucket]
  E -->|Download JSON| F[Test-Script / User]
```

## Sicherheit / IAM
Lambda-Rolle benoetigt minimal:
- CloudWatch Logs (CreateLogGroup/Stream, PutLogEvents)
- Rekognition: `rekognition:RecognizeCelebrities`
- S3 Read: `s3:GetObject` auf In-Bucket Objekte
- S3 Write: `s3:PutObject` auf Out-Bucket Objekte

Siehe Templates:
- `infra/iam-trust-policy.json`
- `infra/lambda-policy.template.json`
