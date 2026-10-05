# Basen är låst med digest, så att varje bygge utgår från exakt samma image.
# Taggen står kvar för läsbarheten. Dependabot föreslår ny digest varje
# vecka (.github/dependabot.yml).
FROM python:3.13-slim@sha256:3dd7cc108ec1493442514f5c2a871af6af0ec31d768ff6e378a93340c3b3db5f

# Säkerhetsuppdateringar i Debian-basen kommer med vid varje bygge,
# även när python-imagen inte har byggts om än (F36).
RUN apt-get update \
 && apt-get upgrade -y --no-install-recommends \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
# pip behövs bara vid bygget. Det tas bort i samma lager, så att pip och
# biblioteken det har inbakade inte följer med i imagen som kör (F56).
RUN pip install --no-cache-dir -r requirements.txt \
 && pip uninstall -y pip

COPY . .

ENV PYTHONPATH=/app/src
ENV FLASK_APP=company_website

EXPOSE 7000

CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:7000", "--access-logfile", "-", "wsgi:app"]
