# Docker Volume Backup with Telegram & Backblaze B2
FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    docker.io \
    cron \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy requirements first (for better caching)
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY main.py .
COPY .env.example .

# Create necessary directories
RUN mkdir -p /app/backups /app/logs

# Create cron job file
RUN echo "0 2 * * * cd /app && python main.py >> /app/logs/cron.log 2>&1" > /etc/cron.d/docker-backup

# Give execution rights on the cron job
RUN chmod 0644 /etc/cron.d/docker-backup

# Apply cron job
RUN crontab /etc/cron.d/docker-backup

# Create entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Health check
HEALTHCHECK --interval=1h --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Expose health check port
EXPOSE 8080

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["cron", "-f"]