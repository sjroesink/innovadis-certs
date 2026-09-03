FROM alpine:3.20

ARG TARGETARCH=amd64
# Pinned: lego v5 changed the CLI (no --accept-tos); entrypoint.sh targets v4.
ARG LEGO_VERSION=4.35.2

RUN apk add --no-cache ca-certificates curl tini nginx openssl bash jq fcgiwrap spawn-fcgi \
 && echo "Installing lego v${LEGO_VERSION} for ${TARGETARCH}" \
 && case "${TARGETARCH}" in \
      amd64) ARCH=amd64 ;; \
      arm64) ARCH=arm64 ;; \
      *)     echo "unsupported arch ${TARGETARCH}"; exit 1 ;; \
    esac \
 && curl -fsSL "https://github.com/go-acme/lego/releases/download/v${LEGO_VERSION}/lego_v${LEGO_VERSION}_linux_${ARCH}.tar.gz" \
      | tar -xz -C /usr/local/bin lego \
 && chmod +x /usr/local/bin/lego \
 && mkdir -p /data /web /run/nginx \
 && rm -rf /var/cache/apk/*

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY certificate-lib.sh /usr/local/bin/certificate-lib.sh
COPY check-avail.sh /usr/local/bin/check-avail.sh
COPY avail.cgi /usr/local/bin/avail.cgi
COPY nginx.conf /etc/nginx/nginx.conf
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/certificate-lib.sh /usr/local/bin/check-avail.sh /usr/local/bin/avail.cgi

ENV LEGO_PATH=/data \
    WEB_DIR=/web \
    PORT=8080 \
    RENEW_DAYS=30 \
    RENEW_INTERVAL_SECONDS=43200

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -q -O- http://127.0.0.1:${PORT}/healthz || exit 1

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/usr/local/bin/entrypoint.sh"]
