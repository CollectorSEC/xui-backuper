#!/bin/bash

BACKUP_SCRIPT="/root/xui-backuper/backup.sh"
XUIB_SCRIPT="/usr/local/bin/xuib"
RCLONE_CONFIG="/root/.config/rclone/rclone.conf"
BACKUP_DIR="/root/xui_backups"
BACKUP_BASE_DIR="/root/xui-backuper"

echo "⏳ Installing required tools..."
apt update -y && apt install -y rclone cron

echo "✅ rclone and cron installed."
echo ""

# Prompt user for credentials with default endpoint
read -p "🔑 Enter your Access Key: " ACCESS_KEY
read -p "🔒 Enter your Secret Key: " SECRET_KEY
read -p "🌐 Enter Arvan endpoint (default: https://s3.ir-thr-at1.arvanstorage.ir): " ENDPOINT
ENDPOINT=${ENDPOINT:-https://s3.ir-thr-at1.arvanstorage.ir}
read -p "📦 Enter your bucket name (e.g. xui-backups): " BUCKET_NAME

CONFIG_DIR="/root/.config/rclone"
mkdir -p "$CONFIG_DIR"

echo "📁 Creating rclone config..."
cat > "$RCLONE_CONFIG" <<EOF
[arvan]
type = s3
provider = Other
access_key_id = $ACCESS_KEY
secret_access_key = $SECRET_KEY
endpoint = $ENDPOINT
EOF

echo "✅ rclone config created."
echo ""

# Create backup script and folders
mkdir -p "$BACKUP_BASE_DIR"
mkdir -p "$BACKUP_DIR"

echo "🛠️ Creating backup script..."
cat > "$BACKUP_SCRIPT" <<'EOF'
#!/bin/bash

DB_PATH="/etc/x-ui/x-ui.db"
BACKUP_DIR="/root/xui_backups"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILE="$BACKUP_DIR/xui_backup_$TIMESTAMP.db"

mkdir -p "$BACKUP_DIR"
cp "$DB_PATH" "$BACKUP_FILE"

# Upload to Arvan
if rclone copy "$BACKUP_FILE" arvan:xui-backups; then
  echo "✅ Backup uploaded successfully."
else
  echo "❌ Backup upload failed!"
fi

# Optional: Delete local backups older than 7 days
find "$BACKUP_DIR" -type f -name "*.db" -mtime +7 -delete
EOF

chmod +x "$BACKUP_SCRIPT"
echo "✅ Backup script created and made executable."
echo ""

# Run initial backup and check
echo "🚀 Running initial backup now..."
if $BACKUP_SCRIPT; then
  echo "✅ Initial backup completed successfully."
else
  echo "❌ Initial backup failed!"
fi
echo ""

# Add default hourly cron job
(crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT"; echo "0 * * * * $BACKUP_SCRIPT") | crontab -
echo "🕐 Default cron job (every 1 hour) added."

# Create the xuib interactive panel script
echo "🛠️ Creating xuib panel script..."

cat > "$XUIB_SCRIPT" <<EOF
#!/bin/bash

BACKUP_SCRIPT="$BACKUP_SCRIPT"
RCLONE_CONFIG="$RCLONE_CONFIG"
BACKUP_DIR="$BACKUP_DIR"
BACKUP_BASE_DIR="$BACKUP_BASE_DIR"

show_banner() {
cat <<'EOB'
                  _________ ______  
|\     /||\     /|\__   __/(  ___ \ 
( \   / )| )   ( |   ) (   | (   ) )
 \ (_) / | |   | |   | |   | (__/ / 
  ) _ (  | |   | |   | |   |  __ (  
 / ( ) \ | |   | |   | |   | (  \ \ 
( /   \ )| (___) |___) (___| )___) )
|/     \|(_______)\_______/|/ \___/ 
                                      
      C O L L E C T O R S E C

=== XUI Backup Panel ===
EOB
}

show_menu() {
  clear
  show_banner
  echo "0) Send backup now"
  echo "1) Send backup every 1 hour (default)"
  echo "2) Send backup every 3 hours"
  echo "3) Send backup every 6 hours"
  echo "4) Send backup every 12 hours"
  echo "5) Delete all backup scripts and settings"
  echo "6) Exit"
  echo -n "Choose an option [0-6]: "
}

set_cron_job() {
  local interval=\$1
  crontab -l 2>/dev/null | grep -v "\$BACKUP_SCRIPT" | crontab -
  if [ "\$interval" != "none" ]; then
    echo "Setting backup interval to every \$interval hour(s)..."
    (crontab -l 2>/dev/null; echo "0 */\$interval * * * \$BACKUP_SCRIPT") | crontab -
  else
    echo "Removing backup cron jobs..."
  fi
}

delete_all() {
  echo "Removing cron jobs..."
  crontab -l 2>/dev/null | grep -v "\$BACKUP_SCRIPT" | crontab -

  echo "Deleting backup scripts and directories..."
  rm -rf "\$BACKUP_BASE_DIR"
  rm -rf "\$BACKUP_DIR"

  echo "Deleting rclone config..."
  rm -f "\$RCLONE_CONFIG"

  echo "Deleting panel script..."
  rm -f "$XUIB_SCRIPT"

  echo "All backup scripts and settings removed."
  echo "Exiting..."
  exit 0
}

while true; do
  show_menu
  read -r choice
  case \$choice in
    0)
      echo "Sending backup now..."
      if \$BACKUP_SCRIPT; then
        echo "✅ Backup sent successfully."
      else
        echo "❌ Backup failed!"
      fi
      read -p "Press Enter to continue..."
      ;;
    1)
      set_cron_job 1
      echo "Backup scheduled every 1 hour."
      read -p "Press Enter to continue..."
      ;;
    2)
      set_cron_job 3
      echo "Backup scheduled every 3 hours."
      read -p "Press Enter to continue..."
      ;;
    3)
      set_cron_job 6
      echo "Backup scheduled every 6 hours."
      read -p "Press Enter to continue..."
      ;;
    4)
      set_cron_job 12
      echo "Backup scheduled every 12 hours."
      read -p "Press Enter to continue..."
      ;;
    5)
      echo "Deleting all backup scripts and settings..."
      read -p "Are you sure? This action is irreversible! (y/N): " confirm
      if [[ "\$confirm" =~ ^[Yy]$ ]]; then
        delete_all
      else
        echo "Cancelled."
        read -p "Press Enter to continue..."
      fi
      ;;
    6)
      echo "Exiting..."
      exit 0
      ;;
    *)
      echo "Invalid option. Try again."
      sleep 1
      ;;
  esac
done
EOF

chmod +x "$XUIB_SCRIPT"

echo "✅ xuib panel script created at $XUIB_SCRIPT"
echo ""
echo "🎉 Setup complete! Use the command 'xuib' to open the backup panel."
