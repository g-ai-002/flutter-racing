import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_racing/models/game_enums.dart';
import 'package:flutter_racing/models/track_def.dart';
import 'package:flutter_racing/providers/race_provider.dart';
import 'package:flutter_racing/services/storage_service.dart';
import 'package:flutter_racing/widgets/touch_controls.dart';

Future<RaceProvider> _makeRace() async {
  final storage = await StorageService.instance;
  return RaceProvider(
    storage: storage,
    trackDef: TrackCatalog.all[0],
    mode: RaceMode.itemRace,
    playerCharacterIndex: 0,
    autoThrottle: true,
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets('按住按钮触发按压回调，松开触发释放', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    var starts = 0;
    var ends = 0;
    await tester.pumpWidget(
      _wrap(
        Center(
          child: HoldButton(
            key: const Key('btn_hold'),
            label: '漂移',
            size: 96,
            onPressStart: () => starts++,
            onPressEnd: () => ends++,
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('btn_hold'))),
    );
    await tester.pump();
    expect(starts, 1);
    expect(ends, 0);

    await gesture.up();
    await tester.pump();
    expect(starts, 1);
    expect(ends, 1);
  });

  testWidgets('组件销毁后迟到的抬起事件不崩溃', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    var starts = 0;
    var ends = 0;
    await tester.pumpWidget(
      _wrap(
        Center(
          child: HoldButton(
            key: const Key('btn_hold'),
            label: '漂移',
            size: 96,
            onPressStart: () => starts++,
            onPressEnd: () => ends++,
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('btn_hold'))),
    );
    await tester.pump();
    expect(starts, 1);

    // 按住期间换树销毁组件，迟到的抬起事件必须被安全忽略
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await gesture.up();
    await tester.pump();
    expect(starts, 1);
  });

  testWidgets('TouchControls 渲染全部控制按钮', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final race = await _makeRace();
    await tester.pumpWidget(_wrap(TouchControls(race: race)));

    expect(find.byKey(const Key('btn_left')), findsOneWidget);
    expect(find.byKey(const Key('btn_right')), findsOneWidget);
    expect(find.byKey(const Key('btn_drift')), findsOneWidget);
    expect(find.byKey(const Key('btn_brake')), findsOneWidget);
    expect(find.text('道具'), findsOneWidget);
    race.dispose();
  });

  testWidgets('点击道具按钮使用玩家道具', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final race = await _makeRace();
    race.state.phase = RacePhase.running;
    race.state.player.item = ItemType.nitro;
    final speedBefore = race.state.player.speed;

    await tester.pumpWidget(_wrap(TouchControls(race: race)));
    await tester.tap(find.text('道具'));
    await tester.pump();

    expect(race.state.player.item, isNull);
    expect(race.state.player.speed, greaterThan(speedBefore));
    race.dispose();
  });
}
