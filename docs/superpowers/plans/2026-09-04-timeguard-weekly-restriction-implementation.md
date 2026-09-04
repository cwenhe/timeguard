# 自控钟：每周时段应用限制 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在独立鸿蒙工程 `com.cwenhe.timeguard` 中实现“每个 App 一条规则：选择周几与当天起止时间，由 Screen Time Guard 到点禁止/放行”的最小可用版本。

**Architecture:** ArkTS Stage 工程；规则模型与本地存储分离，Screen Time Guard 调用集中在一个 Service；页面只负责展示和调用。系统策略为 BLOCKLIST + START_END_TIME_TYPE + repeat(周几)。

**Tech Stack:** HarmonyOS 6.1/API 23、ArkTS/ArkUI、@kit.ScreenTimeGuardKit、@kit.ArkData preferences、Node 脚本做纯逻辑验证。

---

### Task 1: 初始化工程骨架

**Files:**
- Create: `.gitignore`
- Create: `AGENTS.md`
- Create: `AppScope/app.json5`
- Create: `AppScope/resources/base/element/string.json`
- Create: `AppScope/resources/base/media/app_icon.svg`
- Create: `build-profile.json5`
- Create: `hvigorfile.ts`
- Create: `hvigor/hvigor-config.json5`
- Create: `oh-package.json5`
- Create: `entry/build-profile.json5`
- Create: `entry/hvigorfile.ts`
- Create: `entry/oh-package.json5`
- Create: `entry/src/main/module.json5`
- Create: `entry/src/main/resources/base/element/color.json`
- Create: `entry/src/main/resources/base/element/string.json`
- Create: `entry/src/main/resources/base/profile/main_pages.json`

- [ ] **Step 1: 写入根目录工程文件**

`.gitignore`:

```gitignore
# DevEco/HarmonyOS 构建产物
build/
entry/build/
oh_modules/
entry/oh_modules/
.hvigor/
.idea/
*.iml

# 本地签名和敏感配置
*.p12
*.p7b
*.cer
*.keystore
local.properties

# 日志、临时文件和测试输出
*.log
*.hprof
coverage/
tmp/
.DS_Store

# 文档站生成物和本地索引
public/
.codegraph/
```

`AGENTS.md`:

```markdown
# TimeGuard 协作规则

## 项目边界

- 本仓库是 HarmonyOS 6.1/API 23 的 ArkTS + ArkUI Stage 工程，包名 `com.cwenhe.timeguard`，桌面显示名“自控钟”。
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
```

`AppScope/app.json5`:

```json5
{
  "app": {
    "bundleName": "com.cwenhe.timeguard",
    "vendor": "cwenhe",
    "versionCode": 1000000,
    "versionName": "1.0.0",
    "icon": "$media:app_icon",
    "label": "$string:app_name"
  }
}
```

`AppScope/resources/base/element/string.json`:

```json
{
  "string": [
    {
      "name": "app_name",
      "value": "自控钟"
    }
  ]
}
```

`AppScope/resources/base/media/app_icon.svg`:

```svg
<svg width="96" height="96" viewBox="0 0 96 96" xmlns="http://www.w3.org/2000/svg">
  <rect width="96" height="96" rx="24" fill="#1D4ED8"/>
  <circle cx="48" cy="48" r="28" fill="none" stroke="#FFFFFF" stroke-width="6"/>
  <path d="M48 31v19l13 8" fill="none" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
```

`build-profile.json5`:

```json5
{
  "app": {
    "signingConfigs": [],
    "products": [
      {
        "name": "default",
        "compatibleSdkVersion": "6.1.0(23)",
        "runtimeOS": "HarmonyOS",
        "targetSdkVersion": "6.1.0(23)"
      }
    ],
    "buildModeSet": [
      {
        "name": "debug"
      },
      {
        "name": "release"
      }
    ]
  },
  "modules": [
    {
      "name": "entry",
      "srcPath": "./entry",
      "targets": [
        {
          "name": "default"
        }
      ]
    }
  ]
}
```

`hvigorfile.ts`:

```ts
import { appTasks } from '@ohos/hvigor-ohos-plugin';

export default {
  system: appTasks,
  plugins: []
};
```

`hvigor/hvigor-config.json5`:

```json5
{
  "modelVersion": "5.0.0",
  "dependencies": {}
}
```

`oh-package.json5`:

```json5
{
  "modelVersion": "5.0.0",
  "description": "HarmonyOS 6 自控钟应用限制",
  "dependencies": {},
  "devDependencies": {
    "@ohos/hypium": "1.0.19",
    "@ohos/hamock": "1.0.0"
  }
}
```

- [ ] **Step 2: 写入 entry 模块文件**

`entry/build-profile.json5`:

```json5
{
  "apiType": "stageMode",
  "buildOption": {},
  "targets": [
    {
      "name": "default"
    }
  ]
}
```

`entry/hvigorfile.ts`:

```ts
import { hapTasks } from '@ohos/hvigor-ohos-plugin';

export default {
  system: hapTasks,
  plugins: []
};
```

`entry/oh-package.json5`:

```json5
{
  "name": "entry",
  "version": "1.0.0",
  "description": "自控钟入口模块",
  "main": "",
  "license": "Apache-2.0",
  "dependencies": {}
}
```

`entry/src/main/module.json5`:

```json5
{
  "module": {
    "name": "entry",
    "type": "entry",
    "description": "$string:module_desc",
    "mainElement": "EntryAbility",
    "deviceTypes": [
      "phone",
      "tablet"
    ],
    "deliveryWithInstall": true,
    "installationFree": false,
    "pages": "$profile:main_pages",
    "requestPermissions": [
      {
        "name": "ohos.permission.MANAGE_SCREEN_TIME_GUARD"
      }
    ],
    "abilities": [
      {
        "name": "EntryAbility",
        "srcEntry": "./ets/entryability/EntryAbility.ets",
        "description": "$string:entryability_desc",
        "icon": "$media:app_icon",
        "label": "$string:app_name",
        "startWindowIcon": "$media:app_icon",
        "startWindowBackground": "$color:start_window_background",
        "exported": true,
        "skills": [
          {
            "entities": [
              "entity.system.home"
            ],
            "actions": [
              "action.system.home"
            ]
          }
        ]
      }
    ]
  }
}
```

