import os
import logging
from datetime import datetime
import tarfile
import telebot
import subprocess
import json
import hashlib
from dotenv import load_dotenv

# Load environment variables from .env file if it exists
load_dotenv()

try:
    log_file_name = datetime.now().strftime("%Y%m%d_%H%M%S") + ".txt"
    logging.basicConfig(filename=f"/tmp/{log_file_name}", level=logging.DEBUG)
    log_file_name = f"/tmp/{log_file_name}"
except Exception as retEx:
    logging.error("Cannot create log file: [%s]. Defaulting to current folder", str(retEx))
    logging.basicConfig(filename=log_file_name, level=logging.DEBUG)

TELEGRAM_API_TOKEN: str = os.environ.get('BOT_TOKEN')
if not TELEGRAM_API_TOKEN:
    logging.critical("Input token is empty!")
    raise Exception("Invalid BOT_TOKEN")
else:
    logging.debug("BOT_TOKEN length: [%s]", len(TELEGRAM_API_TOKEN))

# Get destination chat
TELEGRAM_DEST_CHAT: str = os.environ.get('BOT_DEST')
if not TELEGRAM_DEST_CHAT:
    logging.critical("Destination chat is empty!")
    raise Exception("Invalid BOT_DEST")
else:
    TELEGRAM_DEST_CHAT: int = int(TELEGRAM_DEST_CHAT)
    logging.debug("BOT_DEST: [%s]", TELEGRAM_DEST_CHAT)

bot = telebot.TeleBot(TELEGRAM_API_TOKEN)

# Custom message to send before files list
TELEGRAM_BACKUP_MESSAGE: str = os.environ.get('CUST_MSG')
if not TELEGRAM_BACKUP_MESSAGE:
    TELEGRAM_BACKUP_MESSAGE = "Backup at " + datetime.now().strftime("%Y%m%d_%H%M%S")
else:
    TELEGRAM_BACKUP_MESSAGE += "\n\nBackup at " + datetime.now().strftime("%Y%m%d_%H%M%S")

# Get volumes root path
DOCKER_VOLUME_DIRECTORIES: str = os.environ.get('ROOT_DIR')
if not DOCKER_VOLUME_DIRECTORIES:
    # Common volumes locations
    DOCKER_VOLUME_DIRECTORIES = ["/var/snap/docker/common/var-lib-docker/volumes/", "/var/lib/docker/volumes", "/root/backup"]
    logging.warning("ROOT_DIR is empty, falling back to default path(s): %s", DOCKER_VOLUME_DIRECTORIES)
else:
    # Get directories from environment
    DOCKER_VOLUME_DIRECTORIES = [str(x).strip() for x in DOCKER_VOLUME_DIRECTORIES.split(",")]
    logging.debug("ROOT_DIR: [%s]", DOCKER_VOLUME_DIRECTORIES)

# Get temporary path
TMP_DIR: str = os.environ.get('TMP_DIR')
if not TMP_DIR:
    TMP_DIR = "/tmp"
    logging.warning("TMP_DIR is empty, falling back to default path: [%s]", TMP_DIR )
TMP_DIR = os.path.join(TMP_DIR, datetime.now().strftime("%Y%m%d_%H%M%S"))
if not os.path.exists(TMP_DIR):
    try:
        os.mkdir(TMP_DIR)
    except Exception as retEx:
        logging.error("Cannot create temporary folder: [%s]. Defaulting to current folder", str(retEx))
        TMP_DIR = os.getcwd()
logging.debug("TMP_DIR: [%s]", TMP_DIR)

# Backup state file to track previous backup info
BACKUP_STATE_FILE = os.path.join(os.path.dirname(__file__), "backup_state.json")
logging.debug("BACKUP_STATE_FILE: [%s]", BACKUP_STATE_FILE)

