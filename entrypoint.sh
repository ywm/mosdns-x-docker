#!/bin/sh
# 任何命令失败时立即退出
set -e

CRONTAB_FILE="/etc/crontabs/root"

# 动态生成 crontab 配置文件
# 将日志输出重定向到容器的标准输出流，方便通过 docker logs 查看
echo "Initializing cron jobs..."
if [ -n "$crontab" ]; then
    echo "$crontab /etc/mosdns/rules/update >> /proc/1/fd/1 2>> /proc/1/fd/2" >> "$CRONTAB_FILE"
    echo "  -> Scheduled direct update: '$crontab'"
fi

if [ -n "$crontabcnd" ]; then
    echo "$crontabcnd /etc/mosdns/rules/update-cdn >> /proc/1/fd/1 2>> /proc/1/fd/2" >> "$CRONTAB_FILE"
    echo "  -> Scheduled CDN update: '$crontabcnd'"
fi

# 如果定义了任何 cron 任务，则启动 cron 守护进程
if [ -f "$CRONTAB_FILE" ] && [ -s "$CRONTAB_FILE" ]; then
    echo "Starting cron daemon..."
    crond -b -l 8
else
    echo "No cron jobs defined."
fi

echo "Starting mosdns service..."
# 执行 CMD 传入的命令，即启动 mosdns
exec "$@"
