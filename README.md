# Chess Game Review

Ứng dụng Flutter đọc ván cờ từ Chess.com REST API và phân tích bằng Stockfish cục bộ. Dự án thực hiện **Chủ đề 04: Clean Architecture & Dependency Injection**.

## Thành viên và phân công

| Họ và tên | MSSV | Công việc | Đóng góp |
| --- | --- | --- | --- |
| Ha Le Minh Hieu | 106220216 | UI, Business Logic, State Management, API/Stockfish, DI, kiểm thử, báo cáo và slide | 100% |

## Cài đặt và chạy

Yêu cầu:

- Windows x64, PowerShell và kết nối Internet.
- Flutter SDK trong `PATH`, kèm Dart **>=3.11.0 và <4.0.0** để tương thích `pubspec.lock`.
- Visual Studio hoặc Build Tools với **Desktop development with C++**, Windows SDK và CMake tools.

Tải mã nguồn và mở PowerShell tại thư mục chứa `pubspec.yaml`:

```powershell
flutter doctor -v
flutter pub get
dart run build_runner build
powershell -NoProfile -ExecutionPolicy Bypass -File tool/setup_stockfish.ps1
flutter run -d windows
```

Script cài Stockfish 17.1 vào `engine/stockfish/`. Thư mục này không được lưu trong Git nên cần cài trên máy mới. Chạy lại `dart run build_runner build` khi thay đổi đăng ký DI; không sửa tay `lib/injection.config.dart`.

Để chạy thử: nhập username Chess.com, nhấn **Tìm ván**, chọn tháng và một ván cờ tiêu chuẩn, rồi phân tích ở **depth 12**.

## Cấu hình

Ứng dụng không cần API key, `.env` hoặc `google-services.json`. Các cấu hình sau là tùy chọn:

| Cấu hình | Cách truyền | Mục đích |
| --- | --- | --- |
| `STOCKFISH_PATH` | Biến môi trường Windows hoặc `--dart-define` | Dùng executable Stockfish ở đường dẫn riêng; `--dart-define` được ưu tiên |
| `CHESS_USER_AGENT` | `--dart-define` | Đổi User-Agent gửi tới Chess.com; mặc định đã có trong `NetworkModule` |

Ví dụ dùng Stockfish đã cài riêng:

```powershell
$env:STOCKFISH_PATH = 'C:\tools\stockfish\stockfish.exe'
flutter run -d windows
```

## Các yêu cầu Chủ đề 04 trong mã nguồn

| Yêu cầu | Vị trí |
| --- | --- |
| Ba tầng Presentation / Domain / Data | [presentation/](lib/presentation/), [domain/](lib/domain/), [data/](lib/data/) |
| DIP, Repository và UseCase | [GameRepository](lib/domain/repositories/game_repository.dart), [GameRepositoryImpl](lib/data/repositories/game_repository_impl.dart), [GetArchives](lib/domain/usecases/get_archives.dart), [GetMonthlyGames](lib/domain/usecases/get_monthly_games.dart) |
| DI với get_it + injectable | [injection.dart](lib/injection.dart), [injection.config.dart](lib/injection.config.dart) |
| WidgetsBinding, MultiBlocProvider | [main.dart](lib/main.dart), [app.dart](lib/app.dart) |
| Đọc REST API | [ChessComRemoteDataSource](lib/data/datasources/chess_com_remote_data_source.dart) |
| Unit test Domain với mock abstract interface | [get_games_test.dart](test/domain/get_games_test.dart), [review_game_test.dart](test/domain/review_game_test.dart) |
| Kiểm tra Presentation không phụ thuộc Data Source | [architecture_test.dart](test/architecture_test.dart) |

## Kiểm tra

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Chạy riêng các test về Domain, ranh giới kiến trúc và DI:

```powershell
flutter test test/domain test/architecture_test.dart test/core_test.dart
```

## Build Windows

Sau khi cài Stockfish:

```powershell
flutter build windows --release
```

Executable: `build/windows/x64/runner/Release/chess_game_review.exe`.

Khi chuyển sang máy khác, sao chép **toàn bộ thư mục `Release`**, gồm DLL, `data/` và `engine/`. CMake đóng gói Stockfish cùng license và source đi kèm nếu `engine/stockfish/stockfish.exe` tồn tại lúc build.
