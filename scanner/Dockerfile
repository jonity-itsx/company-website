# Image för den dagliga sårbarhetsskanningen (k8s/scanner/cronjob.yaml).
# Allt skriptet behöver byggs in här, så att inget laddas ner och körs när
# jobbet startar i klustret. Versioner och checksummor ändras bara via PR.
FROM alpine:3.24.2@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6

# Checksummorna kommer från respektive releases checksumfil, vars signatur
# kontrollerades med cosign verify-blob (se docs/workshop-4.md, punkt 7).
ARG COSIGN_VERSION=2.6.4
ARG COSIGN_SHA256=309779b0c4e409186b0a80daba99041fe2cf65a920ce645013901df6211895a9
ARG TRIVY_VERSION=0.74.0
ARG TRIVY_SHA256=2ae6fe3ee734b7fdf11335663e18c75ea12dccc76062f09f164a3b0f8be4371a

RUN apk add --no-cache ca-certificates curl jq

RUN set -eux; \
    curl -fsSLo /usr/local/bin/cosign \
      "https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-linux-amd64"; \
    echo "${COSIGN_SHA256}  /usr/local/bin/cosign" | sha256sum -c -; \
    chmod 0755 /usr/local/bin/cosign; \
    curl -fsSLo /tmp/trivy.tar.gz \
      "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz"; \
    echo "${TRIVY_SHA256}  /tmp/trivy.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/trivy.tar.gz -C /usr/local/bin trivy; \
    rm /tmp/trivy.tar.gz

COPY --chmod=0755 scan.sh /usr/local/bin/scan.sh

# Samma användare som CronJoben kräver (runAsNonRoot).
USER 65532:65532
ENTRYPOINT ["/usr/local/bin/scan.sh"]
