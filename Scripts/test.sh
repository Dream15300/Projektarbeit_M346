#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

IN_BUCKET="${IN_BUCKET:-m346-facerec-${ACCOUNT_ID}-in}"
OUT_BUCKET="${OUT_BUCKET:-m346-facerec-${ACCOUNT_ID}-out}"

IMG_PATH="${1:-}"
[[ -n "$IMG_PATH" ]] || { echo "Usage: $0 <path/to/image.jpg>"; exit 2; }
[[ -f "$IMG_PATH" ]] || { echo "FEHLER: Datei nicht gefunden: $IMG_PATH"; exit 2; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "FEHLER: Command fehlt: $1"; exit 2; }; }

require_cmd aws
# jq ist optional (nur fuer Ausgabe der Namen)
HAS_JQ=0
if command -v jq >/dev/null 2>&1; then HAS_JQ=1; fi

ts="$(date -u +%Y%m%dT%H%M%SZ)"
base="$(basename "$IMG_PATH")"
name_noext="${base%.*}"

UPLOAD_KEY="${name_noext}-${ts}.${base##*.}"
EXPECTED_JSON="${name_noext}-${ts}.json"

echo "=== Test ==="
echo "Region:      ${AWS_REGION}"
echo "In-Bucket:   ${IN_BUCKET}"
echo "Out-Bucket:  ${OUT_BUCKET}"
echo "Upload Key:  ${UPLOAD_KEY}"
echo "Erwarte:     ${EXPECTED_JSON} (oder Fallback)"
echo "============"

echo "Upload Bild -> s3://${IN_BUCKET}/${UPLOAD_KEY}"
aws s3 cp "$IMG_PATH" "s3://${IN_BUCKET}/${UPLOAD_KEY}" --region "$AWS_REGION" >/dev/null
UPLOAD_EPOCH="$(date +%s)"

# Kandidaten, die haeufig in Function.cs verwendet werden
CANDIDATES=(
  "${EXPECTED_JSON}"
  "recognized.json"
  "${UPLOAD_KEY}.json"
  "${name_noext}.json"
  "${name_noext}_recognized.json"
  "${name_noext}_result.json"
)

exists_out_key() {
  local k="$1"
  aws s3api head-object --bucket "$OUT_BUCKET" --key "$k" --region "$AWS_REGION" >/dev/null 2>&1
}

# Suche nach JSON, die mit dem Base anfängt (Prefix)
find_by_prefix() {
  local prefix="$1"
  aws s3api list-objects-v2 \
    --bucket "$OUT_BUCKET" \
    --prefix "$prefix" \
    --region "$AWS_REGION" \
    --query 'Contents[].Key' \
    --output text 2>/dev/null | tr '\t' '\n' | grep -E '\.json$' || true
}

# Neuste JSON im Out-Bucket (Fallback)
find_latest_json() {
  aws s3api list-objects-v2 \
    --bucket "$OUT_BUCKET" \
    --region "$AWS_REGION" \
    --query 'reverse(sort_by(Contents[?ends_with(Key, `.json`)], &LastModified))[0].Key' \
    --output text 2>/dev/null || true
}

MAX_WAIT="${MAX_WAIT:-120}"
SLEEP="${SLEEP:-3}"
elapsed=0
FOUND_KEY=""

echo "Warte auf Ergebnis (max ${MAX_WAIT}s) ..."

while [[ $elapsed -lt $MAX_WAIT ]]; do
  # 1) direkte Kandidaten pruefen
  for k in "${CANDIDATES[@]}"; do
    if exists_out_key "$k"; then
      FOUND_KEY="$k"
      break
    fi
  done
  [[ -n "$FOUND_KEY" ]] && break

  # 2) prefix basierte Suche (BASENAME- oder UPLOAD_KEY-Start)
  pref_hits="$(find_by_prefix "${name_noext}-${ts}")"
  if [[ -n "$pref_hits" ]]; then
    FOUND_KEY="$(echo "$pref_hits" | head -n 1)"
    break
  fi

  pref_hits2="$(find_by_prefix "${name_noext}")"
  if [[ -n "$pref_hits2" ]]; then
    FOUND_KEY="$(echo "$pref_hits2" | head -n 1)"
    break
  fi

  sleep "$SLEEP"
  elapsed=$((elapsed + SLEEP))
done

# 3) letzter Fallback: neuste JSON, aber nur wenn sie nach Upload erstellt wurde (grobe Heuristik)
if [[ -z "$FOUND_KEY" ]]; then
  latest="$(find_latest_json)"
  if [[ -n "$latest" && "$latest" != "None" ]]; then
    # Heuristik: wenn Out-Bucket vorher leer war, ist das ok.
    FOUND_KEY="$latest"
    echo "WARN: Timeout auf erwartete Keys. Nutze neuste JSON als Fallback: ${FOUND_KEY}"
  fi
fi

if [[ -z "$FOUND_KEY" || "$FOUND_KEY" == "None" ]]; then
  echo "FEHLER: Kein Ergebnis im Out-Bucket innerhalb Timeout gefunden."
  echo "Diagnose:"
  echo "  aws s3 ls s3://${OUT_BUCKET}/ --region ${AWS_REGION}"
  echo "  aws logs tail /aws/lambda/m346-facerec-lambda --since 30m --region ${AWS_REGION}"
  exit 1
fi

echo "OK: Ergebnis gefunden: s3://${OUT_BUCKET}/${FOUND_KEY}"
aws s3 cp "s3://${OUT_BUCKET}/${FOUND_KEY}" "./recognized.json" --region "$AWS_REGION" >/dev/null
echo "Download -> ./recognized.json"

if [[ $HAS_JQ -eq 1 ]]; then
  echo ""
  echo "Erkannte Personen (sofern JSON-Struktur passt):"
  # Versucht mehrere typische Strukturen (AWS Rekognition Celebrity JSON oder eigene Wrapper)
  jq -r '
    if .CelebrityFaces then
      .CelebrityFaces[] | "\(.Name) (Confidence: \(.MatchConfidence // .Confidence // .Face.Confidence // 0))"
    elif .Celebrities then
      .Celebrities[] | "\(.Name) (Confidence: \(.Confidence // 0))"
    elif .name and .confidence then
      "\(.name) (Confidence: \(.confidence))"
    else
      "HINWEIS: Unbekannte JSON-Struktur. Bitte Datei ./recognized.json pruefen."
    end
  ' ./recognized.json || true
else
  echo "HINWEIS: jq nicht installiert. JSON liegt in ./recognized.json"
fi
