import 'dart:async';

import 'package:chess_game_review/core/errors/app_exception.dart';
import 'package:chess_game_review/core/errors/run_with_error_handling.dart';
import 'package:chess_game_review/domain/entities/game_review.dart';
import 'package:chess_game_review/domain/entities/move.dart';
import 'package:chess_game_review/domain/entities/move_analysis.dart';
import 'package:chess_game_review/domain/entities/position_eval.dart';
import 'package:chess_game_review/domain/services/cancellation_token.dart';
import 'package:chess_game_review/domain/usecases/analyze_move.dart';
import 'package:chess_game_review/domain/usecases/explore_moves.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

class VariationState {
  const VariationState({
    this.basePly = 0,
    this.cursor = 0,
    this.moves = const [],
    this.position,
    this.move,
    this.analysis,
    this.evaluation,
    this.legalMoves = const [],
    this.busy = false,
    this.error,
  });
  final int basePly, cursor;
  final List<Move> moves;
  final ChessPosition? position;
  final Move? move;
  final MoveAnalysis? analysis;
  final PositionEval? evaluation;
  final List<String> legalMoves;
  final bool busy;
  final AppException? error;
  bool get isBranch => moves.isNotEmpty;
  int get navigationIndex => isBranch ? cursor : basePly;
}

/// One temporary line beside the immutable game. Each new request cancels the
/// old search; its token also guards against engines that return after cancel.
@injectable
class VariationCubit extends Cubit<VariationState> {
  VariationCubit(this._explore, this._analyze) : super(const VariationState());
  final ExploreMoves _explore;
  final AnalyzeMove _analyze;
  GameReview? _review;
  int _basePly = 0, _cursor = 0;
  final _moves = <Move>[];
  final _analyses = <MoveAnalysis?>[];
  CancellationToken? _token;

  void load(GameReview review) {
    _review = review;
    selectOriginal(0);
  }

  void clear() {
    _token?.cancel();
    _review = null;
    _moves.clear();
    _analyses.clear();
    emit(const VariationState());
  }

  void selectOriginal(int ply) {
    if (_review == null) return;
    _token?.cancel();
    _basePly = ply.clamp(0, _review!.moves.length);
    _cursor = 0;
    _moves.clear();
    _analyses.clear();
    _publish();
  }

  void returnToGame() => selectOriginal(_basePly);

  void navigate(int index) {
    if (_review == null) return;
    if (_moves.isEmpty) {
      selectOriginal(index);
    } else {
      _token?.cancel();
      _cursor = index.clamp(0, _moves.length);
      _publish();
      unawaited(_evaluateCurrent());
    }
  }

  void play(String uci) {
    final review = _review;
    final position = state.position;
    if (review == null || position == null || !state.legalMoves.contains(uci)) {
      return;
    }
    // Following the game remains on its main line; no unnecessary variation.
    if (_moves.isEmpty &&
        _basePly < review.moves.length &&
        review.moves[_basePly].move.uci == uci) {
      selectOriginal(_basePly + 1);
      return;
    }
    if (_cursor < _moves.length && _moves[_cursor].uci == uci) {
      navigate(_cursor + 1);
      return;
    }
    try {
      final move = _explore(position, uci, ply: _basePly + _cursor + 1);
      _token?.cancel();
      _moves.removeRange(_cursor, _moves.length);
      _analyses.removeRange(_cursor, _analyses.length);
      _moves.add(move);
      _analyses.add(null);
      _cursor++;
      _publish();
      unawaited(_evaluateCurrent());
    } catch (error) {
      _publish(error: AppException.from(error));
    }
  }

  Future<void> retry() => _evaluateCurrent();

  void _publish({bool busy = false, AppException? error}) {
    final review = _review!;
    final original = _basePly == 0 ? null : review.moves[_basePly - 1];
    final move = _cursor == 0 ? original?.move : _moves[_cursor - 1];
    final analysis = _cursor == 0 ? original : _analyses[_cursor - 1];
    final position = move?.after ?? review.initial;
    List<String> legal = const [];
    try {
      legal = _explore.legalMoves(position);
    } catch (failure) {
      error ??= AppException.from(failure);
    }
    emit(
      VariationState(
        basePly: _basePly,
        cursor: _cursor,
        moves: List.unmodifiable(_moves),
        position: position,
        move: move,
        analysis: analysis,
        evaluation:
            analysis?.after ?? (move == null ? review.initialEval : null),
        legalMoves: List.unmodifiable(legal),
        busy: busy,
        error: error,
      ),
    );
  }

  Future<void> _evaluateCurrent() async {
    if (_review == null || _cursor == 0 || _analyses[_cursor - 1] != null) {
      return;
    }
    _token?.cancel();
    final token = CancellationToken();
    _token = token;
    final index = _cursor - 1;
    final review = _review!;
    final previous = index > 0
        ? _analyses[index - 1]
        : _basePly > 0
        ? review.moves[_basePly - 1]
        : null;
    final line = review.initial.fen == ChessPosition.standardFen
        ? [
            ...review.moves.take(_basePly).map((a) => a.move.uci),
            ..._moves.take(_cursor).map((m) => m.uci),
          ]
        : null;
    _publish(busy: true);
    await runWithErrorHandling<MoveAnalysis>(
      () => _analyze(
        _moves[index],
        depth: review.depth,
        cancellation: token,
        openingLine: line,
        opponentLoss: previous?.loss ?? 0,
      ),
      onSuccess: (analysis) {
        if (isClosed || token.isCancelled) return;
        _analyses[index] = analysis;
        _publish();
      },
      onError: (error) {
        if (isClosed || token.isCancelled) return;
        _publish(error: error);
      },
      onFinally: token.cancel,
    );
  }

  @override
  Future<void> close() {
    _token?.cancel();
    return super.close();
  }
}
