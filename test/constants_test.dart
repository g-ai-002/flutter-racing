import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_racing/models/character.dart';
import 'package:flutter_racing/models/game_enums.dart';
import 'package:flutter_racing/models/track_def.dart';
import 'package:flutter_racing/utils/constants.dart';

void main() {
  test('版本与应用名', () {
    expect(AppConstants.version, '0.1.3');
    expect(AppConstants.appName, '极速卡丁车');
    expect(AppConstants.lapsPerRace, 3);
  });

  test('目录规模', () {
    expect(CharacterCatalog.all.length, 4);
    expect(TrackCatalog.all.length, 3);
  });

  test('角色属性倍率合理且颜色有效', () {
    for (final c in CharacterCatalog.all) {
      expect(c.topSpeedMul, inExclusiveRange(0.85, 1.2));
      expect(c.accelMul, inExclusiveRange(0.85, 1.2));
      expect(c.handlingMul, inExclusiveRange(0.85, 1.2));
      expect(c.colorValue, isNot(0));
    }
  });

  test('赛道 id 唯一且可查', () {
    final ids = TrackCatalog.all.map((t) => t.id).toSet();
    expect(ids.length, TrackCatalog.all.length);
    expect(TrackCatalog.byId('seaside').name, '滨海公路');
  });

  test('枚举中文标签齐全', () {
    expect(RaceMode.itemRace.label, '道具赛');
    expect(ItemType.nitro.label, '氮气');
    for (final m in RaceMode.values) {
      expect(m.label, isNotEmpty);
      expect(m.description, isNotEmpty);
    }
    for (final t in ItemType.values) {
      expect(t.label, isNotEmpty);
    }
  });
}
