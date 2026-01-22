# ====== 构建阶段 ======
FROM --platform=$BUILDPLATFORM ubuntu:22.04 AS builder

# 接收 buildx 自动传入的平台参数
ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH
ARG BUILDPLATFORM
ARG MOSDNS_COMMIT=""
ARG GO_VERSION=1.25.5

ENV DEBIAN_FRONTEND=noninteractive

# 安装构建依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl build-essential ca-certificates bash \
 && rm -rf /var/lib/apt/lists/*

# 根据目标架构下载对应的 Go
RUN case "$(uname -m)" in \
        x86_64) BUILD_ARCH="amd64" ;; \
        aarch64) BUILD_ARCH="arm64" ;; \
        *) echo "Unsupported build architecture" && exit 1 ;; \
    esac && \
    echo "Installing Go ${GO_VERSION} for build platform (${BUILD_ARCH})..." && \
    curl -fsSL "https://golang.org/dl/go${GO_VERSION}.linux-${BUILD_ARCH}.tar.gz" -o /tmp/go.tar.gz && \
    tar -C /usr/local -xzf /tmp/go.tar.gz && \
    rm /tmp/go.tar.gz   

ENV PATH="/usr/local/go/bin:${PATH}"

RUN  go version

WORKDIR /build

# 克隆 mosdns-x 源码
RUN git clone https://github.com/pmkol/mosdns-x.git

WORKDIR /build/mosdns-x

# 检出 commit(如果传入)
RUN if [ -n "$MOSDNS_COMMIT" ]; then git checkout $MOSDNS_COMMIT; fi

# 交叉编译 mosdns
RUN echo "Building for ${TARGETOS}/${TARGETARCH}..." && \
    GOOS=${TARGETOS} GOARCH=${TARGETARCH} CGO_ENABLED=0 go build -o mosdns ./main.go && \
    ls -lh mosdns && \
    echo "Built mosdns for ${TARGETOS}/${TARGETARCH}"


# ====== 运行阶段 ======
FROM --platform=$TARGETPLATFORM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# 安装运行所需依赖（添加 cron 用于定时任务）
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates tzdata git cron curl bash \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 克隆 easymosdns 默认配置并删除 .git 减小镜像体积
RUN git clone --depth 1 https://github.com/pmkol/easymosdns.git /opt/easymosdns \
 && chmod +x /opt/easymosdns/rules/update \
 && chmod +x /opt/easymosdns/rules/update-cdn \
 && rm -rf /opt/easymosdns/.git

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
