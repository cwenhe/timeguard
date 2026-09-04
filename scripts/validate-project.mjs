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

/**
 * 执行工程骨架、权限、页面注册和核心 API 的静态门禁。
 */
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
