# ===========================
# 构建参数
# ===========================
ARG TARGETARCH
ARG MOSDNS_COMMIT

# ===========================
# 构建阶段：从源码编译 mosdns
# ===========================
FROM golang:1.21-alpine AS builder
ARG TARGETARCH
ARG MOSDNS_COMMIT

# 安装编译依赖
RUN apk add --no-cache git bash build-base curl

WORKDIR /build

# 克隆 mosdns-x 源码
RUN git clone https://github.com/pmkol/mosdns-x.git
WORKDIR /build/mosdns-x

# checkout commit hash（可指定 version 文件）
RUN if [ -n "$MOSDNS_COMMIT" ]; then git checkout $MOSDNS_COMMIT; fi

# 编译 mosdns 二进制
RUN GOOS=linux GOARCH=${TARGETARCH} CGO_ENABLED=0 go build -o mosdns ./cmd/mosdns

# ===========================
# 最终镜像阶段
# ===========================
FROM alpine:latest

ARG TARGETARCH

# 安装运行依赖
RUN apk add --no-cache tzdata busybox-suid curl git

# 下载最新通用 CA 证书并更新系统 CA
RUN curl -o /usr/local/share/ca-certificates/cacert.crt https://curl.se/ca/cacert.pem && \
    update-ca-certificates

# 从构建阶段复制 mosdns 到 /usr/local/bin
COPY --from=builder /build/mosdns-x/mosdns /usr/local/bin/mosdns
RUN chmod +x /usr/local/bin/mosdns

# 复制入口脚本
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# 克隆 easymosdns 默认配置
RUN git clone --depth 1 https://github.com/pmkol/easymosdns.git /opt/easymosdns && \
    chmod +x /opt/easymosdns/rules/update /opt/easymosdns/rules/update-cdn && \
    apk del git

# 声明配置卷
VOLUME /etc/mosdns

# 暴露 DNS 服务端口（容器内部固定为 53）
# 宿主机可通过 -p <host_port>:53 映射到任意端口，例如 -p 1953:53
EXPOSE 53/tcp
EXPOSE 53/udp

# 设置入口和默认命令
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/local/bin/mosdns", "start", "--dir", "/etc/mosdns"]

