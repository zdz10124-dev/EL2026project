# 运动饮食健康平台实施路线

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将已批准的健康平台设计拆分为四个可独立验收的实施阶段。

**Architecture:** 先建立运动记录领域，再建立饮食与运动的综合分析，随后迁移主导航，最后强化 FastAPI 代理与比赛交付。各阶段只依赖前序阶段公开接口，不直接复用 CyberCoach 的 React/Hono 代码。

**Tech Stack:** Flutter 3.44、Dart 3.12、sqflite、SharedPreferences、FastAPI、Pydantic、httpx、SQLite。

## Global Constraints

- 所有工作只能在 `ftcutter` 或由它创建的 `codex/*` 分支执行，禁止直接修改 `main`。
- 当前设备缺少完整测试环境时，记录未执行项，不安装或升级 Flutter、Android SDK、JDK、Python、依赖包或系统工具。
- 不修改或提交无关的 `EXPERIENCE.md` 本地变更。
- 保留现有饮食记录、吃什么、日记、统计、社区推荐与主题能力。
- AI 识别结果必须经用户确认后保存；不得静默回退为伪 AI 固定结果。
- 健康建议只用于生活方式参考，不提供医学诊断、处方或治疗意见。
- 所有新增和重写文本文件使用 UTF-8；修改中文密集旧文件前先验证真实文件编码。

---

## Execution Order

1. [运动记录 MVP](2026-07-18-exercise-recording-mvp.md)
2. [综合健康分析](2026-07-18-integrated-health-analysis.md)
3. [主信息架构迁移](2026-07-18-health-navigation-migration.md)
4. [服务端与比赛交付](2026-07-18-health-backend-and-contest-delivery.md)

每个计划完成后执行其验收命令并单独评审。若本机无法运行命令，只记录原因和待在远程环境执行的准确命令，不自动配置环境。
