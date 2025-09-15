#!/bin/bash

# Docker Backup Service Setup Script
# This script helps you set up the automated Docker backup service

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🐳 Docker Volume Backup Service Setup"
echo "====================================="
echo ""

# Check if Docker and Docker Compose are installed
echo "🔍 Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    echo "   Visit: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! command -v docker compose &> /dev/null && ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    echo "   Visit: https://docs.docker.com/compose/install/"
    exit 1
fi

echo "✅ Docker and Docker Compose are installed"

# Check Docker daemon
if ! docker ps >/dev/null 2>&1; then
    echo "❌ Docker daemon is not running. Please start Docker first."
    exit 1
fi

echo "✅ Docker daemon is running"
echo ""

# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
    echo "📝 Creating .env configuration file..."
    if [ -f ".env.docker" ]; then
        cp .env.docker .env
        echo "✅ Created .env from template"
    else
        echo "❌ Template file .env.docker not found"
        exit 1
    fi
    echo ""
    echo "⚠️  IMPORTANT: Please edit .env file with your configuration:"
    echo "   - Add your Telegram bot token and chat ID"
    echo "   - Configure Backblaze B2 credentials if using S3"
    echo "   - Adjust volume paths if needed"
    echo ""
    read -p "Press Enter after you've configured .env file..."
    echo ""
else
    echo "✅ .env file already exists"
fi

# Create required directories
echo "📁 Creating required directories..."
mkdir -p backup-data logs
echo "✅ Directories created"

# Validate configuration
echo "🔧 Validating configuration..."

# Source environment variables
if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | grep -v '^$' | xargs) 2>/dev/null || true
fi

# Check required variables
MISSING_VARS=()

if [ -z "$BOT_TOKEN" ] || [ "$BOT_TOKEN" = "your_bot_token_from_botfather" ]; then
    MISSING_VARS+=("BOT_TOKEN")
fi

if [ -z "$BOT_DEST" ] || [ "$BOT_DEST" = "your_chat_id_number" ]; then
    MISSING_VARS+=("BOT_DEST")
fi

if [ "$S3_ENABLED" = "true" ]; then
    if [ -z "$S3_BUCKET" ] || [ "$S3_BUCKET" = "your-backblaze-bucket-name" ]; then
        MISSING_VARS+=("S3_BUCKET")
    fi
    if [ -z "$AWS_ACCESS_KEY_ID" ] || [ "$AWS_ACCESS_KEY_ID" = "your_backblaze_key_id" ]; then
        MISSING_VARS+=("AWS_ACCESS_KEY_ID")
    fi
    if [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ "$AWS_SECRET_ACCESS_KEY" = "your_backblaze_application_key" ]; then
        MISSING_VARS+=("AWS_SECRET_ACCESS_KEY")
    fi
fi

if [ ${#MISSING_VARS[@]} -ne 0 ]; then
    echo "❌ Missing or unconfigured variables in .env:"
    printf "   - %s\n" "${MISSING_VARS[@]}"
    echo ""
    echo "Please edit .env file and configure these variables."
    exit 1
fi

echo "✅ Configuration validated"
echo ""

# Show configuration summary
echo "📋 Configuration Summary:"
echo "   📱 Telegram: Configured"
echo "   📁 Root Directory: ${ROOT_DIR:-/var/lib/docker/volumes}"
echo "   ⏰ Schedule: Daily at 2:00 AM"
if [ "$S3_ENABLED" = "true" ]; then
    echo "   ☁️  Backblaze B2: Enabled ($S3_BUCKET)"
else
    echo "   ☁️  Cloud Storage: Disabled"
fi
echo ""

# Build and start services
echo "🔨 Building Docker image..."
docker compose build

echo ""
echo "🚀 Starting backup service..."
docker compose up -d

echo ""
echo "⏳ Waiting for service to start..."
sleep 10

# Check service status
if docker compose ps | grep -q "Up"; then
    echo "✅ Service started successfully!"
    echo ""
    echo "📊 Service Status:"
    docker compose ps
    echo ""
    echo "📋 Useful Commands:"
    echo "   View logs:          docker compose logs -f"
    echo "   Manual backup:      docker compose exec docker-backup python /app/main.py"
    echo "   Restart service:    docker compose restart"
    echo "   Stop service:       docker compose down"
    echo "   Update service:     docker compose pull && docker compose up -d"
    echo ""
    echo "🎯 Next Steps:"
    echo "   1. Check logs to ensure everything is working"
    echo "   2. Test manual backup to verify configuration"
    echo "   3. Wait for scheduled backup at 2:00 AM or trigger manually"
    echo ""
    echo "📱 Check your Telegram for the startup notification!"
else
    echo "❌ Service failed to start. Check logs:"
    docker compose logs
    exit 1
fi