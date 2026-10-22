# 极速卡丁车 — 项目规划

## 长期目标
- 跨 Android + Windows 双平台的卡丁车竞速游戏（类跑跑卡丁车 / QQ飞车玩法）
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
- **无引擎依赖**：CustomPainter 自绘渲染，依赖均为成熟稳定的纯 Dart / Flutter 插件。
- **可观测**：关键操作写入日志文件，方便排障。
- **几何可回归**：赛道控制点经数值验证（自交/最小半径/车道净空），CI 测试同口径把关。

## 依赖与版本基线
- Flutter: 3.47.7（CI 固定）
- provider: 6.1.5+1
- window_manager: 0.5.2
- shared_preferences: 2.5.6
- path_provider: 2.1.6
- path: 1.9.1
- audioplayers: 6.8.1
