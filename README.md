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

启用 BBR：

```bash
sudo bbr enable
```

查看 BBR 状态：

```bash
sudo bbr status
```

关闭 BBR（恢复默认/恢复备份）：

```bash
sudo bbr disable
```

打开交互菜单：

```bash
sudo bbr menu
```

## 卸载

卸载前建议先关闭 BBR 并恢复原始设置：

```bash
sudo bbr disable
```

移除已安装的全局命令与脚本写入的 sysctl 配置，并重载系统参数：

```bash
sudo rm -f /usr/local/bin/bbr
sudo rm -f /etc/sysctl.d/99-bbr-standalone.conf
```

## 系统要求

- Linux 内核版本 ≥ 4.9
- 需要 root / sudo 权限
- 系统已预装 `curl`、`sysctl`

## 工作原理（简述）

- 启用时：设置 `net.ipv4.tcp_congestion_control=bbr`，并建议使用 `net.core.default_qdisc=fq`
- 为保证重启不失效：写入 sysctl 配置文件并执行 sysctl 重载
- 为保证可恢复：启用前会备份旧值，关闭时优先恢复备份

## 常见检查

确认当前拥塞控制算法：

```bash
sysctl net.ipv4.tcp_congestion_control
```

查看系统支持的拥塞控制算法列表：

```bash
sysctl net.ipv4.tcp_available_congestion_control
```
