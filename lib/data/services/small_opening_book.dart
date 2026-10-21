import 'package:injectable/injectable.dart';
import 'package:chess_game_review/domain/services/opening_book.dart';

@LazySingleton(as: OpeningBook)
class SmallOpeningBook implements OpeningBook {
  static const _lines = {
    'Italian Game': ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'f8c5'],
    'Ruy Lopez': ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1b5', 'a7a6'],
    'Sicilian Defence': [
      'e2e4',
      'c7c5',
      'g1f3',
      'd7d6',
      'd2d4',
      'c5d4',
      'f3d4',
    ],
    'French Defence': ['e2e4', 'e7e6', 'd2d4', 'd7d5', 'b1c3'],
    'Caro-Kann Defence': ['e2e4', 'c7c6', 'd2d4', 'd7d5'],
    "Queen's Gambit": ['d2d4', 'd7d5', 'c2c4', 'e7e6', 'b1c3', 'g8f6'],
    "King's Indian Defence": ['d2d4', 'g8f6', 'c2c4', 'g7g6', 'b1c3', 'f8g7'],
    'English Opening': ['c2c4', 'e7e5', 'b1c3', 'g8f6'],
  };
  @override
  String? openingFor(List<String> playedUci) {
    if (playedUci.isEmpty) return null;
    for (final entry in _lines.entries) {
      if (playedUci.length > entry.value.length) continue;
      var matches = true;
      for (var i = 0; i < playedUci.length; i++) {
        if (playedUci[i] != entry.value[i]) {
          matches = false;
          break;
        }
      }
      if (matches) return entry.key;
    }
    return null;
  }
}
