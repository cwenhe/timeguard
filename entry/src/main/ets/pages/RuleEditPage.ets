import { LengthMetrics, router } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import {
  GuardRule,
  isRuleActiveAt,
  isRuleScheduleActiveAt,
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
  @State private now: Date = new Date();
  @State private busy: boolean = false;
  @State private statusText: string = '';
  @State private statusColor: string = '#64748B';
  private timerId: number = -1;
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
      this.startTick();
      return;
    }
    this.ruleId = id;
    this.startTick();
    void this.loadRule(id);
  }

  /**
   * 页面销毁时停止生效状态刷新定时器。
   */
  public aboutToDisappear(): void {
    this.stopTick();
  }

  /**
   * 启动定时刷新当前时间，让编辑页能自动进入/退出生效锁定状态。
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
   * 判断当前正在编辑的规则是否正处于生效锁定状态。
   *
   * @returns 生效中返回 true。
   */
  private isEditingActive(): boolean {
    return this.existingRule !== null && isRuleActiveAt(this.existingRule, this.now);
  }

  /**
   * 用最新系统时间判断正在编辑的规则是否已进入生效状态。
   *
   * @returns 生效中返回 true。
   */
  private isEditingActiveNow(): boolean {
    return this.existingRule !== null && isRuleActiveAt(this.existingRule, new Date());
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
    if (this.isEditingActiveNow()) {
      this.showStatus('error', '该规则正在生效，本时段内不能修改，结束后自动解除');
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
      enabled: this.existingRule !== null ? this.existingRule.enabled : true
    };
    const errorMessage: string = validateRule(candidate);
    if (errorMessage.length > 0) {
      this.showStatus('error', errorMessage);
      return;
    }
    if (candidate.enabled && isRuleScheduleActiveAt(candidate, this.now) &&
      (this.existingRule === null || !isRuleActiveAt(this.existingRule, this.now))) {
      this.confirmImmediateSave(candidate);
      return;
    }
    await this.doSaveRule(candidate);
  }

  /**
   * 弹出“规则保存后立即生效且本时段内不能解除”的确认框。
   *
   * @param candidate 待保存规则。
   */
  private confirmImmediateSave(candidate: GuardRule): void {
    AlertDialog.show({
      title: '规则将立即生效',
      message: '当前时间已在规则生效时段内，保存后本时段内不能停用或修改。是否继续？',
      primaryButton: {
        value: '仍要保存',
        action: () => {
          void this.doSaveRule(candidate);
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
   * 执行真正的本地保存与系统策略同步。
   *
   * @param candidate 待保存规则。
   */
  private async doSaveRule(candidate: GuardRule): Promise<void> {
    this.busy = true;
    try {
      if (candidate.enabled) {
        if (this.existingRule !== null && this.existingRule.enabled && this.existingRule.appToken !== candidate.appToken) {
          await this.guardService.deactivateRule(this.existingRule);
        }
        await this.guardService.applyRule(candidate);
      }
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

  /**
   * 打开开始时间选择弹窗，用户确认后才更新开始时间。
   */
  private editStartTime(): void {
    this.openTimeDialog(this.timeToDate(this.startTime), (value: TimePickerResult): void => {
      this.startTime = this.dateToTime(new Date(2026, 0, 1, value.hour, value.minute));
    });
  }

  /**
   * 打开结束时间选择弹窗，用户确认后才更新结束时间。
   */
  private editEndTime(): void {
    this.openTimeDialog(this.timeToDate(this.endTime), (value: TimePickerResult): void => {
      this.endTime = this.dateToTime(new Date(2026, 0, 1, value.hour, value.minute));
    });
  }

  /**
   * 弹出系统 24 小时制时间选择弹窗，只有 onAccept 回调才提交选择。
   *
   * @param selected 弹窗初始时间。
   * @param onAccept 用户点确定后执行的回调。
   */
  private openTimeDialog(selected: Date, onAccept: (value: TimePickerResult) => void): void {
    this.getUIContext().showTimePickerDialog({
      selected,
      useMilitaryTime: true,
      onAccept
    });
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
          if (this.isEditingActive()) {
            Text('该规则正在生效：本时段内不能修改，结束后自动解除')
              .fontSize(13)
              .fontColor('#B45309')
              .width('100%')
          }

          TextInput({ text: this.ruleName, placeholder: '规则名，例如：抖音' })
            .height(48)
            .onChange((value: string) => {
              this.ruleName = value;
            })

          Text('生效星期')
            .fontSize(14)
            .fontColor('#334155')
          Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(10), cross: LengthMetrics.vp(10) } }) {
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

          Row() {
            Text('开始时间')
              .fontSize(15)
              .fontColor('#334155')
            Blank()
            Text(this.startTime)
              .fontSize(22)
              .fontWeight(FontWeight.Medium)
              .fontColor('#0F172A')
            Text('›')
              .fontSize(24)
              .fontColor('#94A3B8')
              .margin({ left: 8 })
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .borderRadius(12)
          .backgroundColor('#FFFFFF')
          .onClick(() => {
            this.editStartTime();
          })

          Row() {
            Text('结束时间')
              .fontSize(15)
              .fontColor('#334155')
            Blank()
            Text(this.endTime)
              .fontSize(22)
              .fontWeight(FontWeight.Medium)
              .fontColor('#0F172A')
            Text('›')
              .fontSize(24)
              .fontColor('#94A3B8')
              .margin({ left: 8 })
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .borderRadius(12)
          .backgroundColor('#FFFFFF')
          .onClick(() => {
            this.editEndTime();
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
        .enabled(!this.busy && !this.isEditingActive())
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
