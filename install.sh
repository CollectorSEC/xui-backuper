#!/bin/bash

REPO_URL="https://github.com/CollectorSEC/xui-backuper.git"
DIR="xui-backuper"

# اگر پوشه هست و خالی نیست پاکش کن
if [ -d "$DIR" ] && [ "$(ls -A $DIR)" ]; then
  echo "🚀 Removing existing $DIR directory..."
  rm -rf "$DIR"
fi

echo "📥 Cloning repository from $REPO_URL ..."
git clone "$REPO_URL"

if [ $? -ne 0 ]; then
  echo "❌ Failed to clone repository!"
  exit 1
fi

echo "⚙️ Setting permissions and running setup.sh..."
chmod +x "$DIR/setup.sh"

bash "$DIR/setup.sh"

echo "🎉 Installation and setup complete!"
