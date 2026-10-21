import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable {
  const Failure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

final class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'Không thể kết nối. Hãy kiểm tra mạng.',
  ]);
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure([
    super.message = 'Không tìm thấy người chơi hoặc tháng này.',
  ]);
}

final class RateLimitFailure extends Failure {
  const RateLimitFailure([
    super.message = 'Chess.com đang giới hạn yêu cầu. Hãy thử lại sau.',
  ]);
}

final class ServerFailure extends Failure {
  const ServerFailure([
    super.message = 'Máy chủ Chess.com tạm thời không khả dụng.',
  ]);
}

final class EngineFailure extends Failure {
  const EngineFailure([
    super.message = 'Stockfish không thể phân tích vị trí này.',
  ]);
}

final class ParseFailure extends Failure {
  const ParseFailure([super.message = 'Dữ liệu ván cờ không hợp lệ.']);
}

final class CancelledFailure extends Failure {
  const CancelledFailure() : super('Đã hủy phân tích.');
}
