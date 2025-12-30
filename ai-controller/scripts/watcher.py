#!/usr/bin/env python3
"""
AI Agent Watcher - 外部监控进程
运行在宿主机上，监控和控制AI代理的运行
"""

import subprocess
import time
import os
import sys
import json
import re
from datetime import datetime, timedelta
from pathlib import Path

# 配置
CONTAINER_NAME = "ai-agent"
SANDBOX_DIR = "/home/ai-agent/ai-sandbox"
STOP_HOUR = 4  # 早上4点停止
MIN_API_QUOTA = 1000  # 最低API配额保留
CHECK_INTERVAL = 60  # 检查间隔（秒）

# 日志配置
log_file = Path(__file__).parent.parent / "controller.log"


def log(message, level="INFO"):
    """记录日志"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_msg = f"[{timestamp}] [{level}] {message}"
    print(log_msg)
    with open(log_file, "a") as f:
        f.write(log_msg + "\n")


def run_command(cmd, check=True, capture_output=True):
    """运行命令并返回结果"""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            check=check,
            capture_output=capture_output,
            text=True
        )
        return result
    except subprocess.CalledProcessError as e:
        log(f"Command failed: {cmd}", "ERROR")
        log(f"Error: {e.stderr}", "ERROR")
        return None


def check_api_quota():
    """检查Claude API配额"""
    log("Checking API quota...")
    result = run_command("claude code /glm-plan-usage:usage-query")

    if result and result.stdout:
        # 解析配额信息（根据实际输出格式调整）
        # 假设输出包含 "remaining: 123456" 之类的信息
        match = re.search(r'(\d+).*remaining', result.stdout, re.IGNORECASE)
        if match:
            quota = int(match.group(1))
            log(f"Current API quota: {quota}")
            return quota
        else:
            log("Could not parse API quota from output", "WARN")
            log(f"Output: {result.stdout[:200]}", "DEBUG")
            return None
    else:
        log("Failed to check API quota", "ERROR")
        return None


def check_time_limit():
    """检查是否到达停止时间"""
    now = datetime.now()
    current_hour = now.hour

    # 凌晨1点开始，早上4点停止
    if current_hour >= STOP_HOUR and current_hour < 12:
        log(f"Time limit reached (current hour: {current_hour})")
        return True

    return False


def check_container_running():
    """检查容器是否在运行"""
    result = run_command(f"lxc info {CONTAINER_NAME}")
    if result and "Status: RUNNING" in result.stdout:
        return True
    return False


def check_ai_session_active():
    """检查AI会话是否活跃"""
    # 检查容器内是否有claude进程在运行
    result = run_command(
        f"lxc exec {CONTAINER_NAME} -- ps aux | grep -i claude | grep -v grep",
        check=False
    )
    return result and result.returncode == 0


def get_last_git_activity():
    """获取最后一次git活动时间"""
    result = run_command(
        f"lxc exec {CONTAINER_NAME} -- "
        f"bash -c 'cd {SANDBOX_DIR} && git log -1 --format=%ct 2>/dev/null'"
    )

    if result and result.stdout.strip():
        try:
            timestamp = int(result.stdout.strip())
            last_activity = datetime.fromtimestamp(timestamp)
            return last_activity
        except ValueError:
            return None

    return None


def start_ai_session():
    """在容器中启动AI会话"""
    log("Starting AI session in container...")

    # 读取运行时提示词
    project_root = Path(__file__).parent.parent
    prompt_file = project_root / "config" / "system_prompt_runtime.txt"

    if not prompt_file.exists():
        log(f"System prompt not found: {prompt_file}", "ERROR")
        return False

    with open(prompt_file) as f:
        system_prompt = f.read()

    # 在容器中启动Claude Code
    # 使用非交互模式，让AI自主运行
    cmd = f"""
    lxc exec {CONTAINER_NAME} -- bash -c '
        cd {SANDBOX_DIR}
        echo "Starting autonomous AI session at $(date)" >> logs/session.log
        claude code --prompt "{system_prompt}" >> logs/session.log 2>&1
    '
    """

    # 在后台启动
    process = subprocess.Popen(
        cmd,
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )

    log(f"AI session started with PID: {process.pid}")
    return True


def stop_container():
    """停止容器"""
    log("Stopping container...")
    run_command(f"lxc stop {CONTAINER_NAME} -f")
    log("Container stopped")


def save_session_summary(reason):
    """保存会话总结"""
    summary = {
        "end_time": datetime.now().isoformat(),
        "reason": reason,
        "last_git_activity": str(get_last_git_activity()) if get_last_git_activity() else "Unknown"
    }

    project_root = Path(__file__).parent.parent
    summary_file = project_root / "last_session_summary.json"

    with open(summary_file, "w") as f:
        json.dump(summary, f, indent=2)

    log(f"Session summary saved to: {summary_file}")


def main():
    """主监控循环"""
    log("=" * 50)
    log("AI Agent Watcher Started")
    log("=" * 50)

    # 等待一段时间让AI启动
    time.sleep(10)

    session_active = False
    inactivity_count = 0
    MAX_INACTIVITY = 30  # 30分钟无活动后停止

    try:
        while True:
            # 1. 检查容器状态
            if not check_container_running():
                log("Container is not running. Exiting...")
                save_session_summary("container_stopped")
                break

            # 2. 检查时间限制
            if check_time_limit():
                log("Time limit reached. Stopping...")
                stop_container()
                save_session_summary("time_limit")
                break

            # 3. 检查API配额
            quota = check_api_quota()
            if quota is not None and quota < MIN_API_QUOTA:
                log(f"API quota too low: {quota}. Stopping...")
                stop_container()
                save_session_summary("api_quota_exhausted")
                break

            # 4. 检查AI会话是否活跃
            if not check_ai_session_active():
                if not session_active:
                    # 第一次运行，启动AI
                    log("AI session not active. Starting...")
                    if start_ai_session():
                        session_active = True
                else:
                    # AI会话已结束
                    log("AI session has ended. Checking inactivity...")
                    inactivity_count += 1

                    if inactivity_count >= MAX_INACTIVITY:
                        log(f"No activity for {MAX_INACTIVITY} minutes. Stopping...")
                        stop_container()
                        save_session_summary("inactivity")
                        break
            else:
                # AI会话活跃，重置不活跃计数
                inactivity_count = 0
                session_active = True

                # 每10分钟记录一次活动
                if inactivity_count % 10 == 0:
                    last_git = get_last_git_activity()
                    if last_git:
                        time_since = datetime.now() - last_git
                        log(f"Last git activity: {time_since} ago")

            # 等待下一次检查
            time.sleep(CHECK_INTERVAL)

    except KeyboardInterrupt:
        log("\nReceived interrupt signal. Stopping...")
        stop_container()
        save_session_summary("manual_interrupt")

    except Exception as e:
        log(f"Unexpected error: {e}", "ERROR")
        import traceback
        log(traceback.format_exc(), "ERROR")
        stop_container()
        save_session_summary("error")

    log("Watcher process terminated")


if __name__ == "__main__":
    main()
