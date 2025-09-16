# 多阶段构建 - 构建阶段
FROM alpine:latest AS builder

# 设置构建参数
ARG VERSION
ARG TARGETARCH

# 安装构建依赖
RUN apk add --no-cache \
    curl \
    unzip \
    jq

# 下载 mosdns-x 二进制文件
RUN if [ -z "$VERSION" ]; then \
        VERSION=$(curl -s "https://api.github.com/repos/pmkol/mosdns-x/releases/latest" | jq -r .tag_name); \
    fi && \
    echo "Building version: $VERSION for architecture: $TARGETARCH" && \
    case "$TARGETARCH" in \
        amd64) ARCH="amd64" ;; \
        arm64) ARCH="arm64" ;; \
        *) echo "Unsupported architecture: $TARGETARCH" && exit 1 ;; \
    esac && \
    curl -L "https://github.com/pmkol/mosdns-x/releases/download/${VERSION}/mosdns-x-linux-${ARCH}.zip" -o mosdns.zip && \
    unzip mosdns.zip && \
    chmod +x mosdns

# 下载 easymosdns 配置模板
RUN curl -L "https://github.com/pmkol/easymosdns/archive/refs/heads/main.zip" -o easymosdns.zip && \
    unzip easymosdns.zip && \
    mv easymosdns-main /tmp/easymosdns

# 准备配置文件结构
RUN mkdir -p /etc/mosdns && \
    cp -r /tmp/easymosdns/* /etc/mosdns/ && \
    # 确保更新脚本可执行
    find /etc/mosdns -name "update*" -type f -exec chmod +x {} \; 2>/dev/null || true

# 运行时阶段
FROM alpine:latest

# 安装运行时依赖
RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    dcron \
    bash \
    curl \
    && rm -rf /var/cache/apk/*

# 创建非root用户和组
RUN addgroup -g 1000 mosdns && \
    adduser -D -u 1000 -G mosdns -s /bin/bash mosdns

# 从构建阶段复制二进制文件
COPY --from=builder /mosdns /usr/bin/mosdns

# 将默认配置模板保存到单独位置，避免被挂载覆盖
COPY --from=builder /etc/mosdns /opt/mosdns-template

# 创建必要的目录结构
RUN mkdir -p /etc/mosdns \
    /var/spool/cron/crontabs \
    /var/log/cron \
    && chown -R mosdns:mosdns \
        /etc/mosdns \
        /var/spool/cron \
        /var/log/cron \
        /opt/mosdns-template

# 复制入口脚本
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh && \
    chown mosdns:mosdns /usr/local/bin/entrypoint.sh

# 切换到非root用户
USER mosdns

# 设置工作目录
WORKDIR /etc/mosdns

# 暴露DNS端口
EXPOSE 53/udp 53/tcp

# 设置卷
VOLUME ["/etc/mosdns"]

# 设置入口点和默认命令
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/mosdns", "start", "--dir", "/etc/mosdns"]
