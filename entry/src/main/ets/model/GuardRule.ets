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
 * 判断规则的时间窗在指定时刻是否命中（忽略启用状态）。
 *
 * 生效区间为左闭右开：开始分钟命中，结束分钟不命中。
 *
 * @param rule 规则。
 * @param now 当前时间。
 * @returns 当前星期和时间落在规则时间窗内时返回 true。
 */
export function isRuleScheduleActiveAt(rule: GuardRule, now: Date): boolean {
  const weekday: number = now.getDay() === 0 ? 7 : now.getDay();
  if (normalizeWeekdays(rule.weekdays).indexOf(weekday) === -1) {
    return false;
  }
  const currentMinutes: number = now.getHours() * 60 + now.getMinutes();
  return currentMinutes >= toTimeMinutes(rule.startTime) && currentMinutes < toTimeMinutes(rule.endTime);
}

/**
 * 判断规则当前是否处于生效锁定状态。
 *
 * 仅当规则已启用且时间窗命中时才返回 true，用于锁定停用、删除和编辑入口。
 *
 * @param rule 规则。
 * @param now 当前时间。
 * @returns 规则正在生效时返回 true。
 */
export function isRuleActiveAt(rule: GuardRule, now: Date): boolean {
  return rule.enabled && isRuleScheduleActiveAt(rule, now);
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
