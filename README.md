# BBR 一键管理脚本

用于快速启用/关闭 Linux TCP BBR 拥塞控制算法，并提供状态查看与交互菜单。

## 特性

- 🚀 一键安装：像安装普通软件一样安装脚本
- 🔧 智能配置：自动备份原始配置，关闭时可一键恢复
- ✅ 全局命令：安装后随时随地可调用 `bbr`
- 🛡️ 重启不失效：写入 sysctl 配置并重载系统参数

## 安装


只需一行命令下载并安装：

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
sudo bbr uninstall  # 卸载脚本（尝试恢复设置）
```


## 语言

脚本会根据系统语言环境自动选择输出语言：

- 若 `LANG/LC_ALL/LC_MESSAGES` 包含 `zh`，默认显示中文
- 否则默认显示英文

也支持通过环境变量强制指定：

```bash
sudo BBR_LANG=zh bbr status   # 指定中文
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

## 系统要求

- Linux 内核版本 ≥ 4.9
- 需要 root / sudo 权限
- 系统已预装 `curl`、`sysctl`
- 建议安装 `iproute2`（用于 `ss`/`ip`/`tc`，诊断与队列检查会更完整）

## 工作原理（简述）

- 启用时：设置 `net.ipv4.tcp_congestion_control=bbr`，并使用 `net.core.default_qdisc=fq`
- 为保证重启不失效：写入 sysctl 配置文件并执行 sysctl 重载
- 为保证可恢复：启用前会备份旧值，关闭时优先恢复备份
- BBR 配合 `fq` 队列调度以获得更好的 pacing；否则可能回退到 TCP 栈内部 pacing（资源开销更高）

## 常见检查

确认当前拥塞控制算法：

```bash
sysctl net.ipv4.tcp_congestion_control
```

查看系统支持的拥塞控制算法列表：

```bash
sysctl net.ipv4.tcp_available_congestion_control
```
