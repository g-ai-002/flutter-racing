import 'package:flutter/material.dart';

import '../../providers/race_provider.dart';

/// 比赛暂停浮层：继续 / 重新开始 / 退出。
class RacePauseOverlay extends StatelessWidget {
  const RacePauseOverlay({
    super.key,
    required this.race,
    required this.onResume,
    required this.onRestart,
    required this.onExit,
  });

  final RaceProvider race;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '比赛暂停',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('休息一下，随时回来继续比赛'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: onResume,
                    child: const Text('继续比赛'),
                  ),
                  TextButton(
                    onPressed: onRestart,
                    child: const Text('重新开始'),
                  ),
                  TextButton(
                    onPressed: onExit,
                    child: const Text('退出比赛'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
