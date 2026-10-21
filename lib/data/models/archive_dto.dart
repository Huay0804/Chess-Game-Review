import 'package:chess_game_review/domain/entities/archive_month.dart';

class ArchiveDto {
  const ArchiveDto(this.month);
  final ArchiveMonth month;
  factory ArchiveDto.fromUrl(String url) {
    final uri = Uri.parse(url);
    final parts = uri.pathSegments;
    if (uri.scheme != 'https' ||
        uri.host != 'api.chess.com' ||
        parts.length != 6 ||
        parts[0] != 'pub' ||
        parts[1] != 'player' ||
        parts[3] != 'games') {
      throw const FormatException('Invalid archive URL');
    }
    final month = ArchiveMonth(int.parse(parts[4]), int.parse(parts[5]));
    if (!month.isValid) throw const FormatException('Invalid archive month');
    return ArchiveDto(month);
  }
  ArchiveMonth toEntity() => month;
}
