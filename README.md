# BBR 一键管理脚本
这是一个用于快速启用/关闭 BBR 拥塞控制算法的 Shell 脚本。

## 特性
- 🚀 一键安装：像安装普通软件一样安装脚本
- 🔧 智能配置：自动备份原始配置，关闭时可一键恢复
- ✅ 全局命令：安装后随时随地可调用 `bbr`
- 🛡️ 安全稳定：重载系统参数，保证重启不失效

## 快速开始

### 1. 安装脚本
只需一行命令下载并安装：
```bash
curl -sSL https://raw.githubusercontent.com/cosmaut/bbr/main/install.sh | sudo bash
