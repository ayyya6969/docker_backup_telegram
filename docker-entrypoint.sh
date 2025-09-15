#!/bin/bash
set -e

echo "🐳 Starting Docker Volume Backup Service"
echo "========================================"

# Check if .env file exists
if [ ! -f "/app/.env" ]; then
    echo "⚠️  No .env file found, creating from example..."
    if [ -f "/app/.env.example" ]; then
        cp /app/.env.example /app/.env
        echo "📝 Please edit /app/.env with your configuration"
    else
        echo "❌ No .env.example file found!"
        exit 1
    fi
fi

# Source environment variables
if [ -f "/app/.env" ]; then
    export $(cat /app/.env | grep -v '^#' | grep -v '^$' | xargs)
fi

# Validate required environment variables
echo "🔍 Validating configuration..."

if [ -z "$BOT_TOKEN" ]; then
    echo "❌ BOT_TOKEN is required in .env file"
    exit 1
fi

if [ -z "$BOT_DEST" ]; then
    echo "❌ BOT_DEST is required in .env file"
    exit 1
fi

if [ -z "$ROOT_DIR" ]; then
    echo "⚠️  ROOT_DIR not set, using default: /var/lib/docker/volumes"
    export ROOT_DIR="/var/lib/docker/volumes"
fi

# Backblaze B2 validation
if [ "$S3_ENABLED" = "true" ]; then
    if [ -z "$S3_BUCKET" ]; then
        echo "❌ S3_BUCKET is required when S3_ENABLED=true"
        exit 1
    fi
    if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
        echo "❌ AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are required for Backblaze B2"
        exit 1
    fi
    echo "✅ Backblaze B2 configuration validated"
fi

# Test Docker access
echo "🐳 Testing Docker access..."
if ! docker ps >/dev/null 2>&1; then
    echo "❌ Cannot access Docker daemon. Make sure Docker socket is mounted."
    exit 1
fi
echo "✅ Docker access confirmed"

# Test Telegram bot
echo "📱 Testing Telegram bot..."
python3 -c "
import telebot
import os
try:
    bot = telebot.TeleBot('$BOT_TOKEN')
    bot.send_message($BOT_DEST, '🤖 Docker Backup Service Started\n\n🕐 Scheduled: Daily at 2:00 AM\n📊 Ready to monitor Docker volumes')
    print('✅ Telegram bot working')
except Exception as e:
    print(f'❌ Telegram bot error: {e}')
    exit(1)
"

# Test S3/B2 connection if enabled
if [ "$S3_ENABLED" = "true" ]; then
    echo "☁️  Testing Backblaze B2 connection..."
    python3 -c "
import boto3
from botocore.exceptions import ClientError
try:
    client = boto3.client('s3',
        endpoint_url='https://s3.$AWS_REGION.backblazeb2.com',
        aws_access_key_id='$AWS_ACCESS_KEY_ID',
        aws_secret_access_key='$AWS_SECRET_ACCESS_KEY',
        region_name='$AWS_REGION'
    )
    client.head_bucket(Bucket='$S3_BUCKET')
    print('✅ Backblaze B2 connection successful')
except Exception as e:
    print(f'❌ Backblaze B2 connection error: {e}')
    exit(1)
"
fi

# Create log directory
mkdir -p /app/logs

# Start health check server in background
echo "🔧 Starting health check server..."
python3 -c "
import http.server
import socketserver
import threading
import time

class HealthHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{\"status\":\"healthy\",\"service\":\"docker-backup\"}')
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        pass  # Suppress logs

def start_server():
    with socketserver.TCPServer(('', 8080), HealthHandler) as httpd:
        httpd.serve_forever()

server_thread = threading.Thread(target=start_server, daemon=True)
server_thread.start()
print('✅ Health check server started on port 8080')

# Keep the script running
while True:
    time.sleep(60)
" &

# Show startup summary
echo ""
echo "🚀 Docker Backup Service Configuration:"
echo "   📱 Telegram Bot: Configured"
echo "   📁 Root Directory: $ROOT_DIR"
echo "   ⏰ Schedule: Daily at 2:00 AM"
if [ "$S3_ENABLED" = "true" ]; then
    echo "   ☁️  Backblaze B2: Enabled ($S3_BUCKET)"
else
    echo "   ☁️  Cloud Storage: Disabled"
fi
echo ""
echo "💡 Manual backup: docker exec <container> python /app/main.py"
echo "📊 View logs: docker logs <container>"
echo ""

# Execute the main command
exec "$@"