import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_racing/engine/track_geometry.dart';
import 'package:flutter_racing/models/track_def.dart';
import 'package:flutter_racing/widgets/static_track_layer.dart';

/// 静态赛道层回归：必须能同步构建为矢量 Picture（不依赖栅格化）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('三条赛道均可同步构建为矢量 Picture', () {
    for (final def in TrackCatalog.all) {
      final track = TrackGeometry.fromDef(def);
      final layer = buildStaticTrackLayer(def, track);
      expect(layer.picture, isNotNull);
      layer.picture.dispose();
    }
  });
}
