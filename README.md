# Chess Game Review

Ứng dụng Flutter tìm ván cờ công khai trên Chess.com theo người chơi và tháng.\
Phân tích bằng Stockfish cục bộ, hiển thị chất lượng nước đi, accuracy và biểu đồ.\
Hỗ trợ kéo quân thử nhánh, lật bàn cờ và bố cục thích ứng với kích thước cửa sổ.\
Danh sách hiển thị Thắng / Thua / Hòa và accuracy của các ván đã phân tích trong phiên chạy.

## Thành viên và phân công

| Họ và tên | MSSV | Công việc | Đóng góp |
| --- | --- | --- | --- |
| Ha Le Minh Hieu | 106220216 | UI, Business Logic, State Management, API/Stockfish, DI, kiểm thử, báo cáo và slide | 100% |

## Cài đặt và chạy

- Windows x64, PowerShell và kết nối Internet.
- Flutter SDK trong `PATH`, Dart **>=3.11.0 và <4.0.0**.
- Visual Studio hoặc Build Tools với **Desktop development with C++**, Windows SDK và CMake tools.

Mở PowerShell tại thư mục chứa `pubspec.yaml`:

```powershell
flutter doctor -v
flutter pub get
dart run build_runner build
powershell -NoProfile -ExecutionPolicy Bypass -File tool/setup_stockfish.ps1
flutter run -d windows
```

Script cài Stockfish 17.1 vào `engine/stockfish/` trên máy mới. Chạy lại `dart run build_runner build` khi đổi đăng ký DI; `lib/injection.config.dart` được sinh tự động.

Cấu hình tùy chọn:

| Biến | Cách truyền | Mục đích |
| --- | --- | --- |
| `STOCKFISH_PATH` | Biến môi trường Windows hoặc `--dart-define` | Đường dẫn executable riêng; `--dart-define` được ưu tiên |
| `CHESS_USER_AGENT` | `--dart-define` | User-Agent gửi tới Chess.com |

Ví dụ: đặt `$env:STOCKFISH_PATH = 'C:\tools\stockfish\stockfish.exe'` trước khi chạy, hoặc thêm `--dart-define=CHESS_USER_AGENT="ChessGameReview/1.0"` vào lệnh `flutter run -d windows`.

## Các chủ đề áp dụng

| Chủ đề | Áp dụng | File chính |
| --- | --- | --- |
| **01 — OOP & Xử lý lỗi** | Named/Factory constructor, Mixin, Generics, Custom Exception và wrapper `try-catch-finally` đưa thông báo lỗi lên UI | [DTO](lib/data/models/game_dto.dart), [OperationLogging](lib/core/logging/operation_logging.dart), [UseCase](lib/domain/usecases/usecase.dart), [AppException](lib/core/errors/app_exception.dart), [runWithErrorHandling](lib/core/errors/run_with_error_handling.dart) |
| **02 — Bố cục** | Main/cross axis, Expanded, Flexible, Stack, Positioned; bố cục thích ứng và xử lý overflow | [Review panels](lib/presentation/widgets/review_panels.dart), [Danh sách ván](lib/presentation/widgets/game_list_widgets.dart), [Danh sách nước đi](lib/presentation/widgets/move_list.dart), [Bàn cờ](lib/presentation/widgets/chess_board.dart) |
| **04 — Clean Architecture & DI** | Ba tầng, DIP, Repository + UseCase, get_it + injectable, MultiBlocProvider, REST API; unit test Domain với mock và kiểm tra kiến trúc | [Presentation](lib/presentation/), [Domain](lib/domain/), [Data](lib/data/), [Repository](lib/domain/repositories/game_repository.dart), [Implementation](lib/data/repositories/game_repository_impl.dart), [GetArchives](lib/domain/usecases/get_archives.dart), [GetMonthlyGames](lib/domain/usecases/get_monthly_games.dart), [DI](lib/injection.dart), [DI generated](lib/injection.config.dart), [main](lib/main.dart), [App](lib/app.dart), [REST DataSource](lib/data/datasources/chess_com_remote_data_source.dart) |
| **08 — Animation & Cử chỉ** | AnimatedContainer, TweenAnimationBuilder, AnimationController; kéo thả, phân tích nhánh thử và hủy tác vụ cũ | [Bàn cờ](lib/presentation/widgets/chess_board.dart), [ExploreMoves](lib/domain/usecases/explore_moves.dart), [AnalyzeMove](lib/domain/usecases/analyze_move.dart), [VariationCubit](lib/presentation/bloc/variation_cubit.dart) |
| **10 — State & Cập nhật UI** | StatelessWidget/StatefulWidget, setState, vòng đời State; state cục bộ cho hướng bàn cờ và state chia sẻ cho accuracy | [ReviewPage](lib/presentation/pages/review_page.dart), [GameCard](lib/presentation/widgets/game_card.dart), [GameListBloc](lib/presentation/bloc/game_list_bloc.dart), [ChessBoard](lib/presentation/widgets/chess_board.dart) |

## Demo

Nhập username Chess.com → **Tìm ván** → chọn tháng và ván cờ tiêu chuẩn; chọn **depth 12** để chạy thử.

- **01:** Nhập `../x` để xem lỗi đầu vào; ngắt mạng, tìm `erik`, rồi kết nối lại và nhấn **Thử lại**.
- **02:** Thu hẹp cửa sổ để thấy hai cột chuyển thành một; giảm chiều cao để thử cuộn.
- **04:** Tìm ván theo username/tháng; theo dõi luồng Widget → Bloc → UseCase → Repository và chạy unit test Domain.
- **08:** Kéo quân sang ô hợp lệ để thử nhánh, xem chuyển động và nhãn chất lượng; nhấn **Về ván gốc** hoặc **Esc** để trở lại.
- **10:** Nhấn **Lật bàn cờ** để đổi UI theo state; quay về danh sách để thấy accuracy vẫn được giữ.

## Kiểm tra

Test Domain và UI dùng mock/fake, không cần mạng hay Stockfish thật.

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Chạy riêng Domain, kiến trúc và DI:

```powershell
flutter test test/domain test/architecture_test.dart test/core_test.dart
```

Test chính: [Domain/API](test/domain/get_games_test.dart), [Review](test/domain/review_game_test.dart), [Kiến trúc](test/architecture_test.dart), [Luồng UI](test/presentation/app_flow_test.dart), [Bố cục](test/presentation/responsive_layout_test.dart), [State accuracy](test/presentation/game_list_bloc_test.dart), [Hiển thị accuracy](test/presentation/game_card_accuracy_test.dart).

## Build Windows

Sau khi cài Stockfish:

```powershell
flutter build windows --release
```

Executable: `build/windows/x64/runner/Release/chess_game_review.exe`.

Sao chép **toàn bộ thư mục `Release`**, gồm DLL, `data/` và `engine/`, khi chuyển máy. CMake đóng gói Stockfish cùng license và source đi kèm nếu `engine/stockfish/stockfish.exe` tồn tại lúc build.