`entry/src/main/resources/base/element/string.json`:

```json
{
  "string": [
    {
      "name": "module_desc",
      "value": "每周指定时段禁止指定应用打开"
    },
    {
      "name": "entryability_desc",
      "value": "管理每周时段应用限制"
    },
    {
      "name": "app_name",
      "value": "自控钟"
    }
  ]
}
```

`entry/src/main/resources/base/element/color.json`:

```json
{
  "color": [
    {
      "name": "start_window_background",
      "value": "#F5F7FB"
    }
  ]
}
```

`entry/src/main/resources/base/profile/main_pages.json`:

```json
{
  "src": [
    "pages/RuleListPage",
    "pages/RuleEditPage"
  ]
}
```

- [ ] **Step 3: 校验并提交**

Run:

```bash
git diff --check
git add -A
git commit -m 'chore(timeguard): 初始化自控钟鸿蒙工程骨架'
```

Expected: 空白检查通过，提交成功，工作树干净。

---

### Task 2: 规则纯逻辑与本地脚本测试

**Files:**
- Create: `entry/src/main/ets/model/GuardRule.ets`
- Create: `scripts/guard-rule-test.mjs`

- [ ] **Step 1: 先写 Node 侧规则测试（与 ArkTS 逻辑同一规则，DevEco 之外的快速门禁）**

`scripts/guard-rule-test.mjs`:

```js
import assert from 'node:assert/strict';

const WEEKDAY_NAMES = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

function normalizeWeekdays(values) {
  const seen = [];
  const result = [];
  for (const value of values) {
    if (Number.isInteger(value) && value >= 1 && value <= 7 && seen.indexOf(value) === -1) {
      seen.push(value);
      result.push(value);
    }
  }
  return result.sort((a, b) => a - b);
}

function sameSet(a, b) {
  const left = normalizeWeekdays(a);
  const right = normalizeWeekdays(b);
  if (left.length !== right.length) {
    return false;
  }
  for (let i = 0; i < left.length; i += 1) {
    if (left[i] !== right[i]) {
      return false;
    }
  }
  return true;
}

function isTimeText(value) {
  return /^([01]\d|2[0-3]):[0-5]\d$/.test(value);
}

function toMinutes(value) {
  return Number(value.slice(0, 2)) * 60 + Number(value.slice(3, 5));
}

function validateRule(rule) {
  const name = String(rule.name ?? '').trim();
  if (name.length === 0) {
    return '请填写规则名';
  }
  if (name.length > 30) {
    return '规则名不能超过 30 个字符';
  }
  if (typeof rule.appToken !== 'string' || rule.appToken.length === 0) {
    return '请选择要限制的应用';
  }
  const weekdays = normalizeWeekdays(rule.weekdays ?? []);
  if (weekdays.length === 0) {
    return '请至少选择一个生效日';
  }
  if (!isTimeText(rule.startTime) || !isTimeText(rule.endTime)) {
    return '时间格式应为 HH:mm';
  }
  if (toMinutes(rule.endTime) <= toMinutes(rule.startTime)) {
    return '结束时间必须晚于开始时间';
  }
  return '';
}

function formatWeekdays(days) {
  const values = normalizeWeekdays(days);
  const all = [1, 2, 3, 4, 5, 6, 7];
  const workdays = [1, 2, 3, 4, 5];
  const weekend = [6, 7];
  if (sameSet(values, all)) {
    return '每天';
  }
  if (sameSet(values, workdays)) {
    return '周一至周五';
  }
  if (sameSet(values, weekend)) {
    return '周末';
  }
  return values.map((day) => WEEKDAY_NAMES[day - 1]).join('、');
}

function formatRuleTime(rule) {
  return `${rule.startTime} – ${rule.endTime}`;
}

function buildStrategyName(ruleId) {
  return `rule_${ruleId}`;
}

assert.equal(normalizeWeekdays([3, 1, 3, 2]).join(','), '1,2,3');
assert.equal(normalizeWeekdays([0, 8, -1]).join(','), '');
assert.equal(formatWeekdays([1, 2, 3, 4, 5, 6, 7]), '每天');
assert.equal(formatWeekdays([1, 2, 3, 4, 5]), '周一至周五');
assert.equal(formatWeekdays([6, 7]), '周末');
assert.equal(formatWeekdays([1, 3, 5]), '周一、周三、周五');
assert.equal(isTimeText('00:00'), true);
assert.equal(isTimeText('23:59'), true);
assert.equal(isTimeText('24:00'), false);
assert.equal(isTimeText('9:00'), false);
assert.equal(validateRule({ id: 'r1', name: '  ', appToken: 'a', weekdays: [1], startTime: '19:00', endTime: '21:00', enabled: true }), '请填写规则名');
assert.equal(validateRule({ id: 'r1', name: '抖音', appToken: '', weekdays: [1], startTime: '19:00', endTime: '21:00', enabled: true }), '请选择要限制的应用');
assert.equal(validateRule({ id: 'r1', name: '抖音', appToken: 'a', weekdays: [], startTime: '19:00', endTime: '21:00', enabled: true }), '请至少选择一个生效日');
assert.equal(validateRule({ id: 'r1', name: '抖音', appToken: 'a', weekdays: [1], startTime: '21:00', endTime: '19:00', enabled: true }), '结束时间必须晚于开始时间');
assert.equal(validateRule({ id: 'r1', name: '抖音', appToken: 'a', weekdays: [1], startTime: '19:00', endTime: '21:00', enabled: true }), '');
assert.equal(formatRuleTime({ startTime: '19:00', endTime: '21:00' }), '19:00 – 21:00');
assert.equal(buildStrategyName('abc'), 'rule_abc');

console.log('guard rule tests passed (17 cases)');
```

Run: `node scripts/guard-rule-test.mjs`

Expected: `guard rule tests passed (17 cases)`。

- [ ] **Step 2: 实现 ArkTS 规则模型（与脚本保持一致）**

