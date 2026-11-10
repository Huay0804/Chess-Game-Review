import 'package:chess_game_review/core/theme/app_theme.dart';
import 'package:chess_game_review/domain/entities/game.dart';
import 'package:flutter/material.dart';

class GameCard extends StatelessWidget {
  const GameCard({
    super.key,
    required this.game,
    required this.username,
    this.onTap,
  });

  final Game game;
  final String username;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final date = game.endTime.toLocal();
    final opponent = game.opponentOf(username);
    final (label, icon, color) = switch (game.outcomeOf(username)) {
      GameOutcome.win => (
        'Thắng',
        Icons.check_circle_outline,
        const Color(0xFF9DCC9C),
      ),
      GameOutcome.loss => (
        'Thua',
        Icons.cancel_outlined,
        const Color(0xFFF17C7C),
      ),
      GameOutcome.draw => ('Hòa', Icons.drag_handle, AppTheme.accent),
      GameOutcome.unknown => (
        'Chưa rõ kết quả',
        Icons.help_outline,
        AppTheme.muted,
      ),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: '${username.trim()}: $label',
              excludeSemantics: true,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: color, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              'vs ${opponent.username}  (${opponent.rating})',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Text(
            '${game.timeClass} • ${game.timeControl} • ${date.day}/${date.month}/${date.year}\n'
            '${game.white.username} (${game.white.rating}) — ${game.black.username} (${game.black.rating})'
            '${game.canReview ? '' : '\nBiến thể ${game.rules} chưa được hỗ trợ'}',
            style: const TextStyle(color: AppTheme.muted, height: 1.5),
          ),
        ),
        trailing: game.canReview
            ? const Icon(Icons.arrow_forward_rounded, color: AppTheme.accent)
            : const Icon(Icons.lock_outline),
        onTap: onTap,
      ),
    );
  }
}
