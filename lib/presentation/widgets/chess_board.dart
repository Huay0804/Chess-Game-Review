import 'package:chess_game_review/domain/entities/move.dart';
import 'package:chess_game_review/domain/entities/move_quality.dart';
import 'package:chess_game_review/presentation/widgets/review_formatters.dart';
import 'package:flutter/material.dart';

class ChessBoard extends StatefulWidget {
  const ChessBoard({
    super.key,
    required this.position,
    this.flipped = false,
    this.lastUci,
    this.move,
    this.quality,
    this.legalMoves = const [],
    this.onMove,
  });
  final ChessPosition position;
  final bool flipped;
  final String? lastUci;
  final Move? move;
  final MoveQuality? quality;
  final List<String> legalMoves;
  final ValueChanged<String>? onMove;
  @override
  State<ChessBoard> createState() => _ChessBoardState();
}

class _PieceMotion {
  const _PieceMotion(this.piece, this.from, this.to, this.target);
  final String piece;
  final Offset from, to; // Square units: resizing does not change the path.
  final int target;
}

class _ChessBoardState extends State<ChessBoard>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 350);
  static const _names = {
    'k': 'vua',
    'q': 'hậu',
    'r': 'xe',
    'b': 'tượng',
    'n': 'mã',
    'p': 'tốt',
  };
  final _boardKey = GlobalKey();
  late final AnimationController _controller;
  List<_PieceMotion> _motions = [];
  int? _dragFrom;
  String? _dragFen, _droppedUci;
  bool _reduceMotion = false, _choosingPromotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _duration,
      value: 1,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) _controller.value = 1;
  }

  int _index(String square) =>
      (8 - int.parse(square[1])) * 8 + square.codeUnitAt(0) - 97;
  String _square(int index) =>
      '${String.fromCharCode(97 + index % 8)}${8 - index ~/ 8}';
  Offset _offset(int index) {
    final display = widget.flipped ? 63 - index : index;
    return Offset((display % 8).toDouble(), (display ~/ 8).toDouble());
  }

  @override
  void didUpdateWidget(covariant ChessBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position.fen == widget.position.fen &&
        oldWidget.flipped == widget.flipped) {
      return;
    }
    _controller.value = 1;
    _motions = [];
    _dragFrom = null;
    _dragFen = null;
    final forward =
        widget.move != null &&
        widget.move!.before.fen == oldWidget.position.fen &&
        widget.move!.after.fen == widget.position.fen &&
        widget.move!.ply == (oldWidget.move?.ply ?? 0) + 1;
    final backward =
        oldWidget.move != null &&
        oldWidget.move!.after.fen == oldWidget.position.fen &&
        oldWidget.move!.before.fen == widget.position.fen &&
        oldWidget.move!.ply == (widget.move?.ply ?? 0) + 1;
    final dropped = _droppedUci;
    _droppedUci = null;
    if (_reduceMotion ||
        oldWidget.flipped != widget.flipped ||
        (!forward && !backward)) {
      return;
    }
    final move = forward ? widget.move! : oldWidget.move!;
    final from = _index(move.uci.substring(0, 2)),
        to = _index(move.uci.substring(2, 4));
    void add(int a, int b) {
      final start = forward ? a : b, end = forward ? b : a;
      final piece = oldWidget.position.squares[start];
      if (piece.isNotEmpty) {
        _motions.add(_PieceMotion(piece, _offset(start), _offset(end), end));
      }
    }

    // A dropped piece is already at the destination; the castling rook still slides.
    if (!forward || dropped != move.uci) add(from, to);
    if (move.before.squares[from].toLowerCase() == 'k' &&
        (to - from).abs() == 2) {
      add(from + (to > from ? 3 : -4), from + (to > from ? 1 : -1));
    }
    if (_motions.isNotEmpty) {
      _controller.duration = _duration;
      _controller.forward(from: 0);
    }
  }

  Future<void> _drop(int from, Offset global) async {
    if (!mounted) return;
    final fen = _dragFen;
    final box = _boardKey.currentContext!.findRenderObject()! as RenderBox;
    final local = box.globalToLocal(global);
    final cell = box.size.width / 8;
    final inside = (Offset.zero & box.size).contains(local);
    final display = (local.dy / cell).floor() * 8 + (local.dx / cell).floor();
    final to = widget.flipped ? 63 - display : display;
    setState(() => _dragFrom = null);
    if (fen == null || fen != widget.position.fen) return;
    final prefix = inside ? '${_square(from)}${_square(to)}' : '';
    final candidates = inside
        ? widget.legalMoves.where((m) => m.startsWith(prefix)).toList()
        : <String>[];
    if (candidates.isEmpty) {
      if (!_reduceMotion) {
        _motions = [
          _PieceMotion(
            widget.position.squares[from],
            Offset(local.dx / cell - .5, local.dy / cell - .5),
            _offset(from),
            from,
          ),
        ];
        _controller.duration = const Duration(milliseconds: 200);
        _controller.forward(from: 0);
      }
      return;
    }
    var uci = candidates.singleOrNull;
    if (uci == null) {
      _choosingPromotion = true;
      final chosen = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Chọn quân phong cấp'),
          children: [
            for (final (suffix, label) in [
              ('q', 'Hậu'),
              ('r', 'Xe'),
              ('b', 'Tượng'),
              ('n', 'Mã'),
            ])
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, '$prefix$suffix'),
                child: Text(label),
              ),
          ],
        ),
      );
      if (!mounted) return;
      setState(() => _choosingPromotion = false);
      if (widget.position.fen != fen || chosen == null) return;
      uci = chosen;
    }
    _droppedUci = uci;
    widget.onMove?.call(uci);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cell = constraints.maxWidth / 8;
          final uci = widget.lastUci ?? widget.move?.uci;
          final from = uci?.substring(0, 2), to = uci?.substring(2, 4);
          final targets = _dragFrom == null
              ? <String>{}
              : widget.legalMoves
                    .where((m) => m.startsWith(_square(_dragFrom!)))
                    .map((m) => m.substring(2, 4))
                    .toSet();
          return Listener(
            onPointerCancel: (_) => _dragFen = null,
            child: Stack(
              key: _boardKey,
              children: [
                for (var index = 0; index < 64; index++)
                  Positioned(
                    left: _offset(index).dx * cell,
                    top: _offset(index).dy * cell,
                    width: cell,
                    height: cell,
                    child: _tile(index, from, to, targets, cell),
                  ),
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final moving = _controller.value < 1
                          ? _motions
                          : <_PieceMotion>[];
                      Widget pieceAt(
                        String piece,
                        Offset offset,
                        int index, {
                        bool animated = false,
                      }) {
                        final glyph = _BoardPiece(piece: piece, size: cell);
                        final canDrag =
                            widget.onMove != null &&
                            !_choosingPromotion &&
                            widget.legalMoves.any(
                              (m) => m.startsWith(_square(index)),
                            );
                        return Positioned(
                          key: ValueKey(
                            '${animated ? 'moving' : 'piece'}-${_square(index)}',
                          ),
                          left: offset.dx * cell,
                          top: offset.dy * cell,
                          width: cell,
                          height: cell,
                          child: ExcludeSemantics(
                            child: canDrag
                                ? Draggable<int>(
                                    data: index,
                                    maxSimultaneousDrags: _dragFrom == null
                                        ? 1
                                        : 0,
                                    dragAnchorStrategy:
                                        pointerDragAnchorStrategy,
                                    feedback: FractionalTranslation(
                                      translation: const Offset(-.5, -.5),
                                      child: Material(
                                        type: MaterialType.transparency,
                                        child: glyph,
                                      ),
                                    ),
                                    childWhenDragging: const SizedBox.expand(),
                                    onDragStarted: () {
                                      _controller.value = 1;
                                      setState(() {
                                        _dragFrom = index;
                                        _dragFen = widget.position.fen;
                                      });
                                    },
                                    onDragEnd: (details) =>
                                        _drop(index, details.offset),
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.grab,
                                      child: glyph,
                                    ),
                                  )
                                : IgnorePointer(child: glyph),
                          ),
                        );
                      }

                      return Stack(
                        children: [
                          for (var index = 0; index < 64; index++)
                            if (widget.position.squares[index].isNotEmpty &&
                                !moving.any((m) => m.target == index))
                              pieceAt(
                                widget.position.squares[index],
                                _offset(index),
                                index,
                              ),
                          for (final motion in moving)
                            pieceAt(
                              motion.piece,
                              Offset.lerp(
                                motion.from,
                                motion.to,
                                Curves.easeOutCubic.transform(
                                  _controller.value,
                                ),
                              )!,
                              motion.target,
                              animated: true,
                            ),
                        ],
                      );
                    },
                  ),
                ),
                if (to != null && widget.quality != null)
                  Positioned(
                    left: _offset(_index(to)).dx * cell,
                    top: _offset(_index(to)).dy * cell,
                    width: cell,
                    height: cell,
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) => _controller.value < 1
                            ? const SizedBox.shrink()
                            : Align(
                                alignment: Alignment.topRight,
                                child: TweenAnimationBuilder<double>(
                                  key: ValueKey(
                                    '${widget.position.fen}-${widget.quality}',
                                  ),
                                  tween: Tween(begin: 0, end: 1),
                                  duration: _reduceMotion
                                      ? Duration.zero
                                      : const Duration(milliseconds: 280),
                                  builder: (context, value, child) => Opacity(
                                    opacity: value,
                                    child: Transform.scale(
                                      scale: .75 + .25 * value,
                                      child: child,
                                    ),
                                  ),
                                  child: _QualityBadge(
                                    quality: widget.quality!,
                                    size: cell * .34,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );

  Widget _tile(
    int index,
    String? from,
    String? to,
    Set<String> targets,
    double cell,
  ) {
    final square = _square(index);
    final light = (index ~/ 8 + index % 8).isEven;
    final base = light ? const Color(0xFFD6DCCF) : const Color(0xFF55766F);
    final piece = widget.position.squares[index];
    final white = piece.isNotEmpty && piece == piece.toUpperCase();
    final isLastMoveSquare = square == from || square == to;
    final color = isLastMoveSquare && widget.quality != null
        ? widget.quality!.color
        : isLastMoveSquare || index == _dragFrom
        ? const Color(0xFFCBB776)
        : base;
    final display = widget.flipped ? 63 - index : index;
    return Semantics(
      label:
          '$square ${piece.isEmpty ? 'trống' : '${white ? 'Trắng' : 'Đen'} ${_names[piece.toLowerCase()]}'}'
          '${square == to && widget.quality != null ? ', ${widget.quality!.label}' : ''}',
      child: ExcludeSemantics(
        child: AnimatedContainer(
          key: ValueKey('square-$square'),
          duration: _reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 300),
          color: color,
          child: Stack(
            children: [
              if (display % 8 == 0)
                Positioned(
                  left: 3,
                  top: 1,
                  child: Text(
                    '${8 - index ~/ 8}',
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF16232B),
                    ),
                  ),
                ),
              if (display ~/ 8 == 7)
                Positioned(
                  right: 3,
                  bottom: 1,
                  child: Text(
                    square[0],
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF16232B),
                    ),
                  ),
                ),
              if (targets.contains(square))
                Center(
                  child: Container(
                    width: piece.isEmpty ? cell * .22 : cell * .9,
                    height: piece.isEmpty ? cell * .22 : cell * .9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: piece.isEmpty ? Colors.black26 : null,
                      border: piece.isEmpty
                          ? null
                          : Border.all(color: Colors.black38, width: 3),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoardPiece extends StatelessWidget {
  const _BoardPiece({required this.piece, required this.size});
  final String piece;
  final double size;
  static const glyphs = {
    'k': '♚',
    'q': '♛',
    'r': '♜',
    'b': '♝',
    'n': '♞',
    'p': '♟',
  };
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Center(
      child: Text(
        glyphs[piece.toLowerCase()] ?? '',
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontFamily: 'Segoe UI Symbol',
          fontSize: size * .79,
          height: 1,
          color: piece == piece.toUpperCase()
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
  );
}

class _QualityBadge extends StatelessWidget {
  const _QualityBadge({required this.quality, required this.size});
  final MoveQuality quality;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: quality.color,
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFF16232B), width: 1.5),
    ),
    child: FittedBox(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: quality == MoveQuality.book
            ? const Icon(Icons.menu_book, size: 16, color: Color(0xFF16232B))
            : Text(
                switch (quality) {
                  MoveQuality.brilliant => '!!',
                  MoveQuality.great => '!',
                  MoveQuality.best => '★',
                  MoveQuality.excellent => '✓',
                  MoveQuality.good => '•',
                  MoveQuality.book => '',
                  MoveQuality.inaccuracy => '?!',
                  MoveQuality.mistake => '?',
                  MoveQuality.miss => '×',
                  MoveQuality.blunder => '??',
                },
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF16232B),
                ),
              ),
      ),
    ),
  );
}
