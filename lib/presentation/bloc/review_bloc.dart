import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:chess_game_review/core/errors/app_exception.dart';
import 'package:chess_game_review/core/errors/run_with_error_handling.dart';
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
    await runWithErrorHandling<void>(
      () => emit.forEach(
        _review(
          ReviewGameParams(
            game: request.game,
            depth: request.depth,
            cancellation: token,
          ),
        ),
        onData: (progress) => progress.review == null
            ? ReviewInProgress(progress)
            : ReviewLoaded(progress.review!),
      ),
      onSuccess: (_) {},
      onError: (error) {
        if (emit.isDone) return;
        emit(
          error is CancelledException
              ? const ReviewInitial()
              : ReviewFailed(error),
        );
      },
      onFinally: token.cancel,
    );
  }

  @override
  Future<void> close() {
    _cancellation?.cancel();
    return super.close();
  }
}
