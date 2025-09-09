# mosdns-x 使用说明及功能特色（详细版）

本说明对比分析了本仓库（787a68/mosdns-x）与上游仓库 [pmkol/mosdns-x](https://github.com/pmkol/mosdns-x) 和 [pmkol/easymosdns](https://github.com/pmkol/easymosdns) 的实现方式，详细梳理了本仓库的实际使用方法和特色功能。

---

## 一、整体架构与上游差异

- **本仓库采用多阶段 Docker 构建**，自动拉取上游 mosdns-x 的预编译二进制，极大简化了部署流程。
- **配置文件自动拉取**：构建或启动时自动从 pmkol/easymosdns 仓库克隆配置模板，是本仓库的核心特征之一，无需手动下载规则和配置。
- **入口脚本自动化管理**：通过 entrypoint.sh 动态生成和管理定时任务（cron），提高规则更新的灵活性。
- **与上游 mosdns-x 的区别**：
  - 上游 mosdns-x 仅提供核心 DNS 转发引擎，未集成完整容器部署和自动化配置拉取。
  - 本仓库支持通过环境变量设置自动规则更新时间，并将所有日志输出到容器标准流，方便观察与维护。

---

## 二、详细使用方法

### 镜像构建

```sh
docker build --build-arg VERSION=<版本号> --build-arg TARGETARCH=<架构> -t mosdns-x .
```
- `<版本号>` 对应上游 mosdns-x 的 release tag，如 `v2.7.0`。
- `<架构>` 支持 `amd64`、`arm64` 等主流平台。

### 容器启动与参数

```sh
docker run -d \
  --name mosdns-x \
  -v /your/config/dir:/etc/mosdns \
  -e crontab="0 4 * * *" \
  -e crontabcnd="0 3 * * *" \
  -p 53:53/udp -p 53:53/tcp \
  mosdns-x
```

- `crontab` 环境变量：定时执行 `/etc/mosdns/rules/update`，用于更新国内污染规则。
- `crontabcnd` 环境变量：定时执行 `/etc/mosdns/rules/update-cdn`，用于更新 CDN 相关规则。
- 挂载 `/etc/mosdns` 目录：可自定义规则和配置文件，覆盖默认模板。
- 默认暴露 DNS 端口 53（TCP/UDP）。

### 日志与维护

- 所有定时任务及服务启动日志均输出到标准流，可通过 `docker logs mosdns-x` 查看。
- 推荐定期备份 `/etc/mosdns` 配置目录，便于个性化调整和灾备。

---

## 三、功能特色与对比分析

### 1. 自动化配置拉取与规则更新
- 构建镜像时自动从 [pmkol/easymosdns](https://github.com/pmkol/easymosdns) 拉取最新配置和规则。
- 支持通过 cron 定时自动更新规则，保证 DNS 污染防护实时有效。

### 2. 轻量化镜像与依赖管理
- 多阶段构建，仅保留运行必需依赖，自动卸载构建阶段工具（如 git），镜像体积小、安全性高。
- 入口脚本自动授权，确保更新脚本可执行。

### 3. 日志与可观测性
- 所有更新任务和服务日志均重定向到标准输出，支持主流容器平台日志采集。
- 定时任务失败自动终止（set -e），便于及时发现问题。

### 4. 可定制化
- 支持挂载本地配置目录，完全覆盖默认规则。
- 可灵活配置规则自动更新频率，适应不同运维场景。

### 5. 与上游仓库的差异点
- 上游 mosdns-x 关注于高性能 DNS 转发引擎，本仓库侧重于一站式容器化部署和配置自动化。
- easymosdns 提供规则和脚本，本仓库自动集成，无需用户手动下载和拷贝。

---

## 四、潜在风险与建议

- **配置拉取依赖网络**：首次构建和启动均需访问 GitHub，建议镜像制作后在本地/局域网分发，提高可用性。
- **上游仓库结构变动风险**：若 easymosdns 目录结构或规则脚本发生变化，`mv` 和 `chmod` 操作可能失败。建议在 Dockerfile 中增加容错处理，并关注上游变更日志。
- **健康检查建议**：目前未提供 HEALTHCHECK，建议补充以便容器编排平台自动检测服务状态。
- **国内 DNS 污染规则更新依赖脚本**：请确保 `/etc/mosdns/rules/update` 和 `update-cdn` 脚本存在且可用，否则自动更新功能失效。

---

## 五、常见问题

- 如何自定义规则？
  - 挂载自定义配置目录到 `/etc/mosdns`，覆盖默认模板。
- 如何调整自动更新频率？
  - 修改 `crontab`、`crontabcnd` 环境变量，参考标准 cron 表达式。
- 如何排查服务异常？
  - 通过 `docker logs mosdns-x` 获取实时日志，必要时补充 HEALTHCHECK 实现。

---

如需更详细配置用例或疑难排查，可查阅本仓库及上游 README 或联系维护者。