`entry/src/main/ets/model/GuardRule.ets`:

```ts
export interface GuardRule {
  id: string;
  name: string;
  appToken: string;
  weekdays: number[];
  startTime: string;
  endTime: string;
  enabled: boolean;
}

export const WEEKDAY_NAMES: string[] = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

/**
 * 归一化星期数组：过滤非法值、去重并升序排序。
 *
 * @param values 原始星期数组。
 * @returns 合法且去重后的星期数组。
 */
export function normalizeWeekdays(values: number[]): number[] {
  const seen: number[] = [];
  const result: number[] = [];
  for (const value of values) {
    if (Number.isInteger(value) && value >= 1 && value <= 7 && seen.indexOf(value) === -1) {
      seen.push(value);
      result.push(value);
    }
  }
  return result.sort((left: number, right: number): number => left - right);
}

/**
 * 判断两个星期集合是否等价。
 *
 * @param left 左侧星期集合。
 * @param right 右侧星期集合。
 * @returns 等价时返回 true。
 */
export function sameWeekdaySet(left: number[], right: number[]): boolean {
  const normalizedLeft: number[] = normalizeWeekdays(left);
  const normalizedRight: number[] = normalizeWeekdays(right);
  if (normalizedLeft.length !== normalizedRight.length) {
    return false;
  }
  for (let index: number = 0; index < normalizedLeft.length; index += 1) {
    if (normalizedLeft[index] !== normalizedRight[index]) {
      return false;
    }
  }
  return true;
}

/**
 * 判断文本是否为 HH:mm 格式。
 *
 * @param value 时间文本。
 * @returns 合法时返回 true。
 */
export function isTimeText(value: string): boolean {
  return /^([01]\d|2[0-3]):[0-5]\d$/.test(value);
}

/**
 * 将 HH:mm 文本转换为当天分钟数。
 *
 * @param value 时间文本。
 * @returns 分钟数。
 */
export function toTimeMinutes(value: string): number {
  return Number(value.slice(0, 2)) * 60 + Number(value.slice(3, 5));
}

/**
 * 校验一条规则，返回空字符串表示通过，否则返回用户可读的错误原因。
 *
 * @param rule 待校验规则。
 * @returns 错误原因文本。
 */
export function validateRule(rule: GuardRule): string {
  const name: string = rule.name.trim();
  if (name.length === 0) {
    return '请填写规则名';
  }
  if (name.length > 30) {
    return '规则名不能超过 30 个字符';
  }
  if (rule.appToken.length === 0) {
    return '请选择要限制的应用';
  }
  const weekdays: number[] = normalizeWeekdays(rule.weekdays);
  if (weekdays.length === 0) {
    return '请至少选择一个生效日';
  }
  if (!isTimeText(rule.startTime) || !isTimeText(rule.endTime)) {
    return '时间格式应为 HH:mm';
  }
  if (toTimeMinutes(rule.endTime) <= toTimeMinutes(rule.startTime)) {
    return '结束时间必须晚于开始时间';
  }
  return '';
}

/**
 * 生成规则卡片的生效日展示文本。
 *
 * @param days 星期数组。
 * @returns “每天”“周一至周五”等文本。
 */
export function formatWeekdays(days: number[]): string {
  const values: number[] = normalizeWeekdays(days);
  if (sameWeekdaySet(values, [1, 2, 3, 4, 5, 6, 7])) {
    return '每天';
  }
  if (sameWeekdaySet(values, [1, 2, 3, 4, 5])) {
    return '周一至周五';
  }
  if (sameWeekdaySet(values, [6, 7])) {
    return '周末';
  }
  return values.map((day: number): string => WEEKDAY_NAMES[day - 1]).join('、');
}

/**
 * 生成时间窗展示文本。
 *
 * @param rule 规则。
 * @returns 形如“19:00 – 21:00”的文本。
 */
export function formatRuleTime(rule: GuardRule): string {
  return `${rule.startTime} – ${rule.endTime}`;
}

/**
 * 根据规则 id 生成唯一的 Screen Time Guard 策略名。
 *
 * @param ruleId 规则 id。
 * @returns 策略名。
 */
export function buildStrategyName(ruleId: string): string {
  return `rule_${ruleId}`;
}
```

- [ ] **Step 3: 运行本地测试**

Run: `node scripts/guard-rule-test.mjs`

Expected: 17 个断言全部通过。

- [ ] **Step 4: 提交**

```bash
git add entry/src/main/ets/model/GuardRule.ets scripts/guard-rule-test.mjs
git commit -m 'feat(timeguard): 增加每周时段规则校验与展示逻辑'
```

---

### Task 3: 本地规则存储

**Files:**
- Create: `entry/src/main/ets/storage/GuardRuleRepository.ets`

- [ ] **Step 1: 实现 Preferences 仓库**

`entry/src/main/ets/storage/GuardRuleRepository.ets`:

