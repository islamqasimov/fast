# OSINT IOC Collector - Docker Image
#
# Bu image layihənin bütün Python asılılıqlarını əvvəlcədən quraşdırır.
# İşlədikdə host qovluğu /app olaraq mount edilir (bax: deploy.sh),
# ona görə kod dəyişiklikləri image-i yenidən build etmədən görünür.

FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENTRYPOINT ["python", "cli.py"]
CMD ["--init-db", "--fetch", "--export", "wazuh"]
