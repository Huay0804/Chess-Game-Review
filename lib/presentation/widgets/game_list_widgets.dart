import 'package:chess_game_review/core/theme/app_theme.dart';
import 'package:chess_game_review/domain/entities/game.dart';
import 'package:chess_game_review/presentation/bloc/game_list_bloc.dart';
import 'package:chess_game_review/presentation/widgets/empty_state.dart';
import 'package:chess_game_review/presentation/widgets/game_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class GameListBody extends StatelessWidget {
  const GameListBody({
    super.key,
    required this.usernameController,
    required this.formKey,
    required this.onSearch,
    required this.onReview,
  });

  final TextEditingController usernameController;
  final GlobalKey<FormState> formKey;
  final VoidCallback onSearch;
  final ValueChanged<Game>? onReview;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1100),
      child: BlocBuilder<GameListBloc, GameListState>(
        builder: (context, state) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 18),
            Text(
              'Mỗi ván cờ,\nmột điều để học.',
              style: Theme.of(
                context,
              ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            const Text(
              'Khám phá ván đấu Chess.com của bạn, xem lại từng nước và tìm những cơ hội đã bỏ lỡ.',
              style: TextStyle(color: AppTheme.muted, height: 1.6),
            ),
            const SizedBox(height: 28),
            Form(
              key: formKey,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username Chess.com',
                        hintText: 'Ví dụ: erik',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      onFieldSubmitted: (_) => onSearch(),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Nhập username để bắt đầu'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: onSearch,
                      icon: const Icon(Icons.search),
                      label: const Text('Tìm ván'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            GameListResults(state: state, onReview: onReview),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}

class GameListResults extends StatelessWidget {
  const GameListResults({
    super.key,
    required this.state,
    required this.onReview,
  });

  final GameListState state;
  final ValueChanged<Game>? onReview;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (state.status == GameListStatus.loadingArchives ||
          state.status == GameListStatus.loadingGames)
        const Padding(
          padding: EdgeInsets.only(bottom: 18),
          child: LinearProgressIndicator(),
        ),
      if (state.failure != null)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.accent),
                const SizedBox(width: 12),
                Expanded(child: Text(state.failure!.message)),
                TextButton(
                  onPressed: () => context.read<GameListBloc>().add(
                    state.month == null
                        ? SearchPlayer(state.username)
                        : SelectMonth(state.month!),
                  ),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      if (state.archives.isNotEmpty) ...[
        Text(
          'KHO VÁN CỦA ${state.username.toUpperCase()}',
          style: const TextStyle(
            letterSpacing: 1.5,
            color: AppTheme.muted,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('${state.username}/${state.month?.path}'),
          initialValue: state.month?.path,
          decoration: const InputDecoration(
            labelText: 'Chọn tháng',
            prefixIcon: Icon(Icons.calendar_month_outlined),
          ),
          items: state.archives
              .map(
                (month) => DropdownMenuItem(
                  value: month.path,
                  child: Text(month.label),
                ),
              )
              .toList(),
          onChanged: (path) {
            if (path != null) {
              context.read<GameListBloc>().add(
                SelectMonth(
                  state.archives.firstWhere((month) => month.path == path),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 18),
      ],
      if (state.month != null) ...[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final timeClass in <String?>[
              null,
              'bullet',
              'blitz',
              'rapid',
              'daily',
            ])
              ChoiceChip(
                label: Text(timeClass ?? 'Tất cả'),
                selected: state.timeClass == timeClass,
                onSelected: (_) => context.read<GameListBloc>().add(
                  FilterTimeClass(timeClass),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          '${state.visibleGames.length} VÁN ĐẤU',
          style: const TextStyle(
            color: AppTheme.muted,
            fontSize: 12,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        ...state.visibleGames.map(
          (game) => GameCard(
            game: game,
            username: state.username,
            onTap: game.canReview && onReview != null
                ? () => onReview!(game)
                : null,
          ),
        ),
      ],
      if (state.status == GameListStatus.initial)
        const EmptyState(
          icon: Icons.travel_explore,
          title: 'Bắt đầu từ một username',
          detail:
              'Không cần đăng nhập hay API key. Ván cờ được lấy từ dữ liệu công khai.',
        ),
      if (state.status == GameListStatus.archives && state.archives.isEmpty)
        const EmptyState(
          icon: Icons.folder_open,
          title: 'Chưa có ván đấu',
          detail: 'Người chơi này chưa có tháng nào trong kho công khai.',
        ),
      if (state.status == GameListStatus.loaded && state.visibleGames.isEmpty)
        const EmptyState(
          icon: Icons.filter_alt_off_outlined,
          title: 'Không có ván phù hợp',
          detail: 'Hãy chọn tháng hoặc bộ lọc khác.',
        ),
    ],
  );
}
