# innovadis-certs

Auto-renewing Let's Encrypt PFX bundle for the Innovadis pre-made tenant test
domains. Runs as a single container on Unraid; serves the PFX files (and an
index page) over HTTP via Traefik at https://innovadis-certs.sander.ninja.

## What it does

For each FQDN in `DOMAINS`:

1. Issues (or renews) a Let's Encrypt certificate using DNS-01 against the
   zone's Cloudflare account.
2. Exports the cert as a `.pfx` file, encrypted with `PFX_PASSWORD`.
3. Serves the resulting bundle on `:8080` with an HTML index.

It re-checks every `RENEW_INTERVAL_SECONDS` (default 12h). `lego renew`
no-ops when the cert is still well outside the renewal window, so this is
cheap to run frequently.

State lives in `/data` (mounted on Unraid at
`/mnt/user/appdata/innovadis-certs/data`):

- `/data/accounts/` — ACME account material (persistent)
- `/data/certificates/` — PEM certs + keys + .pfx bundles

## Configuration

| Env | Required | Default | Description |
|---|---|---|---|
| `CLOUDFLARE_DNS_API_TOKEN` | yes | — | Cloudflare token with `Zone:DNS:Edit` on the zone(s) covering every FQDN |
| `PFX_PASSWORD` | yes | — | Password protecting the exported PFX files |
| `CONTACT_EMAIL` | yes | — | ACME account contact email |
| `DOMAINS` | yes | — | Comma-separated FQDN list |
| `RENEW_DAYS` | no | 30 | Renew when fewer than N days remain |
| `RENEW_INTERVAL_SECONDS` | no | 43200 | Sleep between renewal passes |
| `PORT` | no | 8080 | HTTP listen port |

## Deployment

CI/CD pipeline:

```
git push main
  → .github/workflows/deploy.yml
      ├─ docker buildx build + push ghcr.io/<owner>/innovadis-certs:{latest,sha}
      └─ POST https://deploy.roes.ink/hooks/deploy {stack:"innovadis-certs"}
deploy-webhook on Unraid
  → docker compose pull && up -d
```

Public URL via Cloudflare-proxied DNS + Traefik on Unraid:
`https://innovadis-certs.sander.ninja → http://10.0.0.170:8788`.

## Local development

```bash
docker build -t innovadis-certs .
docker run --rm -it \
  -e CLOUDFLARE_DNS_API_TOKEN=... \
  -e PFX_PASSWORD=... \
  -e CONTACT_EMAIL=you@example.com \
  -e DOMAINS=tenant1.innovadis.roes.ink,tenant1-login.innovadis.roes.ink \
  -p 8080:8080 \
  innovadis-certs
```

Test against the Let's Encrypt staging server first by adding
`-e LEGO_CA_SERVER=https://acme-staging-v02.api.letsencrypt.org/directory`
(lego picks this up automatically).
