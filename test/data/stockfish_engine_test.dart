import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:chess_game_review/core/errors/app_exception.dart';
import 'package:chess_game_review/data/datasources/stockfish_data_source.dart';
import 'package:chess_game_review/data/models/uci_info.dart';
import 'package:chess_game_review/data/services/stockfish_evaluation_engine.dart';
import 'package:chess_game_review/domain/services/cancellation_token.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockStockfishSource extends Mock implements StockfishDataSource {}

/// Minimal UCI process to observe lifecycle without requiring Stockfish.
class FakeUciProcess extends Fake implements Process {
  FakeUciProcess() {
    stdin = IOSink(_input.sink);
    _input.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((command) {
          commands.add(command);
          if (command == 'uci') _reply('uciok');
          if (command == 'isready') _reply('readyok');
          if (command.startsWith('go depth ')) {
            _reply('info depth 12 multipv 1 score cp 20 pv e2e4');
            _reply('bestmove e2e4');
          }
          if (command == 'quit') _exit.complete(0);
        });
  }

  final commands = <String>[];
  final _input = StreamController<List<int>>();
  final _output = StreamController<List<int>>();
  final _exit = Completer<int>();
  @override
  late final IOSink stdin;
  @override
  Stream<List<int>> get stdout => _output.stream;
  @override
  Stream<List<int>> get stderr => const Stream.empty();
  @override
  Future<int> get exitCode => _exit.future;

  void _reply(String line) => _output.add(utf8.encode('$line\n'));
  Future<void> closeOutput() => _output.close();
}

const initialFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const blackFen = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1';
const sample = UciEvaluation(
  UciInfo(
    depth: 12,
    multiPv: 1,
    score: 42,
    isMate: false,
    pv: ['e2e4', 'e7e5'],
  ),
  UciInfo(depth: 12, multiPv: 2, score: 24, isMate: false, pv: ['d2d4']),
);

