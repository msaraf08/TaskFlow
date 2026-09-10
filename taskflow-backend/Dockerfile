FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONIOENCODING=utf-8

WORKDIR /app

# Copy dependency requirements first to leverage layer caching
COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

# Copy application source code
COPY app/ ./app/

# Create and switch to non-root user for security
RUN useradd -u 1000 -m -s /bin/sh taskflow && \
    chown -R taskflow:taskflow /app

USER taskflow

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
