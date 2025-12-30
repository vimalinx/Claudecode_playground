#!/bin/bash
# AI Agent 自动安装脚本
# 此脚本会自动配置LXC容器和所有必要的组件

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
CONTAINER_NAME="ai-agent"
SANDBOX_DIR="$PROJECT_ROOT/ai-sandbox"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}AI Agent - Automated Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 检查是否以root运行
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Error: Please do not run this script as root${NC}"
    echo "Run it as a regular user. The script will use sudo where needed."
    exit 1
fi

# 检查sudo权限
if ! sudo -n true 2>/dev/null; then
    echo -e "${YELLOW}This script requires sudo privileges${NC}"
    echo "Please enter your password when prompted."
    sudo -v || exit 1
fi

# 1. 检查系统依赖
echo -e "${GREEN}[1/8] Checking system dependencies...${NC}"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
    echo "Detected OS: $PRETTY_NAME"
else
    echo -e "${RED}Error: Cannot detect OS${NC}"
    exit 1
fi

if [ "$OS" != "ubuntu" ] && [ "$OS" != "debian" ]; then
    echo -e "${YELLOW}Warning: This script is designed for Ubuntu/Debian${NC}"
    echo "Your system: $OS"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 2. 安装LXC
echo ""
echo -e "${GREEN}[2/8] Installing LXC...${NC}"
if ! command -v lxc &> /dev/null; then
    echo "Installing LXC and dependencies..."
    sudo apt-get update
    sudo apt-get install -y lxc lxc-template uidmap bridge-utils

    # 配置LXC默认网络
    if ! grep -q "lxcbr0" /etc/lxc/default.conf 2>/dev/null; then
        echo "Configuring LXC network..."
        sudo mkdir -p /etc/lxc
        echo "lxc.net.0.type = veth" | sudo tee -a /etc/lxc/default.conf
        echo "lxc.net.0.link = lxcbr0" | sudo tee -a /etc/lxc/default.conf
        echo "lxc.net.0.flags = up" | sudo tee -a /etc/lxc/default.conf
    fi

    # 启动lxc-net服务
    sudo systemctl restart lxc-net || true
else
    echo "LXC is already installed"
fi

# 3. 检查并删除旧容器
echo ""
echo -e "${GREEN}[3/8] Checking for existing container...${NC}"
if lxc info "$CONTAINER_NAME" &> /dev/null; then
    echo -e "${YELLOW}Container '$CONTAINER_NAME' already exists${NC}"
    read -p "Delete and recreate? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Deleting existing container..."
        lxc stop "$CONTAINER_NAME" -f 2>/dev/null || true
        lxc delete "$CONTAINER_NAME"
        echo "Container deleted"
    else
        echo "Keeping existing container"
    fi
fi

# 4. 创建LXC容器
echo ""
echo -e "${GREEN}[4/8] Creating LXC container...${NC}"
if ! lxc info "$CONTAINER_NAME" &> /dev/null; then
    echo "Creating container '$CONTAINER_NAME'..."
    lxc-create -n "$CONTAINER_NAME" -t download -- -d ubuntu -r jammy -a amd64
    echo "Container created"
else
    echo "Container already exists, skipping creation"
fi

# 5. 配置容器
echo ""
echo -e "${GREEN}[5/8] Configuring container...${NC}"

# 启动容器
echo "Starting container..."
lxc-start -n "$CONTAINER_NAME" -d

# 等待容器启动
echo "Waiting for container to start..."
sleep 5

# 检查容器是否在运行
if ! lxc-info -n "$CONTAINER_NAME" | grep -q "RUNNING"; then
    echo -e "${RED}Error: Container failed to start${NC}"
    exit 1
fi

# 设置挂载点
echo "Configuring mount point..."
CONTAINER_CONFIG="/var/lib/lxc/$CONTAINER_NAME/config"
if [ -f "$CONTAINER_CONFIG" ]; then
    # 添加挂载点配置
    if ! grep -q "ai-sandbox" "$CONTAINER_CONFIG"; then
        echo "lxc.mount.entry = $SANDBOX_DIR home/ai-agent/ai-sandbox none bind,create=dir 0 0" | sudo tee -a "$CONTAINER_CONFIG"
    fi
fi

# 6. 在容器内安装软件
echo ""
echo -e "${GREEN}[6/8] Installing software in container...${NC}"

