# Nginx Chainguard (Wolfi): roda como nao-root (UID 65532), escuta na porta 8080
# e nao tem shell nem gerenciador de pacotes, para zerar vulnerabilidades no trivy.
FROM cgr.dev/chainguard/nginx:latest
COPY html/ /usr/share/nginx/html/
EXPOSE 8080
