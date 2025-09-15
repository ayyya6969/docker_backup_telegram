# Docker Volume Backup Script

Automated backup solution for Docker volumes and databases with Telegram notifications.

## Features

- 🐳 **Docker Volume Backup**: Automatically compresses and backs up Docker volumes
- 🗄️ **Database Dumps**: Auto-detects and dumps MySQL, MariaDB, PostgreSQL, MongoDB, Redis databases
- 📱 **Telegram Integration**: Sends backup files via Telegram bot
- ⏰ **Cron Scheduling**: Easy automated scheduling with Linux cron
- 🔍 **Smart Detection**: Automatically finds database containers with volumes in specified directories
- ⚡ **Incremental Backups**: Only backs up volumes that have changed (smart change detection)
- 🧹 **Cleanup**: Removes temporary files after successful transmission
- 📊 **Detailed Reports**: Telegram summaries showing what was backed up vs skipped
- ☁️ **B2 Integration**: All backup files stored in Backblaze B2 cloud storage
- 📝 **Comprehensive Logging**: Detailed logs for monitoring and troubleshooting

## 🐳 Docker Deployment

```bash
# Clone repository
git clone https://github.com/ayyya6969/docker_backup_telegram.git
cd docker_backup_telegram

# Run automated setup
chmod +x docker-setup.sh
./docker-setup.sh
```

**What it does:**
- ✅ Build Docker image with all dependencies
- ✅ Create configuration from template  
- ✅ Validate Telegram and Backblaze B2 settings
- ✅ Start backup service with health monitoring
- ✅ Schedule daily backups at 2:00 AM
- ✅ Send startup notification via Telegram


## Configuration

### Environment Variables

Copy `.env.docker` to `.env` and configure:

| Variable | Description | Example |
|----------|-------------|---------|
| `BOT_TOKEN` | Telegram bot token | `123456789:ABCdefGHijklmnopQRSTuvwxyz` |
| `BOT_DEST` | Telegram chat ID | `1234567890` |
| `ROOT_DIR` | Docker volumes root paths (comma-separated) | `/var/lib/docker/volumes,/data` |
| `TMP_DIR` | Temporary directory for backups | `/tmp/backups` |
| `DB_CONTAINERS` | Manual database container list (optional) | `mysql_db,postgres_app` |
| `CUST_MSG` | Custom message prefix (optional) | `Production Backup` |
| `S3_ENABLED` | Enable Backblaze B2 uploads (required) | `true` |
| `S3_BUCKET` | Backblaze B2 bucket name | `my-docker-backups` |
| `S3_PREFIX` | B2 object prefix/folder | `docker-backups/` |
| `AWS_ACCESS_KEY_ID` | Backblaze B2 key ID | `your_key_id` |
| `AWS_SECRET_ACCESS_KEY` | Backblaze B2 application key | `your_app_key` |
| `AWS_REGION` | Backblaze B2 region | `us-west-004` |

### Telegram Bot Setup

1. **Create bot**: Message [@BotFather](https://t.me/botfather) on Telegram
2. **Get token**: Send `/newbot` and follow instructions
3. **Get chat ID**: 
   - Message your bot
   - Visit: `https://api.telegram.org/bot<TOKEN>/getUpdates`
   - Find your chat ID in the response

### Backblaze B2 Setup (Required)

All backup files are stored in Backblaze B2 cloud storage:

1. **Sign up for Backblaze B2**:
   - Visit [backblaze.com/b2](https://www.backblaze.com/b2/cloud-storage.html)
   - Create account (10GB free tier)

2. **Create B2 bucket**:
   - Go to B2 Cloud Storage → Buckets
   - Create new bucket with unique name
   - Note the bucket name and region

3. **Create App Key**:
   - Go to Account → App Keys
   - Create new key with read/write access to your bucket
   - Save the `keyID` and `applicationKey`

4. **Configure in `.env`**:
   ```bash
   S3_ENABLED=true
   S3_BUCKET=your-bucket-name
   AWS_ACCESS_KEY_ID=your_key_id
   AWS_SECRET_ACCESS_KEY=your_application_key
   AWS_REGION=us-west-004  # Your B2 region
   ```

**Backblaze B2 Regions:**
- `us-west-001` (US West - Oregon)
- `us-west-002` (US West - California)  
- `us-west-004` (US West - Arizona)
- `us-east-001` (US East - Virginia)
- `eu-central-003` (EU - Amsterdam)
- `ap-southeast-002` (Asia Pacific - Singapore)

## How It Works

### Backup Process

1. **Database Detection**: Scans running containers for database images
2. **Volume Filtering**: Only processes containers with volumes in `ROOT_DIR`
3. **Database Dumps**: Creates SQL dumps before file backup
4. **Volume Compression**: Compresses each volume directory into `.tar.gz`
5. **File Storage**: 
   - All backup files → Backblaze B2 cloud storage
   - Download links sent via Telegram (7-day expiry)
6. **Summary Report**: Detailed Telegram message with download links
7. **Cleanup**: Removes temporary files

### Supported Databases

- **MySQL/MariaDB**: Uses `mysqldump --all-databases`
- **PostgreSQL**: Uses `pg_dumpall -U postgres`
- **MongoDB**: Detected but requires custom dump implementation
- **Redis**: Detected but requires custom dump implementation

## Directory Structure

```
backup/
├── main.py                    # Main backup script
├── requirements.txt           # Python dependencies
├── Dockerfile                 # Docker image definition
├── docker-compose.yml         # Docker Compose orchestration  
├── docker-entrypoint.sh       # Container startup script
├── docker-setup.sh            # Automated Docker setup
├── .env.docker               # Environment configuration template
├── .gitignore                 # Git ignore rules
├── README.md                  # This file
└── backup_state.json          # Incremental backup state (auto-generated)
```

## Usage Examples

### Docker Service Management

```bash
# View status
docker compose ps

# View live logs  
docker compose logs -f

# Manual backup test
docker compose exec docker-backup python /app/main.py

# Restart service
docker compose restart

# Stop service
docker compose down

# Update and restart
git pull && docker compose up -d --build
```

## Monitoring

### Log Files
- **Container logs**: `docker compose logs -f`
- **Application logs**: Inside container at `/app/logs/`
- **Health endpoint**: `curl http://localhost:8080/health`

### Health Checks
```bash
# Check service health
docker compose ps

# Monitor logs in real-time
docker compose logs -f docker-backup

# Check health endpoint
curl http://localhost:8080/health

# View backup state
docker compose exec docker-backup cat /app/backup_state.json
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

1. **Docker environment issues**:
   ```bash
   # Check Docker installation
   docker --version
   docker compose --version
   
   # Restart Docker service
   sudo systemctl restart docker
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

6. **Backblaze B2 upload failures**:
   - Verify B2 credentials and bucket name
   - Check B2 region configuration  
   - Test connection: `docker compose logs docker-backup`
   - Ensure bucket has read/write permissions

7. **Docker service issues**:
   - Check service status: `docker compose ps`
   - View logs: `docker compose logs -f`
   - Restart service: `docker compose restart`
   - Manual backup test: `docker compose exec docker-backup python /app/main.py`


### Debug Mode
```bash
# Run backup manually with verbose output
docker compose exec docker-backup python /app/main.py

# View detailed container logs
docker compose logs -f docker-backup
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