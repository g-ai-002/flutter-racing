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
  String _logContent = '';
  String _logDir = '';

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _loadLogDir();
  }

  Future<void> _loadLogs() async {
    final logs = LogService.getRecentLogs(200);
    if (mounted) {
      setState(() => _logContent = logs.join('\n'));
    }
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
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // 外观
          const _SectionHeader(title: '外观'),
          SwitchListTile(
            title: const Text('深色模式'),
            subtitle: const Text('切换深色/浅色主题'),
            secondary: Icon(
              settings.darkMode ? Icons.dark_mode : Icons.light_mode,
              color: theme.colorScheme.primary,
            ),
            value: settings.darkMode,
            onChanged: (value) => settings.setDarkMode(value),
          ),

          const Divider(),

          // 音效
          const _SectionHeader(title: '音效'),
          SwitchListTile(
            title: const Text('游戏音效'),
            subtitle: const Text('引擎声、道具与背景音乐'),
            secondary: Icon(
              settings.soundEnabled ? Icons.volume_up : Icons.volume_off,
              color: theme.colorScheme.primary,
            ),
            value: settings.soundEnabled,
            onChanged: (value) => settings.setSoundEnabled(value),
          ),

          const Divider(),

          // 关于
          const _SectionHeader(title: '关于'),
          ListTile(
            leading: Icon(Icons.info_outline, color: theme.colorScheme.primary),
            title: const Text('版本'),
            subtitle: const Text(AppConstants.version),
          ),
          // 日志目录
          if (_logDir.isNotEmpty)
            _buildDirTile(
              theme,
              icon: Icons.folder_special,
              title: '日志目录',
              path: _logDir,
              hint: '出现问题时可提供此目录下日志文件',
            ),
          ListTile(
            leading: Icon(
              Icons.description_outlined,
              color: theme.colorScheme.primary,
            ),
            title: const Text('查看日志'),
            subtitle: const Text('查看应用运行日志'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLogDialog(context),
          ),

          const Divider(),

          // 提示
          const _SectionHeader(title: '提示'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: Text(
              '漂移小技巧：按住漂移键过弯集气，能量条满一档松开小喷、满两档大喷；'
              '直道用氮气道具冲刺，弯道前丢香蕉皮防守。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirTile(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String path,
    required String hint,
  }) {
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            path,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.copy, color: theme.colorScheme.primary),
            tooltip: '复制路径',
            onPressed: () => _copyText(context, path),
          ),
          if (_canOpenDir)
            IconButton(
              icon: Icon(Icons.open_in_new, color: theme.colorScheme.primary),
              tooltip: '打开目录',
              onPressed: () async {
                final ok =
                    await FileSystemService.instance.openDirectory(path);
                if (!ok && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('当前平台不支持打开目录')),
                  );
                }
              },
            ),
        ],
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
    _loadLogs();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBar(
                    title: const Text('应用日志'),
                    automaticallyImplyLeading: false,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () {
                          _loadLogs();
                          setDialogState(() {});
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        tooltip: '复制全部',
                        onPressed: () => _copyText(ctx, _logContent),
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
                        _logContent.isEmpty ? '暂无日志' : _logContent,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
