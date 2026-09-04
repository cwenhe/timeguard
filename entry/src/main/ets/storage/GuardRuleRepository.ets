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
