import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../engine/track_geometry.dart';
import '../models/character.dart';
import '../models/game_enums.dart';
import '../models/track_def.dart';
import '../providers/settings_provider.dart';
import '../services/storage_service.dart';
import '../widgets/hud.dart';
import 'race_page.dart';

/// 赛前准备：车库选车手 + 赛道选择。
class RaceSetupPage extends StatefulWidget {
  final RaceMode mode;

  const RaceSetupPage({super.key, required this.mode});

  @override
  State<RaceSetupPage> createState() => _RaceSetupPageState();
}

class _RaceSetupPageState extends State<RaceSetupPage> {
  static final Map<String, TrackGeometry> _geoCache = {};

  int _selectedTrack = 0;

  TrackGeometry _geoFor(TrackDef def) {
    return _geoCache.putIfAbsent(def.id, () => TrackGeometry.fromDef(def));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final selectedChar = settings.selectedCharacter;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('${widget.mode.label} · 选择车手与赛道')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('车库', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 158,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = 0; i < CharacterCatalog.all.length; i++)
                    _CharacterCard(
                      character: CharacterCatalog.all[i],
                      selected: selectedChar == i,
                      onTap: () => settings.setSelectedCharacter(i),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('赛道', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (var i = 0; i < TrackCatalog.all.length; i++)
              _TrackCard(
                def: TrackCatalog.all[i],
                geometry: _geoFor(TrackCatalog.all[i]),
                selected: _selectedTrack == i,
                showTotal: widget.mode == RaceMode.timeTrial,
                onTap: () => setState(() => _selectedTrack = i),
              ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RacePage(
                        track: TrackCatalog.all[_selectedTrack],
                        characterIndex: selectedChar,
                        mode: widget.mode,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.flag),
                label: const Text('开始比赛', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '共 3 圈 · ${widget.mode == RaceMode.timeTrial ? '单圈计时，刷新纪录' : '与 3 名 AI 车手同场竞技'}',
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

class _CharacterCard extends StatelessWidget {
  final RacerCharacter character;
  final bool selected;
  final VoidCallback onTap;

  const _CharacterCard({
    required this.character,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 152,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primaryContainer.withValues(alpha: 0.35)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Color(character.colorValue),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    character.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle, size: 16, color: colorScheme.primary),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              character.tagline,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            _StatBar(label: '极速', mul: character.topSpeedMul),
            const SizedBox(height: 3),
            _StatBar(label: '加速', mul: character.accelMul),
            const SizedBox(height: 3),
            _StatBar(label: '操控', mul: character.handlingMul),
          ],
        ),
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  final String label;
  final double mul;

  const _StatBar({required this.label, required this.mul});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // 属性倍率 0.9~1.15 映射到 25%~100% 宽度
    final frac = ((mul - 0.85) / 0.32).clamp(0.25, 1.0).toDouble();
    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            label,
            style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Container(
            height: 5,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: frac,
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrackCard extends StatelessWidget {
  final TrackDef def;
  final TrackGeometry geometry;
  final bool selected;
  final bool showTotal;
  final VoidCallback onTap;

  const _TrackCard({
    required this.def,
    required this.geometry,
    required this.selected,
    required this.showTotal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final storage = StorageService.instanceSync;
    final bestLap = storage?.bestLapFor(def.id);
    final bestTotal = storage?.bestTotalFor(def.id);
    final km = geometry.totalLength / 1000;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primaryContainer.withValues(alpha: 0.35)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  color: const Color(0xFF2B3A46),
                  child: CustomPaint(
                    painter: MiniMapPainter(track: geometry),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        def.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      for (var i = 0; i < 3; i++)
                        Icon(
                          Icons.star,
                          size: 14,
                          color: i < def.difficulty
                              ? const Color(0xFFFFC107)
                              : colorScheme.surfaceContainerHighest,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    def.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '单圈 ${km.toStringAsFixed(2)} km · 最佳圈 ${formatRaceTime(bestLap ?? 0)}'
                    '${showTotal ? ' · 最佳总成绩 ${formatRaceTime(bestTotal ?? 0)}' : ''}',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
