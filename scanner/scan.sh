#!/bin/sh
# Skannar SBOM:en för den image som faktiskt kör i klustret mot Trivys
# senaste sårbarhetsdatabas och rapporterar till Discord.
# Körs av k8s/scanner/cronjob.yaml. Se docs/workshop-4.md, punkt 7.
set -eu
set -o pipefail

: "${WEBHOOK_URL:?WEBHOOK_URL saknas}"
: "${TARGET_NAMESPACE:?TARGET_NAMESPACE saknas}"
: "${LABEL_SELECTOR:?LABEL_SELECTOR saknas}"
: "${CERT_IDENTITY_REGEXP:?CERT_IDENTITY_REGEXP saknas}"
: "${CERT_OIDC_ISSUER:=https://token.actions.githubusercontent.com}"

WORK=$(mktemp -d)
FOOTER="sbom-scanner i security-tools • pod ${HOSTNAME:-okänd}"
STEP="start"

# Skickar ett meddelande till Discord: titel, text, färg och valfri bilaga.
# jq bygger JSON:en, så citattecken och radbrytningar i texten blir rätt.
# Webhook-URL:en går till curl via stdin (-K -), inte som argument, eftersom
# argument syns för alla som ser processlistan, t.ex. Falco (F33).
notify() {
  payload=$(jq -n --arg t "$1" --arg d "$2" --argjson c "$3" --arg f "$FOOTER" \
    '{embeds: [{title: $t, description: $d, color: $c, footer: {text: $f}}]}')
  if [ -n "${4:-}" ]; then
    printf 'url = "%s"\n' "$WEBHOOK_URL" \
      | curl -fsS -K - -o /dev/null -F "payload_json=$payload" -F "file=@$4"
  else
    printf 'url = "%s"\n' "$WEBHOOK_URL" \
      | curl -fsS -K - -o /dev/null -H "Content-Type: application/json" -d "$payload"
  fi
}

# Körs alltid när skriptet avslutas. Har något steg misslyckats skickas ett
# eget larm, så att ett fel inte ser ut som att allt är lugnt.
on_exit() {
  rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "[!] Misslyckades i steget: $STEP (felkod $rc)" >&2
    notify "⚠️ Supply chain-skanning misslyckades" \
      "Steget **${STEP}** avbröts med felkod ${rc}. Ingen skanning gjordes.
Loggen: \`kubectl logs -n security-tools ${HOSTNAME:-<pod>}\`" \
      16753920 || true
  fi
  rm -rf "$WORK"
}
trap on_exit EXIT

# 1. Vilka images kör just nu? Samma fråga som "kubectl get pods -l ...",
#    ställd direkt mot API:t med poddens ServiceAccount-token. Token går via
#    stdin av samma skäl som webhooken. printf är inbyggt i skalet och syns
#    inte som en egen process.
STEP="hämta poddar med ${LABEL_SELECTOR} i ${TARGET_NAMESPACE}"
SA=/var/run/secrets/kubernetes.io/serviceaccount
printf 'header = "Authorization: Bearer %s"\n' "$(cat "$SA/token")" \
  | curl -fsS -G -K - --cacert "$SA/ca.crt" \
      --data-urlencode "labelSelector=${LABEL_SELECTOR}" \
      "https://kubernetes.default.svc/api/v1/namespaces/${TARGET_NAMESPACE}/pods" \
  > "$WORK/pods.json"

# imageID är den digest som containerd faktiskt startade, inte taggen i
# manifestet. Alla poddar och containrar tas med (t.ex. under en utrullning).
jq -r '.items[].status.containerStatuses[]?.imageID' "$WORK/pods.json" \
  | sed 's|^.*://||' | sort -u > "$WORK/images.txt"

STEP="hitta någon körande pod med ${LABEL_SELECTOR}"
[ -s "$WORK/images.txt" ]

TOTAL=0
LINES=""
: > "$WORK/report.txt"

# Digesterna innehåller inga mellanslag, så en vanlig for-loop räcker.
for IMAGE in $(cat "$WORK/images.txt"); do
  echo "[*] $IMAGE"

  # 2. Hämta SBOM:en och kontrollera att den är signerad av vår
  #    deploy-workflow och hör till exakt den här digesten.
  STEP="verifiera SBOM-attestationen för ${IMAGE}"
  cosign verify-attestation --type cyclonedx \
    --certificate-identity-regexp "$CERT_IDENTITY_REGEXP" \
    --certificate-oidc-issuer "$CERT_OIDC_ISSUER" \
    "$IMAGE" > "$WORK/attestations.jsonl"
  head -n 1 "$WORK/attestations.jsonl" | jq -r .payload | base64 -d \
    | jq .predicate > "$WORK/sbom.json"

  # 3. Jämför paketen i SBOM:en med dagens sårbarhetsdatabas.
  STEP="skanna SBOM:en för ${IMAGE} med Trivy"
  trivy sbom --quiet --ignore-unfixed --format json \
    -o "$WORK/trivy.json" "$WORK/sbom.json"
  COUNT=$(jq '[.Results[]?.Vulnerabilities[]?
               | select(.Severity == "HIGH" or .Severity == "CRITICAL")]
              | length' "$WORK/trivy.json")
  echo "[+] $COUNT High/Critical"

  TOTAL=$((TOTAL + COUNT))
  LINES="${LINES}
\`${IMAGE}\`: **${COUNT}**"
  if [ "$COUNT" -gt 0 ]; then
    {
      echo "== $IMAGE"
      trivy sbom --quiet --skip-db-update --ignore-unfixed \
        --severity HIGH,CRITICAL --format table "$WORK/sbom.json"
    } >> "$WORK/report.txt"
  fi
done

# 4. Rapportera.
STEP="skicka resultatet till Discord"
if [ "$TOTAL" -eq 0 ]; then
  notify "🟢 Supply chain-skanning: inga kända High/Critical" \
    "Inga High/Critical-sårbarheter med tillgänglig fix i det som kör:${LINES}" \
    3066993
else
  notify "🚨 Supply chain-skanning: ${TOTAL} High/Critical" \
    "Sårbarheter med tillgänglig fix i det som kör:${LINES}
Detaljer i bifogad rapport." \
    15158332 "$WORK/report.txt"
fi
echo "[+] Klar"
