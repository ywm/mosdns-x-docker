#!/usr/bin/env bash
# 脚本执行期间，任何命令返回非零退出码时立即终止执行
set -e

# --- 变量定义 ---
CONFIG_DIR="/etc/mosdns"
DEFAULT_CONFIG_DIR="/opt/easymosdns"

# --- 步骤一：自动更新 CA 证书 ---
echo "Updating CA certificates..."
if curl -fsSL -o /usr/local/share/ca-certificates/cacert.crt https://curl.se/ca/cacert.pem; then
    update-ca-certificates
else
    echo "WARNING: Failed to update CA certificates, using existing ones."
fi

# --- 步骤二：初始化配置 ---
# 检查目标配置目录 /etc/mosdns 是否为空
if [ -d "$CONFIG_DIR" ] && [ -z "$(find "$CONFIG_DIR" -mindepth 1 -maxdepth 1 2>/dev/null)" ]; then
    echo "$CONFIG_DIR is empty. Populating with default configuration..."
    cp -r "$DEFAULT_CONFIG_DIR/." "$CONFIG_DIR/"
    echo "Default configuration copied."
fi

# --- 步骤三：应用自定义配置 ---
# 检查 /data/config.yaml 文件是否存在（用于挂载自定义配置）
if [ -f "/data/config.yaml" ]; then
    echo "Applying custom configuration file..."
    cp -fv "/data/config.yaml" "$CONFIG_DIR/"
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
echo "Initializing cron jobs..."

# Ubuntu 使用标准 cron，需要使用 crontab 命令而不是直接写文件
CRON_TEMP="/tmp/crontab.tmp"
> "$CRON_TEMP"  # 创建临时文件

# 添加规则更新定时任务
if [ -n "$crontab" ]; then
    echo "$crontab $CONFIG_DIR/rules/update >> /proc/1/fd/1 2>&1" >> "$CRON_TEMP"
    echo "  -> Scheduled direct update: '$crontab'"
fi

# 添加 CDN 规则更新定时任务（不会覆盖上面的任务）
if [ -n "$crontabcdn" ]; then
    echo "$crontabcdn $CONFIG_DIR/rules/update-cdn >> /proc/1/fd/1 2>&1" >> "$CRON_TEMP"
    echo "  -> Scheduled CDN update: '$crontabcdn'"
fi

# --- 步骤七：启动 Cron 守护进程 ---
if [ -f "$CRON_TEMP" ] && [ -s "$CRON_TEMP" ]; then
    # 安装 crontab
    crontab "$CRON_TEMP"
    rm -f "$CRON_TEMP"

    echo "Starting cron daemon..."
    # Ubuntu 使用 cron 而不是 crond
    service cron start
else
    echo "No cron jobs defined. Skipping cron."
    rm -f "$CRON_TEMP"
fi

# --- 步骤八：启动主服务 ---
echo "Starting mosdns service..."
exec "$@"
