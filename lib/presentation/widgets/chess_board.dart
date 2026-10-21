import 'package:flutter/material.dart';
import 'package:chess_game_review/domain/entities/move.dart';

class ChessBoard extends StatelessWidget {
  const ChessBoard({
    super.key,
    required this.position,
    this.flipped = false,
    this.lastUci,
  });
  final ChessPosition position;
  final bool flipped;
  final String? lastUci;
  static const _glyphs = {
    'k': '♚',
    'q': '♛',
    'r': '♜',
    'b': '♝',
    'n': '♞',
    'p': '♟',
  };
  static const _names = {
    'k': 'vua',
    'q': 'hậu',
    'r': 'xe',
    'b': 'tượng',
    'n': 'mã',
    'p': 'tốt',
  };
  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LayoutBuilder(
        builder: (context, constraints) => GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
          ),
          itemCount: 64,
          itemBuilder: (context, displayIndex) {
            final index = flipped ? 63 - displayIndex : displayIndex;
            final file = index % 8, rank = 8 - index ~/ 8;
            final square = '${String.fromCharCode(97 + file)}$rank';
            final piece = position.squares[index];
            final white = piece.isNotEmpty && piece == piece.toUpperCase();
            final highlighted =
                lastUci != null &&
                lastUci!.length >= 4 &&
                (lastUci!.substring(0, 2) == square ||
                    lastUci!.substring(2, 4) == square);
            final light = (index ~/ 8 + file).isEven;
            return Semantics(
              label:
                  '$square ${piece.isEmpty ? 'trống' : '${white ? 'Trắng' : 'Đen'} ${_names[piece.toLowerCase()]}'}',
              child: ExcludeSemantics(
                child: Container(
                  color: highlighted
                      ? const Color(0xFFCBB776)
                      : light
                      ? const Color(0xFFD6DCCF)
                      : const Color(0xFF55766F),
                  child: Stack(
                    children: [
                      if (piece.isNotEmpty)
                        Center(
                          child: Text(
                            _glyphs[piece.toLowerCase()] ?? '',
                            style: TextStyle(
                              fontFamily: 'Segoe UI Symbol',
                              fontSize: constraints.maxWidth / 8 * .79,
                              height: 1,
                              color: white
                                  ? const Color(0xFFFFFDF3)
                                  : const Color(0xFF16232B),
                              shadows: const [
                                Shadow(
                                  color: Color(0x88000000),
                                  blurRadius: 1.5,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (displayIndex % 8 == 0)
                        Positioned(
                          left: 3,
                          top: 1,
                          child: Text(
                            '$rank',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: light
                                  ? const Color(0xFF55766F)
                                  : const Color(0xFFD6DCCF),
                            ),
                          ),
                        ),
                      if (displayIndex ~/ 8 == 7)
                        Positioned(
                          right: 3,
                          bottom: 1,
                          child: Text(
                            String.fromCharCode(97 + file),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: light
                                  ? const Color(0xFF55766F)
                                  : const Color(0xFFD6DCCF),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
