import 'package:flutter/material.dart';

import '../../../core/state/app_controller.dart';
import 'genre_icon_provider.dart';
import 'genre_typography.dart';

class GenreCategoriesGrid extends StatelessWidget {
  const GenreCategoriesGrid({
    required this.genres,
    required this.selectedGenres,
    required this.onGenreClick,
    required this.onSelectionToggle,
    required this.onSelectAll,
    required this.onClearSelection,
    required this.onSelectionOptions,
    super.key,
  });

  final List<String> genres;
  final List<String> selectedGenres;
  final ValueChanged<String> onGenreClick;
  final ValueChanged<String> onSelectionToggle;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onSelectionOptions;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final grid = controller.boolSetting('search_genre_grid', true);
    final systemBottomInset = MediaQuery.viewPaddingOf(
      context,
    ).bottom.clamp(0.0, 96.0);
    final navigationBarHeight = controller.navBarCompactMode ? 64.0 : 90.0;
    final bottomContentPadding =
        28.0 + navigationBarHeight + systemBottomInset + 64.0;
    return Column(
      children: [
        if (selectedGenres.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${selectedGenres.length} selected',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onSelectAll,
                  icon: const Icon(Icons.select_all_rounded),
                  tooltip: 'Select all',
                ),
                IconButton.filledTonal(
                  onPressed: onSelectionOptions,
                  icon: const Icon(Icons.more_horiz_rounded),
                  tooltip: 'Selection options',
                ),
                IconButton(
                  onPressed: onClearSelection,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Clear selection',
                ),
              ],
            ),
          ),
        Expanded(
          child: ClipPath(
            clipper: ShapeBorderClipper(
              shape: const RoundedSuperellipseBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
            ),
            child: CustomScrollView(
              key: const PageStorageKey('genre-categories-scroll'),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
                  sliver: SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 6, 0, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Browse by genre',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          TweenAnimationBuilder<double>(
                            tween: Tween(end: grid ? 50 : 12),
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.fastOutSlowIn,
                            builder: (context, radius, child) =>
                                IconButton.filledTonal(
                                  onPressed: () => controller.setBoolSetting(
                                    'search_genre_grid',
                                    !grid,
                                  ),
                                  style: IconButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        radius,
                                      ),
                                    ),
                                  ),
                                  icon: child!,
                                  tooltip: grid ? 'List view' : 'Grid view',
                                ),
                            child: Icon(
                              grid
                                  ? Icons.view_list_rounded
                                  : Icons.grid_view_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(18, 0, 18, bottomContentPadding),
                  sliver: SliverGrid(
                    gridDelegate: grid
                        ? const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1.2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          )
                        : const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 1,
                            mainAxisExtent: 100,
                            mainAxisSpacing: 12,
                          ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final genre = genres[index];
                      return _GenreCard(
                        genre: genre,
                        grid: grid,
                        selected: selectedGenres.contains(genre),
                        selectionIndex: selectedGenres.indexOf(genre) + 1,
                        onTap: () {
                          if (selectedGenres.isNotEmpty) {
                            onSelectionToggle(genre);
                          } else {
                            onGenreClick(genre);
                          }
                        },
                        onLongPress: () => onSelectionToggle(genre),
                      );
                    }, childCount: genres.length),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GenreCard extends StatelessWidget {
  const _GenreCard({
    required this.genre,
    required this.grid,
    required this.selected,
    required this.selectionIndex,
    required this.onTap,
    required this.onLongPress,
  });

  final String genre;
  final bool grid;
  final bool selected;
  final int selectionIndex;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  static const lightColors = <(Color, Color)>[
    (Color(0xFFD7E3FF), Color(0xFF005AC1)),
    (Color(0xFFFFD8E4), Color(0xFF631835)),
    (Color(0xFFFFD8EC), Color(0xFF631B4B)),
    (Color(0xFFCCE8EA), Color(0xFF004F58)),
    (Color(0xFFCBEFD0), Color(0xFF042106)),
    (Color(0xFFFFDEAC), Color(0xFF281900)),
    (Color(0xFFEFF1F7), Color(0xFF44474F)),
    (Color(0xFFE8DEF8), Color(0xFF1D192B)),
    (Color(0xFFFFB4AB), Color(0xFF690005)),
    (Color(0xFFDDF669), Color(0xFF2F3300)),
    (Color(0xFF8CF4E6), Color(0xFF00201C)),
    (Color(0xFFEADDFF), Color(0xFF21005D)),
    (Color(0xFFFFD9E2), Color(0xFF3B071D)),
    (Color(0xFFFFE084), Color(0xFF231B00)),
    (Color(0xFF99CBFF), Color(0xFF003258)),
    (Color(0xFFD1E4FF), Color(0xFF051C36)),
    (Color(0xFFFFDAD6), Color(0xFF410002)),
    (Color(0xFFE2E2E9), Color(0xFF191C20)),
    (Color(0xFFF2DAFF), Color(0xFF2C004F)),
    (Color(0xFFFFDEA5), Color(0xFF261900)),
  ];

  static const darkColors = <(Color, Color)>[
    (Color(0xFF004A77), Color(0xFFC2E7FF)),
    (Color(0xFF7D5260), Color(0xFFFFD8E4)),
    (Color(0xFF633B48), Color(0xFFFFD8EC)),
    (Color(0xFF004F58), Color(0xFF88FAFF)),
    (Color(0xFF324F34), Color(0xFFCBEFD0)),
    (Color(0xFF6E4E13), Color(0xFFFFDEAC)),
    (Color(0xFF3F474D), Color(0xFFDEE3EB)),
    (Color(0xFF4A4458), Color(0xFFE8DEF8)),
    (Color(0xFF7D2B2B), Color(0xFFFFB4AB)),
    (Color(0xFF5B6300), Color(0xFFDDF669)),
    (Color(0xFF005047), Color(0xFF8CF4E6)),
    (Color(0xFF4F378B), Color(0xFFEADDFF)),
    (Color(0xFF8B4A62), Color(0xFFFFD9E2)),
    (Color(0xFF725C00), Color(0xFFFFE084)),
    (Color(0xFF00213B), Color(0xFF99CBFF)),
    (Color(0xFF23507D), Color(0xFFD1E4FF)),
    (Color(0xFF93000A), Color(0xFFFFDAD6)),
    (Color(0xFF45464F), Color(0xFFC4C6D0)),
    (Color(0xFF5D3F75), Color(0xFFE8B6FF)),
    (Color(0xFF7A5900), Color(0xFFFFDEA5)),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final normalized = genre.trim().toLowerCase();
    final (
      container,
      content,
    ) = normalized == 'unknown' || normalized == 'unknown genre'
        ? dark
              ? (const Color(0xFF3A3B42), const Color(0xFFF2F1F6))
              : (const Color(0xFFE5E5EA), const Color(0xFF1B1B20))
        : (dark ? darkColors : lightColors)[_kotlinHash(genre).abs() %
              lightColors.length];
    final title = resolveGenreTitle(genre, grid: grid);
    return AnimatedScale(
      scale: selected ? .98 : 1,
      duration: const Duration(milliseconds: 200),
      child: Card(
        margin: EdgeInsets.zero,
        color: container,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: selected
              ? BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2.5,
                )
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Stack(
            children: [
              Positioned(
                right: -16,
                bottom: -16,
                child: Icon(
                  genreIconFor(genre),
                  size: 90,
                  color: content.withValues(alpha: .55),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(14, 14, grid ? 14 : 96, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.firstLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: title.style.copyWith(color: content),
                    ),
                    if (title.secondLine case final second?)
                      Text(
                        second,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: title.style.copyWith(color: content),
                      ),
                  ],
                ),
              ),
              if (selected)
                Positioned.fill(
                  child: ColoredBox(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .4),
                    child: Center(
                      child: Text(
                        '$selectionIndex',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  int _kotlinHash(String value) {
    var hash = 0;
    for (final unit in value.codeUnits) {
      hash = (31 * hash + unit) & 0xFFFFFFFF;
    }
    return hash > 0x7FFFFFFF ? hash - 0x100000000 : hash;
  }
}
