import 'dart:async';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'pages/home_page.dart';
import 'providers/settings_provider.dart';
import 'services/file_system_service.dart';
import 'services/log_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'utils/constants.dart';

const _startupStepTimeout = Duration(seconds: 10);

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 全局异常捕获：所有框架/异步错误先落日志，设置页可查看并反馈
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      LogService.error(
        'Flutter 框架异常',
        details.exception,
        details.stack,
      );
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      LogService.error('未捕获的异步异常', error, stack);
      return true;
    };

    if (Platform.isWindows) {
      await _startupStep('Windows 窗口初始化', () async {
        await windowManager.ensureInitialized();
        const opts = WindowOptions(
          size: Size(1280, 720),
          minimumSize: Size(960, 540),
          center: true,
          skipTaskbar: false,
          titleBarStyle: TitleBarStyle.normal,
          title: AppConstants.appName,
        );
        windowManager.waitUntilReadyToShow(opts, () async {
          await windowManager.show();
          await windowManager.focus();
        });
      });
    }

    await _startupStep('本地存储初始化', () async {
      await StorageService.instance;
    });
    await _startupStep('日志服务初始化',
        () => LogService.init(logRoot: FileSystemService.instance.getLogRoot));

    LogService.info('应用启动: ${AppConstants.appName} v${AppConstants.version}');
    LogService.info(
      '运行环境: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    );
    LogService.info('日志文件: ${LogService.logFilePath}');

    // 赛车游戏全局锁横屏
    await _startupStep('横屏偏好设置', () async {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    });

    final storage = StorageService.instanceSync;
    if (storage == null) {
      LogService.error('本地存储初始化失败，进入降级提示界面');
      runApp(const _FatalStartupApp());
      return;
    }
    runApp(RacingApp(storage: storage));
  }, (error, stack) {
    LogService.error('根 Zone 未捕获异常', error, stack);
  });
}

/// 启动步骤统一兜底：失败或超时只记录日志并降级继续，绝不阻断 runApp。
Future<void> _startupStep(String name, Future<void> Function() action) async {
  final watch = Stopwatch()..start();
  try {
    await action().timeout(_startupStepTimeout);
    LogService.info('启动步骤完成: $name (${watch.elapsedMilliseconds}ms)');
  } catch (e, stack) {
    LogService.error('启动步骤失败（已降级继续）: $name', e, stack);
  }
}

/// 关键服务初始化失败时的降级界面，避免出现"无提示黑屏"。
class _FatalStartupApp extends StatelessWidget {
  const _FatalStartupApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 56,
                  color: Color(0xFFE53935),
                ),
                const SizedBox(height: 16),
                const Text(
                  '应用初始化失败，无法继续运行。\n请将日志目录下的日志文件反馈给开发者。',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  LogService.logFilePath.isEmpty
                      ? '（日志文件不可用，仅内存日志）'
                      : '日志文件：${LogService.logFilePath}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RacingApp extends StatelessWidget {
  final StorageService storage;

  const RacingApp({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    final fontFamily = Platform.isWindows ? 'Microsoft YaHei UI' : null;
    return ChangeNotifierProvider(
      create: (_) => SettingsProvider(storage),
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: buildLightTheme(fontFamily: fontFamily),
            darkTheme: buildDarkTheme(fontFamily: fontFamily),
            themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('zh', 'CN')],
            locale: const Locale('zh', 'CN'),
            home: const HomePage(),
          );
        },
      ),
    );
  }
}