# Database configuration
DB_CONTAINERS = os.environ.get('DB_CONTAINERS', '').split(',') if os.environ.get('DB_CONTAINERS') else []
DB_CONTAINERS = [container.strip() for container in DB_CONTAINERS if container.strip()]
logging.debug("DB_CONTAINERS: [%s]", DB_CONTAINERS)



# Function to get directory size and modification info
def get_directory_info(directory_path):
    """
    Get directory size and modification time info for change detection
    """
    try:
        total_size = 0
        file_count = 0
        latest_mtime = 0
        
        # Create a hash of directory structure and sizes
        dir_hash = hashlib.md5()
        
        for root, dirs, files in os.walk(directory_path):
            for file in files:
                file_path = os.path.join(root, file)
                try:
                    stat_info = os.stat(file_path)
                    file_size = stat_info.st_size
                    file_mtime = stat_info.st_mtime
                    
                    total_size += file_size
                    file_count += 1
                    latest_mtime = max(latest_mtime, file_mtime)
                    
                    # Add file info to hash (relative path + size + mtime)
                    rel_path = os.path.relpath(file_path, directory_path)
                    dir_hash.update(f"{rel_path}:{file_size}:{file_mtime}".encode())
                    
                except (OSError, IOError) as e:
                    logging.warning("Cannot access file [%s]: %s", file_path, str(e))
                    continue
        
        return {
            'size': total_size,
            'file_count': file_count,
            'latest_mtime': latest_mtime,
            'content_hash': dir_hash.hexdigest()
        }
    except Exception as e:
        logging.error("Error getting directory info for [%s]: %s", directory_path, str(e))
        return None

# Function to load backup state
def load_backup_state():
    """Load previous backup state from JSON file"""
    try:
        if os.path.exists(BACKUP_STATE_FILE):
            with open(BACKUP_STATE_FILE, 'r') as f:
                return json.load(f)
    except Exception as e:
        logging.warning("Cannot load backup state: %s", str(e))
    return {}

# Function to save backup state
def save_backup_state(state):
    """Save current backup state to JSON file"""
    try:
        with open(BACKUP_STATE_FILE, 'w') as f:
            json.dump(state, f, indent=2)
        logging.debug("Backup state saved to [%s]", BACKUP_STATE_FILE)
    except Exception as e:
        logging.error("Cannot save backup state: %s", str(e))


# Function to check if volume needs backup
def volume_needs_backup(volume_path, volume_name, previous_state):
    """
    Check if volume has changed since last backup
    """
    current_info = get_directory_info(volume_path)
    if not current_info:
        logging.warning("Cannot get info for volume [%s], will backup anyway", volume_name)
        return True, current_info
    
    if volume_name not in previous_state:
        logging.info("Volume [%s] - first time backup", volume_name)
        return True, current_info
    
    prev_info = previous_state[volume_name]
    
    # Check if content has changed
    if current_info['content_hash'] != prev_info.get('content_hash'):
        logging.info("Volume [%s] - content changed (hash: %s -> %s)", 
                    volume_name, prev_info.get('content_hash', 'none')[:8], 
                    current_info['content_hash'][:8])
        return True, current_info
    
    # Check if size changed significantly
    size_diff = abs(current_info['size'] - prev_info.get('size', 0))
    size_change_percent = (size_diff / max(prev_info.get('size', 1), 1)) * 100
    
    if size_change_percent > 1:  # More than 1% size change
        logging.info("Volume [%s] - size changed by %.1f%% (%d -> %d bytes)", 
                    volume_name, size_change_percent, 
                    prev_info.get('size', 0), current_info['size'])
        return True, current_info
    
    # Check if files were modified recently
    prev_mtime = prev_info.get('latest_mtime', 0)
    if current_info['latest_mtime'] > prev_mtime:
        logging.info("Volume [%s] - files modified (latest: %s)", 
                    volume_name, datetime.fromtimestamp(current_info['latest_mtime']))
        return True, current_info
    
    logging.info("Volume [%s] - no changes detected, skipping backup", volume_name)
    return False, current_info

