import { router } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { formatRuleTime, formatWeekdays, GuardRule, isRuleActiveAt, isRuleScheduleActiveAt } from '../model/GuardRule';
import { ScreenTimeGuardService } from '../service/ScreenTimeGuardService';
import { GuardRuleRepository } from '../storage/GuardRuleRepository';

@Entry
@Component
struct RuleListPage {
  @State private rules: GuardRule[] = [];
  @State private now: Date = new Date();
  @State private busy: boolean = false;
  @State private statusText: string = '正在同步规则…';
  @State private statusColor: string = '#64748B';
  private timerId: number = -1;
  private readonly repository: GuardRuleRepository = GuardRuleRepository.getInstance();
  private readonly guardService: ScreenTimeGuardService = ScreenTimeGuardService.getInstance();

  /**
   * 页面显示（含从编辑页返回）时从本地读取规则，并按系统真实策略校准启用状态。
   */
  public onPageShow(): void {
    this.startTick();
    void this.loadRules();
  }

  /**
   * 页面隐藏时停止生效状态刷新定时器。
   */
  public onPageHide(): void {
    this.stopTick();
  }

  /**
   * 启动定时刷新当前时间，让“限制生效中”状态能随规则时间窗自动变化。
   */
  private startTick(): void {
    this.stopTick();
    this.timerId = setInterval(() => {
      this.now = new Date();
    }, 30000);
  }

  /**
   * 停止当前生效状态刷新定时器。
   */
  private stopTick(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  /**
   * 用最新系统时间判断规则是否正在生效，供操作前做最终拦截。
   *
   * @param rule 规则。
   * @returns 生效中返回 true。
   */
  private isRuleActiveNow(rule: GuardRule): boolean {
    return isRuleActiveAt(rule, new Date());
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
    const target: GuardRule | undefined = this.rules.find((item: GuardRule): boolean => item.id === ruleId);
    if (target !== undefined && this.isRuleActiveNow(target)) {
      this.showStatus('error', `“${target.name}”正在生效，本时段内不能编辑`);
      return;
    }
    void router.pushUrl({
      url: 'pages/RuleEditPage',
      params: { ruleId }
    });
  }

  /**
   * 统一处理启用/停用入口：生效中禁止停用，立即生效的启用先弹确认。
   *
   * @param rule 规则。
   * @param enabled 目标启用状态。
   */
  private async toggleRule(rule: GuardRule, enabled: boolean): Promise<void> {
    if (this.busy) {
      return;
    }
    if (!enabled && this.isRuleActiveNow(rule)) {
      this.showStatus('error', `“${rule.name}”正在生效，本时段内不能停用`);
      return;
    }
    if (enabled && isRuleScheduleActiveAt(rule, this.now)) {
      this.confirmEnableNow(rule);
      return;
    }
    await this.doSetRuleEnabled(rule, enabled);
  }

  /**
   * 弹出“规则立即生效且本时段内不能解除”的确认框。
   *
   * @param rule 规则。
   */
  private confirmEnableNow(rule: GuardRule): void {
    AlertDialog.show({
      title: '规则将立即生效',
      message: `“${rule.name}”当前时间已在生效时段内，启用后本时段内不能停用或修改。是否继续？`,
      primaryButton: {
        value: '仍要启用',
        action: () => {
          void this.doSetRuleEnabled(rule, true);
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {
        }
      }
    });
  }

  /**
   * 执行真正的启用/停用系统策略与本地保存。
   *
   * @param rule 规则。
   * @param enabled 目标启用状态。
   */
  private async doSetRuleEnabled(rule: GuardRule, enabled: boolean): Promise<void> {
    this.busy = true;
    const updated: GuardRule = this.copyRule(rule, enabled);
    try {
      if (enabled) {
        await this.guardService.applyRule(updated);
      } else {
        await this.guardService.deactivateRule(updated);
      }
      await this.repository.saveRule(updated);
      this.replaceRule(updated);
      this.showStatus('idle', enabled ? `“${rule.name}”已启用` : `“${rule.name}”已停用`);
    } catch (error) {
      this.showStatus('error', `${enabled ? '启用' : '停用'}失败：${this.guardService.describeError(error as BusinessError)}`);
      this.rules = await this.repository.loadRules();
    } finally {
      this.busy = false;
    }
  }

  private confirmDelete(rule: GuardRule): void {
    if (this.isRuleActiveNow(rule)) {
      this.showStatus('error', `“${rule.name}”正在生效，本时段内不能删除`);
      return;
    }
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
      this.rules = this.rules.filter((item: GuardRule): boolean => item.id !== rule.id);
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

  private replaceRule(updated: GuardRule): void {
    const next: GuardRule[] = this.rules.slice();
    const index: number = next.findIndex((item: GuardRule): boolean => item.id === updated.id);
    if (index >= 0) {
      next.splice(index, 1, updated);
    } else {
      next.push(updated);
    }
    this.rules = next;
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
                  .enabled(!this.busy && !isRuleActiveAt(rule, this.now))
                  .onChange((value: boolean) => {
                    void this.toggleRule(rule, value);
                  })
              }
              .width('100%')

              if (isRuleActiveAt(rule, this.now)) {
                Text('限制生效中：本时段内不能停用或修改')
                  .fontSize(12)
                  .fontColor('#B45309')
              }

              Row({ space: 12 }) {
                Button('编辑')
                  .fontSize(14)
                  .backgroundColor('#1D4ED8')
                  .enabled(!isRuleActiveAt(rule, this.now))
                  .onClick(() => {
                    this.openEditPage(rule.id);
                  })
                Button('删除')
                  .fontSize(14)
                  .backgroundColor('#E11D48')
                  .enabled(!isRuleActiveAt(rule, this.now))
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