```ts
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { GuardRule } from '../model/GuardRule';

const PREFERENCES_NAME: string = 'timeguard_preferences';
const RULES_KEY: string = 'rules_v1';

export class GuardRuleRepository {
  private static instance: GuardRuleRepository | null = null;
  private context: common.UIAbilityContext | null = null;
  private store: preferences.Preferences | null = null;

  /**
   * 获取单例仓库。
   *
   * @returns 仓库实例。
   */
  public static getInstance(): GuardRuleRepository {
    if (GuardRuleRepository.instance === null) {
      GuardRuleRepository.instance = new GuardRuleRepository();
    }
    return GuardRuleRepository.instance;
  }

  /**
   * 绑定 UIAbility 上下文并初始化 Preferences。
   *
   * @param context 应用上下文。
   */
  public bindContext(context: common.UIAbilityContext): void {
    this.context = context;
    void this.ensureStore();
  }

  /**
   * 读取全部本地规则。
   *
   * @returns 规则数组。
   */
  public async loadRules(): Promise<GuardRule[]> {
    try {
      const store: preferences.Preferences = await this.ensureStore();
      const raw: preferences.ValueType = await store.get(RULES_KEY, '[]');
      const text: string = typeof raw === 'string' ? raw : '[]';
      return JSON.parse(text) as GuardRule[];
    } catch (error) {
      const message: string = this.describeError(error as BusinessError);
      console.error(`自控钟读取本地规则失败：${message}`);
      return [];
    }
  }

  /**
   * 保存或覆盖一条规则。
   *
   * @param rule 待保存规则。
   */
  public async saveRule(rule: GuardRule): Promise<void> {
    const rules: GuardRule[] = await this.loadRules();
    const index: number = rules.findIndex((item: GuardRule): boolean => item.id === rule.id);
    if (index >= 0) {
      rules.splice(index, 1, rule);
    } else {
      rules.push(rule);
    }
    await this.writeRules(rules);
  }

  /**
   * 删除一条规则。
   *
   * @param ruleId 规则 id。
   */
  public async deleteRule(ruleId: string): Promise<void> {
    const rules: GuardRule[] = await this.loadRules();
    const next: GuardRule[] = rules.filter((item: GuardRule): boolean => item.id !== ruleId);
    await this.writeRules(next);
  }

  private async ensureStore(): Promise<preferences.Preferences> {
    if (this.store !== null) {
      return this.store;
    }
    if (this.context === null) {
      throw new Error('应用上下文尚未准备好');
    }
    this.store = await preferences.getPreferences(this.context, PREFERENCES_NAME);
    return this.store;
  }

  private async writeRules(rules: GuardRule[]): Promise<void> {
    const store: preferences.Preferences = await this.ensureStore();
    await store.put(RULES_KEY, JSON.stringify(rules));
    await store.flush();
  }

  private describeError(error: BusinessError): string {
    if (error !== null && error !== undefined && error.message !== undefined && error.message.length > 0) {
      return error.message;
    }
    return String(error);
  }
}
```

- [ ] **Step 2: 运行结构检查并提交**

Run: `git diff --check`

```bash
git add entry/src/main/ets/storage/GuardRuleRepository.ets
git commit -m 'feat(timeguard): 增加本地规则持久化仓库'
```

---

### Task 4: Screen Time Guard 服务封装

**Files:**
- Create: `entry/src/main/ets/service/ScreenTimeGuardService.ets`

- [ ] **Step 1: 实现系统策略服务**

`entry/src/main/ets/service/ScreenTimeGuardService.ets`:

```ts
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { appPicker, guardService } from '@kit.ScreenTimeGuardKit';
import { buildStrategyName, GuardRule } from '../model/GuardRule';

const ERROR_STRATEGY_NOT_FOUND: number = 1019000006;
const ERROR_STRATEGY_NOT_STARTED: number = 1019000008;

export class ScreenTimeGuardService {
  private static instance: ScreenTimeGuardService | null = null;
  private context: common.UIAbilityContext | null = null;

  /**
   * 获取单例服务。
   *
   * @returns 服务实例。
   */
  public static getInstance(): ScreenTimeGuardService {
    if (ScreenTimeGuardService.instance === null) {
      ScreenTimeGuardService.instance = new ScreenTimeGuardService();
    }
    return ScreenTimeGuardService.instance;
  }

  /**
   * 绑定 UIAbility 上下文。
   *
   * @param context 应用上下文。
   */
  public bindContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  /**
   * 请求用户授权 Screen Time Guard 管控能力。
   */
  public async requestUserAuth(): Promise<void> {
    this.requireContext();
    await guardService.requestUserAuth(this.context);
  }

  /**
   * 拉起系统应用选择页并返回目标应用 token。
   *
   * @param previousToken 编辑时用于预勾选的原 token，可为空字符串。
   * @returns 选中的应用 token。
   */
  public async pickTargetApp(previousToken: string): Promise<string> {
    this.requireContext();
    await this.requestUserAuth();
    const selected: string[] = await appPicker.startAppPicker(this.context, {
      appTokens: previousToken.length > 0 ? [previousToken] : []
    });
    if (selected.length !== 1) {
      throw new Error('请选择一个要限制的应用');
    }
    return selected[0];
  }

  /**
   * 将启用的规则下发为系统守护策略并启动。
   *
   * @param rule 规则。
   */
  public async applyRule(rule: GuardRule): Promise<void> {
    const name: string = buildStrategyName(rule.id);
    const strategy: guardService.GuardStrategy = this.buildStrategy(rule, name);
    const exists: boolean = await this.containsStrategy(name);
    if (exists) {
      await this.stopStrategyIfExists(name);
      await guardService.updateGuardStrategy(name, strategy);
    } else {
      await guardService.addGuardStrategy(strategy);
    }
    await guardService.startGuardStrategy(name);
  }

  /**
   * 停用/删除前解除系统限制并移除策略。
   *
   * @param rule 规则。
   */
  public async deactivateRule(rule: GuardRule): Promise<void> {
    const appInfo: guardService.AppInfo = { appTokens: [rule.appToken] };
    try {
      await guardService.releaseAppsRestriction(appInfo, guardService.RestrictionType.BLOCKLIST_TYPE);
    } catch (error) {
      console.warn(`自控钟解除应用限制失败（继续清理策略）：${this.describeError(error as BusinessError)}`);
    }
    const name: string = buildStrategyName(rule.id);
    if (!(await this.containsStrategy(name))) {
      return;
    }
    await this.stopStrategyIfExists(name);
    await guardService.removeGuardStrategy(name);
  }

  /**
   * 查询系统当前有效的策略名列表，用于启动时校准界面。
   *
   * @returns 策略名列表。
   */
  public async activeStrategyNames(): Promise<string[]> {
    const strategies: guardService.GuardStrategy[] = await guardService.queryGuardStrategies();
    return strategies.map((item: guardService.GuardStrategy): string => item.name);
  }

  /**
   * 将接口错误转成中文提示。
   *
   * @param error 错误对象。
   * @returns 中文提示。
   */
  public describeError(error: BusinessError): string {
    if (error === null || error === undefined) {
      return '未知错误';
    }
    switch (error.code) {
      case 201:
        return '权限校验失败，请检查签名 Profile 或 ACL 授权';
      case 401:
        return '参数错误，请检查规则内容';
      case 801:
        return '当前设备或系统版本不支持屏幕时间守护';
      case 1019000001:
        return '系统内部错误，请重试';
      case 1019000002:
        return '尚未获得屏幕时间守护授权';
      case 1019000003:
        return '用户取消了操作';
      case 1019000004:
        return '守护策略数量已达上限，请先停用或删除其他规则';
      case 1019000005:
        return '守护策略已存在，正在按更新流程处理';
      case 1019000006:
        return '守护策略不存在';
      case 1019000007:
        return '守护策略正在执行，已先停止再更新';
      case 1019000008:
        return '守护策略尚未启动';
      default:
        return error.message !== undefined && error.message.length > 0 ? error.message : String(error);
    }
  }

  private requireContext(): common.UIAbilityContext {
    if (this.context === null) {
      throw new Error('应用上下文尚未准备好');
    }
    return this.context;
  }

  private buildStrategy(rule: GuardRule, name: string): guardService.GuardStrategy {
    return {
      name,
      timeStrategy: {
        type: guardService.TimeStrategyType.START_END_TIME_TYPE,
        startTime: rule.startTime,
        endTime: rule.endTime,
        repeat: rule.weekdays.slice()
      },
      appInfo: {
        appTokens: [rule.appToken]
      },
      appRestrictionType: guardService.RestrictionType.BLOCKLIST_TYPE
    };
  }

  private async containsStrategy(name: string): Promise<boolean> {
    const names: string[] = await this.activeStrategyNames();
    return names.indexOf(name) >= 0;
  }

  private async stopStrategyIfExists(name: string): Promise<void> {
    try {
      await guardService.stopGuardStrategy(name);
    } catch (error) {
      const businessError: BusinessError = error as BusinessError;
      if (businessError.code !== ERROR_STRATEGY_NOT_FOUND && businessError.code !== ERROR_STRATEGY_NOT_STARTED) {
        throw error;
      }
    }
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add entry/src/main/ets/service/ScreenTimeGuardService.ets
git commit -m 'feat(timeguard): 封装屏幕时间守护授权与策略管理'
```

