class UciInfo {
  const UciInfo({
    required this.depth,
    required this.multiPv,
    required this.score,
    required this.isMate,
    required this.pv,
  });
  final int depth;
  final int multiPv;
  final int score;
  final bool isMate;
  final List<String> pv;

  static UciInfo? parse(String line) {
    if (!line.startsWith('info ') ||
        line.contains('lowerbound') ||
        line.contains('upperbound')) {
      return null;
    }
    final tokens = line.trim().split(RegExp(r'\s+'));
    String? after(String key) {
      final index = tokens.indexOf(key);
      return index < 0 || index + 1 >= tokens.length ? null : tokens[index + 1];
    }

    final depth = int.tryParse(after('depth') ?? '');
    final scoreIndex = tokens.indexOf('score');
    final pvIndex = tokens.indexOf('pv');
    if (depth == null ||
        scoreIndex < 0 ||
        scoreIndex + 2 >= tokens.length ||
        pvIndex < 0 ||
        pvIndex + 1 >= tokens.length) {
      return null;
    }
    final kind = tokens[scoreIndex + 1];
    final score = int.tryParse(tokens[scoreIndex + 2]);
    if (score == null || (kind != 'cp' && kind != 'mate')) return null;
    return UciInfo(
      depth: depth,
      multiPv: int.tryParse(after('multipv') ?? '') ?? 1,
      score: score,
      isMate: kind == 'mate',
      pv: List.unmodifiable(tokens.sublist(pvIndex + 1)),
    );
  }
}

class UciEvaluation {
  const UciEvaluation(this.best, this.second);
  final UciInfo best;
  final UciInfo? second;
}
