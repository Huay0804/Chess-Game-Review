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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: CircleAvatar(
          backgroundColor: AppTheme.background,
          child: Text(
            game.result,
            style: const TextStyle(fontSize: 12, color: AppTheme.accent),
          ),
        ),
        title: Text(
          'vs ${opponent.username}  (${opponent.rating})',
          style: const TextStyle(fontWeight: FontWeight.w600),
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