---

### Task 5: 入口 Ability 与规则列表页

**Files:**
- Create: `entry/src/main/ets/entryability/EntryAbility.ets`
- Create: `entry/src/main/ets/pages/RuleListPage.ets`

- [ ] **Step 1: 实现 EntryAbility**

`entry/src/main/ets/entryability/EntryAbility.ets`:

```ts
import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { ScreenTimeGuardService } from '../service/ScreenTimeGuardService';
import { GuardRuleRepository } from '../storage/GuardRuleRepository';

export default class EntryAbility extends UIAbility {
  private readonly guardRepository: GuardRuleRepository = GuardRuleRepository.getInstance();
  private readonly guardService: ScreenTimeGuardService = ScreenTimeGuardService.getInstance();

  /**
   * Ability 创建时绑定上下文，供页面与仓库使用。
   */
  public onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    this.guardRepository.bindContext(this.context);
    this.guardService.bindContext(this.context);
  }

  /**
   * 主窗口创建后加载规则列表页。
   */
  public onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/RuleListPage', (error: BusinessError) => {
      if (error.code !== 0) {
        console.error(`自控钟加载主页面失败：${error.code} ${error.message}`);
      }
    });
  }
}
```

- [ ] **Step 2: 实现规则列表页**

`entry/src/main/ets/pages/RuleListPage.ets`:

