# Base Chainguard (Wolfi): sem shell e sem gerenciador de pacotes na imagem final,
# para zerar vulnerabilidades no scan do trivy.
# ---------- estagio 1: dependencias ----------
FROM cgr.dev/chainguard/python:latest-dev AS build
WORKDIR /app
RUN python -m venv --without-pip /app/venv
COPY requirements.txt .
RUN pip --python /app/venv/bin/python install --no-cache-dir -r requirements.txt

# ---------- estagio 2: imagem final ----------
FROM cgr.dev/chainguard/python:latest

# A versao e gravada na imagem no momento do build:
#   docker buildx build --build-arg APP_VERSION=2.0 ...
ARG APP_VERSION=1.0
ENV APP_VERSION=${APP_VERSION} \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/app/venv/bin:$PATH"

COPY --from=build /app/venv /app/venv
WORKDIR /app
COPY app ./app

# A imagem ja roda como nao-root com UID numerico 65532 (exigido por runAsNonRoot)
EXPOSE 8000
ENTRYPOINT []
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
