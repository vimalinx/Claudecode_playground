# AI Agent Setup Guide

## Quick Start

### 1. 配置API密钥

AI代理需要Anthropic API密钥才能运行。

#### 方式A: 在容器内配置（推荐）

```bash
# 进入容器
lxc exec claude-sandbox -- su - ai-agent

# 运行登录命令
claude /login

# 按提示输入API密钥
```

#### 方式B: 手动配置API密钥

```bash
# 在容器内创建配置
lxc exec claude-sandbox -- bash -c '
cat > /home/ai-agent/.claude.json << EOF
{
  "apiKey": "your-api-key-here"
}
EOF
chown ai-agent:ai-agent /home/ai-agent/.claude.json
'
```

获取API密钥：https://console.anthropic.com/settings/keys

### 2. 启动AI代理

#### 手动启动（测试）

```bash
./ai-controller/scripts/start.sh
```

#### 查看日志

```bash
# 控制器日志
tail -f ai-controller/controller.log

# AI会话日志
lxc exec claude-sandbox -- tail -f /home/ai-agent/ai-sandbox/logs/session.log
```

#### 停止AI

```bash
./ai-controller/scripts/stop.sh
```

### 3. 配置自动定时任务

编辑crontab：

```bash
crontab -e
```

添加以下内容：

```bash
# AI Agent 自动启动/停止
0 1 * * * /home/vimalinx/Claudecode_playground/ai-controller/scripts/start.sh
0 4 * * * /home/vimalinx/Claudecode_playground/ai-controller/scripts/stop.sh
```

### 4. 监控AI活动

```bash
# 查看AI的日记
cat ai-sandbox/memory/daily/*.md

# 查看记忆索引
cat ai-sandbox/memory/index.md

# 查看git历史
cd ai-sandbox && git log --oneline

# 查看AI创建的项目
ls -la ai-sandbox/playground/
```

## 工作原理

### 启动流程

1. **cron触发** → 凌晨1点
2. **start.sh执行** → 启动容器
3. **watcher.py运行** → 监控进程
4. **唤醒AI** → 传入系统提示词
5. **AI自主活动** → 探索、学习、创建

### 监控机制

- **时间限制**: 早上4点自动停止
- **API配额**: 配额不足时停止
- **活动检测**: 30分钟无活动停止
- **容器状态**: 异常时报警

### AI的日常

AI被唤醒后会：

1. 读取记忆索引 (`memory/index.md`)
2. 阅读昨天的日记 (`memory/daily/`)
3. 决定今天要探索什么
4. 在`playground/`创建项目
5. 在`experiments/`做实验
6. 更新记忆系统
7. 提交到git

## 故障排查

### API密钥问题

```bash
# 检查API密钥配置
lxc exec claude-sandbox -- cat /home/ai-agent/.claude.json

# 重新登录
lxc exec claude-sandbox -- su - ai-agent -c "claude /login"
```

### 容器未运行

```bash
# 检查容器状态
lxc list

# 启动容器
lxc start claude-sandbox
```

### 权限问题

```bash
# 修复sandbox权限
chmod -R 777 ai-sandbox/

# 修复容器内权限
lxc exec claude-sandbox -- chown -R ai-agent:ai-agent /home/ai-agent
```

### 查看AI做了什么

```bash
# Git提交历史
cd ai-sandbox
git log --stat

# 今天的修改
git diff --stat HEAD~1 HEAD

# AI的日记
find memory/daily -type f -exec cat {} \;
```

## 高级配置

### 修改运行时间

编辑 `ai-controller/config/limits.conf`:

```bash
START_HOUR=2   # 改为凌晨2点启动
STOP_HOUR=5    # 改为早上5点停止
```

### 调整API配额限制

```bash
MIN_API_QUOTA=5000  # 保留5000 tokens
```

### 自定义系统提示词

编辑 `ai-controller/config/system_prompt.txt`

### 添加新的监控

编辑 `ai-controller/scripts/watcher.py`

## 安全建议

1. **API密钥保护**
   - 不要在公开仓库中提交API密钥
   - 定期轮换API密钥
   - 设置使用限额

2. **资源限制**
   - 监控容器资源使用
   - 设置CPU/内存限制
   - 定期检查日志

3. **数据备份**
   - 定期备份ai-sandbox目录
   - 保留git历史
   - 备份重要的日记

## 享受你的AI代理的自主探索之旅！🤖
