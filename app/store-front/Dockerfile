# Nginx que roda como usuario nao-root (UID 65532) e escuta na porta 8080.
# Variante -dev + netcat: nc e usado pelo teste de NetworkPolicy do verifica-gs.sh (C6).
FROM cgr.dev/chainguard/nginx:latest-dev
USER root
RUN apk add --no-cache netcat-openbsd
USER 65532
COPY html/ /usr/share/nginx/html/
EXPOSE 8080