```ts
import { router } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { formatRuleTime, formatWeekdays, GuardRule } from '../model/GuardRule';
import { ScreenTimeGuardService } from '../service/ScreenTimeGuardService';
import { GuardRuleRepository } from '../storage/GuardRuleRepository';

@Entry
@Component
struct RuleListPage {
  @State private rules: GuardRule[] = [];
  @State private busy: boolean = false;
  @State private statusText: string = '正在同步规则…';
  @State private statusColor: string = '#64748B';
  private readonly repository: GuardRuleRepository = GuardRuleRepository.getInstance();
  private readonly guardService: ScreenTimeGuardService = ScreenTimeGuardService.getInstance();

  /**
   * 页面显示时从本地读取规则，并按系统真实策略校准启用状态。
   */
  public aboutToAppear(): void {
    void this.loadRules();
  }

  private async loadRules(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    try {
      const localRules: GuardRule[] = await this.repository.loadRules();
      let activeNames: string[] = [];
      try {
        activeNames = await this.guardService.activeStrategyNames();
      } catch (error) {
        this.showStatus('error', `读取系统策略失败：${this.guardService.describeError(error as BusinessError)}`);
      }
      for (const rule of localRules) {
        const active: boolean = activeNames.indexOf(`rule_${rule.id}`) >= 0;
        if (rule.enabled !== active) {
          rule.enabled = active;
          await this.repository.saveRule(rule);
        }
      }
      this.rules = localRules;
      this.showStatus('idle', localRules.length === 0 ? '还没有规则，点击下方“添加规则”开始' : '规则已同步');
    } catch (error) {
      this.showStatus('error', `读取本地规则失败：${String(error)}`);
    } finally {
      this.busy = false;
    }
  }

  private openCreatePage(): void {
    void router.pushUrl({ url: 'pages/RuleEditPage' });
  }

  private openEditPage(ruleId: string): void {
    void router.pushUrl({
      url: 'pages/RuleEditPage',
      params: { ruleId }
    });
  }

  private async toggleRule(rule: GuardRule, enabled: boolean): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    const updated: GuardRule = this.copyRule(rule, enabled);
    try {
      if (enabled) {
        await this.guardService.applyRule(updated);
      } else {
        await this.guardService.deactivateRule(updated);
      }
      await this.repository.saveRule(updated);
      await this.loadRules();
      this.showStatus('idle', enabled ? `“${rule.name}”已启用` : `“${rule.name}”已停用`);
    } catch (error) {
      this.showStatus('error', `${enabled ? '启用' : '停用'}失败：${this.guardService.describeError(error as BusinessError)}`);
    } finally {
      this.busy = false;
    }
  }

  private confirmDelete(rule: GuardRule): void {
    AlertDialog.show({
      title: '删除规则',
      message: `确定删除“${rule.name}”？删除后系统限制立即解除。`,
      primaryButton: {
        value: '删除',
        action: () => {
          void this.deleteRule(rule);
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {
        }
      }
    });
  }

  private async deleteRule(rule: GuardRule): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    try {
      if (rule.enabled) {
        await this.guardService.deactivateRule(rule);
      }
      await this.repository.deleteRule(rule.id);
      await this.loadRules();
      this.showStatus('idle', `已删除“${rule.name}”`);
    } catch (error) {
      this.showStatus('error', `删除失败：${this.guardService.describeError(error as BusinessError)}`);
    } finally {
      this.busy = false;
    }
  }

  private copyRule(rule: GuardRule, enabled: boolean): GuardRule {
    return {
      id: rule.id,
      name: rule.name,
      appToken: rule.appToken,
      weekdays: rule.weekdays.slice(),
      startTime: rule.startTime,
      endTime: rule.endTime,
      enabled
    };
  }

  private showStatus(kind: string, message: string): void {
    this.statusText = message;
    this.statusColor = kind === 'error' ? '#B42318' : kind === 'success' ? '#15803D' : '#64748B';
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 8 }) {
        Text('自控钟')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0F172A')
        Text('每周指定时段禁止指定应用打开')
          .fontSize(14)
          .fontColor('#475569')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')

      Text(this.statusText)
        .fontSize(14)
        .fontColor(this.statusColor)
        .width('100%')

      List({ space: 12 }) {
        ForEach(this.rules, (rule: GuardRule) => {
          ListItem() {
            Column({ space: 10 }) {
              Row() {
                Column({ space: 4 }) {
                  Text(rule.name)
                    .fontSize(17)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#0F172A')
                  Text(`${formatWeekdays(rule.weekdays)} ${formatRuleTime(rule)}`)
                    .fontSize(13)
                    .fontColor('#64748B')
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Toggle({ type: ToggleType.Switch, isOn: rule.enabled })
                  .onChange((value: boolean) => {
                    void this.toggleRule(rule, value);
                  })
              }
              .width('100%')

              Row({ space: 12 }) {
                Button('编辑')
                  .fontSize(14)
                  .backgroundColor('#1D4ED8')
                  .onClick(() => {
                    this.openEditPage(rule.id);
                  })
                Button('删除')
                  .fontSize(14)
                  .backgroundColor('#E11D48')
                  .onClick(() => {
                    this.confirmDelete(rule);
                  })
              }
              .width('100%')
            }
            .alignItems(HorizontalAlign.Start)
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(16)
            .width('100%')
          }
        }, (rule: GuardRule) => rule.id)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Auto)

      Button('添加规则')
        .width('100%')
        .height(50)
        .fontSize(16)
        .fontColor('#FFFFFF')
        .backgroundColor('#1D4ED8')
        .enabled(!this.busy)
        .onClick(() => {
          this.openCreatePage();
        })

      Button('重新同步')
        .width('100%')
        .height(44)
        .fontSize(14)
        .fontColor('#1D4ED8')
        .backgroundColor('#E8F0FF')
        .enabled(!this.busy)
        .onClick(() => {
          void this.loadRules();
        })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 22, right: 22, top: 30, bottom: 22 })
    .backgroundColor('#F5F7FB')
  }
}
```

- [ ] **Step 3: 提交**

```bash
git add entry/src/main/ets/entryability/EntryAbility.ets entry/src/main/ets/pages/RuleListPage.ets
git commit -m 'feat(timeguard): 增加规则列表与启停同步'
```

---

### Task 6: 规则编辑页

**Files:**
- Create: `entry/src/main/ets/pages/RuleEditPage.ets`

- [ ] **Step 1: 实现新增/编辑页**

`entry/src/main/ets/pages/RuleEditPage.ets`:

