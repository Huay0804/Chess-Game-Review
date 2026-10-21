import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dartchess/dartchess.dart' as dc;
import 'package:chess_game_review/core/constants/app_config.dart';
import 'package:chess_game_review/domain/entities/review_config.dart';
import 'package:injectable/injectable.dart';
import 'package:chess_game_review/domain/services/cancellation_token.dart';
import 'package:chess_game_review/data/models/uci_info.dart';

/// Process binding for the official desktop Stockfish executable.
/// The EvaluationEngine adapter serializes access to this single process.
@lazySingleton
class StockfishDataSource {
  StockfishDataSource({
    @ignoreParam Future<Process> Function(String, List<String>)? startProcess,
  }) : _startProcess =
           startProcess ??
           ((executable, args) =>
               Process.start(executable, args, runInShell: false));

  final Future<Process> Function(String, List<String>) _startProcess;
  Process? _process;
  StreamController<String>? _lines;
  StreamSubscription<String>? _stdout;
  StreamSubscription<String>? _stderr;
  Future<void>? _ready;
  bool _disposed = false;
  bool _searching = false;

  String _executable() {
    const defined = String.fromEnvironment('STOCKFISH_PATH');
    final configured = defined.isNotEmpty
        ? defined
        : Platform.environment['STOCKFISH_PATH'];
    if (configured != null && configured.isNotEmpty) return configured;
    final name = Platform.isWindows ? 'stockfish.exe' : 'stockfish';
    final bundled = File(
      '${File(Platform.resolvedExecutable).parent.path}/engine/stockfish/$name',
    );
    if (bundled.existsSync()) return bundled.absolute.path;
    final development = File('engine/stockfish/$name');
    if (development.existsSync()) return development.absolute.path;
    return name; // Also permit a system installation on PATH.
  }

  Future<void> _start() async {
    if (_disposed) throw StateError('Engine disposed');
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      throw UnsupportedError(
        'This process binding requires a desktop platform.',
      );
    }
    final process = await _startProcess(_executable(), []);
    _process = process;
    unawaited(process.stdin.done.catchError((Object _) {}));
    final controller = StreamController<String>.broadcast(sync: true);
    _lines = controller;
    _stdout = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (!controller.isClosed) controller.add(line);
          },
          onError: (Object error) {
            if (!controller.isClosed) controller.addError(error);
          },
          onDone: () {
            if (!controller.isClosed) unawaited(controller.close());
          },
        );
    _stderr = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((_) {});
    await _commandUntil('uci', (line) => line == 'uciok');
    _send('setoption name Threads value ${AppConfig.engineThreads}');
    _send('setoption name Hash value ${AppConfig.engineHashMb}');
    _send('setoption name MultiPV value ${AppConfig.multiPv}');
    _send('setoption name UCI_Chess960 value false');
    await _commandUntil('isready', (line) => line == 'readyok');
  }

  void _send(String command) {
    final process = _process;
    if (process == null) throw StateError('Engine is not running');
    process.stdin.writeln(command);
  }

  Future<void> _commandUntil(
    String command,
    bool Function(String) matches,
  ) async {
    final done = Completer<void>();
    final subscription = _lines!.stream.listen(
      (line) {
        if (matches(line) && !done.isCompleted) done.complete();
      },
      onError: (Object error) {
        if (!done.isCompleted) done.completeError(error);
      },
      onDone: () {
        if (!done.isCompleted) done.completeError(StateError('Engine exited'));
      },
    );
    try {
      _send(command);
      await done.future.timeout(AppConfig.handshakeTimeout);
    } finally {
      await subscription.cancel();
    }
  }

  void _validateInput(String fen, int depth) {
    if (depth < ReviewConfig.minDepth || depth > ReviewConfig.maxDepth) {
      throw ArgumentError.value(depth, 'depth', 'Must be between 12 and 20');
    }
    if (fen.contains('\n') ||
        fen.contains('\r') ||
        fen.split(' ').length != 6) {
      throw const FormatException('Invalid FEN');
    }
    try {
      dc.Chess.fromSetup(dc.Setup.parseFen(fen));
    } on dc.FenException {
      throw const FormatException('Invalid FEN');
    } on dc.PositionSetupException {
      throw const FormatException('Invalid chess position');
    }
  }

  Future<UciEvaluation?> evaluate(
    String fen,
    int depth,
    CancellationToken cancellation,
  ) async {
    if (cancellation.isCancelled) return null;
    if (_searching) throw StateError('UCI searches must be serial');
    // Input errors must not start, stop or reset a healthy UCI process.
    _validateInput(fen, depth);
    try {
      await (_ready ??= _start());
      if (cancellation.isCancelled) return null;
      _searching = true;
      final variations = <int, UciInfo>{};
      final done = Completer<void>();
      final subscription = _lines!.stream.listen(
        (line) {
          final info = UciInfo.parse(line);
          if (info != null && info.multiPv <= AppConfig.multiPv) {
            final previous = variations[info.multiPv];
            if (previous == null || info.depth >= previous.depth) {
              variations[info.multiPv] = info;
            }
          }
          if (line.startsWith('bestmove ') && !done.isCompleted) {
            done.complete();
          }
        },
        onError: (Object error) {
          if (!done.isCompleted) done.completeError(error);
        },
        onDone: () {
          if (!done.isCompleted) {
            done.completeError(StateError('Engine exited during search'));
          }
        },
      );
      void Function() detach = () {};
      Timer? stopTimer;
      try {
        _send('position fen $fen');
        _send('go depth $depth');
        detach = cancellation.listen(() {
          if (_process != null && !done.isCompleted) {
            _send('stop');
            stopTimer = Timer(AppConfig.engineStopTimeout, () {
              if (!done.isCompleted) {
                done.completeError(
                  TimeoutException('Engine did not acknowledge stop'),
                );
              }
            });
          }
        });
        // Drain through bestmove before accepting another position. This avoids
        // mixing output from a cancelled search with the next game.
        await done.future.timeout(AppConfig.engineTimeout);
        if (cancellation.isCancelled) return null;
        final best = variations[1];
        if (best == null) throw StateError('No scored principal variation');
        final second = variations[2];
        return UciEvaluation(best, second?.depth == best.depth ? second : null);
      } finally {
        detach();
        stopTimer?.cancel();
        await subscription.cancel();
        _searching = false;
      }
    } catch (_) {
      // A timeout/crash invalidates protocol state. Restart lazily on retry.
      await _shutdown();
      rethrow;
    }
  }

  Future<void> _shutdown() async {
    final process = _process;
    _process = null;
    _ready = null;
    if (process != null) {
      try {
        process.stdin.writeln('quit');
        await process.stdin.flush();
        await process.exitCode.timeout(AppConfig.engineStopTimeout);
      } catch (_) {
        process.kill();
        await process.exitCode;
      }
      await process.stdin.close().catchError((Object _) {});
    }
    await _stdout?.cancel();
    await _stderr?.cancel();
    if (_lines != null && !_lines!.isClosed) await _lines!.close();
    _stdout = null;
    _stderr = null;
    _lines = null;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _shutdown();
  }
}
