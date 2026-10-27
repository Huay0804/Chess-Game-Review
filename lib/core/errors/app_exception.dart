import 'package:equatable/equatable.dart';

sealed class AppException extends Equatable implements Exception {
  const AppException(this.message);

  /// Keep known messages; never expose raw technical errors to the UI.
  factory AppException.from(Object error) =>
      error is AppException ? error : const UnexpectedException();

  final String message;
  @override
  List<Object?> get props => [message];

  @override
  String toString() => '$runtimeType: $message';
}

final class NetworkException extends AppException {
  const NetworkException([
    super.message =
        'Chưa kết nối được với Chess.com. '
        'Bạn hãy kiểm tra Internet rồi thử lại.',
  ]);
}

final class NotFoundException extends AppException {
  const NotFoundException([
    super.message =
        'Không tìm thấy dữ liệu. '
        'Bạn hãy kiểm tra tên người chơi hoặc chọn tháng khác.',
  ]);
}

final class RateLimitException extends AppException {
  const RateLimitException([
    super.message =
        'Chess.com đang tạm giới hạn lượt truy cập. '
        'Bạn hãy chờ một chút rồi thử lại.',
  ]);
}

final class ServerException extends AppException {
  const ServerException([
    super.message =
        'Hiện chưa tải được dữ liệu từ Chess.com. '
        'Bạn hãy thử lại sau.',
  ]);
}

final class EngineException extends AppException {
  const EngineException([
    super.message =
        'Chưa phân tích được ván cờ này. '
        'Bạn hãy thử phân tích lại.',
  ]);
}

final class ParseException extends AppException {
  const ParseException([
    super.message =
        'Chưa đọc được dữ liệu ván cờ. '
        'Bạn hãy thử tải lại hoặc chọn ván khác.',
  ]);
}

final class CancelledException extends AppException {
  const CancelledException() : super('Đã hủy phân tích.');
}

final class UnexpectedException extends AppException {
  const UnexpectedException()
    : super('Đã có sự cố khi xử lý. Bạn hãy thử lại.');
}
