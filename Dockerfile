FROM python:3.13-slim

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
