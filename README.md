# 自控钟

HarmonyOS 6 独立应用，包名 `com.cwenhe.timeguard`。

## 能力

- 每个应用一条规则。
- 规则可选择周一至周日的任意组合。
- 规则可选择当天开始/结束时间，保存后立即启用。
- 到点由 Screen Time Guard 禁止指定应用打开，到结束时间自动放行。
- 规则策略启动期间，系统禁止卸载自控钟（需要鸿蒙 6.1.1 及以上授权配置）。

## 导入与构建

1. 使用 DevEco Studio（HarmonyOS 6.1/API 23）打开本目录。
2. 在 `File > Project Structure > Signing` 配置包含 `MANAGE_SCREEN_TIME_GUARD` 的调试 Profile。
3. 真机运行 entry 模块。

本仓库不提交证书、Profile 或构建产物。
