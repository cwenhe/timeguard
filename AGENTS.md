# TimeGuard 协作规则

## 项目边界

- 本仓库是 HarmonyOS 6.1.1/API 24 的 ArkTS + ArkUI Stage 工程，包名 `com.cwenhe.timeguard`，桌面显示名“自控钟”。
- 与 `timefence-harmony`、`timefence-android` 相互独立。
- 第一版只使用 Screen Time Guard Kit 原生“周几 + 当天起止时间”能力，不实现交易日历、跨天时段和悬浮窗。

## 默认分支和验证

- 默认开发分支为 `develop`。
- 修改 `.ets`、`.json5` 或文档后运行：
  - `node scripts/guard-rule-test.mjs`
  - `node scripts/validate-project.mjs`
  - `git diff --check`
- 有 DevEco Studio 时额外运行 `./hvigorw assembleHap --mode module -p module=entry`，并在 API 23 真机验收限制行为。

## 代码约定

- 新增函数必须有中文职责注释，说明关键副作用或边界。
- Screen Time Guard 系统调用统一在 `service/ScreenTimeGuardService.ets`，页面不得直接散落调用。
- 任何权限、用户取消、策略冲突或设备不支持错误都要转成用户可理解的中文状态，不得静默吞错。
- 不提交证书、profile、`build/`、`oh_modules/`、日志或真机快照。

## 文档和提交

- 文档、注释和提交说明使用简体中文；提交遵循 Conventional Commits，例如 `feat(timeguard): 支持每周时段应用限制`。
- 需求级验收场景同步维护在设计规格 `docs/superpowers/specs/2026-09-04-self-restriction-rules-design.md`。
