import assert from 'node:assert/strict';

const WEEKDAY_NAMES = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

/**
 * 归一化应用 token 数组：过滤空串并去重，保持首次出现顺序。
 *
 * @param {string[]} values 原始 token 数组。
 * @returns {string[]} 去重且不含空串的 token 数组。
 */
function normalizeAppTokens(values) {
  const seen = [];
  const result = [];
  for (const value of values) {
    const text = String(value ?? '').trim();
    if (text.length > 0 && seen.indexOf(text) === -1) {
      seen.push(text);
      result.push(text);
    }
  }
  return result;
}

/**
 * 归一化星期数组：过滤非法值、去重并升序排序。
 *
 * @param {number[]} values 原始星期数组。
 * @returns {number[]} 合法且去重后的星期数组。
 */
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

/**
 * 判断两个星期集合是否等价。
 *
 * @param {number[]} a 左侧星期集合。
 * @param {number[]} b 右侧星期集合。
 * @returns {boolean} 等价时返回 true。
 */
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

/**
 * 判断两组应用 token 是否等价，忽略顺序与重复项。
 *
 * @param {string[]} a 左侧 token 数组。
 * @param {string[]} b 右侧 token 数组。
 * @returns {boolean} 归一化且排序后完全一致时返回 true。
 */
function sameAppTokenSet(a, b) {
  const left = normalizeAppTokens(a).sort((x, y) => (x < y ? -1 : x > y ? 1 : 0));
  const right = normalizeAppTokens(b).sort((x, y) => (x < y ? -1 : x > y ? 1 : 0));
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

/**
 * 把本地存储的历史结构转换为当前规则结构。
 *
 * @param {object} stored 本地存储的规则，可含 appToken 或 appTokens。
 * @returns {object} 始终包含 appTokens 数组的规则。
 */
function toGuardRule(stored) {
  const storedTokens = Array.isArray(stored.appTokens) ? stored.appTokens : [];
  const legacyToken = typeof stored.appToken === 'string' ? stored.appToken : '';
  const appTokens = normalizeAppTokens(storedTokens.length > 0
    ? storedTokens
    : (legacyToken.length > 0 ? [legacyToken] : []));
  return {
    id: stored.id,
    name: stored.name,
    appTokens,
    weekdays: (stored.weekdays ?? []).slice(),
    startTime: stored.startTime,
    endTime: stored.endTime,
    enabled: stored.enabled
  };
}

/**
 * 判断文本是否为 HH:mm 格式。
 *
 * @param {string} value 时间文本。
 * @returns {boolean} 合法时返回 true。
 */
function isTimeText(value) {
  return /^([01]\d|2[0-3]):[0-5]\d$/.test(value);
}

/**
 * 将 HH:mm 文本转换为当天分钟数。
 *
 * @param {string} value 时间文本。
 * @returns {number} 分钟数。
 */
function toMinutes(value) {
  return Number(value.slice(0, 2)) * 60 + Number(value.slice(3, 5));
}

/**
 * 校验一条规则，返回空字符串表示通过。
 *
 * @param {object} rule 待校验规则。
 * @returns {string} 错误原因文本。
 */
function validateRule(rule) {
  const name = String(rule.name ?? '').trim();
  if (name.length === 0) {
    return '请填写规则名';
  }
  if (name.length > 30) {
    return '规则名不能超过 30 个字符';
  }
  if (normalizeAppTokens(Array.isArray(rule.appTokens) ? rule.appTokens : []).length === 0) {
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

/**
 * 生成规则卡片的应用数量展示文本。
 *
 * @param {string[]} appTokens 应用 token 数组。
 * @returns {string} 未选择时提示尚未选择，否则显示受限应用个数。
 */
function formatAppCount(appTokens) {
  const count = normalizeAppTokens(appTokens).length;
  return count > 0 ? `限制 ${count} 个应用` : '尚未选择应用';
}

/**
 * 判断规则时间窗在指定时刻是否命中（忽略启用状态）。
 *
 * @param {object} rule 规则。
 * @param {Date} now 当前时间。
 * @returns {boolean} 时间窗命中时返回 true。
 */
function isRuleScheduleActiveAt(rule, now) {
  const weekday = now.getDay() === 0 ? 7 : now.getDay();
  if (normalizeWeekdays(rule.weekdays ?? []).indexOf(weekday) === -1) {
    return false;
  }
  const currentMinutes = now.getHours() * 60 + now.getMinutes();
  return currentMinutes >= toMinutes(rule.startTime) && currentMinutes < toMinutes(rule.endTime);
}

/**
 * 判断规则是否处于生效锁定状态。
 *
 * @param {object} rule 规则。
 * @param {Date} now 当前时间。
 * @returns {boolean} 规则正在生效时返回 true。
 */
function isRuleActiveAt(rule, now) {
  return Boolean(rule.enabled) && isRuleScheduleActiveAt(rule, now);
}

/**
 * 生成星期集合的展示文本。
 *
 * @param {number[]} days 星期数组。
 * @returns {string} 展示文本。
 */
function formatWeekdays(days) {
  const values = normalizeWeekdays(days);
  if (sameSet(values, [1, 2, 3, 4, 5, 6, 7])) {
    return '每天';
  }
  if (sameSet(values, [1, 2, 3, 4, 5])) {
    return '周一至周五';
  }
  if (sameSet(values, [6, 7])) {
    return '周末';
  }
  return values.map((day) => WEEKDAY_NAMES[day - 1]).join('、');
}

/**
 * 生成时间窗展示文本。
 *
 * @param {object} rule 规则。
 * @returns {string} 形如“19:00 – 21:00”的文本。
 */
function formatRuleTime(rule) {
  return `${rule.startTime} – ${rule.endTime}`;
}

/**
 * 根据规则 id 生成策略名。
 *
 * @param {string} ruleId 规则 id。
 * @returns {string} 策略名。
 */
function buildStrategyName(ruleId) {
  return `rule_${ruleId}`;
}

assert.equal(normalizeWeekdays([3, 1, 3, 2]).join(','), '1,2,3');
assert.equal(normalizeWeekdays([0, 8, -1]).join(','), '');
assert.deepEqual(normalizeAppTokens(['b', 'a', 'b', '', ' a ']), ['b', 'a']);
assert.equal(sameAppTokenSet(['a', 'b'], ['b', 'a']), true);
assert.equal(sameAppTokenSet(['a', 'b'], ['a']), false);
assert.equal(sameAppTokenSet(['a', 'b', 'a'], ['b', 'a']), true);
const migratedRule = toGuardRule({
  id: 'r-old',
  name: '抖音',
  appToken: 'old-token',
  weekdays: [1, 2],
  startTime: '19:00',
  endTime: '21:00',
  enabled: true
});
assert.deepEqual(migratedRule.appTokens, ['old-token']);
assert.equal(migratedRule.name, '抖音');
assert.equal(migratedRule.weekdays.join(','), '1,2');
assert.equal(toGuardRule({
  id: 'r-new',
  name: '双应用',
  appTokens: ['x', 'x', 'y'],
  weekdays: [1],
  startTime: '19:00',
  endTime: '21:00',
  enabled: false
}).appTokens.join(','), 'x,y');
assert.equal(formatAppCount([]), '尚未选择应用');
assert.equal(formatAppCount(['a', 'b']), '限制 2 个应用');
assert.equal(formatWeekdays([1, 2, 3, 4, 5, 6, 7]), '每天');
assert.equal(formatWeekdays([1, 2, 3, 4, 5]), '周一至周五');
assert.equal(formatWeekdays([6, 7]), '周末');
assert.equal(formatWeekdays([1, 3, 5]), '周一、周三、周五');
assert.equal(isTimeText('00:00'), true);
assert.equal(isTimeText('23:59'), true);
assert.equal(isTimeText('24:00'), false);
assert.equal(isTimeText('9:00'), false);
const timeRule = {
  id: 'r-lock',
  name: '同花顺',
  appTokens: ['a'],
  weekdays: [1],
  startTime: '19:00',
  endTime: '21:00',
  enabled: true
};
assert.equal(isRuleActiveAt(timeRule, new Date(2026, 8, 7, 18, 59)), false);
assert.equal(isRuleActiveAt(timeRule, new Date(2026, 8, 7, 19, 0)), true);
assert.equal(isRuleActiveAt(timeRule, new Date(2026, 8, 7, 20, 59)), true);
assert.equal(isRuleActiveAt(timeRule, new Date(2026, 8, 7, 21, 0)), false);
assert.equal(isRuleActiveAt(timeRule, new Date(2026, 8, 8, 20, 0)), false);
assert.equal(isRuleScheduleActiveAt(timeRule, new Date(2026, 8, 8, 20, 0)), false);
const disabledTimeRule = { ...timeRule, enabled: false };
assert.equal(isRuleScheduleActiveAt(disabledTimeRule, new Date(2026, 8, 7, 20, 0)), true);
assert.equal(isRuleActiveAt(disabledTimeRule, new Date(2026, 8, 7, 20, 0)), false);
const sundayRule = { ...timeRule, weekdays: [7] };
assert.equal(isRuleActiveAt(sundayRule, new Date(2026, 8, 6, 20, 0)), true);
assert.equal(isRuleActiveAt(sundayRule, new Date(2026, 8, 7, 0, 0)), false);
assert.equal(validateRule({ id: 'r1', name: '  ', appTokens: ['a'], weekdays: [1], startTime: '19:00', endTime: '21:00', enabled: true }), '请填写规则名');
assert.equal(validateRule({ id: 'r1', name: '抖音', appTokens: [], weekdays: [1], startTime: '19:00', endTime: '21:00', enabled: true }), '请选择要限制的应用');
assert.equal(validateRule({ id: 'r1', name: '抖音', appTokens: ['', ' '], weekdays: [1], startTime: '19:00', endTime: '21:00', enabled: true }), '请选择要限制的应用');
assert.equal(validateRule({ id: 'r1', name: '抖音', appTokens: ['a', 'b'], weekdays: [], startTime: '19:00', endTime: '21:00', enabled: true }), '请至少选择一个生效日');
assert.equal(validateRule({ id: 'r1', name: '抖音', appTokens: ['a', 'b'], weekdays: [1], startTime: '21:00', endTime: '19:00', enabled: true }), '结束时间必须晚于开始时间');
assert.equal(validateRule({ id: 'r1', name: '抖音', appTokens: ['a', 'b'], weekdays: [1], startTime: '19:00', endTime: '21:00', enabled: true }), '');
assert.equal(formatRuleTime({ startTime: '19:00', endTime: '21:00' }), '19:00 – 21:00');
assert.equal(buildStrategyName('abc'), 'rule_abc');

console.log('guard rule tests passed (34 cases)');
