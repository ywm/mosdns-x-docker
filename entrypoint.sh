#!/bin/sh
# 脚本执行期间，任何命令返回非零退出码时立即终止执行
set -e

# --- 变量定义 ---
CONFIG_DIR="/etc/mosdns"
DEFAULT_CONFIG_DIR="/opt/easymosdns"

# --- 步骤一：自动更新 CA 证书 ---
echo "Updating CA certificates..."
curl -sSL -o /usr/local/share/ca-certificates/cacert.crt https://curl.se/ca/cacert.pem
update-ca-certificates

# --- 步骤二：初始化配置 ---
# 检查目标配置目录 /etc/mosdns 是否为空
if [ -z "$(ls -A $CONFIG_DIR 2>/dev/null)" ]; then
    echo "$CONFIG_DIR is empty. Populating with default configuration..."
    cp -rT "$DEFAULT_CONFIG_DIR/" "$CONFIG_DIR/"
    echo "Default configuration copied."
fi

# --- 步骤三：应用自定义配置 ---
# 检查 /data/config.yaml 文件是否存在（用于挂载自定义配置）
if [ -f "/data/config.yaml" ]; then
    echo "Applying custom configuration file..."
    cp -fv /data/config.yaml "$CONFIG_DIR/"
fi

# --- 步骤四：确保更新脚本存在 ---
mkdir -p "$CONFIG_DIR/rules"
for script in update update-cdn; do
    if [ ! -x "$CONFIG_DIR/rules/$script" ]; then
        echo "NOTICE: '$script' script missing or not executable. Restoring..."
        cp "$DEFAULT_CONFIG_DIR/rules/$script" "$CONFIG_DIR/rules/$script"
        chmod +x "$CONFIG_DIR/rules/$script"
    fi
done

# --- 步骤五：日志重定向 ---
# 将 MosDNS 的日志文件路径创建一个指向标准输出的符号链接
LOG_FILE_PATH="$CONFIG_DIR/mosdns.log"
echo "Redirecting log to stdout..."
ln -sf /dev/stdout "$LOG_FILE_PATH"

# --- 步骤六：配置定时任务 ---
CRONTAB_FILE="/etc/crontabs/root"
echo "Initializing cron jobs..."
> "$CRONTAB_FILE"  # 清空 crontab 文件

# 添加规则更新定时任务
if [ -n "$crontab" ]; then
    echo "$crontab $CONFIG_DIR/rules/update >> /proc/1/fd/1 2>&1" >> "$CRONTAB_FILE"
    echo "  -> Scheduled direct update: '$crontab'"
fi

# 添加 CDN 规则更新定时任务（不会覆盖上面的任务）
if [ -n "$crontabcnd" ]; then
    echo "$crontabcnd $CONFIG_DIR/rules/update-cdn >> /proc/1/fd/1 2>&1" >> "$CRONTAB_FILE"
    echo "  -> Scheduled CDN update: '$crontabcnd'"
fi

# --- 步骤七：启动 Cron 守护进程 ---
if [ -f "$CRONTAB_FILE" ] && [ -s "$CRONTAB_FILE" ]; then
    echo "Starting cron daemon..."
    crond -b -l 8
else
    echo "No cron jobs defined. Skipping cron."
fi

# --- 步骤八：启动主服务 ---
echo "Starting mosdns service..."
exec "$@"
