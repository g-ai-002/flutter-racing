import 'dart:io';

import 'package:flutter/foundation.dart';

import 'file_system_service.dart';

/// 日志服务：内存环形缓冲 + 按天文件落盘。
///
/// - 初始化前产生的日志先进入早期缓冲，初始化后自动补写文件；
/// - 日志目录不可用时（单测/异常环境）降级为仅内存模式，绝不阻断启动；
/// - 设置页可读取最近日志、复制内容或打开日志目录。
class LogService {
  static LogService? _instance;
  static final List<String> _earlyBuffer = [];
  File? _logFile;
  bool _initialized = false;
  final List<String> _buffer = [];
  static const int _maxBufferLines = 2000;
  static const int _maxEarlyLines = 500;

  LogService._();

  static Future<void> init() async {
    _instance ??= LogService._();
    await _instance!._init();
  }

  Future<void> _init() async {
    if (_initialized) return;
    _logFile = await _openLogFileSafely();
    _initialized = true;
    // 补写初始化前的早期日志（启动步骤失败等）
    if (_earlyBuffer.isNotEmpty) {
      for (final line in _earlyBuffer) {
        _appendLine(line);
      }
      _earlyBuffer.clear();
    }
    _write(
      'INFO',
      '==== LogService 已初始化, 日志文件: ${_logFile?.path ?? '内存模式'} ====',
    );
  }

  static Future<File?> _openLogFileSafely() async {
    try {
      final dir = await FileSystemService.instance.getLogRoot();
      final now = DateTime.now();
      final dateStr =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final file = File('${dir.path}${Platform.pathSeparator}app_$dateStr.log');
      if (!await file.exists()) {
        await file.create(recursive: true);
      }
      return file;
    } catch (e) {
      debugPrint('[LogService] 日志文件不可用，降级为内存日志: $e');
      return null;
    }
  }

  /// 当前日志文件路径（内存模式或未初始化时为空串）
  static String get logFilePath => _instance?._logFile?.path ?? '';

  static void info(String message) => _log('INFO', message);

  static void warning(String message) => _log('WARN', message);

  static void error(String message, [Object? error, StackTrace? stack]) {
    final msg = error != null ? '$message | $error' : message;
    _log('ERROR', msg);
    if (stack != null) {
      _log('ERROR', stack.toString());
    }
  }

  static void _log(String level, String message) {
    final inst = _instance;
    if (inst == null || !inst._initialized) {
      final line = _formatLine(level, message);
      _earlyBuffer.add(line);
      if (_earlyBuffer.length > _maxEarlyLines) {
        _earlyBuffer.removeAt(0);
      }
      return;
    }
    inst._write(level, message);
  }

  static String _formatLine(String level, String message) {
    final now = DateTime.now();
    final ts =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';
    return '[$ts][$level] $message';
  }

  void _write(String level, String message) {
    final line = _formatLine(level, message);
    _buffer.add(line);
    if (_buffer.length > _maxBufferLines) {
      _buffer.removeAt(0);
    }
    _appendLine(line);
  }

  void _appendLine(String line) {
    try {
      _logFile?.writeAsStringSync('$line\n', mode: FileMode.append);
    } catch (_) {}
  }

  /// 最近日志（内存缓冲，含尚未落盘的早期日志）
  static List<String> getRecentLogs([int lines = 200]) {
    final inst = _instance;
    final all = <String>[
      ..._earlyBuffer,
      if (inst != null) ...inst._buffer,
    ];
    if (all.length <= lines) {
      return all;
    }
    return all.sublist(all.length - lines);
  }
}
