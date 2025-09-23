#!/bin/sh
set -e

CONFIG_DIR="/etc/mosdns"
DEFAULT_CONFIG_DIR="/opt/easymosdns"

# ====== 自动更新 CA 证书 ======
echo "Updating CA certificates..."
curl -sSL -o /usr/local/share/ca-certificates/cacert.crt https://curl.se/ca/cacert.pem
update-ca-certificates

# ====== 初始化配置 ======
if [ -z "$(ls -A $CONFIG_DIR 2>/dev/null)" ]; then
    echo "$CONFIG_DIR is empty. Populating with default configuration..."
    cp -rT "$DEFAULT_CONFIG_DIR/" "$CONFIG_DIR/"
    echo "Default configuration copied."
fi

mkdir -p "$CONFIG_DIR/rules"

# 确保更新脚本存在
for script in update update-cdn; do
    if [ ! -x "$CONFIG_DIR/rules/$script" ]; then
        echo "NOTICE: '$script' script missing or not executable. Restoring..."
        cp "$DEFAULT_CONFIG_DIR/rules/$script" "$CONFIG_DIR/rules/$script"
        chmod +x "$CONFIG_DIR/rules/$script"
    fi
done

# ====== 配置 cron ======
CRONTAB_FILE="/etc/crontabs/root"
echo "Initializing cron jobs..."
> "$CRONTAB_FILE"

if [ -n "$crontab" ]; then
    echo "$crontab $CONFIG_DIR/rules/update >> /proc/1/fd/1 2>&1" >> "$CRONTAB_FILE"
    echo "  -> Scheduled direct update: '$crontab'"
fi

if [ -n "$crontabcnd" ]; then
    echo "$crontabcnd $CONFIG_DIR/rules/update-cdn >> /proc/1/fd/1 2>&1" >> "$CRONTAB_FILE"
    echo "  -> Scheduled CDN update: '$crontabcnd'"
fi

[ -f "$CRONTAB_FILE" ] && [ -s "$CRONTAB_FILE" ] && crond -b -l 8 || echo "No cron jobs defined."

# ====== 执行 mosdns ======
echo "Starting mosdns service..."
exec "$@"
