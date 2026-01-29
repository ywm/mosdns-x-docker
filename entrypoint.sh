#!/usr/bin/env bash
# 脚本执行期间，任何命令返回非零退出码时立即终止执行
set -e

# --- 变量定义 ---
CONFIG_DIR="/etc/mosdns"
DEFAULT_CONFIG_DIR="/opt/easymosdns"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
LOG_FILE_PATH="$CONFIG_DIR/mosdns.log"

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

# --- 步骤五：日志处理（智能检测） ---
# 检测用户是否在配置文件中启用了日志文件输出
log_to_file=false

if [ -f "$CONFIG_FILE" ]; then
    # 检查配置文件中是否有 log.file 配置且不为空
    # 匹配类似: file: "./mosdns.log" 或 file: /path/to/log
    if grep -qE '^\s*file:\s*["\x27]?\.?/?[a-zA-Z0-9_./-]+["\x27]?\s*$' "$CONFIG_FILE" 2>/dev/null; then
        # 进一步确认是在 log: 块下的 file 配置
        if awk '/^log:/{found=1} found && /^\s*file:/{print; exit}' "$CONFIG_FILE" | grep -qE 'file:\s*["\x27]?.+["\x27]?'; then
            log_to_file=true
            echo "Detected log file configuration in config.yaml"
        fi
    fi
fi

if [ "$log_to_file" = true ]; then
    # 用户配置了日志文件，确保是真实文件而不是符号链接
    echo "Log file output enabled in config. Ensuring real log file exists..."
    if [ -L "$LOG_FILE_PATH" ]; then
        echo "Removing existing symlink at $LOG_FILE_PATH"
        rm -f "$LOG_FILE_PATH"
    fi
    # 创建真实日志文件（如果不存在）
    if [ ! -f "$LOG_FILE_PATH" ]; then
        touch "$LOG_FILE_PATH"
    fi
    echo "Log will be written to: $LOG_FILE_PATH"
else
    # 用户未配置日志文件，使用符号链接重定向到标准输出
    echo "No log file configured. Redirecting log to stdout..."
    rm -f "$LOG_FILE_PATH"
    ln -sf /dev/stdout "$LOG_FILE_PATH"
fi

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
