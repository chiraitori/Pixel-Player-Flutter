import 'package:flutter/material.dart';

import '../../core/models/song.dart';
import '../../shared/widgets/artwork.dart';

Future<void> showPlayerArtistPickerSheet({
  required BuildContext context,
  required List<Artist> artists,
  required ValueChanged<Artist> onArtistSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
    builder: (sheetContext) => _PlayerArtistPickerContent(
      artists: artists,
      onArtistSelected: (artist) {
        Navigator.pop(sheetContext);
        onArtistSelected(artist);
      },
    ),
  );
}

class _PlayerArtistPickerContent extends StatelessWidget {
  const _PlayerArtistPickerContent({
    required this.artists,
    required this.onArtistSelected,
  });

  final List<Artist> artists;
  final ValueChanged<Artist> onArtistSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pick an Artist',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontFamily: 'GoogleSansFlex',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < artists.length; index++) ...[
            _PlayerArtistShortcutCard(
              artist: artists[index],
              isPrimary: index == 0,
              shape: _artistShortcutShape(index, artists.length),
              onTap: () => onArtistSelected(artists[index]),
            ),
            if (index != artists.length - 1) const SizedBox(height: 4),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _PlayerArtistShortcutCard extends StatelessWidget {
  const _PlayerArtistShortcutCard({
    required this.artist,
    required this.isPrimary,
    required this.shape,
    required this.onTap,
  });

  final Artist artist;
  final bool isPrimary;
  final RoundedRectangleBorder shape;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final container = isPrimary
        ? colors.secondaryContainer
        : colors.surfaceContainerLow;
    final foreground = isPrimary
        ? colors.onSecondaryContainer
        : colors.onSurface;
    final labelContainer = isPrimary
        ? colors.tertiary
        : colors.surfaceContainerHighest;
    final labelForeground = isPrimary
        ? colors.onTertiary
        : colors.onSurfaceVariant;

    return Material(
      color: container,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isPrimary
                      ? colors.onSecondaryContainer.withValues(alpha: .12)
                      : colors.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                child: Artwork(
                  colors: artist.colors,
                  size: 52,
                  borderRadius: 26,
                  iconSize: 24,
                  mediaStoreId: artist.songs.first.mediaStoreId,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: foreground,
                        fontFamily: 'GoogleSansFlex',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DecoratedBox(
                      decoration: ShapeDecoration(
                        color: labelContainer,
                        shape: const StadiumBorder(),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Text(
                          isPrimary ? 'Primary artist' : 'Artist page',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: labelForeground),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: foreground.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: foreground,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

RoundedRectangleBorder _artistShortcutShape(int index, int count) {
  const outer = Radius.circular(26);
  const inner = Radius.circular(10);
  if (count <= 1) {
    return const RoundedRectangleBorder(borderRadius: BorderRadius.all(outer));
  }
  if (index == 0) {
    return const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: outer,
        topRight: outer,
        bottomLeft: inner,
        bottomRight: inner,
      ),
    );
  }
  if (index == count - 1) {
    return const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: inner,
        topRight: inner,
        bottomLeft: outer,
        bottomRight: outer,
      ),
    );
  }
  return const RoundedRectangleBorder(borderRadius: BorderRadius.all(inner));
}
