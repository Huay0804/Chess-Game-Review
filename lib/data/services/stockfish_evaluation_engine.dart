import 'dart:async';
import 'package:chess_game_review/core/constants/app_config.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:chess_game_review/domain/entities/review_config.dart';
import 'package:chess_game_review/core/errors/failure.dart';
import 'package:chess_game_review/domain/entities/player.dart';
import 'package:chess_game_review/domain/entities/position_eval.dart';
import 'package:chess_game_review/domain/services/cancellation_token.dart';
import 'package:chess_game_review/domain/services/evaluation_engine.dart';
import 'package:chess_game_review/data/datasources/stockfish_data_source.dart';
import 'package:chess_game_review/data/models/uci_info.dart';

@LazySingleton(as: EvaluationEngine)
class StockfishEvaluationEngine implements EvaluationEngine {
  StockfishEvaluationEngine(this._source);
  final StockfishDataSource _source;
  final _cache = <String, PositionEval>{};
  Future<void> _tail = Future.value();
  CancellationToken? _active;
  bool _disposed = false;

  @override
  Future<Either<Failure, PositionEval>> evaluate(
    String fen, {
    required int depth,
    required CancellationToken cancellation,
  }) {
    final result = _tail.then((_) => _evaluate(fen, depth, cancellation));
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<Either<Failure, PositionEval>> _evaluate(
    String fen,
    int depth,
    CancellationToken cancellation,
  ) async {
    if (cancellation.isCancelled || _disposed) {
      return const Left(CancelledFailure());
    }
    if (depth < ReviewConfig.minDepth || depth > ReviewConfig.maxDepth) {
      return const Left(EngineFailure('Depth phải nằm trong khoảng 12–20.'));
    }
    final key = '$depth|$fen';
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      return Right(cached);
    }
    _active = cancellation;
    try {
      final raw = await _source.evaluate(fen, depth, cancellation);
      if (raw == null || cancellation.isCancelled) {
        return const Left(CancelledFailure());
      }
      final turn = fen.split(' ')[1] == 'w' ? ChessSide.white : ChessSide.black;
      EngineVariation convert(UciInfo info) => EngineVariation(
        cpWhite: PositionEval.normalizedCp(
          score: info.score,
          isMate: info.isMate,
          turn: turn,
        ),
        mateWhite: info.isMate ? info.score * turn.sign : null,
        pv: info.pv,
        depth: info.depth,
      );
      final best = convert(raw.best);
      final result = PositionEval(
        cpWhite: best.cpWhite,
        mateWhite: best.mateWhite,
        bestMove: best.bestMove,
        pv: best.pv,
        depth: best.depth,
        second: raw.second == null ? null : convert(raw.second!),
      );
      _cache[key] = result;
      if (_cache.length > AppConfig.maxCachedPositions) {
        _cache.remove(_cache.keys.first);
      }
      return Right(result);
    } on FormatException {
      return const Left(ParseFailure('Vị trí FEN không hợp lệ.'));
    } on TimeoutException {
      if (cancellation.isCancelled) return const Left(CancelledFailure());
      return const Left(
        EngineFailure(
          'Stockfish vượt quá thời gian phân tích. Hãy thử depth thấp hơn.',
        ),
      );
    } catch (_) {
      if (cancellation.isCancelled) return const Left(CancelledFailure());
      return const Left(
        EngineFailure(
          'Không chạy được Stockfish. Kiểm tra engine đã được cài và đường dẫn hợp lệ rồi thử lại.',
        ),
      );
    } finally {
      _active = null;
    }
  }

  @override
  @disposeMethod
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _active?.cancel();
    await _tail;
    _cache.clear();
    await _source.dispose();
  }
}
