#!/bin/bash

echo "⏳ Installing required tools..."
apt update -y && apt install -y rclone cron

echo "✅ rclone and cron installed."
echo ""

# Prompt user for credentials
read -p "🔑 Enter your Access Key: " ACCESS_KEY
read -p "🔒 Enter your Secret Key: " SECRET_KEY
read -p "🌐 Enter Arvan endpoint (e.g. https://s3.ir-thr-at1.arvanstorage.ir): " ENDPOINT
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

# Create backup script
BACKUP_SCRIPT="/root/xui-backuper/backup.sh"
mkdir -p /root/xui-backuper
mkdir -p /root/xui_backups

echo "🛠️ Creating backup script..."
cat > "$BACKUP_SCRIPT" <<EOF
#!/bin/bash

DB_PATH="/etc/x-ui/x-ui.db"
BACKUP_DIR="/root/xui_backups"
TIMESTAMP=\$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILE="\$BACKUP_DIR/xui_backup_\$TIMESTAMP.db"

mkdir -p "\$BACKUP_DIR"
cp "\$DB_PATH" "\$BACKUP_FILE"

# Upload to Arvan
rclone copy "\$BACKUP_FILE" arvan:$BUCKET_NAME

# Optional: Delete local backups older than 7 days
find "\$BACKUP_DIR" -type f -name "*.db" -mtime +7 -delete
EOF

chmod +x "$BACKUP_SCRIPT"

echo "✅ Backup script created and made executable."

# Add to crontab
echo "🕐 Adding hourly cron job..."
(crontab -l 2>/dev/null; echo "0 * * * * $BACKUP_SCRIPT") | crontab -

echo ""
echo "🎉 Setup complete! A backup will now be taken and uploaded to Arvan every hour."
