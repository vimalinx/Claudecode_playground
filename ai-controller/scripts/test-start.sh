#!/bin/bash
# 简化的测试启动脚本

CONTAINER_NAME="claude-sandbox"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SANDBOX_DIR="/home/ai-agent/ai-sandbox"

echo "========================================"
echo "AI Agent Test Start"
echo "========================================"
echo "Container: $CONTAINER_NAME"
echo "Sandbox: $SANDBOX_DIR"
echo ""

# 检查容器是否在运行
if ! lxc info "$CONTAINER_NAME" &> /dev/null; then
    echo "Error: Container '$CONTAINER_NAME' not found"
    exit 1
fi

if ! lxc info "$CONTAINER_NAME" | grep -q "RUNNING"; then
    echo "Starting container..."
    lxc start "$CONTAINER_NAME"
    sleep 5
fi

# 准备系统提示词
SYSTEM_PROMPT_TEMPLATE="$PROJECT_ROOT/ai-controller/config/system_prompt.txt"

if [ ! -f "$SYSTEM_PROMPT_TEMPLATE" ]; then
    echo "Error: System prompt not found"
    exit 1
fi

# 读取提示词
SYSTEM_PROMPT=$(cat "$SYSTEM_PROMPT_TEMPLATE")

# 注入当前信息
CURRENT_DATE=$(date +"%Y-%m-%d")
CURRENT_TIME=$(date +"%H:%M:%S")

# 在容器内启动Claude Code会话
echo "Starting AI session..."
echo "Current time: $CURRENT_DATE $CURRENT_TIME"
echo ""
echo "To stop the AI session, press Ctrl+C"
echo ""

lxc exec "$CONTAINER_NAME" -- su - ai-agent -c "
    cd $SANDBOX_DIR
    echo '[$(date)] Starting AI session' >> logs/session.log
    claude code --permission-mode bypassPermissions --prompt '$SYSTEM_PROMPT'
"
