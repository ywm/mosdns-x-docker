# mosdns-x Docker 镜像

一个自动构建的 mosdns-x 容器镜像，始终跟随上游最新源码：

- 🚀 **自动跟踪构建**：每日自动检测上游更新并从源码编译最新版本
- 📦 **开箱即用**：内置规则与配置模板（来自 `pmkol/easymosdns`）
- ⏰ **定时更新规则**：通过环境变量配置定时任务，自动更新 DNS 规则
- 📊 **便捷日志**：日志输出到标准流，便于 `docker logs` 观察
- 🔧 **动态 Go 版本**：自动匹配上游项目要求的 Go 版本进行编译

参考上游项目：[pmkol/mosdns-x](https://github.com/pmkol/mosdns-x) 、[pmkol/easymosdns](https://github.com/pmkol/easymosdns)

---

## 特性

- **自动化构建**：GitHub Actions 每日自动检测上游 commit，有更新时自动编译推送新镜像
- **源码编译**：直接从 mosdns-x 源码编译，第一时间获得最新功能和修复
- **内置模板**：预置 `easymosdns` 配置至 `/etc/mosdns`，运行即用
- **可定制更新**：`entrypoint.sh` 依据环境变量注册 cron 任务，定时执行规则更新脚本
- **标准日志**：定时任务与服务日志写入容器标准输出，易于采集与排查
- **自动证书更新**：启动时自动更新 CA 证书，确保 HTTPS 连接正常

---

## 快速开始

### 使用 latest 标签（推荐）

```sh
docker run -d \
  --name mosdns-x-docker \
  -p 53:53/udp -p 53:53/tcp \
  -v /your/config/dir:/etc/mosdns \
  -e crontab="0 4 * * *" \
  ghcr.io/ywm/mosdns-x-docker:latest
```

### 使用特定版本标签

每次构建会生成带有上游 commit hash 和日期的标签，例如：

```sh
docker run -d \
  --name mosdns-x-docker \
  -p 53:53/udp -p 53:53/tcp \
  -v /your/config/dir:/etc/mosdns \
  -e crontab="0 4 * * *" \
  ghcr.io/ywm/mosdns-x-docker:a1b2c3d_20260122
```

### 环境变量说明

- `crontab`：定时运行 `/etc/mosdns/rules/update`（GitHub 直连更新）
  - 示例：`"0 4 * * *"` 表示每天凌晨 4 点更新
- `crontabcnd`：定时运行 `/etc/mosdns/rules/update-cdn`（CDN 加速更新）
  - 示例：`"0 3 * * *"` 表示每天凌晨 3 点更新
- `TZ`：设置时区，影响 cron 执行时间和日志时间
  - 示例：`"Asia/Shanghai"`

### 查看日志

```sh
docker logs -f mosdns-x
```

---

## Docker Compose 示例

```yaml
version: '3.8'

services:
  mosdns-x-docker:
    image: ghcr.io/ywm/mosdns-x-docker:latest
    container_name: mosdns-x-docker
    restart: unless-stopped
    ports:
      - "53:53/udp"
      - "53:53/tcp"
    volumes:
      - ./mosdns-config:/etc/mosdns
    environment:
      - crontab=0 4 * * *        # 每天 4 点更新规则
      - TZ=Asia/Shanghai         # 设置时区
```

---

## 运行原理与默认行为

- **入口命令**：`CMD ["/usr/bin/mosdns", "start", "--dir", "/etc/mosdns"]`
- **入口脚本**：`entrypoint.sh` 会：
  1. 自动更新 CA 证书
  2. 检测 `/etc/mosdns` 是否为空，空则复制默认配置
  3. 应用自定义配置（如果存在 `/data/config.yaml`）
  4. 确保更新脚本存在且可执行
  5. 根据 `crontab` 和 `crontabcnd` 环境变量写入 `/etc/crontabs/root`
  6. 启动 `crond` 守护进程
  7. 启动 mosdns 主服务
- **日志**：定时任务输出重定向到 `/proc/1/fd/1`（stdout），可用 `docker logs` 查看
- **卷**：`VOLUME /etc/mosdns`，建议映射宿主机路径以持久化与自定义配置

---

## 配置与自定义

### 基本配置

- **覆盖配置**：将本地目录挂载到 `/etc/mosdns` 即可覆盖默认模板
- **定时更新**：使用标准 cron 表达式设置 `crontab` 或 `crontabcnd`
  - 每天凌晨 4 点：`0 4 * * *`
  - 每 6 小时：`0 */6 * * *`
  - 每周日凌晨 3 点：`0 3 * * 0`
- **时区**：镜像包含 `tzdata`，可通过设置 `TZ` 环境变量影响 cron 与日志时间

### 挂载与数据初始化

- **首次启动初始化**：当您将一个**空目录**挂载到容器的 `/etc/mosdns` 路径时，入口脚本会检测到这是一个"首次运行"场景。它会自动将镜像内预置的所有默认配置文件、规则列表和更新脚本完整地复制到您挂载的目录中。这确保了服务可以"开箱即用"。

- **持久化与自定义**：在首次启动后，您可以直接修改挂载目录中的任何文件（如 `config.yaml` 或规则文件）。后续重启容器时，脚本会检测到目录非空，并**跳过**自动复制，从而安全地保留您的所有自定义修改。

- **自动恢复更新脚本**：如果您不小心删除了 `/etc/mosdns/rules/update` 或 `/etc/mosdns/rules/update-cdn` 脚本，入口脚本会在每次启动时自动检测并恢复这些文件。

- **重要提示**：请始终通过挂载**整个目录**（`-v /your/config/dir:/etc/mosdns`）的方式来管理配置。**不要只挂载单个文件**，这种操作会阻止初始化流程，导致 `mosdns` 因缺少必要的依赖文件而启动失败。

---

## 自动构建说明

本项目使用 GitHub Actions 实现自动化构建：

1. **每日检测**：每天凌晨 3 点自动运行检测任务
2. **版本对比**：
   - 获取上游 `pmkol/mosdns-x` 的最新 commit hash
   - 获取上游 `go.mod` 中要求的 Go 版本
   - 与本地 `version` 文件对比
3. **按需构建**：
   - 如果上游有新 commit，触发构建
   - 使用检测到的 Go 版本进行编译
   - 推送到 GitHub Container Registry
4. **标签命名**：
   - `latest`：始终指向最新构建
   - `<commit-hash>_<date>`：特定版本标签，例如 `a1b2c3d_20260122`
5. **提交信息**：
   - 格式：`<上游提交信息> - <短hash> - Go <版本>`
   - 例如：`feat: add new DNS plugin - a1b2c3d - Go 1.25.5`


---

## 常见问题（FAQ）

### 配置从哪里来？

镜像内已预置来自 `pmkol/easymosdns` 的模板到 `/opt/easymosdns`，首次运行时会自动复制到 `/etc/mosdns`。

### 规则没更新？

1. 确认已设置 `crontab` 或 `crontabcnd` 环境变量
2. 检查 `/etc/mosdns/rules/update*` 是否存在且可执行
3. 查看容器日志：`docker logs mosdns-x-docker`
4. 进入容器检查 crontab：`docker exec mosdns-x-docker cat /etc/crontabs/root`

### 如何手动更新规则？

```sh
# GitHub 直连更新
docker exec mosdns-x-docker /etc/mosdns/rules/update

# CDN 加速更新
docker exec mosdns-x-docker /etc/mosdns/rules/update-cdn
```

### 如何查看当前镜像版本？

```sh
# 查看镜像标签
docker inspect ghcr.io/ywm/mosdns-x-docker:latest | grep -A 5 "Labels"

# 查看 mosdns 版本
docker exec mosdns-x-docker /usr/bin/mosdns version
```

### 如何排查问题？

1. 先查看容器日志：`docker logs -f mosdns-x-docker`
2. 检查配置文件：`docker exec mosdns-x-docker cat /etc/mosdns/config.yaml`
3. 检查 crontab：`docker exec mosdns-x-docker cat /etc/crontabs/root`
4. 检查目录结构：`docker exec mosdns-x-docker ls -la /etc/mosdns`
5. 进入容器调试：`docker exec -it mosdns-x-docker sh`

### 为什么选择源码编译而不是预编译版本？

- ✅ 第一时间获得上游最新功能和修复（不需要等待 release）
- ✅ 自动跟踪上游要求的 Go 版本
- ✅ 可以针对特定 commit 构建
- ✅ 更灵活的构建控制

---

## 与其他项目的差异

### 与上游 `pmkol/mosdns-x` 的关系

- 上游提供核心 DNS 引擎
- 本项目提供容器化封装、自动构建和配置自动化

### 与 `pmkol/easymosdns` 的关系

- 本镜像在构建时即集成其模板与脚本
- 无需手动下载，开箱即用

### 与 `787a68/mosdns-x` 的关系

- Fork 自该项目，感谢原作者的工作
- 主要差异：
  - 使用源码编译而非预编译版本
  - 自动检测并使用上游要求的 Go 版本
  - 每日自动构建，始终保持最新
  - 基于 Ubuntu 而非 Alpine（更好的兼容性）

---

## 许可与致谢

- **许可**：请参考上游仓库的许可条款
- **致谢**：
  - [pmkol/mosdns-x](https://github.com/pmkol/mosdns-x) - 核心 DNS 引擎
  - [pmkol/easymosdns](https://github.com/pmkol/easymosdns) - 优秀的配置模板和规则
  - [787a68/mosdns-x](https://github.com/787a68/mosdns-x-docker) - 原始 Docker 化项目

---

## 贡献

欢迎提交 Issue 和 Pull Request！

如果您发现任何问题或有改进建议，请：

1. 提交 [Issue](https://github.com/ywm/mosdns-x-docker/issues)
2. Fork 本项目并提交 Pull Request
3. 在 [Discussions](https://github.com/ywm/mosdns-x-docker/discussions) 中讨论

---

## Star History

如果这个项目对您有帮助，请给个 ⭐️ Star 支持一下！
