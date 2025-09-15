#!/bin/bash

# Docker Volume Backup Cron Job Setup Script
# This script sets up a cron job to run the backup script automatically

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SCRIPT="$SCRIPT_DIR/main.py"
PYTHON_PATH=$(which python3 || which python)

echo "Setting up cron job for Docker volume backup..."
echo "Script location: $BACKUP_SCRIPT"
echo "Python path: $PYTHON_PATH"

# Check if backup script exists
if [ ! -f "$BACKUP_SCRIPT" ]; then
    echo "Error: Backup script not found at $BACKUP_SCRIPT"
    exit 1
fi

# Check if python is available
if [ -z "$PYTHON_PATH" ]; then
    echo "Error: Python not found in PATH"
    exit 1
fi

# Create cron job entry
CRON_ENTRY="0 2 * * * cd \"$SCRIPT_DIR\" && \"$PYTHON_PATH\" \"$BACKUP_SCRIPT\" >> \"$SCRIPT_DIR/cron.log\" 2>&1"

echo "Cron job entry:"
echo "$CRON_ENTRY"
echo ""

# Add to crontab
echo "Adding cron job..."
(crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -

if [ $? -eq 0 ]; then
    echo "✅ Cron job successfully added!"
    echo "The backup will run daily at 2:00 AM"
    echo "Logs will be written to: $SCRIPT_DIR/cron.log"
    echo ""
    echo "To view current cron jobs: crontab -l"
    echo "To remove this cron job: crontab -e (then delete the line)"
    echo "To change schedule: crontab -e (then edit the time)"
else
    echo "❌ Failed to add cron job"
    exit 1
fi

echo ""
echo "Cron schedule format: minute hour day month weekday"
echo "Examples:"
echo "  0 2 * * *     - Daily at 2:00 AM"
echo "  0 */6 * * *   - Every 6 hours"
echo "  0 2 * * 0     - Weekly on Sunday at 2:00 AM"
echo "  0 2 1 * *     - Monthly on 1st day at 2:00 AM"