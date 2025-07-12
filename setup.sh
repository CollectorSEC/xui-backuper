#!/bin/bash

BACKUP_SCRIPT="/root/xui-backuper/backup.sh"
XUIB_SCRIPT="/usr/local/bin/xuib"

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
cat > "$CONFIG_DIR/rclone.conf" <<EOF
[arvan]
type = s3
provider = Other
access_key_id = $ACCESS_KEY
secret_access_key = $SECRET_KEY
endpoint = $ENDPOINT
region = auto
EOF

echo "✅ rclone config created."
echo ""

# Create backup script and folders
mkdir -p /root/xui-backuper
mkdir -p /root/xui_backups

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

cat > "$XUIB_SCRIPT" <<'EOF'
#!/bin/bash

BACKUP_SCRIPT="/root/xui-backuper/backup.sh"

show_menu() {
  clear
  echo "=== XUI Backup Panel ==="
  echo "0) Send backup now"
  echo "1) Send backup every 1 hour (default)"
  echo "2) Send backup every 3 hours"
  echo "3) Send backup every 6 hours"
  echo "4) Send backup every 12 hours"
  echo "5) Exit"
  echo -n "Choose an option [0-5]: "
}

set_cron_job() {
  local interval=$1
  crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT" | crontab -
  if [ "$interval" != "none" ]; then
    echo "Setting backup interval to every $interval hour(s)..."
    (crontab -l 2>/dev/null; echo "0 */$interval * * * $BACKUP_SCRIPT") | crontab -
  else
    echo "Removing backup cron jobs..."
  fi
}

while true; do
  show_menu
  read -r choice
  case $choice in
    0)
      echo "Sending backup now..."
      if $BACKUP_SCRIPT; then
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
