## mosdns-x 容器化使用说明

一个开箱即用的 mosdns-x 容器镜像：
- 轻量化预构建镜像，开箱即用
- 内置规则与配置模板（来自 `pmkol/easymosdns`）
- 通过环境变量配置定时任务，自动更新规则
- 日志输出到标准流，便于 `docker logs` 观察

参考上游项目：[pmkol/mosdns-x](https://github.com/pmkol/mosdns-x) 、[pmkol/easymosdns](https://github.com/pmkol/easymosdns) 。

---

## 特性

- 轻量镜像：仅保留运行期依赖，体积小、启动快。
- 内置模板：预置 `easymosdns` 配置至 `/etc/mosdns`，运行即用。
- 可定制更新：`entrypoint.sh` 依据环境变量注册 cron 任务，定时执行规则更新脚本。
- 标准日志：定时任务与服务日志写入容器标准输出，易于采集与排查。
- 可扩展证书信任：支持将额外根证书加入系统信任（镜像已内置时开箱可用）。

---

## 快速开始

```sh
docker run -d \
  --name mosdns-x \
  -p 53:53/udp -p 53:53/tcp \
  -v /your/config/dir:/etc/mosdns \
  -e crontab="0 4 * * *" \
  #-e crontabcnd="0 3 * * *" \
  ghcr.io/787a68/mosdns-x:latest
```

- `crontab`：定时运行 `/etc/mosdns/rules/update`（github直连更新）。
- `crontabcnd`：定时运行 `/etc/mosdns/rules/update-cdn`（CDN 更新）。
- 映射 `/etc/mosdns` 可覆盖或持久化配置与规则。

查看日志：

```sh
docker logs -f mosdns-x
```

---

 

## 运行原理与默认行为

- 入口命令：`CMD ["/usr/bin/mosdns", "start", "--dir", "/etc/mosdns"]`
- 入口脚本：`entrypoint.sh` 会根据 `crontab`、`crontabcnd` 环境变量写入 `/etc/crontabs/root`，并以后台方式启动 `crond`。
- 日志：定时任务输出重定向到 `/proc/1/fd/1`（stdout）与 `/proc/1/fd/2`（stderr），可用 `docker logs` 查看。
- 卷：`VOLUME /etc/mosdns`，建议映射宿主机路径以持久化与自定义配置。

---

## 配置与自定义

- 覆盖配置：将本地目录挂载到 `/etc/mosdns` 即可覆盖默认模板。
- 定时更新：使用标准 cron 表达式设置 `crontab`、`crontabcnd`，例如 `0 4 * * *`。
- 时区：镜像包含 `tzdata`，可通过设置 `TZ` 环境变量（如 `Asia/Shanghai`）影响 cron 与日志时间。

```sh
docker run -d \
  --name mosdns-x \
  -e TZ=Asia/Shanghai \
  -e crontab="0 4 * * *" \
  #-e crontabcnd="0 3 * * *" \
  -p 53:53/udp -p 53:53/tcp \
  -v /your/config/dir:/etc/mosdns \
  ghcr.io/787a68/mosdns-x:latest
```

---

## 常见问题（FAQ）

- 配置从哪里来？
  - 镜像内已预置来自 `pmkol/easymosdns` 的模板到 `/etc/mosdns`。运行时可通过挂载覆盖。
- 规则没更新？
  - 确认已设置 `crontab`/`crontabcnd`，并检查 `/etc/mosdns/rules/update*` 是否存在且可执行。
- 如何排查问题？
  - 先看 `docker logs mosdns-x`；必要时在运行容器内检查 `/etc/crontabs/root`、`/etc/mosdns` 目录结构与权限。

---

## 兼容性与差异

- 与上游 `mosdns-x`：上游提供核心 DNS 引擎；本镜像补充容器化与配置自动化。
- 与 `easymosdns`：本镜像在构建时即集成其模板与脚本，无需手动下载。
- 架构：通过 `TARGETARCH` 构建 `amd64`、`arm64` 等主流平台镜像。

---

## 许可与致谢

- 许可：请参考上游仓库的许可条款。
- 感谢 [pmkol/mosdns-x](https://github.com/pmkol/mosdns-x) 和 [pmkol/easymosdns](https://github.com/pmkol/easymosdns) 的优秀项目。

