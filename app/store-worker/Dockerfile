# ---------- estagio 1: dependencias ----------
FROM cgr.dev/chainguard/python:latest-dev AS build
WORKDIR /app
RUN python -m venv --without-pip /app/venv
COPY requirements.txt .
RUN pip --python /app/venv/bin/python install --no-cache-dir -r requirements.txt

# ---------- estagio 2: imagem final ----------
FROM cgr.dev/chainguard/python:latest
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/app/venv/bin:$PATH"
COPY --from=build /app/venv /app/venv
WORKDIR /app
COPY worker ./worker

# A imagem ja roda como nao-root com UID numerico 65532 (exigido por runAsNonRoot)
# Padrao: consumidor da fila. O CronJob troca o comando para:
#   python -m worker.relatorio
ENTRYPOINT []
CMD ["python", "-m", "worker.main"]
