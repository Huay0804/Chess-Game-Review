import 'package:chess_game_review/app.dart';
import 'package:chess_game_review/injection.dart';
import 'package:flutter/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const App());
}