# Function to compress a folder
def MakeTar(source_dir, output_filename):
    logging.debug("Compressing: [%s] to: [%s]", source_dir, output_filename)
    try:
        with tarfile.open(output_filename, "w:gz") as tar:
            tar.add(source_dir, arcname=os.path.basename(source_dir))
        return True
    except:
        return False

# Function to detect database volumes and containers
def detect_database_volumes():
    """
    Detect database containers and their volumes by scanning Docker volumes
    """
    db_info = []
    
    try:
        # Get all Docker containers
        result = subprocess.run(['docker', 'ps', '-a', '--format', '{{.Names}}\t{{.Image}}\t{{.Status}}'], 
                              capture_output=True, text=True, timeout=30)
        
        if result.returncode != 0:
            logging.error("Failed to get Docker containers")
            return db_info
            
        containers = result.stdout.strip().split('\n')
        
        for container_line in containers:
            if not container_line.strip():
                continue
                
            parts = container_line.split('\t')
            if len(parts) >= 3:
                container_name = parts[0]
                image = parts[1].lower()
                status = parts[2]
                
                # Check if container image suggests it's a database
                is_db = any(db_type in image for db_type in ['mysql', 'mariadb', 'postgres', 'mongo', 'redis'])
                
                if is_db and 'up' in status.lower():
                    # Get volume mounts for this container
                    volume_result = subprocess.run(['docker', 'inspect', '--format', 
                                                  '{{range .Mounts}}{{.Source}}:{{.Destination}}\n{{end}}', 
                                                  container_name], 
                                                 capture_output=True, text=True, timeout=10)
                    
                    if volume_result.returncode == 0:
                        volumes = []
                        for mount_line in volume_result.stdout.strip().split('\n'):
                            if ':' in mount_line and mount_line.strip():
                                source, dest = mount_line.split(':', 1)
                                volumes.append({'source': source, 'destination': dest})
                        
                        db_info.append({
                            'container': container_name,
                            'image': image,
                            'volumes': volumes
                        })
                        logging.info("Found database container: [%s] with image [%s]", container_name, image)
        
    except Exception as e:
        logging.error("Error detecting database volumes: %s", str(e))
    
    return db_info

# Function to dump database
def dump_database(container_name, output_dir):
    """
    Dump database from Docker container.
    Supports MySQL/MariaDB and PostgreSQL containers.
    """
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    
    try:
        # Check if container exists and is running
        result = subprocess.run(['docker', 'inspect', '--format={{.State.Running}}', container_name], 
                              capture_output=True, text=True, timeout=10)
        if result.returncode != 0 or result.stdout.strip() != 'true':
            logging.warning("Container [%s] is not running or doesn't exist", container_name)
            return None
        
        # Detect database type by checking running processes
        detect_cmd = ['docker', 'exec', container_name, 'ps', 'aux']
        detect_result = subprocess.run(detect_cmd, capture_output=True, text=True, timeout=10)
        
        if detect_result.returncode == 0:
            processes = detect_result.stdout.lower()
            
            if 'mysqld' in processes or 'mariadb' in processes:
                # MySQL/MariaDB dump
                dump_file = os.path.join(output_dir, f"{container_name}_mysql_{timestamp}.sql")
                dump_cmd = ['docker', 'exec', container_name, 'mysqldump', '--all-databases', 
                           '--single-transaction', '--routines', '--triggers']
                
            elif 'postgres' in processes:
                # PostgreSQL dump
                dump_file = os.path.join(output_dir, f"{container_name}_postgres_{timestamp}.sql")
                dump_cmd = ['docker', 'exec', container_name, 'pg_dumpall', '-U', 'postgres']
                
            else:
                logging.warning("Unknown database type in container [%s]", container_name)
                return None
            
            # Execute dump command
            logging.info("Dumping database from container [%s]", container_name)
            with open(dump_file, 'w') as f:
                result = subprocess.run(dump_cmd, stdout=f, stderr=subprocess.PIPE, 
                                      text=True, timeout=300)
            
            if result.returncode == 0:
                logging.info("Database dump successful: [%s]", dump_file)
                return dump_file
            else:
                logging.error("Database dump failed for [%s]: %s", container_name, result.stderr)
                if os.path.exists(dump_file):
                    os.remove(dump_file)
                return None
                
    except subprocess.TimeoutExpired:
        logging.error("Database dump timed out for container [%s]", container_name)
        return None
    except Exception as e:
        logging.error("Error dumping database from [%s]: %s", container_name, str(e))
        return None


