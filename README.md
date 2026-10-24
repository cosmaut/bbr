# BBR 一键管理脚本 v0.0.2

用于快速启用/关闭 Ubuntu、Debian 系统的 BBR 拥塞控制算法，并提供状态查看与交互菜单。

本项目面向 Linux 服务器环境设计，对中文用户体验做了专门优化：在 `zh` 语言环境下优先输出中文提示、中文菜单和中文错误信息，降低运维使用门槛。

## 特性

- 🚀 一键安装：像安装普通软件一样安装脚本
- 🔧 智能配置：自动备份原始配置，关闭时可一键恢复
- ✅ 全局命令：安装后随时随地可调用 `bbr`
- 🛡️ 重启不失效：写入 sysctl 配置并重载系统参数
- 🔒 完整性校验：安装时自动验证 SHA256，防止供应链攻击
- 🇨🇳 中文优化：自动识别中文系统语言环境，优先显示中文菜单、提示与诊断信息

## 安装

只需一行命令下载并安装（安装时自动验证脚本完整性）：

```bash
curl -fsSL https://raw.githubusercontent.com/cosmaut/bbr/main/install.sh | tr -d '\r' | sudo bash
```

## 使用

安装完成后，直接运行以下命令：

打开交互菜单（推荐）：

```bash
sudo bbr   # 打开交互菜单
```

命令一览：

```bash
sudo bbr enable     # 启用 BBR
sudo bbr disable    # 关闭 BBR（恢复默认/恢复备份）
sudo bbr status     # 查看当前状态
sudo bbr diagnose   # 诊断环境（含队列/缓冲/ss 摘要）
sudo bbr ss         # 查看 TCP 连接状态（ss -tin，可按端口过滤）
sudo bbr version    # 查看当前版本
sudo bbr uninstall  # 卸载脚本（尝试恢复设置）
```


## 语言

脚本会根据系统语言环境自动选择输出语言：

- 若 `LANG/LC_ALL/LC_MESSAGES` 包含 `zh`，默认显示中文
- 否则默认显示英文
- 中文环境下，交互菜单、状态输出、错误提示与诊断信息均优先使用中文文案，更适合中文运维场景
- 英文环境下自动切换为英文输出，便于国际化服务器环境统一使用

也支持通过环境变量强制指定：

```bash
sudo BBR_LANG=zh bbr status   # 指定中文
```

```bash
sudo BBR_LANG=en bbr status   # 指定英文
```

交互菜单也支持在运行时切换语言（仅对当前会话生效）。

## 卸载

卸载前建议先关闭 BBR 并恢复原始设置：

```bash
sudo bbr disable
```

一键卸载（会尝试恢复启用前设置，并移除命令与配置文件）：

```bash
sudo bbr uninstall
```

如需手动卸载，可移除已安装的全局命令与脚本写入的 sysctl 配置文件：

```bash
sudo rm -f /usr/local/bin/bbr
sudo rm -f /etc/sysctl.d/99-bbr-standalone.conf
```

## 支持的系统

- 仅支持 Linux，**不支持 Windows / macOS**
- Linux 内核版本 ≥ 4.9，需要 root / sudo 权限
- 推荐发行版示例：Ubuntu、Debian、CentOS Stream、Rocky Linux、AlmaLinux
- 以上仅为常见/推荐使用示例，不表示官方逐一实机验证支持列表

## 工作原理（简述）

- 启用时：设置 `net.ipv4.tcp_congestion_control=bbr`，并使用 `net.core.default_qdisc=fq`
- 为保证重启不失效：写入 sysctl 配置文件并执行 sysctl 重载
- 为保证可恢复：启用前会备份旧值，关闭时优先恢复备份
- BBR 配合 `fq` 队列调度以获得更好的 pacing；否则可能回退到 TCP 栈内部 pacing（资源开销更高）

### 🔴 v0.0.2 / v0.0.3 修复：mq 多队列网卡（云服务器常见）

**问题**：多队列网卡（`qdisc mq` 根，如甲骨云 / AWS / GCP 的 ARM 实例）的实际队列是
`mq` 根 + 若干 `pfifo_fast` 子队列。v0.0.1 检测到 `mq` 就**直接放弃**设置 fq，
只写 sysctl ⇒ 结果是 **BBR 开着、但实际队列仍是 `pfifo_fast`** ⇒ BBR 拿不到 pacing，
遇丢包照样退化成「砍半」行为；且开机持久化单元走同一分支，**每次重启都跳过**。

**v0.0.3 的正解（已在真机 Oracle ARM 6.8.0-1062 / iproute2-5.15 上实测通过）**：

```bash
# 单队列网卡
tc qdisc replace dev eth0 root fq
# mq 多队列网卡：重建 mq 根 —— 内核会按当前 net.core.default_qdisc 重新创建每个子队列
tc qdisc replace dev enp0s6 root handle 1: mq
```

执行后子队列自动变为 fq：

```
qdisc mq 1: root
qdisc fq 0: parent 1:2 limit 10000p flow_limit 100p buckets 1024 ...
qdisc fq 0: parent 1:1 limit 10000p flow_limit 100p buckets 1024 ...
```

⚠️ **v0.0.2 曾用的「逐个子队列 parent :N」写法在真机上不可用**，实测两种报错：

| 写法 | 真机报错 | 原因 |
|---|---|---|
| `tc qdisc replace dev X parent :1 root fq` | `Error: "root" is duplicate parent ID` | 带 `parent` 时 `root` 被解析成第二个 parent ID |
| `tc qdisc replace dev X parent :1 handle 0: fq`<br>`tc qdisc replace dev X parent 1:1 handle 0: fq`<br>`tc qdisc replace dev X parent 0:1 ...` | `Error: Failed to find qdisc with specified classid.` | **mq 的 classid 在内核里不可寻址**（`tc class show` 能看到 `class mq :1 root`，但按它操作找不到） |

⇒ 所以 mq 网卡**只能重建根队列**，不能逐个子队列替换。
（代价：重建会瞬时重置队列、打断在途包 ⇒ 脚本会先检查子队列是否已是 fq，是则不动。）

### 🔴 v0.0.2 修复：状态判定「假绿」

旧版 `is_bbr_optimized()` 先看 `net.core.default_qdisc` 的值，
而**该值只是 sysctl 里的期望值，对已存在的队列不生效**（设 fq ≠ 实际跑 fq）
⇒ 在「sysctl 说 fq、实际队列是 pfifo_fast」的机器上会**误报「已优化」**。

新版改为**以网卡上真实存在的队列为准**：

- 根队列是 `mq` ⇒ 逐个检查子队列是否全部为 `fq` / `cake` / `fq_codel`
- 根队列是其它类型 ⇒ 直接看根队列
- 仅当探测不到实际网卡队列时，才退化为参考 sysctl

⇒ `bbr status` / `bbr diagnose` 现在会如实报告「未优化」，并给出可执行的修复建议。

## 安全说明

- 安装脚本会从 `shasum.txt` 获取 SHA256 校验和，下载后自动验证 `bbr.sh` 的完整性
- 如校验失败，脚本会中止安装并显示错误信息
- 如需手动校验，可执行：
  ```bash
  curl -fsSL https://raw.githubusercontent.com/cosmaut/bbr/main/bbr.sh | sha256sum
  ```

## 常见检查

确认当前拥塞控制算法：

```bash
sysctl net.ipv4.tcp_congestion_control
```

查看系统支持的拥塞控制算法列表：

```bash
sysctl net.ipv4.tcp_available_congestion_control
```
