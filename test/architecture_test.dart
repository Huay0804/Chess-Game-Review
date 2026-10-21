import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _domainPackages = {'equatable', 'fpdart', 'injectable'};
const _domainLibraries = {
  'dart:async',
  'dart:collection',
  'dart:convert',
  'dart:core',
  'dart:math',
  'dart:typed_data',
};

// Include exports, parts and every URI in a conditional import.
Iterable<String> _imports(String source) sync* {
  final directives = RegExp(
    r'''^\s*(?:import|export|part)\s+(?!of\b)([^;]+);''',
    multiLine: true,
  );
  final quotedUris = RegExp(r'''['"]([^'"]+)['"]''');
  for (final directive in directives.allMatches(source)) {
    for (final uri in quotedUris.allMatches(directive.group(1)!)) {
      yield uri.group(1)!;
    }
  }
}

List<String> _violations({
  required String source,
  required Uri file,
  required Uri libRoot,
  required bool isDomain,
}) {
  final violations = <String>[];
  for (final reference in _imports(source)) {
    final uri = Uri.parse(reference);
    bool allowed;
    if (uri.scheme == 'dart') {
      allowed = !isDomain || _domainLibraries.contains(reference);
    } else if (uri.scheme == 'package' &&
        uri.pathSegments.first != 'chess_game_review') {
      final package = uri.pathSegments.first;
      allowed = isDomain
          ? _domainPackages.contains(package)
          : !{'dio', 'dartchess', 'stockfish'}.contains(package);
    } else {
      final target = uri.scheme == 'package'
          ? libRoot.resolve(uri.pathSegments.skip(1).join('/'))
          : file.resolveUri(uri);
      final prefixes = isDomain
          ? ['domain/', 'core/errors/']
          : [
              'presentation/',
              'domain/',
              'core/errors/',
              'core/theme/',
              'core/constants/',
            ];
      allowed = prefixes.any(
        (prefix) =>
            target.toString().startsWith(libRoot.resolve(prefix).toString()),
      );
    }
    if (!allowed) violations.add('${file.toFilePath()} imports $reference');
  }
  return violations;
}

void main() {
  final libRoot = Directory('lib').absolute.uri;

  test('presentation and domain imports respect layer boundaries', () async {
    final counts = <String, int>{};
    final violations = <String>[];
    for (final layer in ['domain', 'presentation', 'core/errors']) {
      final files = await Directory.fromUri(libRoot.resolve('$layer/'))
          .list(recursive: true)
          .where((entry) => entry is File && entry.path.endsWith('.dart'))
          .cast<File>()
          .toList();
      // An empty scan must fail instead of reporting a false success.
      expect(files, isNotEmpty, reason: 'No files checked in $layer');
      counts[layer] = files.length;
      for (final file in files) {
        violations.addAll(
          _violations(
            source: await file.readAsString(),
            file: file.uri,
            libRoot: libRoot,
            isDomain: layer != 'presentation',
          ),
        );
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
    // ignore: avoid_print
    print('Architecture PASS: $counts');
  });

  test('Domain rejects SDK, package and local infrastructure dependencies', () {
    for (final uri in [
      'dart:ui',
      'dart:io',
      'package:flutter/widgets.dart',
      'package:dio/dio.dart',
      'package:dartchess/dartchess.dart',
      'package:stockfish/stockfish.dart',
      'package:unapproved/library.dart',
      'package:chess_game_review/data/models/game_dto.dart',
      '../../data/models/game_dto.dart',
      '../../presentation/pages/review_page.dart',
      '../../core/network/dio_module.dart',
      '../../injection.dart',
    ]) {
      expect(
        _violations(
          source: "import '$uri';",
          file: libRoot.resolve('domain/usecases/example.dart'),
          libRoot: libRoot,
          isDomain: true,
        ),
        isNotEmpty,
        reason: 'Failed to reject $uri',
      );
    }
  });

  test(
    'Presentation rejects Data even through exports and conditional URIs',
    () {
      for (final source in [
        "import 'package:chess_game_review/data/models/game_dto.dart';",
        "export '../../data/models/game_dto.dart';",
        "part '../../data/models/game_dto.dart';",
        "import '../widgets/empty_state.dart'\n"
            "  if (dart.library.io) '../../data/models/game_dto.dart';",
        "import '../../injection.dart';",
        "import 'package:dio/dio.dart';",
      ]) {
        expect(
          _violations(
            source: source,
            file: libRoot.resolve('presentation/pages/example.dart'),
            libRoot: libRoot,
            isDomain: false,
          ),
          isNotEmpty,
          reason: 'Failed to reject $source',
        );
      }
    },
  );

  test('Domain accepts pure libraries, interfaces and shared Failures', () {
    expect(
      _violations(
        source: '''
import 'dart:math';
import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'usecase.dart';
import '../repositories/game_repository.dart';
import 'package:chess_game_review/core/errors/failure.dart';
''',
        file: libRoot.resolve('domain/usecases/example.dart'),
        libRoot: libRoot,
        isDomain: true,
      ),
      isEmpty,
    );
  });
}
