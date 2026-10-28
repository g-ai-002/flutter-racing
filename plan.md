# 极速卡丁车 — 项目规划

## 长期目标
- 跨 Android + Windows + Web 三平台的卡丁车竞速游戏（类跑跑卡丁车 / QQ飞车玩法）
- 精美克制的界面，操作与主流赛车游戏一致
- 持续可演进：每个版本可独立交付，可观测、可回滚

## 中期目标
- [x] 卡丁车竞速核心玩法（漂移集气、氮气、多圈竞速）
- [x] 道具系统（导弹/水弹/香蕉皮/护盾/氮气）
- [x] AI 车手（前瞻转向、弯道限速、橡皮筋、道具策略）
- [x] 三条主题赛道 + 车手车库
- [x] 音效与背景音乐（程序化生成）
- [ ] 排行榜与成就系统
- [ ] 车辆涂装自定义
- [ ] 自适应布局（折叠屏/平板/桌面）

## 短期目标
- 持续按版本节奏推进：新功能 → patch 修复 → patch 重构

---

## 版本历史

### Web 平台适配（2026-10-27，未发版）
- **状态**: 开发完成，待发版 🚧
- **目标**: 让同一套代码在 Android / Windows / Web 三平台运行，并接入 GitHub Pages 多版本试玩
- **任务**:
  - [x] `LogService` 拆为条件导出 + `log_service_io.dart`（落盘）/`log_service_web.dart`（内存），`init` 的 `logRoot` 改为可选
  - [x] `FileSystemService` 拆为条件导出 + `_io`/`_web`，公开 API 统一为 `getLogRootPath()`/`getUserRootPath()`/`openDirectory()`
  - [x] 新增 `logging_init.dart/_io/_web`，IO 交 `Directory` 给日志服务，Web 直接内存初始化
  - [x] 新增 `utils/window_setup.dart/_io/_web`，`window_manager` 只留在 IO 实现
  - [x] 新增 `utils/platform_info.dart` 与 `utils/game_hints.dart`（桌面/触屏文案集中管理）
  - [x] `main.dart` 去掉 `dart:io` 与 `window_manager` 直接依赖，字体判断改用 `kIsWeb`/`defaultTargetPlatform`
  - [x] `race_page.dart`/`settings_page.dart`/`audio_service.dart` 去掉 `dart:io`，Web 隐藏「打开目录」
  - [x] `RaceGame` 在暂停/结算时 `pauseEngine()`，继续时由 provider 监听 `resumeEngine()`
  - [x] GitHub Actions 增加 `build-web`：tag 发 `v<版本>/`，其余发 `debug/`，写 gh-pages 与版本索引页
  - [x] 新增 `.github/pages/index.template.html`（赛车版操作说明）
  - [x] Gitea Actions 增加 `build-web`，只构建 `-web.zip` 并附到 Release
  - [x] README 增加 Web 平台、在线试玩入口与 Web 构建说明
  - [x] 更新 plan/versions（版本号暂不提升）

### v0.3.0 (MINOR)

- **状态**: 已发布 ✅
- **目标**: 支持 Web 平台并新增 GitHub Pages 多版本在线试玩
- **任务**:
  - [x] Web 平台条件导入：日志、文件系统、窗口初始化拆分 `_io` / `_web`
  - [x] Web 端日志回退到内存，设置页仍可查看
  - [x] 静态网格/地形烘焙为 `ui.Picture`
  - [x] 暂停/结算时暂停 Flame 主循环，恢复时重启
  - [x] 平台自适应操作提示
  - [x] GitHub Pages 多版本站点与 Gitea Web ZIP 产物
  - [x] 静态赛道继续复用已有 `ui.Picture` 缓存
  - [x] 版本号 0.2.1 → 0.3.0
  - [x] 更新 README/plan/versions

### v0.2.1 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 比赛画面渲染性能优化
- **任务**:
  - [x] `TrackGeometry` 一次性计算采样点包围盒，供小地图与静态赛道层复用
  - [x] `StaticTrackLayer` 按赛道缓存，重开同赛道不再重复录制矢量指令
  - [x] `RaceProvider` HUD 通知节流到约 10Hz，阶段切换与使用道具立即通知
  - [x] 补充 HUD 节流与包围盒回归测试
  - [x] 版本号 0.2.0 → 0.2.1
  - [x] 更新 plan/versions

### v0.2.0 (MINOR)
- **状态**: 已发布 ✅
- **目标**: 将比赛渲染与 60Hz 主循环迁移到 Flame 引擎
- **任务**:
  - [x] 引入 Flame 1.38.2，比赛画面改为 `World` + `CameraComponent`
  - [x] 镜头跟随/旋转/缩放由相机承担（锚点 0.58 与旧画布变换一致）
  - [x] 静态赛道层改为组件回放矢量 Picture，构建失败退化为纯色地面
  - [x] 胎痕/道具箱/水弹/导弹/卡丁车/粒子拆为 `RaceWorldLayerComponent`
  - [x] 速度线拆为 viewport 屏幕空间组件
  - [x] 16ms Timer 主循环改为 `FlameGame.update` 驱动
  - [x] HUD、小地图、触屏控件、结算与暂停对话框保持 Flutter 实现
  - [x] 版本号 0.1.4 → 0.2.0
  - [x] 更新 README/plan/versions

### v0.1.0 (MINOR)
- **状态**: 已发布 ✅
- **目标**: 首个版本：卡丁车竞速最小可用集
- **任务**:
  - [x] 项目脚手架（pubspec/analysis_options/.gitignore/.metadata）
  - [x] Android 平台文件（manifest、build.gradle、统一签名、minSdk=35/targetSdk=37/compileSdk=37）
  - [x] 主题（Material 3 浅/深色、Windows YaHei UI）
  - [x] 数据模型（角色/赛道/卡丁车/比赛状态/引擎事件）
  - [x] 引擎层（赛道几何、卡丁车物理、AI 驾驶、道具、比赛编排）
  - [x] 服务层：日志、文件系统、存储（最佳圈速）、音频（引擎随速变速）
  - [x] 状态层：SettingsProvider / RaceProvider（60Hz 主循环）
  - [x] 界面：主页 / 赛前准备（车库+赛道）/ 比赛页 / 设置页
  - [x] Canvas 渲染（旋转镜头、赛道主题装饰、粒子特效、胎痕、HUD）
  - [x] 触屏控制（带指针销毁守护）+ 键盘控制
  - [x] 程序化音效生成脚本（.build/generate_audio.py，14 个 WAV）
  - [x] 赛道控制点数值验证（Python 设计期脚本 + Dart CI 测试双口径回归）
  - [x] 单元测试（9 个测试文件，含 AI 全链路跑圈回归）
  - [x] GitHub + Gitea Actions：lint + 单测 + Android APK + Windows ZIP + tag 自动 release
  - [x] README / plan / versions

---

## 设计原则
- **离线优先**：所有数据来自本地，不联网。
- **Flame 驱动**：渲染与主循环由 Flame 组件/相机承担，HUD 与菜单保持 Flutter 实现。
- **可观测**：关键操作写入日志文件，方便排障。
- **几何可回归**：赛道控制点经数值验证（自交/最小半径/车道净空），CI 测试同口径把关。

## 依赖与版本基线
- Flutter: 3.47.8（CI 固定）
- flame: 1.38.2
- provider: 6.1.5+1
- window_manager: 0.5.2
- shared_preferences: 2.5.6
- path_provider: 2.1.6
- path: 1.9.1
- audioplayers: 6.8.1
