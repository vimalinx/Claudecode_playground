#!/bin/bash
# AI Agent启动脚本
# 在宿主机上运行此脚本以启动AI代理

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONTAINER_NAME="claude-sandbox"

echo "========================================"
echo "AI Agent Controller - Starting"
echo "========================================"
echo "Time: $(date)"
echo ""

# 检查LXC是否已安装
if ! command -v lxc &> /dev/null; then
    echo "Error: LXC is not installed. Please run install.sh first."
    exit 1
fi

# 检查容器是否存在
if ! lxc info "$CONTAINER_NAME" &> /dev/null; then
    echo "Error: Container '$CONTAINER_NAME' does not exist."
    echo "Please run install.sh to set up the container."
    exit 1
fi

# 启动容器
echo "Starting LXC container: $CONTAINER_NAME"
lxc start "$CONTAINER_NAME" 2>/dev/null || echo "Container already running"

# 等待容器启动
echo "Waiting for container to be ready..."
sleep 5

# 检查容器网络
echo "Checking container network..."
if ! lxc exec "$CONTAINER_NAME" -- ping -c 1 8.8.8.8 &> /dev/null; then
    echo "Warning: Container may not have network access"
fi

# 检查Claude Code是否在容器内安装
if ! lxc exec "$CONTAINER_NAME" -- command -v claude &> /dev/null; then
    echo "Error: Claude Code is not installed in container."
    echo "Please run install.sh to set up the container."
    lxc stop "$CONTAINER_NAME"
    exit 1
fi

# 检查API密钥是否配置
echo "Checking API key configuration..."
if ! lxc exec "$CONTAINER_NAME" -- su - ai-agent -c "cat /home/ai-agent/.claude.json" | grep -q '"apiKey"'; then
    echo "Warning: API key not configured!"
    echo ""
    echo "To configure API key, run:"
    echo "  lxc exec $CONTAINER_NAME -- su - ai-agent -c 'claude /login'"
    echo ""
    echo "Or see SETUP_API.md for instructions."
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted. Please configure API key first."
        lxc stop "$CONTAINER_NAME" 2>/dev/null || true
        exit 1
    fi
fi

# 准备系统提示词（注入当前时间和配额）
SYSTEM_PROMPT_TEMPLATE="$PROJECT_ROOT/config/system_prompt.txt"
SYSTEM_PROMPT_TEMP="$PROJECT_ROOT/config/system_prompt_runtime.txt"

if [ ! -f "$SYSTEM_PROMPT_TEMPLATE" ]; then
    echo "Error: System prompt template not found: $SYSTEM_PROMPT_TEMPLATE"
    exit 1
fi

# 注入运行时信息
CURRENT_DATE=$(date +"%Y-%m-%d")
CURRENT_TIME=$(date +"%H:%M:%S")
API_QUOTA=$(claude code /glm-plan-usage:usage-query 2>/dev/null | grep -oP '\d+(?= remaining)' || echo "Unknown")

sed -e "s/{DATE}/$CURRENT_DATE/g" \
    -e "s/{TIME}/$CURRENT_TIME/g" \
    -e "s/{QUOTA}/$API_QUOTA/g" \
    "$SYSTEM_PROMPT_TEMPLATE" > "$SYSTEM_PROMPT_TEMP"

# 启动监控进程（会在后台启动AI会话）
echo "Starting watcher process..."
nohup python3 "$SCRIPT_DIR/watcher.py" >> "$PROJECT_ROOT/controller.log" 2>&1 &
WATCHER_PID=$!
echo "Watcher PID: $WATCHER_PID"

# 保存PID用于后续管理
echo "$WATCHER_PID" > "$PROJECT_ROOT/watcher.pid"

echo ""
echo "========================================"
echo "AI Agent started successfully!"
echo "========================================"
echo "Monitor logs with: tail -f $PROJECT_ROOT/controller.log"
echo "Stop with: $SCRIPT_DIR/stop.sh"
echo ""
