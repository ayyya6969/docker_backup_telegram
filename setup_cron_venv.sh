#!/bin/bash

# Cron Setup Script for Virtual Environment
# This script sets up a cron job that works with Python virtual environment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/backup_env"
BACKUP_SCRIPT="$SCRIPT_DIR/main.py"
PYTHON_VENV="$VENV_DIR/bin/python"

echo "Setting up cron job with virtual environment for Docker volume backup..."
echo "Script location: $BACKUP_SCRIPT"
echo "Virtual env: $VENV_DIR"

# Check if virtual environment exists
if [ ! -d "$VENV_DIR" ]; then
    echo "❌ Error: Virtual environment not found at $VENV_DIR"
    echo "   Please run ./setup_venv.sh first"
    exit 1
fi

# Check if Python exists in venv
if [ ! -f "$PYTHON_VENV" ]; then
    echo "❌ Error: Python not found in virtual environment"
    echo "   Please recreate virtual environment with ./setup_venv.sh"
    exit 1
fi

# Check if backup script exists
if [ ! -f "$BACKUP_SCRIPT" ]; then
    echo "❌ Error: Backup script not found at $BACKUP_SCRIPT"
    exit 1
fi

# Test virtual environment packages
echo "🧪 Testing virtual environment..."
"$PYTHON_VENV" -c "import telebot; import dotenv; print('✅ Virtual environment is working')" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "❌ Error: Required packages not found in virtual environment"
    echo "   Please run ./setup_venv.sh to reinstall packages"
    exit 1
fi

# Create cron job entry with virtual environment
CRON_ENTRY="0 2 * * * cd \"$SCRIPT_DIR\" && \"$PYTHON_VENV\" \"$BACKUP_SCRIPT\" >> \"$SCRIPT_DIR/cron.log\" 2>&1"

echo "Cron job entry:"
echo "$CRON_ENTRY"
echo ""

# Add to crontab
echo "Adding cron job..."
(crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -

if [ $? -eq 0 ]; then
    echo "✅ Cron job successfully added!"
    echo "The backup will run daily at 2:00 AM using virtual environment"
    echo "Logs will be written to: $SCRIPT_DIR/cron.log"
    echo ""
    echo "📋 Useful commands:"
    echo "  View cron jobs: crontab -l"
    echo "  Edit cron jobs: crontab -e"
    echo "  Remove cron job: crontab -l | grep -v 'main.py' | crontab -"
    echo "  View logs: tail -f $SCRIPT_DIR/cron.log"
    echo "  Test manually: cd $SCRIPT_DIR && source backup_env/bin/activate && python main.py"
else
    echo "❌ Failed to add cron job"
    exit 1
fi

echo ""
echo "🕐 Cron schedule examples:"
echo "  0 2 * * *     - Daily at 2:00 AM"
echo "  0 */6 * * *   - Every 6 hours"
echo "  0 2 * * 0     - Weekly on Sunday at 2:00 AM"
echo "  0 2 1 * *     - Monthly on 1st day at 2:00 AM"