```ts
import { router } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import {
  GuardRule,
  normalizeWeekdays,
  validateRule,
  WEEKDAY_NAMES
} from '../model/GuardRule';
import { ScreenTimeGuardService } from '../service/ScreenTimeGuardService';
import { GuardRuleRepository } from '../storage/GuardRuleRepository';

const WEEKDAY_OPTIONS: number[] = [1, 2, 3, 4, 5, 6, 7];

@Entry
@Component
struct RuleEditPage {
  @State private ruleId: string = '';
  @State private ruleName: string = '';
  @State private appToken: string = '';
  @State private appText: string = '尚未选择应用';
  @State private weekdays: number[] = [1, 2, 3, 4, 5, 6, 7];
  @State private startTime: string = '19:00';
  @State private endTime: string = '21:00';
  @State private busy: boolean = false;
  @State private statusText: string = '';
  @State private statusColor: string = '#64748B';
  private existingRule: GuardRule | null = null;
  private readonly repository: GuardRuleRepository = GuardRuleRepository.getInstance();
  private readonly guardService: ScreenTimeGuardService = ScreenTimeGuardService.getInstance();

  /**
   * 页面出现时根据路由参数加载已有规则或进入新增状态。
   */
  public aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    const id: string = params !== null && params !== undefined && params['ruleId'] !== undefined
      ? params['ruleId']
      : '';
    if (id.length === 0) {
      return;
    }
    this.ruleId = id;
    void this.loadRule(id);
  }

  private async loadRule(id: string): Promise<void> {
    const rules: GuardRule[] = await this.repository.loadRules();
    const rule: GuardRule | undefined = rules.find((item: GuardRule): boolean => item.id === id);
    if (rule === undefined) {
      this.showStatus('error', '没有找到这条规则');
      return;
    }
    this.existingRule = rule;
    this.ruleName = rule.name;
    this.appToken = rule.appToken;
    this.appText = '已选择应用（编辑时重新打开选择页可查看）';
    this.weekdays = rule.weekdays.slice();
    this.startTime = rule.startTime;
    this.endTime = rule.endTime;
  }

  private async chooseApp(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    try {
      const token: string = await this.guardService.pickTargetApp(this.appToken);
      this.appToken = token;
      this.appText = '已选择 1 个应用';
      this.showStatus('idle', '应用已选择');
    } catch (error) {
      this.showStatus('error', `选择应用失败：${this.guardService.describeError(error as BusinessError)}`);
    } finally {
      this.busy = false;
    }
  }

  private toggleWeekday(day: number): void {
    const index: number = this.weekdays.indexOf(day);
    const next: number[] = this.weekdays.slice();
    if (index >= 0) {
      next.splice(index, 1);
    } else {
      next.push(day);
    }
    this.weekdays = normalizeWeekdays(next);
  }

  private async saveRule(): Promise<void> {
    if (this.busy) {
      return;
    }
    const id: string = this.ruleId.length > 0 ? this.ruleId : this.createId();
    const candidate: GuardRule = {
      id,
      name: this.ruleName,
      appToken: this.appToken,
      weekdays: this.weekdays.slice(),
      startTime: this.startTime,
      endTime: this.endTime,
      enabled: true
    };
    const errorMessage: string = validateRule(candidate);
    if (errorMessage.length > 0) {
      this.showStatus('error', errorMessage);
      return;
    }
    this.busy = true;
    try {
      if (this.existingRule !== null && this.existingRule.enabled && this.existingRule.appToken !== candidate.appToken) {
        await this.guardService.deactivateRule(this.existingRule);
      }
      await this.guardService.applyRule(candidate);
      await this.repository.saveRule(candidate);
      router.back();
    } catch (error) {
      this.showStatus('error', `保存失败：${this.guardService.describeError(error as BusinessError)}`);
    } finally {
      this.busy = false;
    }
  }

  private createId(): string {
    return `${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 10)}`;
  }

  private timeToDate(value: string): Date {
    return new Date(2026, 0, 1, Number(value.slice(0, 2)), Number(value.slice(3, 5)));
  }

  private dateToTime(value: Date): string {
    const hour: number = value.getHours();
    const minute: number = value.getMinutes();
    return `${hour < 10 ? '0' : ''}${hour}:${minute < 10 ? '0' : ''}${minute}`;
  }

  private showStatus(kind: string, message: string): void {
    this.statusText = message;
    this.statusColor = kind === 'error' ? '#B42318' : '#15803D';
  }

  build() {
    Column({ space: 18 }) {
      Row() {
        Text(this.ruleId.length > 0 ? '编辑规则' : '添加规则')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0F172A')
        Blank()
        Text('返回')
          .fontSize(15)
          .fontColor('#1D4ED8')
          .onClick(() => {
            router.back();
          })
      }
      .width('100%')

      Scroll() {
        Column({ space: 16 }) {
          TextInput({ text: this.ruleName, placeholder: '规则名，例如：抖音' })
            .height(48)
            .onChange((value: string) => {
              this.ruleName = value;
            })

          Text('生效星期')
            .fontSize(14)
            .fontColor('#334155')
          Flex({ wrap: FlexWrap.Wrap, space: { main: 10, cross: 10 } }) {
            ForEach(WEEKDAY_OPTIONS, (day: number) => {
              Column({ space: 4 }) {
                Text(WEEKDAY_NAMES[day - 1])
                  .fontSize(13)
                  .fontColor(this.weekdays.indexOf(day) >= 0 ? '#1D4ED8' : '#64748B')
                Toggle({
                  type: ToggleType.Checkbox,
                  isOn: this.weekdays.indexOf(day) >= 0
                })
                  .onChange(() => {
                    this.toggleWeekday(day);
                  })
              }
              .width(72)
              .padding(8)
              .borderRadius(10)
              .backgroundColor(this.weekdays.indexOf(day) >= 0 ? '#E8F0FF' : '#FFFFFF')
            }, (day: number) => day.toString())
          }
          .width('100%')

          Text('开始时间')
            .fontSize(14)
            .fontColor('#334155')
          TimePicker({ selected: this.timeToDate(this.startTime) })
            .useMilitaryTime(true)
            .height(120)
            .onChange((value: TimePickerResult) => {
              this.startTime = this.dateToTime(new Date(2026, 0, 1, value.hour, value.minute));
            })

          Text('结束时间')
            .fontSize(14)
            .fontColor('#334155')
          TimePicker({ selected: this.timeToDate(this.endTime) })
            .useMilitaryTime(true)
            .height(120)
            .onChange((value: TimePickerResult) => {
              this.endTime = this.dateToTime(new Date(2026, 0, 1, value.hour, value.minute));
            })

          Button(this.appToken.length > 0 ? '重新选择要限制的应用' : '选择要限制的应用')
            .width('100%')
            .height(48)
            .fontSize(15)
            .fontColor('#1D4ED8')
            .backgroundColor('#E8F0FF')
            .enabled(!this.busy)
            .onClick(() => {
              void this.chooseApp();
            })

          Text(this.appText)
            .fontSize(13)
            .fontColor('#64748B')

          if (this.statusText.length > 0) {
            Text(this.statusText)
              .fontSize(13)
              .fontColor(this.statusColor)
              .width('100%')
          }
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')

      Button('保存并启用')
        .width('100%')
        .height(50)
        .fontSize(16)
        .fontColor('#FFFFFF')
        .backgroundColor('#1D4ED8')
        .enabled(!this.busy)
        .onClick(() => {
          void this.saveRule();
        })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 22, right: 22, top: 28, bottom: 22 })
    .backgroundColor('#F5F7FB')
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add entry/src/main/ets/pages/RuleEditPage.ets
git commit -m 'feat(timeguard): 增加规则新增与编辑页面'
```

---

### Task 7: 工程门禁、文档与收尾验证

**Files:**
- Create: `scripts/validate-project.mjs`
- Create: `README.md`
- Create: `docs/project-integration/testing.md`

- [ ] **Step 1: 写工程校验脚本**

`scripts/validate-project.mjs`:

