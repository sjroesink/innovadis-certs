FROM alpine:3.20

ARG TARGETARCH=amd64

RUN apk add --no-cache ca-certificates curl tini nginx openssl bash jq \
 && LEGO_VERSION=$(curl -fsSL https://api.github.com/repos/go-acme/lego/releases/latest | jq -r .tag_name | sed 's/^v//') \
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
 && apk del jq \
 && rm -rf /var/cache/apk/*

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY nginx.conf /etc/nginx/nginx.conf
RUN chmod +x /usr/local/bin/entrypoint.sh

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
