import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../services/file_system_service.dart';
import '../services/log_service.dart';
import '../utils/constants.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _logDir = '';

  @override
  void initState() {
    super.initState();
    _loadLogDir();
  }

  Future<void> _loadLogDir() async {
    try {
      final dir = await FileSystemService.instance.getLogRoot();
      if (!mounted) {
        return;
      }
      setState(() => _logDir = dir.path);
    } catch (e, stack) {
      LogService.error('读取日志目录失败', e, stack);
    }
  }

  bool get _canOpenDir =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final logFile = LogService.logFilePath;

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
            ListTile(
              leading: const Icon(Icons.folder_special),
              title: const Text('日志目录'),
              subtitle: Text(
                _logDir.isEmpty ? '正在获取…' : _logDir,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: '复制路径',
                    onPressed:
                        _logDir.isEmpty ? null : () => _copyText(context, _logDir),
                  ),
                  if (_canOpenDir)
                    IconButton(
                      icon: const Icon(Icons.open_in_new),
                      tooltip: '打开目录',
                      onPressed: _logDir.isEmpty
                          ? null
                          : () async {
                              final ok = await FileSystemService.instance
                                  .openDirectory(_logDir);
                              if (!ok && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('打开目录失败')),
                                );
                              }
                            },
                    ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('查看日志'),
              subtitle: Text(
                logFile.isEmpty ? '内存日志' : logFile,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLogDialog(context),
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

  void _copyText(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制到剪贴板'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showLogDialog(BuildContext context) {
    final logs = LogService.getRecentLogs(200);
    final content = logs.isEmpty ? '暂无日志' : logs.join('\n');
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: const Text('应用日志（最近 200 行）'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: '复制全部',
                    onPressed: () => _copyText(ctx, content),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    content,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
