# Automated Backup Setup (Linux)

This directory contains scripts to set up automated backups using Linux cron.

## Setup

1. Make the setup script executable:
   ```bash
   chmod +x setup_cron.sh
   ```

2. Run the setup script:
   ```bash
   ./setup_cron.sh
   ```

3. The backup will run daily at 2:00 AM

### Manual Cron Setup
```bash
# Edit crontab
crontab -e

# Add this line for daily backup at 2:00 AM:
0 2 * * * cd "/path/to/backup" && python3 main.py >> cron.log 2>&1
```

## Schedule Examples

### Cron Format
```
# ┌───────────── minute (0 - 59)
# │ ┌───────────── hour (0 - 23)
# │ │ ┌───────────── day of month (1 - 31)
# │ │ │ ┌───────────── month (1 - 12)
# │ │ │ │ ┌───────────── day of week (0 - 6) (Sunday=0)
# │ │ │ │ │
# * * * * *

0 2 * * *     # Daily at 2:00 AM
0 */6 * * *   # Every 6 hours
0 2 * * 0     # Weekly on Sunday at 2:00 AM
0 2 1 * *     # Monthly on 1st day at 2:00 AM
30 1 * * *    # Daily at 1:30 AM
```

## Monitoring

### View Logs
```bash
tail -f cron.log
```

### Check Cron Status
```bash
# View current cron jobs
crontab -l

# View cron service status
systemctl status cron
```

## Troubleshooting

1. **Python not found**: Ensure Python is in PATH
2. **Permission denied**: Run setup script with sudo
3. **Script not running**: Check logs in `cron.log`
4. **Telegram errors**: Verify bot token and chat ID in `.env`
5. **Docker access**: Ensure user has Docker permissions

## Environment Variables

Make sure your `.env` file contains:
```
BOT_TOKEN=your_telegram_bot_token
BOT_DEST=your_chat_id
ROOT_DIR=D:\docker\portainer
TMP_DIR=D:\docker\portainer\temp
DB_CONTAINERS=mysql_container,postgres_db
```