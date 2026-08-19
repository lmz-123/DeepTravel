FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 5000

CMD ["sh", "-c", "alembic upgrade head && flask --app 'app:create_app' seed && gunicorn --bind 0.0.0.0:5000 --workers 2 --threads 4 'app:create_app()'"]

