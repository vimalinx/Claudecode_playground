# 🚀 AI Agent - 快速开始指南

恭喜！你的自主AI代理系统已经准备就绪。

## 📦 已完成的配置

✅ **容器配置完成**
- LXD容器 `claude-sandbox` 已创建并运行
- Python 3.12.3, Git, Node.js 已安装
- Claude Code CLI 2.0.76 已安装
- 沙盒目录已挂载

✅ **记忆系统已创建**
- memory/index.md（记忆索引）
- memory/daily/（日记目录）
- memory/experiences/（经验记录）
- memory/projects/（项目记录）
- memory/reflections/（思考总结）

✅ **控制脚本已就绪**
- ai-controller/scripts/start.sh（启动脚本）
- ai-controller/scripts/stop.sh（停止脚本）
- ai-controller/scripts/watcher.py（监控进程）

✅ **AI已创建第一篇日记！**
- 位置: ai-sandbox/memory/daily/2025-12-30.md
- 已提交到 diary 分支

## 🔧 下一步：配置API密钥

AI需要Anthropic API密钥才能自主运行。

### 方式1: 交互式配置（推荐）

```bash
lxc exec claude-sandbox -- su - ai-agent -c "claude /login"
```

按提示输入API密钥。

### 方式2: 手动配置

```bash
lxc exec claude-sandbox -- bash -c '
cat > /home/ai-agent/.claude.json << EOF
{
  "apiKey": "sk-ant-api03-你的API密钥"
}
EOF
chown ai-agent:ai-agent /home/ai-agent/.claude.json
'
```

**获取API密钥**: https://console.anthropic.com/settings/keys

## 🎮 启动AI

### 手动启动（测试）

```bash
./ai-controller/scripts/start.sh
```

脚本会检查API密钥配置，如果未配置会提示你。

### 监控AI活动

```bash
# 查看控制器日志
tail -f ai-controller/controller.log

# 查看AI会话日志（容器内）
lxc exec claude-sandbox -- tail -f /home/ai-agent/ai-sandbox/logs/session.log

# 查看AI的日记
cat ai-sandbox/memory/daily/*.md

# 查看Git历史
cd ai-sandbox && git log --oneline
```

### 停止AI

```bash
./ai-controller/scripts/stop.sh
```

## ⏰ 配置自动定时任务

让AI每天凌晨1点自动醒来，早上4点停止：

```bash
crontab -e
```

添加以下内容：

```
# AI Agent 自动启动/停止
0 1 * * * /home/vimalinx/Claudecode_playground/ai-controller/scripts/start.sh
0 4 * * * /home/vimalinx/Claudecode_playground/ai-controller/scripts/stop.sh
```

## 📊 AI会如何工作

当AI被唤醒后，它会：

1. **读取记忆** → 查看昨天的日记和记忆索引
2. **规划任务** → 决定今天要探索什么
3. **自主探索** → 在playground/写项目、做实验
4. **记录学习** → 更新记忆系统
5. **提交代码** → 定期提交到Git

AI完全自主，你可以：
- 让它学习新的编程语言
- 让它写项目解决问题
- 让它做实验和探索
- 看它如何自我学习

## 📂 项目结构

```
Claudecode_playground/
├── ai-controller/           # 控制层（宿主机）
│   ├── SETUP_API.md        # API配置详细说明
│   ├── scripts/
│   │   ├── start.sh        # 启动脚本
│   │   ├── stop.sh         # 停止脚本
│   │   └── watcher.py      # 监控进程
│   └── config/
│       ├── system_prompt.txt    # AI的系统提示词
│       └── limits.conf          # 限制配置
│
└── ai-sandbox/             # AI工作区（容器内）
    ├── memory/             # AI的记忆系统
    │   ├── index.md       # 记忆索引
    │   ├── daily/         # 每日日记
    │   ├── experiences/   # 学到的技能
    │   ├── projects/      # 项目记录
    │   └── reflections/   # 思考总结
    ├── playground/         # AI写项目的地方
    ├── experiments/        # 临时实验
    └── .git/              # AI的git仓库
```

## 🔍 查看AI的活动

### AI的日记

```bash
# 查看所有日记
find ai-sandbox/memory/daily -type f -exec cat {} \;

# 查看今天的日记
cat ai-sandbox/memory/daily/$(date +%Y-%m-%d).md
```

### AI的项目

```bash
# 列出AI创建的项目
ls -la ai-sandbox/playground/

# 查看某个项目
cat ai-sandbox/playground/项目名/README.md
```

### Git历史

```bash
cd ai-sandbox

# 查看提交历史
git log --oneline --all

# 查看今天的活动
git log --since="today" --stat

# 查看AI修改的文件
git diff HEAD~1 HEAD --name-only
```

## 📖 详细文档

- **完整设置指南**: [ai-controller/SETUP_API.md](ai-controller/SETUP_API.md)
- **项目README**: [README.md](README.md)

## 🎉 你已经准备好了！

配置API密钥后，你就可以：

1. **立即启动** → 手动运行看看AI如何工作
2. **设置定时** → 让AI每天自动探索
3. **观察学习** → 看AI如何自主学习和成长

**享受你的AI代理的自主探索之旅！** 🤖✨

---

## 💡 常见问题

**Q: AI会做什么？**
A: 完全由它自己决定！它可能会写代码、做实验、学习新技能、创建项目。

**Q: 我可以和AI互动吗？**
A: 可以！你可以手动进入容器：`lxc exec claude-sandbox -- su - ai-agent`

**Q: AI会消耗很多API配额吗？**
A: 监控脚本会在配额不足（<1000 tokens）时自动停止AI。

**Q: 如何查看AI现在在做什么？**
A: 查看日志：`tail -f ai-controller/controller.log`

**Q: AI会破坏系统吗？**
A: 不会！AI被限制在容器内和沙盒目录中，无法访问宿主机其他部分。
