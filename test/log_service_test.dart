import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_racing/services/log_service.dart';

/// LogService 必须在无插件环境下可用：文件不可用时降级内存模式且不抛。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('初始化失败时降级为内存日志且不抛', () async {
    await LogService.init();
    LogService.info('测试日志条目');
    LogService.warning('测试告警条目');
    LogService.error('测试错误条目', StateError('boom'));

    final logs = LogService.getRecentLogs();
    expect(logs.any((l) => l.contains('测试日志条目')), isTrue);
    expect(logs.any((l) => l.contains('测试告警条目')), isTrue);
    expect(logs.any((l) => l.contains('测试错误条目')), isTrue);
    expect(logs.any((l) => l.contains('boom')), isTrue);
  });

  test('日志行带级别与时间戳格式', () {
    LogService.info('格式检查');
    final logs = LogService.getRecentLogs();
    final line = logs.lastWhere((l) => l.contains('格式检查'));
    expect(line.startsWith('['), isTrue);
    expect(line.contains('[INFO]'), isTrue);
  });
}
