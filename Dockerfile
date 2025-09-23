# ====== 构建阶段 ======
FROM ubuntu:22.04 AS builder

ARG TARGETARCH=amd64
ARG MOSDNS_COMMIT=""

ENV DEBIAN_FRONTEND=noninteractive
ARG GO_VERSION=1.25.1

# 安装构建依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl build-essential ca-certificates bash \
 && rm -rf /var/lib/apt/lists/*

# 安装官方 Go 1.25.1
RUN curl -sSL https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz | tar -C /usr/local -xzf - \
 && ln -s /usr/local/go/bin/go /usr/bin/go \
 && go version

WORKDIR /build

# 克隆 mosdns-x 源码
RUN git clone https://github.com/pmkol/mosdns-x.git
WORKDIR /build/mosdns-x

# 检出 commit-hash（如果传入）
RUN if [ -n "$MOSDNS_COMMIT" ]; then git checkout $MOSDNS_COMMIT; fi

# 编译 mosdns（静态编译）
RUN GOOS=linux GOARCH=${TARGETARCH} CGO_ENABLED=0 go build -o mosdns ./main.go

# ====== 运行阶段 ======
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# 安装运行所需依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates tzdata git busybox sudo bash \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 克隆 easymosdns 默认配置
RUN git clone --depth 1 https://github.com/pmkol/easymosdns.git /opt/easymosdns \
 && chmod +x /opt/easymosdns/rules/update \
 && chmod +x /opt/easymosdns/rules/update-cdn

# 拷贝 mosdns 可执行文件
COPY --from=builder /build/mosdns-x/mosdns /usr/bin/mosdns

# 拷贝入口脚本
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# 声明配置卷
VOLUME /etc/mosdns

# 暴露 DNS 端口
EXPOSE 53/tcp 53/udp

# 设置入口
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# 默认 CMD
CMD ["/usr/bin/mosdns", "start", "--dir", "/etc/mosdns"]