```js
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

/**
 * 读取工程文本文件，缺失时断言失败。
 *
 * @param {string} relativePath 相对仓库根目录的路径。
 * @returns {string} 文件内容。
 */
function readProjectFile(relativePath) {
  const absolutePath = path.join(root, relativePath);
  assert.ok(fs.existsSync(absolutePath), `缺少工程文件：${relativePath}`);
  return fs.readFileSync(absolutePath, 'utf8');
}

/**
 * 解析 JSON5 配置文件并返回对象。
 *
 * @param {string} relativePath 配置文件路径。
 * @returns {object} 配置对象。
 */
function parseConfig(relativePath) {
  return JSON.parse(readProjectFile(relativePath));
}

function validateProject() {
  const appConfig = parseConfig('AppScope/app.json5');
  const buildConfig = parseConfig('build-profile.json5');
  const moduleConfig = parseConfig('entry/src/main/module.json5');
  const pagesConfig = parseConfig('entry/src/main/resources/base/profile/main_pages.json');

  assert.equal(appConfig.app.bundleName, 'com.cwenhe.timeguard');
  assert.equal(buildConfig.app.products[0].targetSdkVersion, '6.1.0(23)');
  assert.equal(moduleConfig.module.mainElement, 'EntryAbility');
  assert.ok(moduleConfig.module.requestPermissions.some(
    (item) => item.name === 'ohos.permission.MANAGE_SCREEN_TIME_GUARD'
  ));
  assert.deepEqual(pagesConfig.src, ['pages/RuleListPage', 'pages/RuleEditPage']);

  const model = readProjectFile('entry/src/main/ets/model/GuardRule.ets');
  const service = readProjectFile('entry/src/main/ets/service/ScreenTimeGuardService.ets');
  const repository = readProjectFile('entry/src/main/ets/storage/GuardRuleRepository.ets');
  const listPage = readProjectFile('entry/src/main/ets/pages/RuleListPage.ets');
  const editPage = readProjectFile('entry/src/main/ets/pages/RuleEditPage.ets');

  assert.match(model, /validateRule/);
  assert.match(model, /formatWeekdays/);
  assert.match(model, /buildStrategyName/);
  assert.match(service, /requestUserAuth/);
  assert.match(service, /startAppPicker/);
  assert.match(service, /addGuardStrategy/);
  assert.match(service, /updateGuardStrategy/);
  assert.match(service, /startGuardStrategy/);
  assert.match(service, /stopGuardStrategy/);
  assert.match(service, /removeGuardStrategy/);
  assert.match(service, /releaseAppsRestriction/);
  assert.match(repository, /preferences\.getPreferences/);
  assert.match(listPage, /Toggle\(\{ type: ToggleType\.Switch/);
  assert.match(editPage, /TimePicker/);

  console.log('project validation passed');
}

validateProject();
```

Run: `node scripts/guard-rule-test.mjs && node scripts/validate-project.mjs`

Expected: `guard rule tests passed (17 cases)` 与 `project validation passed`。

- [ ] **Step 2: 补充 README 与真机验收清单**

`README.md`:

```markdown
# 自控钟

HarmonyOS 6 独立应用，包名 `com.cwenhe.timeguard`。

## 能力

- 每个应用一条规则。
- 规则可选择周一至周日的任意组合。
- 规则可选择当天开始/结束时间，保存后立即启用。
- 到点由 Screen Time Guard 禁止指定应用打开，到结束时间自动放行。

## 导入与构建

1. 使用 DevEco Studio（HarmonyOS 6.1/API 23）打开本目录。
2. 在 `File > Project Structure > Signing` 配置包含 `MANAGE_SCREEN_TIME_GUARD` 的调试 Profile。
3. 真机运行 entry 模块。

本仓库不提交证书、Profile 或构建产物。
```

`docs/project-integration/testing.md`:

```markdown
# 真机验收清单

对应设计规格：`docs/superpowers/specs/2026-09-04-self-restriction-rules-design.md`

1. 首次选择应用时出现系统授权弹窗，拒绝和允许行为正确。
2. 授权后可拉起应用选择页并返回目标应用 token。
3. 新建“同花顺：周一至周五 19:00–21:00 禁用”并保存。
4. 生效期间同花顺无法打开；正在使用时行为以真机为准，若系统不主动退出需停下向用户确认。
5. 结束时间后同花顺自动恢复。
6. 同花顺规则不影响抖音和其他应用。
7. 新增“抖音：每天 22:00–23:00 禁用”，两条规则并存。
8. 编辑规则时系统选择页预勾选原应用，更换应用后策略更新。
9. 停用/删除后系统限制立即解除。
10. 重启手机或清理 App 后，已启用规则仍由系统生效。
11. 用户撤销授权后 App 状态提示正确。
```

- [ ] **Step 3: 全量本地验证并提交**

Run:

```bash
node scripts/guard-rule-test.mjs
node scripts/validate-project.mjs
git diff --check
git add -A
git commit -m 'docs(timeguard): 补充工程门禁与验收清单'
```

Expected: 两个脚本通过，空白检查通过，提交成功。

---

### Task 8: 真机编译与验收（需要用户在 DevEco 上执行）

**Files:** 无代码改动。

- [ ] **Step 1: 在 DevEco 配置签名**

在 AGC/DevEco 使用包名 `com.cwenhe.timeguard` 的 Profile，勾选 `MANAGE_SCREEN_TIME_GUARD`；确认工程构建配置读取到该 Profile。

- [ ] **Step 2: 构建 HAP**

Run: `./hvigorw assembleHap --mode module -p module=entry`

Expected: `BUILD SUCCESSFUL`；若有 ArkTS 类型告警，按错误修正后重新运行。

- [ ] **Step 3: 按验收清单真机执行并记录结果**

逐条执行 `docs/project-integration/testing.md`；无法通过的条目如实记录，不修改验收预期来掩盖问题。

---

## 自审记录

1. **规格覆盖**：规则模型/界面/本地存储/STG 服务/错误码/启停删除/真机清单均有对应任务。
2. **占位符扫描**：无 TBD/TODO；代码步骤均给出完整文件内容。
3. **类型一致性**：`GuardRule`、`buildStrategyName`、`validateRule`、`formatWeekdays`、`ScreenTimeGuardService` 方法名在页面与仓库间保持一致。
