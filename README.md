# Claude Code Autonomous AI Agent

一个自主的AI代理项目，运行在LXC容器中，每天自动醒来、学习、探索，并记录自己的活动。

## 项目概述

这个项目创建了一个受控但自主的AI代理环境：
- AI代理在LXC容器隔离环境中运行
- 每天凌晨1点自动启动，早上4点自动停止
- 拥有自己的记忆系统，可以持续学习和积累经验
- 可以自由探索、写项目、做实验
- 所有活动通过git进行版本控制

## 架构设计

```
Claudecode_playground/
├── ai-controller/              # 控制层（AI无权访问）
│   ├── scripts/
│   │   ├── start.sh           # 启动脚本
│   │   ├── stop.sh            # 停止脚本
│   │   └── watcher.py         # 监控进程
│   ├── config/
│   │   ├── system_prompt.txt  # AI的系统提示词
│   │   └── limits.conf        # 限制配置
│   └── controller.log         # 控制器日志
│
└── ai-sandbox/                # AI的沙盒工作区（完全访问）
    ├── memory/                # 记忆系统
    │   ├── index.md          # 记忆索引
    │   ├── daily/            # 每日日记
    │   ├── experiences/      # 学习的经验
    │   ├── projects/         # 项目记录
    │   └── reflections/      # 思考总结
    ├── playground/            # 写项目的区域
    ├── experiments/           # 实验区域
    ├── workspace/             # 临时工作区
    ├── logs/                  # AI的日志
    └── .git/                  # AI的git仓库
```

### 安全隔离

- **控制层**：运行在宿主机，AI完全无法访问
- **AI沙盒**：运行在LXC容器中，只能访问ai-sandbox目录
- **外部监控**：watcher.py在宿主机监控AI的运行状态

## 快速开始

### 1. 安装系统依赖

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y lxc lxc-template uidmap bridge-utils
```

### 2. 运行自动安装脚本

```bash
cd Claudecode_playground
chmod +x install.sh
./install.sh
```

这个脚本会：
- 检查并安装LXC
- 创建ai-agent容器
- 在容器内安装Python、Git、Claude Code
- 配置目录挂载
- 初始化git仓库

### 3. 配置Claude Code

如果自动安装脚本没有成功安装Claude Code，手动在容器内安装：

```bash
# 进入容器
lxc-attach -n ai-agent

# 安装Claude Code
curl -fsSL https://claude.ai/install.sh | sh

# 或者使用npm
npm install -g @anthropic-ai/claude-code
```

### 4. 手动测试

```bash
# 启动AI
./ai-controller/scripts/start.sh

# 查看日志
tail -f ai-controller/controller.log

# 停止AI
./ai-controller/scripts/stop.sh
```

### 5. 配置自动任务

编辑crontab：

```bash
crontab -e
```

添加以下内容：

```
0 1 * * * /home/vimalinx/Claudecode_playground/ai-controller/scripts/start.sh
0 4 * * * /home/vimalinx/Claudecode_playground/ai-controller/scripts/stop.sh
```

## 工作原理

### 启动流程

1. **cron触发**：每天凌晨1点，cron调用start.sh
2. **启动容器**：start.sh启动LXC容器
3. **加载配置**：读取系统提示词和限制配置
4. **启动监控**：启动watcher.py监控进程
5. **唤醒AI**：在容器内启动Claude Code，传入系统提示词

### 监控机制

`watcher.py` 在宿主机上运行，监控：

- **时间限制**：早上4点强制停止
- **API配额**：配额不足时停止（保留1000 tokens）
- **活动状态**：30分钟无活动自动停止
- **容器状态**：容器异常时报警

### AI的自主循环

AI被唤醒后：

1. **读取记忆**：查看memory/index.md和昨天的日记
2. **规划任务**：基于记忆和好奇心决定今天做什么
3. **执行探索**：在playground/中写项目、做实验
4. **记录学习**：更新记忆系统
5. **Git提交**：定期提交活动记录
6. **自我反思**：记录思考和总结

### 记忆系统

AI的记忆系统包括：

- **index.md**：记忆索引，快速查找重要信息
- **daily/**：每日日记，记录每天的活动
- **experiences/**：学到的技能和知识
- **projects/**：项目记录和文档
- **reflections/**：思考和反思

## 配置文件

### limits.conf

定义AI的运行限制：

```bash
# 时间限制
START_HOUR=1
STOP_HOUR=4

