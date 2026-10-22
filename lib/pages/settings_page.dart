import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../utils/constants.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: SafeArea(
        child: ListView(
          children: [
            SwitchListTile(
              secondary: Icon(
                settings.soundEnabled ? Icons.volume_up : Icons.volume_off,
              ),
              title: const Text('游戏音效'),
              subtitle: const Text('引擎声、道具与背景音乐'),
              value: settings.soundEnabled,
              onChanged: (v) => settings.setSoundEnabled(v),
            ),
            SwitchListTile(
              secondary: Icon(
                settings.darkMode ? Icons.dark_mode : Icons.light_mode,
              ),
              title: const Text('深色模式'),
              subtitle: const Text('界面主题配色'),
              value: settings.darkMode,
              onChanged: (v) => settings.setDarkMode(v),
            ),
            const Divider(height: 1),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('关于'),
              subtitle: Text(
                '${AppConstants.appName} v${AppConstants.version}\n'
                'Flutter 赛车游戏 · Android + Windows',
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '漂移小技巧：按住漂移键过弯集气，能量条满一档松开小喷、满两档大喷；'
                '直道用氮气道具冲刺，弯道前丢香蕉皮防守。',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
