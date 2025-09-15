# Docker Volume Backup Script

Automated backup solution for Docker volumes and databases with Telegram notifications.

## Features

- 🐳 **Docker Volume Backup**: Automatically compresses and backs up Docker volumes
- 🗄️ **Database Dumps**: Auto-detects and dumps MySQL, MariaDB, PostgreSQL, MongoDB, Redis databases
- 📱 **Telegram Integration**: Sends backup files via Telegram bot
- ⏰ **Cron Scheduling**: Easy automated scheduling with Linux cron
- 🔍 **Smart Detection**: Automatically finds database containers with volumes in specified directories
- 🧹 **Cleanup**: Removes temporary files after successful transmission
- 📝 **Comprehensive Logging**: Detailed logs for monitoring and troubleshooting

## Quick Start

1. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

2. **Configure environment**:
   ```bash
   cp .env.example .env
   # Edit .env with your settings
   ```

3. **Run backup manually**:
   ```bash
   python main.py
   ```

4. **Setup automated backups**:
   ```bash
   chmod +x setup_cron.sh
   ./setup_cron.sh
   ```

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

| Variable | Description | Example |
|----------|-------------|---------|
| `BOT_TOKEN` | Telegram bot token | `123456789:ABCdefGHijklmnopQRSTuvwxyz` |
| `BOT_DEST` | Telegram chat ID | `1234567890` |
| `ROOT_DIR` | Docker volumes root paths (comma-separated) | `/var/lib/docker/volumes,/data` |
| `TMP_DIR` | Temporary directory for backups | `/tmp/backups` |
| `DB_CONTAINERS` | Manual database container list (optional) | `mysql_db,postgres_app` |
| `CUST_MSG` | Custom message prefix (optional) | `Production Backup` |

### Telegram Bot Setup

1. **Create bot**: Message [@BotFather](https://t.me/botfather) on Telegram
2. **Get token**: Send `/newbot` and follow instructions
3. **Get chat ID**: 
   - Message your bot
   - Visit: `https://api.telegram.org/bot<TOKEN>/getUpdates`
   - Find your chat ID in the response

## How It Works

### Backup Process

1. **Database Detection**: Scans running containers for database images
2. **Volume Filtering**: Only processes containers with volumes in `ROOT_DIR`
3. **Database Dumps**: Creates SQL dumps before file backup
4. **Volume Compression**: Compresses each volume directory into `.tar.gz`
5. **Telegram Delivery**: Sends all backup files via Telegram
6. **Cleanup**: Removes temporary files

### Supported Databases

- **MySQL/MariaDB**: Uses `mysqldump --all-databases`
- **PostgreSQL**: Uses `pg_dumpall -U postgres`
- **MongoDB**: Detected but requires custom dump implementation
- **Redis**: Detected but requires custom dump implementation

## Directory Structure

```
backup/
├── main.py              # Main backup script
├── requirements.txt     # Python dependencies
├── .env                 # Configuration (create from .env.example)
├── .env.example         # Environment template
├── .gitignore          # Git ignore rules
├── setup_cron.sh       # Cron setup script
├── README.md           # This file
└── README_CRON.md      # Cron-specific documentation
```

## Usage Examples

### Manual Backup
```bash
# Run once
python main.py
```

### Scheduled Backup
```bash
# Setup daily backup at 2 AM
./setup_cron.sh

# View cron jobs
crontab -l

# View logs
tail -f cron.log
```

### Custom Schedule
```bash
# Edit crontab manually
crontab -e

# Add custom schedule (every 6 hours)
0 */6 * * * cd /path/to/backup && python3 main.py >> cron.log 2>&1
```

## Monitoring

### Log Files
- **Application logs**: Timestamped files in temp directory
- **Cron logs**: `cron.log` in script directory
- **Telegram delivery**: Logs sent to Telegram chat

### Health Checks
```bash
# Check last backup
ls -la /tmp/backup_logs/

# Monitor cron logs
tail -f cron.log

# Test Telegram connectivity
python -c "
import telebot
from dotenv import load_dotenv
import os
load_dotenv()
bot = telebot.TeleBot(os.environ.get('BOT_TOKEN'))
bot.send_message(os.environ.get('BOT_DEST'), 'Test message')
"
```

## Security Considerations

- ✅ **Read-only access** to Docker volumes
- ✅ **Temporary file cleanup** after transmission
- ✅ **No permanent local storage** of sensitive data
- ✅ **Environment-based configuration** (no hardcoded secrets)
- ⚠️ **Telegram transmission**: Backups sent over internet
- ⚠️ **Bot token security**: Keep `.env` file secure

## Troubleshooting

### Common Issues

1. **Python not found**:
   ```bash
   which python3
   sudo apt install python3 python3-pip
   ```

2. **Docker permission denied**:
   ```bash
   sudo usermod -aG docker $USER
   # Logout and login again
   ```

3. **Telegram errors**:
   - Verify bot token and chat ID
   - Ensure bot is started with `/start` command
   - Check network connectivity

4. **No volumes found**:
   - Verify `ROOT_DIR` paths exist
   - Check Docker volume locations: `docker volume ls`
   - Ensure containers are running

5. **Database dump failures**:
   - Verify container names: `docker ps`
   - Check database user permissions
   - Review container logs: `docker logs <container>`

### Debug Mode
```bash
# Run with verbose logging
python main.py 2>&1 | tee debug.log
```

## Contributing

1. Fork the repository
2. Create feature branch
3. Test thoroughly
4. Submit pull request

## License

MIT License - see LICENSE file for details.

## Support

- 📖 Documentation: See `README_CRON.md` for scheduling details
- 🐛 Issues: Report bugs in project issues
- 💬 Questions: Use project discussions