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
    const context: common.UIAbilityContext = this.requireContext();
    await guardService.requestUserAuth(context);
  }

  /**
   * 拉起系统应用选择页并返回目标应用 token。
   *
   * @param previousToken 编辑时用于预勾选的原 token，可为空字符串。
   * @returns 选中的应用 token。
   */
  public async pickTargetApp(previousToken: string): Promise<string> {
    const context: common.UIAbilityContext = this.requireContext();
    await this.requestUserAuth();
    const selected: string[] = await appPicker.startAppPicker(context, {
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
        const detail: string = businessError.message !== undefined && businessError.message.length > 0
          ? businessError.message
          : `错误码 ${businessError.code}`;
        throw new Error(`守护策略停止失败：${detail}`);
      }
    }
  }
}
