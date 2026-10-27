import 'dart:async';
import 'package:chess_game_review/core/logging/operation_logging.dart';
import 'package:chess_game_review/core/constants/app_config.dart';
import 'package:injectable/injectable.dart';
import 'package:chess_game_review/domain/entities/review_config.dart';
import 'package:chess_game_review/core/errors/app_exception.dart';
import 'package:chess_game_review/domain/entities/player.dart';
import 'package:chess_game_review/domain/entities/position_eval.dart';
import 'package:chess_game_review/domain/services/cancellation_token.dart';
import 'package:chess_game_review/domain/services/evaluation_engine.dart';
import 'package:chess_game_review/data/datasources/stockfish_data_source.dart';
import 'package:chess_game_review/data/models/uci_info.dart';

@LazySingleton(as: EvaluationEngine)
class StockfishEvaluationEngine
    with OperationLogging
    implements EvaluationEngine {
  StockfishEvaluationEngine(this._source);
  final StockfishDataSource _source;
  final _cache = <String, PositionEval>{};
  Future<void> _tail = Future.value();
  CancellationToken? _active;
  bool _disposed = false;

  @override
  Future<PositionEval> evaluate(
    String fen, {
    required int depth,
    required CancellationToken cancellation,
  }) {
    final result = _tail.then(
      (_) => logOperation(
        'Stockfish depth $depth',
        () => _evaluate(fen, depth, cancellation),
      ),
    );
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<PositionEval> _evaluate(
    String fen,
    int depth,
    CancellationToken cancellation,
  ) async {
    if (cancellation.isCancelled || _disposed) {
      throw const CancelledException();
    }
    if (depth < ReviewConfig.minDepth || depth > ReviewConfig.maxDepth) {
      throw const EngineException(
        'Bạn hãy chọn độ sâu phân tích từ 12 đến 20.',
      );
    }
    final key = '$depth|$fen';
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      return cached;
    }
    _active = cancellation;
    try {
      final raw = await _source.evaluate(fen, depth, cancellation);
      if (raw == null || cancellation.isCancelled) {
        throw const CancelledException();
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
      return result;
    } on AppException {
      rethrow;
    } on FormatException {
      throw const ParseException(
        'Vị trí trên bàn cờ không hợp lệ. Bạn hãy chọn ván khác.',
      );
    } on TimeoutException {
      if (cancellation.isCancelled) throw const CancelledException();
      throw const EngineException(
        'Phân tích mất nhiều thời gian hơn dự kiến. '
        'Bạn hãy chọn độ sâu thấp hơn rồi thử lại.',
      );
    } catch (_) {
      if (cancellation.isCancelled) throw const CancelledException();
      throw const EngineException(
        'Chưa mở được bộ phân tích. Bạn hãy mở lại ứng dụng; '
        'nếu vẫn lỗi, kiểm tra bộ cài Stockfish.',
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