void main() {
  setUpAll(() => registerFallbackValue(CancellationToken()));
  test('invalid FEN or depth never starts a native process', () async {
    var starts = 0;
    final source = StockfishDataSource(
      startProcess: (_, _) async {
        starts++;
        throw StateError('Input validation must happen before process startup');
      },
    );
    addTearDown(source.dispose);
    for (final fen in [
      'bad fen',
      '$initialFen\nquit',
      'bad w - - 0 1',
      '8/8/8/8/8/8/8/8 w - - 0 1',
    ]) {
      await expectLater(
        source.evaluate(fen, 12, CancellationToken()),
        throwsFormatException,
      );
    }
    await expectLater(
      source.evaluate(initialFen, 11, CancellationToken()),
      throwsArgumentError,
    );
    expect(starts, 0);
  });
  test(
    'invalid FEN preserves a running process and the next valid search',
    () async {
      final process = FakeUciProcess();
      var starts = 0;
      final source = StockfishDataSource(
        startProcess: (_, _) async {
          starts++;
          return process;
        },
      );
      addTearDown(() async {
        await source.dispose();
        await process.closeOutput();
      });
      expect(
        await source.evaluate(initialFen, 12, CancellationToken()),
        isNotNull,
      );
      final commandsBefore = List<String>.of(process.commands);
      await expectLater(
        source.evaluate('bad w - - 0 1', 12, CancellationToken()),
        throwsFormatException,
      );
      expect(process.commands, commandsBefore);
      expect(
        await source.evaluate(blackFen, 12, CancellationToken()),
        isNotNull,
      );
      expect(starts, 1);
      expect(process.commands, isNot(contains('quit')));
      expect(
        process.commands.where((command) => command.startsWith('go ')),
        hasLength(2),
      );
    },
  );
  test(
    'invalid FEN becomes ParseException instead of an engine install error',
    () async {
      final source = MockStockfishSource();
      when(
        () => source.evaluate(any(), any(), any()),
      ).thenThrow(const FormatException('Invalid FEN'));
      when(source.dispose).thenAnswer((_) async {});
      final engine = StockfishEvaluationEngine(source);
      addTearDown(engine.dispose);
      final result = engine.evaluate(
        'bad fen',
        depth: 12,
        cancellation: CancellationToken(),
      );
      await expectLater(result, throwsA(isA<ParseException>()));
    },
  );
  test('UCI parses centipawn, mate, MultiPV and rejects bounds/debug lines', () {
    final info = UciInfo.parse(
      'info depth 14 seldepth 20 multipv 2 score cp -31 nodes 200 pv g8f6 d2d4',
    )!;
    expect(info.score, -31);
    expect(info.multiPv, 2);
    expect(info.pv.first, 'g8f6');
    expect(
      UciInfo.parse('info depth 14 score mate -3 pv a2a3')!.isMate,
      isTrue,
    );
    expect(
      UciInfo.parse('info depth 14 score cp 100 lowerbound pv e2e4'),
      isNull,
    );
    expect(UciInfo.parse('info string NNUE evaluation'), isNull);
  });
  test(
    'adapter caches FEN+depth and flips Black scores including second PV',
    () async {
      final source = MockStockfishSource();
      when(
        () => source.evaluate(any(), any(), any()),
      ).thenAnswer((_) async => sample);
      when(source.dispose).thenAnswer((_) async {});
      final engine = StockfishEvaluationEngine(source);
      final token = CancellationToken();
      final first = await engine.evaluate(
        blackFen,
        depth: 12,
        cancellation: token,
      );
      final second = await engine.evaluate(
        blackFen,
        depth: 12,
        cancellation: token,
      );
      expect(first, second);
      expect(first.cpWhite, -42);
      expect(first.second!.cpWhite, -24);
      verify(() => source.evaluate(blackFen, 12, token)).called(1);
      await engine.evaluate(blackFen, depth: 14, cancellation: token);
      verify(() => source.evaluate(blackFen, 14, token)).called(1);
      await engine.dispose();
      verify(source.dispose).called(1);
    },
  );
  test(
    'concurrent requests are queued and queued cancellation never starts a search',
    () async {
      final source = MockStockfishSource();
      final pending = Completer<UciEvaluation?>();
      when(
        () => source.evaluate(any(), any(), any()),
      ).thenAnswer((_) => pending.future);
      when(source.dispose).thenAnswer((_) async {});
      final engine = StockfishEvaluationEngine(source);
      final first = engine.evaluate(
        initialFen,
        depth: 12,
        cancellation: CancellationToken(),
      );
      final cancel = CancellationToken();
      final second = engine.evaluate(blackFen, depth: 12, cancellation: cancel);
      final cancelled = expectLater(second, throwsA(isA<CancelledException>()));
      await Future<void>.delayed(Duration.zero);
      verify(() => source.evaluate(any(), any(), any())).called(1);
      cancel.cancel();
      pending.complete(sample);
      expect((await first).cpWhite, 42);
      await cancelled;
      verifyNever(() => source.evaluate(blackFen, any(), any()));
      await engine.dispose();
    },
  );
  test('engine exceptions become EngineException', () async {
    final source = MockStockfishSource();
    when(
      () => source.evaluate(any(), any(), any()),
    ).thenThrow(StateError('crashed'));
    when(source.dispose).thenAnswer((_) async {});
    final engine = StockfishEvaluationEngine(source);
    final result = engine.evaluate(
      initialFen,
      depth: 12,
      cancellation: CancellationToken(),
    );
    await expectLater(result, throwsA(isA<EngineException>()));
    await engine.dispose();
  });
  test(
    'REAL Stockfish: UCI handshake, depth 12, MultiPV, stop and reuse',
    () async {
      final engine = StockfishEvaluationEngine(StockfishDataSource());
      addTearDown(engine.dispose);
      final result = await engine.evaluate(
        initialFen,
        depth: 12,
        cancellation: CancellationToken(),
      );
      final evaluation = result;
      expect(evaluation.depth, greaterThanOrEqualTo(12));
      expect(
        evaluation.bestMove,
        matches(RegExp(r'^[a-h][1-8][a-h][1-8][qrbn]?$')),
      );
      expect(evaluation.second, isNotNull);
      final token = CancellationToken();
      final pending = engine.evaluate(blackFen, depth: 20, cancellation: token);
      final timer = Timer(const Duration(milliseconds: 80), token.cancel);
      await expectLater(pending, throwsA(isA<CancelledException>()));
      timer.cancel();
      final resumed = await engine.evaluate(
        blackFen,
        depth: 12,
        cancellation: CancellationToken(),
      );
      expect(resumed.depth, greaterThanOrEqualTo(12));
    },
    timeout: const Timeout(Duration(seconds: 90)),
    skip:
        !Platform.isWindows ||
            !File('engine/stockfish/stockfish.exe').existsSync()
        ? 'Run tool/setup_stockfish.ps1 on Windows for the real engine smoke test.'
        : false,
  );
}
