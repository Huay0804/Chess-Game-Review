enum MoveQuality {
  brilliant,
  great,
  best,
  excellent,
  good,
  book,
  inaccuracy,
  mistake,
  miss,
  blunder;

  bool get needsSuggestion =>
      this == inaccuracy || this == mistake || this == miss || this == blunder;
  bool get isHeuristic => this == brilliant || this == great || this == miss;
}
