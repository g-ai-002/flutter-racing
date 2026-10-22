import 'package:flutter/material.dart';

import '../models/character.dart';
import '../models/game_enums.dart';
import '../models/race_state.dart';
import '../providers/race_provider.dart';
import 'hud.dart';

/// 比赛结算浮层：名次 / 总时间 / 最佳圈 + 再来一局 / 更换配置 / 返回主页。
class RaceResultsOverlay extends StatelessWidget {
  final RaceProvider race;
  final VoidCallback onRestart;
  final VoidCallback onChangeSetup;
  final VoidCallback onExit;

  const RaceResultsOverlay({
    super.key,
    required this.race,
    required this.onRestart,
    required this.onChangeSetup,
    required this.onExit,
  });

  static const _placeColors = [
    Color(0xFFFFD700),
    Color(0xFFC0C0C0),
    Color(0xFFCD7F32),
    Color(0xFF78909C),
  ];

  @override
  Widget build(BuildContext context) {
    final state = race.state;
    final results = state.results;
    if (results == null) {
      return const SizedBox.shrink();
    }
    final isTimeTrial = state.mode == RaceMode.timeTrial;
    return Container(
      color: Colors.black.withValues(alpha: 0.62),
      child: Center(
        child: Container(
          width: 420,
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2733),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isTimeTrial ? '计时完成' : '比赛结束',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              for (final row in results)
                _ResultRow(state: state, row: row),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onRestart,
                      icon: const Icon(Icons.refresh),
                      label: const Text('再来一局'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onChangeSetup,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF546E7A)),
                      ),
                      child: const Text('更换配置'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: onExit,
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                child: const Text('返回主页'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final RaceState state;
  final ResultRow row;

  const _ResultRow({required this.state, required this.row});

  @override
  Widget build(BuildContext context) {
    final kart = state.karts[row.kartIndex];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: kart.isPlayer
            ? const Color(0xFF1E88E5).withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: _placeColors[(row.place - 1) % _placeColors.length],
            child: Text(
              '${row.place}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(
                CharacterCatalog.byIndex(kart.characterIndex).colorValue,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              kart.name,
              style: TextStyle(
                fontSize: 14,
                color: kart.isPlayer ? const Color(0xFFFFE082) : Colors.white,
                fontWeight:
                    kart.isPlayer ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                row.finished ? formatRaceTime(row.totalTime) : '未完赛',
                style: const TextStyle(fontSize: 13, color: Colors.white),
              ),
              if (row.bestLap > 0)
                Text(
                  '最佳圈 ${formatRaceTime(row.bestLap)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
