# Chess Game Review

Ứng dụng Flutter đọc ván cờ từ Chess.com REST API và phân tích bằng Stockfish cục bộ. Dự án áp dụng **Chủ đề 01: OOP nâng cao & Xử lý lỗi trong Dart**, **Chủ đề 02: Bố cục linh hoạt & Xử lý không gian**, **Chủ đề 08: Animation & Cử chỉ**, đồng thời giữ kiến trúc của **Chủ đề 04: Clean Architecture & Dependency Injection**.

Danh sách ván hiển thị **Thắng / Thua / Hòa** theo người chơi được tìm kiếm. Trong màn hình xem lại, nút **Cài đặt phân tích** chọn độ sâu; mục **Chi tiết** mở các chỉ số và biến phân tích của nước đi. Các nút thông tin cung cấp hướng dẫn khi cần.

Sau khi phân tích, màn hình hiện biểu đồ và tổng kết trước. Nhấn **Bắt đầu xem lại** để xem nước đầu tiên; bảng bên cạnh chuyển sang nhận xét, danh sách nước đi, biểu đồ và nút điều hướng. **Tổng kết → Tiếp tục xem lại** giữ nguyên vị trí và nhánh đang thử, không phân tích lại. Chọn điểm trên biểu đồ hoặc kéo quân cũng mở phần xem từng nước. Cửa sổ rộng giữ bàn cờ bên trái và cuộn bảng bên phải; cửa sổ hẹp hoặc thấp xếp các phần theo chiều dọc.

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

Ứng dụng chạy với cấu hình mặc định. Các tùy chọn bên dưới cho phép đổi đường dẫn Stockfish và User-Agent:

| Cấu hình | Cách truyền | Mục đích |
| --- | --- | --- |
| `STOCKFISH_PATH` | Biến môi trường Windows hoặc `--dart-define` | Dùng executable Stockfish ở đường dẫn riêng; `--dart-define` được ưu tiên |
| `CHESS_USER_AGENT` | `--dart-define` | Đổi User-Agent gửi tới Chess.com; mặc định đã có trong `NetworkModule` |

Ví dụ dùng Stockfish đã cài riêng:

```powershell
$env:STOCKFISH_PATH = 'C:\tools\stockfish\stockfish.exe'
flutter run -d windows
```

## Các yêu cầu Chủ đề 01 (Tuần 11) trong mã nguồn

| Yêu cầu | Vị trí và cách áp dụng |
| --- | --- |
| Named constructor | [GameDto.fromChessCom](lib/data/models/game_dto.dart) trực tiếp tạo DTO từ JSON Chess.com: đọc các trường có kiểu, đổi timestamp sang UTC và xử lý accuracy tùy chọn; DataSource gọi khi tải ván, `toEntity()` chuyển DTO thành `Game` cho Domain |
| Factory constructor | [PlayerDto.fromJson](lib/data/models/game_dto.dart) tạo DTO người chơi từ JSON; [AppException.from](lib/core/errors/app_exception.dart) chuẩn hóa lỗi cho UI |
| Mixin | [OperationLogging](lib/core/logging/operation_logging.dart) được dùng bằng `with` trong `ChessComRemoteDataSource` và `StockfishEvaluationEngine` để ghi lỗi và thời gian xử lý qua `dart:developer` |
| Generics | [UseCase<T, P>](lib/domain/usecases/usecase.dart), `logOperation<T>` và [runWithErrorHandling<T>](lib/core/errors/run_with_error_handling.dart) dùng lại cho nhiều kiểu dữ liệu |
| Custom Exception | [AppException](lib/core/errors/app_exception.dart) và các lớp con biểu diễn lỗi mạng, HTTP, dữ liệu, engine và hủy thao tác; Data chuyển lỗi Dio thành exception của ứng dụng |
| Wrapper, try-catch-finally | [runWithErrorHandling](lib/core/errors/run_with_error_handling.dart) bắt lỗi đồng bộ/bất đồng bộ tại Bloc, chuyển lỗi thành state; `finally` hủy token khi kết thúc theo dõi review |
| Thông báo thân thiện trên UI | `GameListBloc` và `ReviewBloc` truyền exception qua state; widget hiển thị `message`, hỗ trợ thử lại; kiểm chứng trong [app_flow_test.dart](test/presentation/app_flow_test.dart) |

Repository/UseCase trả dữ liệu trực tiếp (`Future<T>`, `Stream<ReviewProgress>`) và ném `AppException` khi thất bại. `ReviewBloc` chờ và bắt lỗi từ stream qua wrapper.

Demo xử lý lỗi: nhập `../x` rồi nhấn **Tìm ván** để thấy lỗi kiểm tra đầu vào; hoặc ngắt mạng và tìm `erik` để thấy lỗi kết nối, sau đó kết nối lại và nhấn **Thử lại**.

## Các yêu cầu Chủ đề 02 (Tuần 12) trong mã nguồn

| Yêu cầu | Vị trí và cách áp dụng |
| --- | --- |
| Main axis, cross axis, phân chia không gian | [review_panels.dart](lib/presentation/widgets/review_panels.dart): `LayoutBuilder` chọn `Row` hai cột hoặc `Column`; `Expanded` chia không gian bàn cờ và kết quả theo tỷ lệ 6:4 |
| Expanded, Flexible | `Expanded` cấp phần chiều rộng còn lại cho bàn cờ; `Flexible` cho nhãn chất lượng nước đi xuống dòng trong bảng tổng kết |
| Stack, Positioned | [chess_board.dart](lib/presentation/widgets/chess_board.dart): xếp quân cờ và tọa độ lên từng ô; `AspectRatio` giữ bàn cờ vuông khi resize |
| Xử lý overflow | [game_list_widgets.dart](lib/presentation/widgets/game_list_widgets.dart): ô tìm kiếm và nút chuyển sang chiều dọc khi thiếu chỗ; các panel review dùng `Wrap` và vùng cuộn; [move_list.dart](lib/presentation/widgets/move_list.dart) tính chiều cao hàng theo nội dung và cỡ chữ, dùng cùng chiều cao để cuộn tới nước đang chọn |
| Kiểm chứng thay đổi kích thước/nội dung | [responsive_layout_test.dart](test/presentation/responsive_layout_test.dart): cửa sổ hẹp/thấp, chữ 100–200%, tên dài, thông báo lỗi dài, thao tác nút và giữ nước đi khi resize |

