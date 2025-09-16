#!/bin/sh
set -e

# 配置智能初始化函数
init_mosdns_config() {
    local config_dir="/etc/mosdns"
    local template_dir="/opt/mosdns-template"
    
    echo "Initializing MosDNS configuration..."
    
    # 检查挂载目录的状态
    if [ "$(ls -A $config_dir 2>/dev/null)" ]; then
        echo "Found existing configuration in $config_dir"
        
        # 检查关键文件是否存在
        if [ ! -f "$config_dir/config.yaml" ]; then
            echo "Warning: config.yaml not found, copying from template..."
            [ -f "$template_dir/config.yaml" ] && cp "$template_dir/config.yaml" "$config_dir/"
        fi
        
        # 检查rules目录
        if [ ! -d "$config_dir/rules" ]; then
            echo "Warning: rules directory not found, copying from template..."
            [ -d "$template_dir/rules" ] && cp -r "$template_dir/rules" "$config_dir/"
        fi
        
        # 检查更新脚本
        if [ ! -f "$config_dir/rules/update" ] && [ -f "$template_dir/rules/update" ]; then
            echo "Copying missing update scripts..."
            cp "$template_dir/rules/update"* "$config_dir/rules/" 2>/dev/null || true
        fi
    else
        echo "Empty configuration directory, initializing with template..."
        # 目录为空，复制所有模板文件
        cp -r "$template_dir"/* "$config_dir/" 2>/dev/null || true
    fi
    
    # 确保更新脚本可执行
    find "$config_dir/rules" -name "update*" -type f -exec chmod +x {} \; 2>/dev/null || true
    
    echo "Configuration initialization completed."
}

# 设置Cron任务（兼容非root用户）
setup_cron_jobs() {
    # 使用当前用户的crontab
    local current_user=$(whoami)
    local cron_dir="/var/spool/cron/crontabs"
    local crontab_file="$cron_dir/$current_user"
    
    echo "Setting up cron jobs for user: $current_user"
    
    # 确保cron目录存在
    mkdir -p "$cron_dir"
    touch "$crontab_file"
    
    # 清空现有内容（避免重复运行时累积）
    > "$crontab_file"
    
    # 添加定时任务
    if [ -n "$crontab" ]; then
        echo "$crontab /etc/mosdns/rules/update >> /proc/1/fd/1 2>> /proc/1/fd/2" >> "$crontab_file"
        echo "  -> Scheduled direct update: '$crontab'"
    fi

    if [ -n "$crontabcnd" ]; then
        echo "$crontabcnd /etc/mosdns/rules/update-cdn >> /proc/1/fd/1 2>> /proc/1/fd/2" >> "$crontab_file"
        echo "  -> Scheduled CDN update: '$crontabcnd'"
    fi

    # 启动cron守护进程
    if [ -s "$crontab_file" ]; then
        echo "Starting cron daemon..."
        # 使用-f前台模式，然后转到后台
        crond -f &
        echo "Cron daemon started with PID: $!"
    else
        echo "No cron jobs defined, skipping cron daemon."
    fi
}

# 权限检查和修复
fix_permissions() {
    local config_dir="/etc/mosdns"
    
    echo "Checking and fixing permissions..."
    
    # 尝试修复权限，如果失败就提示但不中断启动
    if ! chmod -R u+rwX "$config_dir" 2>/dev/null; then
        echo "Warning: Could not set full permissions on $config_dir"
        echo "This might affect configuration updates."
    fi
    
    # 确保更新脚本可执行
    find "$config_dir" -name "update*" -type f -exec chmod +x {} \; 2>/dev/null || {
        echo "Warning: Could not make update scripts executable"
    }
}

# 验证配置文件
validate_config() {
    local config_file="/etc/mosdns/config.yaml"
    
    if [ ! -f "$config_file" ]; then
        echo "Error: Configuration file $config_file not found!"
        echo "Please ensure your mounted directory contains a valid config.yaml file."
        exit 1
    fi
    
    echo "Configuration file found: $config_file"
}

# 主要初始化流程
echo "=== MosDNS Container Initialization ==="
echo "Current user: $(whoami) (UID: $(id -u))"
echo "Mounted volume: /etc/mosdns"

# 执行初始化步骤
init_mosdns_config
fix_permissions
validate_config
setup_cron_jobs

echo "=== Initialization Complete ==="
echo "Starting MosDNS service..."

# 启动主进程
exec "$@"
