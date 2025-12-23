#!/usr/bin/env bash
set -euo pipefail
export AWS_PAGER=""

# ============================================================
# M346 Projekt: FaceRecognition Service (S3 -> Lambda -> S3)
# Test-Script
#
# - laedt ein Bild ins In-Bucket hoch
# - wartet bis JSON im Out-Bucket erzeugt wurde
# - laedt JSON herunter (recognized.json)
# - gibt erkannte Personen + Confidence aus
#
# Voraussetzungen:
# - init.sh wurde erfolgreich ausgefuehrt
# - jq ist installiert (JSON Parsing)
#
# Nutzung:
#   ./Scripts/test.sh <bildpfad>
#   ENV-Overrides:
#     AWS_REGION, PROJECT_PREFIX, IN_BUCKET, OUT_BUCKET
# ============================================================

if [[ $# -lt 1 ]]; then
  echo "Nutzung: $0 <bildpfad>"
  exit 1
fi

IMAGE_PATH="$1"
if [[ ! -f "${IMAGE_PATH}" ]]; then
  echo "FEHLER: Datei nicht gefunden: ${IMAGE_PATH}"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_PREFIX="${PROJECT_PREFIX:-m346-facerec}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text 2>/dev/null || true)"
if [[ -z "${ACCOUNT_ID}" || "${ACCOUNT_ID}" == "None" ]]; then
  echo "FEHLER: AWS CLI ist nicht konfiguriert oder Credentials fehlen."
  exit 1
fi

IN_BUCKET="${IN_BUCKET:-${PROJECT_PREFIX}-${ACCOUNT_ID}-in}"
OUT_BUCKET="${OUT_BUCKET:-${PROJECT_PREFIX}-${ACCOUNT_ID}-out}"

if ! command -v jq >/dev/null 2>&1; then
  echo "FEHLER: jq ist nicht installiert."
  echo "Linux (Debian/Ubuntu): sudo apt-get install -y jq"
  echo "Windows: via WSL oder Git Bash + jq"
  exit 1
fi

base="$(basename "${IMAGE_PATH}")"
name="${base%.*}"
ext="${base##*.}"

# Key so waehlen, dass Kollisionen unwahrscheinlich sind
ts="$(date -u +%Y%m%dT%H%M%SZ)"
key="${name}-${ts}.${ext}"
expected_json="${name}-${ts}.json"

echo "=== Test ==="
echo "Region:      ${AWS_REGION}"
echo "In-Bucket:   ${IN_BUCKET}"
echo "Out-Bucket:  ${OUT_BUCKET}"
echo "Upload Key:  ${key}"
echo "Erwarte:     ${expected_json}"
echo "============"

echo "Upload Bild -> s3://${IN_BUCKET}/${key}"
aws s3 cp "${IMAGE_PATH}" "s3://${IN_BUCKET}/${key}" --region "${AWS_REGION}" >/dev/null

# Polling: warte bis JSON im Out-Bucket vorhanden ist
timeout_sec=90
interval=3
elapsed=0

echo "Warte auf Ergebnis (max ${timeout_sec}s) ..."
found=""

while [[ "${elapsed}" -lt "${timeout_sec}" ]]; do
  if aws s3api head-object --bucket "${OUT_BUCKET}" --key "${expected_json}" --region "${AWS_REGION}" >/dev/null 2>&1; then
    found="${expected_json}"
    break
  fi
  sleep "${interval}"
  elapsed=$((elapsed + interval))
done

if [[ -z "${found}" ]]; then
  echo "FEHLER: Kein Ergebnis im Out-Bucket innerhalb Timeout gefunden."
  echo "Diagnose:"
  echo "  aws s3 ls s3://${OUT_BUCKET}/ --region ${AWS_REGION}"
  echo "  aws logs tail /aws/lambda/${PROJECT_PREFIX}-lambda --since 30m --region ${AWS_REGION}"
  exit 1
fi

echo "OK: Ergebnis gefunden -> Download recognized.json"
aws s3 cp "s3://${OUT_BUCKET}/${found}" "${PROJECT_DIR}/recognized.json" --region "${AWS_REGION}" >/dev/null

echo
echo "=== Erkannte Personen ==="
jq -r '.Celebrities[]? | "\(.Name) (Confidence: \(.MatchConfidence))"' "${PROJECT_DIR}/recognized.json" || true

count="$(jq '.Celebrities | length' "${PROJECT_DIR}/recognized.json")"
if [[ "${count}" -eq 0 ]]; then
  echo "(Keine bekannte Persoenlichkeit erkannt)"
fi

echo
echo "Output: ${PROJECT_DIR}/recognized.json"
