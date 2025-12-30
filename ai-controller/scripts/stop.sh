#!/bin/bash
# AI Agent停止脚本
# 在宿主机上运行此脚本以停止AI代理

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONTAINER_NAME="claude-sandbox"
PID_FILE="$PROJECT_ROOT/watcher.pid"

echo "========================================"
echo "AI Agent Controller - Stopping"
echo "========================================"
echo "Time: $(date)"
echo ""

# 停止监控进程
if [ -f "$PID_FILE" ]; then
    WATCHER_PID=$(cat "$PID_FILE")
    if ps -p "$WATCHER_PID" > /dev/null 2>&1; then
        echo "Stopping watcher process (PID: $WATCHER_PID)..."
        kill "$WATCHER_PID"
        sleep 2
        # 强制杀死如果还没停止
        if ps -p "$WATCHER_PID" > /dev/null 2>&1; then
            kill -9 "$WATCHER_PID"
        fi
        echo "Watcher stopped."
    else
        echo "Watcher process not running (PID: $WATCHER_PID)"
    fi
    rm -f "$PID_FILE"
else
    echo "No watcher PID file found"
fi

# 额外检查：杀死所有watcher.py进程
pkill -f "watcher.py" 2>/dev/null && echo "Killed remaining watcher processes" || true

# 停止LXC容器
if lxc info "$CONTAINER_NAME" &> /dev/null; then
    echo "Stopping LXC container: $CONTAINER_NAME"
    lxc stop "$CONTAINER_NAME" -f
    echo "Container stopped."
else
    echo "Container '$CONTAINER_NAME' does not exist"
fi

echo ""
echo "========================================"
echo "AI Agent stopped successfully!"
echo "========================================"
echo ""