# API配额
MIN_API_QUOTA=1000

# 活动监控
MAX_INACTIVITY_MINUTES=30
CHECK_INTERVAL=60
```

### system_prompt.txt

AI的系统提示词，采用中立设计：

- ✅ 提供工具和能力的描述
- ✅ 明确工作空间和限制
- ✅ 鼓励自主性和创造力
- ❌ 不预设具体目标
- ❌ 不引导特定行为
- ❌ 不暗示任务方向

## 分支说明

- **main分支**：核心代码和配置
  - 控制脚本（start.sh, stop.sh, watcher.py）
  - 配置文件（system_prompt.txt, limits.conf）
  - LXC配置
  - 安装脚本
  - README文档

- **diary分支**：AI的活动和日志
  - AI的日记
  - AI写的项目代码
  - AI的实验记录
  - AI的学习笔记
  - Git提交历史

## 安全考虑

### 隔离机制

1. **LXC容器**：进程级隔离
2. **目录限制**：只能访问ai-sandbox目录
3. **无特权容器**：非特权模式运行
4. **外部监控**：监控进程在容器外
5. **资源限制**：CPU、内存限制

### 权限管理

- **控制层**：只有宿主机用户可访问
- **AI沙盒**：AI完全控制，但无法逃离
- **监控进程**：可以强制终止AI

### 数据保护

- 所有AI活动都有git记录
- 控制器日志记录所有监控事件
- 定期备份可以防止数据丢失

## 故障排查

### 容器无法启动

```bash
# 检查LXC服务
sudo systemctl status lxc
sudo systemctl restart lxc

# 检查容器状态
lxc-info -n ai-agent

# 查看容器日志
lxc-log -n ai-agent
```

### Claude Code未安装

```bash
# 进入容器手动安装
lxc-attach -n ai-agent
curl -fsSL https://claude.ai/install.sh | sh
```

### 网络问题

```bash
# 检查桥接网络
ip addr show lxcbr0

# 重启lxc-net
sudo systemctl restart lxc-net

# 在容器内测试网络
lxc-attach -n ai-agent -- ping -c 3 8.8.8.8
```

### 权限问题

```bash
# 修复沙盒目录权限
sudo chown -R 1000000:1000000 ai-sandbox/

# 设置脚本权限
chmod +x ai-controller/scripts/*.sh
chmod +x ai-controller/scripts/*.py
```

## 扩展和定制

### 修改运行时间

编辑`ai-controller/config/limits.conf`：

```bash
START_HOUR=2   # 改为凌晨2点
STOP_HOUR=5    # 改为早上5点
```

### 添加新的监控指标

编辑`ai-controller/scripts/watcher.py`，在主循环中添加新的检查。

### 自定义系统提示词

编辑`ai-controller/config/system_prompt.txt`，保持中立的前提下添加新的能力描述。

### 增加记忆类型

在`ai-sandbox/memory/`下创建新的子目录，并在系统提示词中告诉AI。

## 监控和调试

### 查看实时日志

```bash
# 控制器日志
tail -f ai-controller/controller.log

# AI会话日志
tail -f ai-sandbox/logs/session.log
```

### 查看Git历史

```bash
cd ai-sandbox
git log --oneline --all

# 查看AI今天的活动
git log --since="today" --stat
```

### 进入容器调试

```bash
# 交互式进入容器
lxc-attach -n ai-agent

# 切换到ai-agent用户
su - ai-agent

# 查看工作目录
cd /home/ai-agent/ai-sandbox
ls -la
```

## 贡献和反馈

这是一个实验性的AI自主代理项目。欢迎：
- 报告问题
- 提出改进建议
- 分享你的使用经验
- 贡献代码和想法

## 许可证

MIT License

## 免责声明

本项目仅用于研究和学习目的。AI代理的行为是不可预测的，请确保：
- 在隔离环境中运行
- 监控资源使用
- 定期备份数据
- 理解潜在风险

---

**享受你的AI代理的自主探索之旅！** 🤖
