import 'package:chess_game_review/domain/entities/game.dart';
import 'package:chess_game_review/domain/entities/review_config.dart';

sealed class ReviewEvent {}

class StartReview extends ReviewEvent {
  StartReview(this.game, {this.depth = ReviewConfig.defaultDepth});

  final Game game;
  final int depth;
}

class CancelReview extends ReviewEvent {}
