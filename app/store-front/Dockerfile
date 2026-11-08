# Nginx que roda como usuario nao-root (UID 65532) e escuta na porta 8080.
# Variante -dev: traz sh e wget, usados pelo teste de NetworkPolicy do verifica-gs.sh (C6).
FROM cgr.dev/chainguard/nginx:latest-dev
COPY html/ /usr/share/nginx/html/
EXPOSE 8080
