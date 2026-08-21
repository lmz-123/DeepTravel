FROM docker.m.daocloud.io/library/python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --index-url https://pypi.tuna.tsinghua.edu.cn/simple -r requirements.txt

COPY . .

RUN mkdir -p /app/media /app/private-evidence

EXPOSE 5000

CMD ["sh", "-c", "alembic upgrade head && flask --app 'app:create_app' seed && gunicorn --bind 0.0.0.0:5000 --workers 2 --threads 4 'app:create_app()'"]