# 更新容器内的软件包
echo "Updating packages in container..."
lxc-attach -n "$CONTAINER_NAME" -- bash -c "
    apt-get update
    apt-get install -y python3 python3-pip git curl wget vim
"

# 安装Claude Code
echo "Installing Claude Code in container..."
lxc-attach -n "$CONTAINER_NAME" -- bash -c "
    # 检查是否已安装
    if ! command -v claude &> /dev/null; then
        # 使用npm或curl安装
        if command -v npm &> /dev/null; then
            npm install -g @anthropic-ai/claude-code
        elif command -v curl &> /dev/null; then
            curl -fsSL https://claude.ai/install.sh | sh
        else
            echo 'Error: Neither npm nor curl is available'
            exit 1
        fi
    else
        echo 'Claude Code is already installed'
    fi
"

# 7. 配置容器环境
echo ""
echo -e "${GREEN}[7/8] Configuring container environment...${NC}"

# 创建ai-agent用户
echo "Setting up ai-agent user..."
lxc-attach -n "$CONTAINER_NAME" -- bash -c "
    # 创建用户（如果不存在）
    if ! id ai-agent &>/dev/null; then
        useradd -m -s /bin/bash ai-agent
        echo 'ai-agent ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
    fi

    # 创建目录结构
    mkdir -p /home/ai-agent/ai-sandbox/{memory/{daily,experiences,projects,reflections},playground,experiments,workspace,logs}

    # 初始化git仓库
    if [ ! -d /home/ai-agent/ai-sandbox/.git ]; then
        cd /home/ai-agent/ai-sandbox
        git init
        git config user.name 'AI Agent'
        git config user.email 'ai-agent@claude-sandbox.local'

        # 创建初始提交
        git add .
        git commit -m 'Initial commit: AI sandbox initialized'
    fi

    # 设置权限
    chown -R ai-agent:ai-agent /home/ai-agent
"

# 8. 验证安装
echo ""
echo -e "${GREEN}[8/8] Verifying installation...${NC}"

# 检查容器状态
if lxc-info -n "$CONTAINER_NAME" | grep -q "RUNNING"; then
    echo -e "${GREEN}✓ Container is running${NC}"
else
    echo -e "${RED}✗ Container is not running${NC}"
    exit 1
fi

# 检查挂载点
if lxc-attach -n "$CONTAINER_NAME" -- test -d /home/ai-agent/ai-sandbox; then
    echo -e "${GREEN}✓ Sandbox directory is mounted${NC}"
else
    echo -e "${RED}✗ Sandbox directory is not mounted${NC}"
    exit 1
fi

# 检查Python
if lxc-attach -n "$CONTAINER_NAME" -- command -v python3 &> /dev/null; then
    echo -e "${GREEN}✓ Python is installed${NC}"
else
    echo -e "${RED}✗ Python is not installed${NC}"
fi

# 检查Git
if lxc-attach -n "$CONTAINER_NAME" -- command -v git &> /dev/null; then
    echo -e "${GREEN}✓ Git is installed${NC}"
else
    echo -e "${RED}✗ Git is not installed${NC}"
fi

# 检查Claude Code
if lxc-attach -n "$CONTAINER_NAME" -- command -v claude &> /dev/null; then
    echo -e "${GREEN}✓ Claude Code is installed${NC}"
else
    echo -e "${YELLOW}⚠ Claude Code may not be installed${NC}"
    echo "Please install it manually inside the container"
fi

# 设置脚本权限
echo ""
echo "Setting script permissions..."
chmod +x "$PROJECT_ROOT/ai-controller/scripts/"*.sh
chmod +x "$PROJECT_ROOT/ai-controller/scripts/"*.py

# 停止容器（准备使用）
echo ""
echo "Stopping container for initial setup..."
lxc-stop -n "$CONTAINER_NAME"

# 完成
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Next steps:"
echo "1. Review the configuration in ai-controller/config/"
echo "2. Make sure Claude Code is installed in the container"
echo "3. Test the setup:"
echo "   - Start: $PROJECT_ROOT/ai-controller/scripts/start.sh"
echo "   - Stop:  $PROJECT_ROOT/ai-controller/scripts/stop.sh"
echo ""
echo "4. Set up cron jobs for automatic start/stop:"
echo "   0 1 * * * $PROJECT_ROOT/ai-controller/scripts/start.sh"
echo "   0 4 * * * $PROJECT_ROOT/ai-controller/scripts/stop.sh"
echo ""
