# 自控钟：规则支持多个应用 实施计划

> **For agentic workers:** 本计划按任务逐个执行；每个任务都包含精确文件、代码与验证命令。

**Goal:** 让“自控钟”的一条规则可以同时选择多个受限应用，并兼容已保存的单应用旧规则。

**Architecture:** 本地规则模型由单个 `appToken` 改为 `appTokens: string[]`；系统应用选择页天然支持多选与预勾选；Screen Time Guard 策略的 `appInfo.appTokens` 本来就是数组，服务层直接透传即可。因系统不允许 token 反查应用名，界面只显示已选数量，真实名单仍由系统选择页展示。

**Tech Stack:** HarmonyOS 6.1/API 23、ArkTS/ArkUI、@kit.ScreenTimeGuardKit、Node 脚本纯逻辑验证。

---

### Task 1: 同步需求规格

**Files:**
- Modify: `docs/superpowers/specs/2026-09-04-self-restriction-rules-design.md`

- [ ] **Step 1: 更新数据模型与界面描述**

把“一条规则 = 一个目标应用”改为“一条规则 = 一个或多个目标应用”，模型字段 `appToken: string` 改为 `appTokens: string[]`，系统策略 `appInfo.appTokens` 直接透传规则数组。

- [ ] **Step 2: 更新验证矩阵**

补充应用 token 数组归一化、旧数据迁移、规则卡片显示“限制 N 个应用”、真机多选与预勾选验收场景。

### Task 2: 模型层迁移

**Files:**
- Modify: `entry/src/main/ets/model/GuardRule.ets`

- [ ] **Step 1: 调整接口并新增兼容函数**

```ts
export interface GuardRule {
  id: string;
  name: string;
  appTokens: string[];
  weekdays: number[];
  startTime: string;
  endTime: string;
  enabled: boolean;
}

export interface StoredGuardRule {
  id: string;
  name: string;
  appTokens?: string[];
  appToken?: string;
  weekdays: number[];
  startTime: string;
  endTime: string;
  enabled: boolean;
}
```

新增函数：`normalizeAppTokens`（去空去重保序）、`sameAppTokenSet`（判断两组 token 是否等价）、`toGuardRule`（旧 `appToken` 转新数组）、`formatAppCount`（生成“限制 N 个应用”文案）。所有新函数使用中文注释说明职责与边界。

- [ ] **Step 2: 更新校验函数**

`validateRule` 改为归一化 `rule.appTokens`，长度为零时返回“请选择要限制的应用”。

### Task 3: 本地存储兼容旧数据

**Files:**
- Modify: `entry/src/main/ets/storage/GuardRuleRepository.ets`

- [ ] **Step 1: 读取时迁移**

```ts
const parsed: StoredGuardRule[] = JSON.parse(text) as StoredGuardRule[];
return parsed.map((stored: StoredGuardRule): GuardRule => toGuardRule(stored));
```

导入 `StoredGuardRule` 与 `toGuardRule`；`loadRules()` 的返回值统一为带 `appTokens` 的新模型。

### Task 4: 服务层多应用透传

**Files:**
- Modify: `entry/src/main/ets/service/ScreenTimeGuardService.ets`

- [ ] **Step 1: 选择接口返回完整数组**

```ts
public async pickTargetApps(previousTokens: string[]): Promise<string[]> {
  const context: common.UIAbilityContext = this.requireContext();
  await this.requestUserAuth();
  const selected: string[] = await appPicker.startAppPicker(context, {
    appTokens: previousTokens.slice()
  });
  return normalizeAppTokens(selected);
}
```

移除“必须恰好 1 个 token”的限制。

- [ ] **Step 2: 策略与解除限制使用数组**

`deactivateRule` 的 `AppInfo` 使用 `rule.appTokens.slice()`；`buildStrategy` 的 `appInfo.appTokens` 使用 `normalizeAppTokens(rule.appTokens)`。

### Task 5: 新增/编辑页支持多选

**Files:**
- Modify: `entry/src/main/ets/pages/RuleEditPage.ets`

- [ ] **Step 1: 状态改为数组并移除固定文案状态**

`appToken: string` 与 `appText: string` 合并为 `appTokens: string[]`。

- [ ] **Step 2: 加载、选择与保存改数组**

编辑加载：`this.appTokens = rule.appTokens.slice();`

选择：`const tokens: string[] = await this.guardService.pickTargetApps(this.appTokens); this.appTokens = tokens;`；为空时提示“尚未选择要限制的应用”。

保存：`candidate.appTokens = this.appTokens.slice()`；应用名单变化判定改用 `sameAppTokenSet`。

- [ ] **Step 3: 展示数量与重新选择入口**

按钮文案：有 token 时“重新选择要限制的应用”，否则“选择要限制的应用”。说明文本：`已选择 N 个应用（打开系统选择页可查看名单）`。

### Task 6: 规则列表显示应用数量

**Files:**
- Modify: `entry/src/main/ets/pages/RuleListPage.ets`

- [ ] **Step 1: 卡片增加数量行**

规则名下方增加 `Text(formatAppCount(rule.appTokens))`。

- [ ] **Step 2: 复制规则同步数组**

`copyRule` 中使用 `appTokens: rule.appTokens.slice()`。

### Task 7: 更新测试与静态门禁

**Files:**
- Modify: `scripts/guard-rule-test.mjs`
- Modify: `scripts/validate-project.mjs`

- [ ] **Step 1: 更新纯逻辑测试**

镜像新增 `normalizeAppTokens`、`sameAppTokenSet`、`toGuardRule`、`formatAppCount`，并补充断言：

```js
assert.deepEqual(normalizeAppTokens(['b', 'a', 'b', '', 'a']), ['b', 'a']);
assert.equal(sameAppTokenSet(['a', 'b'], ['b', 'a']), true);
assert.equal(toGuardRule({ id: 'r1', name: '抖音', appToken: 'old', weekdays: [1], startTime: '19:00', endTime: '21:00', enabled: true }).appTokens.join(','), 'old');
assert.equal(formatAppCount(['a', 'b']), '限制 2 个应用');
```

所有测试对象改用 `appTokens` 字段。

- [ ] **Step 2: 静态门禁增加新锚点**

`validate-project.mjs` 增加：模型含 `normalizeAppTokens`，服务含 `pickTargetApps`，编辑页含 `pickTargetApps`，列表页含 `formatAppCount`。

- [ ] **Step 3: 运行验证**

```bash
node scripts/guard-rule-test.mjs
node scripts/validate-project.mjs
git diff --check
```

### Task 8: 鸿蒙编译验证

**Files:**
- 无新增文件

- [ ] **Step 1: 编译 Debug HAP**

使用仓库本地的 hvigorw 或命令行工具执行 `assembleHap`，确认 ArkTS 编译通过。

### Task 9: 提交

**Files:**
- 上述所有修改与新增文档

- [ ] **Step 1: 中文 Conventional Commit**

```bash
git add docs/superpowers/specs/2026-09-04-self-restriction-rules-design.md docs/superpowers/plans/2026-09-05-timeguard-multi-app-rule-implementation.md entry/src/main/ets/model/GuardRule.ets entry/src/main/ets/storage/GuardRuleRepository.ets entry/src/main/ets/service/ScreenTimeGuardService.ets entry/src/main/ets/pages/RuleEditPage.ets entry/src/main/ets/pages/RuleListPage.ets scripts/guard-rule-test.mjs scripts/validate-project.mjs
git commit -m "feat(timeguard): 规则支持选择多个受限应用"
```
