# Scan de vulnerabilidades (trivy)

Gerado em 2026-11-08 com `trivy 0.75.0` (`trivy image --scanners vuln`), nas imagens publicadas no ECR.

| Imagem | Vulnerabilidades | Relatório |
|---|---:|---|
| `store-api:1.0` | 0 | [store-api-1.0.txt](store-api-1.0.txt) |
| `store-api:2.0` | 0 | [store-api-2.0.txt](store-api-2.0.txt) |
| `store-worker:1.0` | 0 | [store-worker-1.0.txt](store-worker-1.0.txt) |
| `store-front:1.0` | 0 | [store-front-1.0.txt](store-front-1.0.txt) |
| `store-front:1.1` | 0 | [store-front-1.1.txt](store-front-1.1.txt) |

Nenhum `CRITICAL` (nem de outra severidade). Correções aplicadas para chegar a zero:

| Mudança | Motivo |
|---|---|
| Base `python:3.12-slim` → `cgr.dev/chainguard/python` | imagem Wolfi mínima, sem shell nem gerenciador de pacotes: elimina as CVEs do Debian |
| Base `nginx-unprivileged:1.28-alpine` → `cgr.dev/chainguard/nginx:latest-dev` (`1.1`) | imagem Wolfi mínima, não-root e na porta 8080. A variante `-dev` mantém só `sh` e `wget` (busybox), usados pelo teste de NetworkPolicy (C6) |
| `psycopg[binary]` 3.2.9 → 3.3.8 | a base Chainguard usa Python 3.15, sem pacote binário da 3.2 |
| `fastapi` 0.115.12 → 0.162.2 | a 0.115 prende o `starlette` 0.46.2, com 7 CVEs (3 HIGH, ex.: CVE-2025-62727) |

Regerar:

```bash
trivy image --scanners vuln <registry>/store-api:1.0
```
