import 'package:equatable/equatable.dart';

enum ChessSide {
  white,
  black;

  ChessSide get opposite => this == white ? black : white;
  int get sign => this == white ? 1 : -1;
}

class Player extends Equatable {
  const Player({
    required this.username,
    required this.rating,
    required this.result,
  });
  final String username;
  final int rating;
  final String result;
  @override
  List<Object?> get props => [username, rating, result];
}
