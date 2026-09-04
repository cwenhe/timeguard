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
