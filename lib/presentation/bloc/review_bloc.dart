import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:chess_game_review/core/errors/failure.dart';
import 'package:chess_game_review/domain/services/cancellation_token.dart';
import 'package:chess_game_review/domain/usecases/review_game.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:chess_game_review/presentation/bloc/review_event.dart';
import 'package:chess_game_review/presentation/bloc/review_state.dart';

export 'package:chess_game_review/presentation/bloc/review_event.dart';
export 'package:chess_game_review/presentation/bloc/review_state.dart';

@injectable
class ReviewBloc extends Bloc<ReviewEvent, ReviewState> {
  ReviewBloc(this._review) : super(const ReviewInitial()) {
    on<ReviewEvent>(_handle, transformer: restartable());
  }

  final ReviewGame _review;
  CancellationToken? _cancellation;

  Future<void> _handle(ReviewEvent event, Emitter<ReviewState> emit) async {
    _cancellation?.cancel();
    if (event is CancelReview) {
      emit(const ReviewInitial());
      return;
    }
    final request = event as StartReview;
    final token = CancellationToken();
    _cancellation = token;
    emit(const ReviewLoading());
    try {
      await emit.forEach(
        _review(
          ReviewGameParams(
            game: request.game,
            depth: request.depth,
            cancellation: token,
          ),
        ),
        onData: (result) => result.fold(
          (failure) => failure is CancelledFailure
              ? const ReviewInitial()
              : ReviewFailed(failure),
          (progress) => progress.review == null
              ? ReviewInProgress(progress)
              : ReviewLoaded(progress.review!),
        ),
        onError: (_, _) => const ReviewFailed(EngineFailure()),
      );
    } finally {
      token.cancel();
    }
  }

  @override
  Future<void> close() {
    _cancellation?.cancel();
    return super.close();
  }
}