if __name__ == '__main__':
    # Send custom message
    bot.send_message(TELEGRAM_DEST_CHAT, TELEGRAM_BACKUP_MESSAGE)
    # Create temporary output path
    if not os.path.exists(TMP_DIR):
        logging.info("Creating: [" + TMP_DIR + "] folder")
        os.mkdir(TMP_DIR)
    else:
        logging.warning("Folder: [" + TMP_DIR + "] already exists, this could cause some troubles")
    
    # Detect database containers and dump them first
    logging.info("Detecting database containers and volumes...")
    detected_dbs = detect_database_volumes()
    
    # Filter detected databases to only include those with volumes in ROOT_DIR
    relevant_dbs = []
    for db_info in detected_dbs:
        for volume in db_info['volumes']:
            volume_source = volume['source']
            # Check if volume source is within any of our ROOT_DIR paths
            for root_dir in DOCKER_VOLUME_DIRECTORIES:
                if volume_source.startswith(root_dir):
                    relevant_dbs.append(db_info)
                    logging.info("Database container [%s] has volume in ROOT_DIR: [%s]", 
                               db_info['container'], volume_source)
                    break
    
    # Dump databases first (before file backup to ensure consistency)
    dumped_containers = []
    for db_info in relevant_dbs:
        container_name = db_info['container']
        if container_name not in dumped_containers:
            dump_file = dump_database(container_name, TMP_DIR)
            if dump_file:
                try:
                    bot.send_document(TELEGRAM_DEST_CHAT, open(dump_file, 'rb'))
                    logging.info("Database dump sent: [%s]", dump_file)
                    # Delete dump file after sending
                    os.remove(dump_file)
                    logging.debug("Database dump file deleted: [%s]", dump_file)
                    dumped_containers.append(container_name)
                except Exception as retEx:
                    logging.error("Cannot send database dump [%s]: %s", dump_file, str(retEx))
    
    # Also dump containers explicitly listed in DB_CONTAINERS env var
    for container_name in DB_CONTAINERS:
        if container_name and container_name not in dumped_containers:
            dump_file = dump_database(container_name, TMP_DIR)
            if dump_file:
                try:
                    bot.send_document(TELEGRAM_DEST_CHAT, open(dump_file, 'rb'))
                    logging.info("Database dump sent: [%s]", dump_file)
                    # Delete dump file after sending
                    os.remove(dump_file)
                    logging.debug("Database dump file deleted: [%s]", dump_file)
                except Exception as retEx:
                    logging.error("Cannot send database dump [%s]: %s", dump_file, str(retEx))
    
    # Load previous backup state for incremental backup
    logging.info("Loading previous backup state...")
    previous_state = load_backup_state()
    current_state = previous_state.copy()  # Start with previous state
    
    # Process path(s) list
    for singleLocation in DOCKER_VOLUME_DIRECTORIES:
        try:
            # Check if we can access that folder
            subFolders = os.listdir(singleLocation)
        except FileNotFoundError:
            logging.warning("Cannot access path: [" + singleLocation + "]")
            continue
        # If the path exists
        for singleSubfolder in subFolders:
            folderToCompress = os.path.join(singleLocation, singleSubfolder)
            # Check if it is a folder
            if os.path.isdir(folderToCompress):
                logging.debug("Found valid folder: " + folderToCompress)
                
                # Check if volume needs backup (incremental backup)
                needs_backup, volume_info = volume_needs_backup(folderToCompress, singleSubfolder, previous_state)
                
                if not needs_backup:
                    logging.info("Skipping backup for volume [%s] - no changes detected", singleSubfolder)
                    # Update current info but keep previous backup timestamp
                    if volume_info:
                        current_state[singleSubfolder] = {**volume_info, 
                                                         'last_backup': previous_state.get(singleSubfolder, {}).get('last_backup')}
                    continue
                
                archiveName = singleSubfolder + "-" + datetime.now().strftime("%Y%m%d_%H%M%S") + ".tar.gz"
                outputPath = os.path.join(TMP_DIR, archiveName)
                
                logging.info("Backing up changed volume: [%s]", singleSubfolder)
                if (MakeTar(folderToCompress, outputPath)):
                    logging.info("Successfully compressed: [" + outputPath + "]")
                    # Send archive
                    try:
                        bot.send_document(TELEGRAM_DEST_CHAT, open(outputPath, 'rb'))
                        logging.info("Document: [" + outputPath + "] was sent successfully")
                        # Only update state after successful backup and transmission
                        current_state[singleSubfolder] = {**volume_info, 'last_backup': datetime.now().isoformat()}
                    except Exception as retEx:
                        logging.error("Cannot send document: [" + str(retEx) + "]")
                        # Don't update state if transmission failed
                        if volume_info:
                            current_state[singleSubfolder] = volume_info
                    # Delete archive
                    try:
                        os.remove(outputPath)
                        logging.debug("File: [" + outputPath + "] was deleted successfully")
                    except Exception as retEx:
                        logging.error("Error while deleting: [" + str(retEx) + "]")
                else:
                    logging.error("Cannot compress: [" + outputPath + "]")
                    # Don't update state if compression failed
                    if volume_info:
                        current_state[singleSubfolder] = volume_info
    
    # Save updated backup state
    save_backup_state(current_state)
    
    # Send summary message to Telegram
    backed_up_volumes = [vol for vol, info in current_state.items() 
                        if info and 'last_backup' in info]
    skipped_volumes = [vol for vol, info in current_state.items() 
                      if info and 'last_backup' not in info]
    
    summary_message = f"🔄 **Backup Summary**\n\n"
    
    if backed_up_volumes:
        summary_message += f"✅ **Backed up volumes ({len(backed_up_volumes)}):**\n"
        for vol in backed_up_volumes:
            size_mb = current_state[vol]['size'] / (1024 * 1024)
            file_count = current_state[vol]['file_count']
            summary_message += f"• `{vol}` ({size_mb:.1f} MB, {file_count} files)\n"
        summary_message += "\n"
    
    if skipped_volumes:
        summary_message += f"⏭️ **Skipped volumes ({len(skipped_volumes)}) - no changes:**\n"
        for vol in skipped_volumes:
            size_mb = current_state[vol]['size'] / (1024 * 1024)
            summary_message += f"• `{vol}` ({size_mb:.1f} MB)\n"
        summary_message += "\n"
    
    if not backed_up_volumes and not skipped_volumes:
        summary_message += "ℹ️ No volumes found to process.\n\n"
    
    # Add database info if any were dumped
    if dumped_containers:
        summary_message += f"🗄️ **Database dumps ({len(dumped_containers)}):**\n"
        for container in dumped_containers:
            summary_message += f"• `{container}`\n"
        summary_message += "\n"
    
    summary_message += f"📅 Completed at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
    
    try:
        bot.send_message(TELEGRAM_DEST_CHAT, summary_message, parse_mode='Markdown')
        logging.info("Backup summary sent to Telegram")
    except Exception as retEx:
        logging.error("Cannot send summary message: [%s]", str(retEx))

    try:
        # Send log file
        bot.send_document(TELEGRAM_DEST_CHAT, open(log_file_name, 'rb'))
        logging.debug("Backup file sent")
    except Exception as retEx:
        logging.error("Error while sending log file: [" + str(retEx) + "]")


    # Done, bye!
    logging.info("Completed!")