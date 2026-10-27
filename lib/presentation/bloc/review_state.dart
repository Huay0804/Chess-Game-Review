import 'package:chess_game_review/core/errors/app_exception.dart';
import 'package:chess_game_review/domain/entities/game_review.dart';
import 'package:equatable/equatable.dart';

sealed class ReviewState extends Equatable {
  const ReviewState();

  @override
  List<Object?> get props => [];
}

class ReviewInitial extends ReviewState {
  const ReviewInitial();
}

class ReviewLoading extends ReviewState {
  const ReviewLoading();
}

class ReviewInProgress extends ReviewState {
  const ReviewInProgress(this.progress);

  final ReviewProgress progress;

  @override
  List<Object?> get props => [progress];
}

class ReviewLoaded extends ReviewState {
  const ReviewLoaded(this.review);

  final GameReview review;

  @override
  List<Object?> get props => [review];
}

class ReviewFailed extends ReviewState {
  const ReviewFailed(this.failure);

  final AppException failure;

  @override
  List<Object?> get props => [failure];
}
