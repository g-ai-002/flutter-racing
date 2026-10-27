# 极速卡丁车

类跑跑卡丁车 / QQ飞车玩法的 Flutter 赛车游戏，支持 Android、Windows 与 Web 三平台。

## 功能特性

- 🏁 俯视角 2D 手绘赛道：镜头随车头旋转，滨海/沙漠/雪山三主题
- 🎮 三种比赛模式：道具赛 / 竞速赛 / 计时赛
- 🔥 漂移集气：按住漂移键过弯攒能量，松开按档位触发小喷/大喷
- 💨 氮气加速：道具氮气直道冲刺，尾焰与速度线特效
- 🎯 道具系统：追踪导弹 / 水弹 / 香蕉皮 / 护盾，道具箱定时刷新
- 🤖 AI 车手 ×3：中心线前瞻过弯 + 弯道限速 + 橡皮筋难度 + 道具使用策略
- 🏎️ 4 名车手角色：极速/加速/操控属性差异，车库选择
- 🗺️ 赛道系统：闭合样条中心线、检查点防抄近道、红白路缘、格纹起跑线、小地图
- 📊 完整比赛流程：3-2-1 倒计时、实时名次、圈速计时、最佳圈纪录、结算页
- 🎵 程序化 chiptune 音效：引擎声随速变速、漂移摩擦、道具/爆炸/BGM
- 🎨 Material 3 设计：浅色/深色主题
- 📱 跨平台：Android（触屏按钮）+ Windows（键盘）+ Web（键盘与触屏按钮自适应）
- 🧭 平台自适应提示：桌面讲键盘按键，移动端与浏览器讲触屏按钮
- ⏸️ 暂停与结算时停掉 Flame 主循环，避免后台空转重绘
- 🕹️ Web 版：发布 tag 自动构建并部署到 GitHub Pages，每个 tag 一个独立版本

## 操作说明

| 操作 | 桌面端 | 移动端 |
|------|--------|--------|
| 油门 | ↑ / W | 自动油门 |
| 转向 | ← → / A D | 左右转向按钮 |
| 刹车 | ↓ / S | 刹车按钮 |
| 漂移 | 空格（按住） | 漂移按钮 |
| 道具 | Ctrl / E | 道具按钮 |
| 暂停 | P / Esc | 暂停按钮 |

浏览器里打开 Web 版时，键盘与触屏按钮同时可用：桌面浏览器按上表左列操作，
手机/平板浏览器按右列的触屏按钮操作。

## 玩法规则

- 道具赛：拾取道具箱，用导弹与水弹攻击前方对手、香蕉皮防守、氮气冲刺，最先跑完 3 圈获胜
- 竞速赛：无道具，专注漂移集气与走线
- 计时赛：单人挑战，刷新每条赛道的最佳圈速与最佳总成绩（本地保存）
- 漂移积气一档小喷、两档大喷；出路面大幅减速；逆行会有警告提示

## 版本历史

### v0.3.0 (2026-10-27)

- 支持 Web 平台与 GitHub Pages 多版本在线试玩
- 日志、文件系统、窗口初始化改为条件导入，Web 端保留内存日志
- 静态网格/地形烘焙为 `ui.Picture`，暂停/结算时停掉 Flame 主循环
- 操作提示按桌面、触屏与浏览器自适应
- 版本号 0.2.1 → 0.3.0

### v0.2.1 (2026-10-24)
- 赛道几何一次性计算采样点包围盒，小地图与静态赛道层复用
- 静态赛道层按赛道缓存，重开同赛道不再重复录制矢量指令
- HUD 通知节流到约 10Hz，阶段切换与使用道具立即通知
- 补充 HUD 节流与包围盒回归测试

### v0.2.0 (2026-10-24)
- 比赛渲染与 60Hz 主循环迁移到 Flame 1.38.2（World + CameraComponent）
- 静态赛道层改为组件回放矢量 Picture，镜头跟随/旋转/缩放交给相机
- 胎痕、道具箱、水弹、导弹、卡丁车、粒子与速度线拆为 Flame 组件
- HUD、小地图、触屏控件与结算/暂停界面保持 Flutter 实现

### v0.1.0 (2026-10-22)
- 首个版本：俯视角卡丁车竞速最小可用集
- 三种比赛模式（道具赛/竞速赛/计时赛）与三条主题赛道
- 漂移集气/氮气物理、道具系统、AI 车手、名次与圈速结算
- 程序化 chiptune 音效（引擎随速变速 + BGM）
- Android 触屏控制 + Windows 键盘控制，横屏锁定
- 统一签名、阿里云镜像、GitHub/Gitea 双 CI、13 条 lint 规则

## 下载

- [GitHub Releases](https://github.com/g-ai-002/flutter-racing/releases)

发布产物包含 Android APK（arm64-v8a）、Windows ZIP（x86-64）与 Web 归档
（`-web.zip`）。

### 在线试玩

推送到 GitHub 的每个 `v*` tag 都会额外构建 Web 版并发布到 GitHub Pages，
各版本互不覆盖，历史版本长期保留：

- 版本列表：<https://g-ai-002.github.io/flutter-racing/>
  （首页顶部是最新正式版本的醒目入口，点开即玩；下方分「正式版本」与
  「调试版本」两列，历史正式版本从新到旧排列）
- 预览版：<https://g-ai-002.github.io/flutter-racing/debug/>

非 tag 触发（手动运行 `构建与发布` 工作流）构建出来的站点会发到 `debug/`
目录，方便合并前验证效果；tag 触发时除了更新 `v<版本>/`，还会把 Web 产物
`<仓库名>-<版本>-web.zip` 一并归档到 GitHub Release，与 APK、Windows ZIP 放在一起。

Pages 首次使用需在仓库 Settings → Pages 里把发布来源设为 `gh-pages` 分支的
根目录；之后每次推送 tag 都会自动更新站点（含版本索引页与 `versions.json`）。

## 开发

```bash
# 安装依赖
flutter pub get

# 运行测试
flutter test

# 运行应用
flutter run

# 重新生成音效资产（需要 Python 3）
python .build/generate_audio.py
```

### Web 预览与构建

`web/` 属于平台生成文件，不入库；首次在本地构建 Web 前先生成平台目录：

```bash
flutter create --platforms=web --project-name flutter_racing .
flutter run -d chrome
```

构建发布版本时 `--base-href` 必须与线上路径一致，否则资源会 404：

```bash
flutter build web --release --base-href /flutter-racing/v0.3.0/
```

Web 端没有可写目录，日志退化为内存缓冲（设置页仍可查看、复制），
「打开目录」按钮在浏览器里自动隐藏。

## 技术栈

- Flutter 3.47.7（Android / Windows / Web）
- Provider 状态管理
- Material 3 设计系统
- Flame 1.38.2 游戏引擎（组件化世界 + 相机跟随）
- audioplayers 音频
- 条件导入隔离平台能力：`dart:io`、`path_provider`、`window_manager` 只进 IO 实现
- GitHub Pages 多版本站点：每个 tag 一个子目录，根目录自动生成版本索引