Demo: mở một ván đã phân tích, chọn nước đi và đảo bàn cờ; kéo cửa sổ từ rộng xuống hẹp để thấy hai cột chuyển thành một cột, sau đó giảm chiều cao để thử cuộn. Ứng dụng giữ nguyên nước đang chọn và hướng bàn cờ. Chạy `flutter test test/presentation/responsive_layout_test.dart` để kiểm tra thêm trường hợp chữ lớn và nội dung dài bằng dữ liệu kiểm thử.

## Các yêu cầu Chủ đề 04 (Tuần 10) trong mã nguồn

| Yêu cầu | Vị trí |
| --- | --- |
| Ba tầng Presentation / Domain / Data | [presentation/](lib/presentation/), [domain/](lib/domain/), [data/](lib/data/) |
| DIP, Repository và UseCase | [GameRepository](lib/domain/repositories/game_repository.dart), [GameRepositoryImpl](lib/data/repositories/game_repository_impl.dart), [GetArchives](lib/domain/usecases/get_archives.dart), [GetMonthlyGames](lib/domain/usecases/get_monthly_games.dart) |
| DI với get_it + injectable | [injection.dart](lib/injection.dart), [injection.config.dart](lib/injection.config.dart) |
| WidgetsBinding, MultiBlocProvider | [main.dart](lib/main.dart), [app.dart](lib/app.dart) |
| Đọc REST API | [ChessComRemoteDataSource](lib/data/datasources/chess_com_remote_data_source.dart) |
| Unit test Domain với mock abstract interface | [get_games_test.dart](test/domain/get_games_test.dart), [review_game_test.dart](test/domain/review_game_test.dart) |
| Kiểm tra Presentation không phụ thuộc Data Source | [architecture_test.dart](test/architecture_test.dart) |

## Các yêu cầu Chủ đề 08 trong mã nguồn

| Yêu cầu | Vị trí và cách áp dụng |
| --- | --- |
| Implicit animation | [chess_board.dart](lib/presentation/widgets/chess_board.dart): `AnimatedContainer` chuyển màu cả ô xuất phát và ô đích; `TweenAnimationBuilder` cho nhãn chất lượng ở ô đích xuất hiện bằng opacity và scale |
| AnimationController và tài nguyên | Quân trượt 350 ms khi xem từng nước; nhãn chất lượng xuất hiện trong 280 ms sau khi quân tới ô đích. Thả sai trả quân về trong 200 ms; `SingleTickerProviderStateMixin`, `initState`, `dispose`, hỗ trợ `disableAnimations` |
| Gesture có chức năng thực tế | `Draggable` cho phép kéo quân trực tiếp, gợi ý ô hợp lệ, chọn quân phong cấp; quân bám con trỏ khi kéo |
| Phân tích nước thử | [ExploreMoves](lib/domain/usecases/explore_moves.dart) dùng abstract `ChessRules` để kiểm tra/thực hiện nước; [AnalyzeMove](lib/domain/usecases/analyze_move.dart) đánh giá trước/sau qua abstract `EvaluationEngine` và dùng lại công thức phân loại |
| Không cản thao tác | [VariationCubit](lib/presentation/bloc/variation_cubit.dart) cập nhật bàn ngay, hủy tìm kiếm cũ và bỏ qua kết quả đến muộn; cho phép đi tiếp trong lúc engine tính; xóa màu/điểm cũ khi chuyển sang vị trí mới |

Demo: mở một ván đã phân tích → chọn vị trí → kéo quân của bên tới lượt sang ô có chấm. Đi đúng nước tiếp theo vẫn theo ván gốc; đi khác tự tạo nhánh ngay khi thả quân. Thả sai hoặc ngoài bàn sẽ trả quân về. Sau khi Stockfish tính xong, cả ô xuất phát và ô đích đổi cùng màu chất lượng nước đi, kèm nhãn nhỏ ở ô đích; phần nhận xét bên dưới vẫn có tên chất lượng bằng chữ.

Có thể kéo tiếp cho cả hai bên, dùng nút/phím ← → hoặc chọn nước trong nhánh. Bấm **Về ván gốc**, phím **Esc**, hoặc chọn một nước trong danh sách/biểu đồ ván gốc để trở lại. Nhánh là tạm thời: đi khác ở giữa nhánh thay phần tiếp theo; trở về ván gốc bỏ nhánh. Tổng kết accuracy và biểu đồ luôn thuộc ván gốc. Nếu phân tích lỗi, vị trí vẫn giữ nguyên và có nút thử lại.

Kiểm chứng: `test/domain/analyze_move_test.dart` mock các interface; `test/data/interactive_rules_test.dart` kiểm tra luật; `test/presentation/chess_board_test.dart` và `variation_cubit_test.dart` kiểm tra kéo thả, chuyển động, nhánh, hủy/tái thử.

## Kiểm tra

Các test Domain, bố cục và tương tác nêu trên không cần mạng hay Stockfish thật.

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
