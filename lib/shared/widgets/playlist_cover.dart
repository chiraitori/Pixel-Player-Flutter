import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/song.dart';
import '../../core/theme/rounded_star_clipper.dart';
import 'artwork.dart';

/// Flutter counterpart of PixelPlay's Compose `PlaylistCover`.
class PlaylistCover extends StatelessWidget {
  const PlaylistCover({required this.playlist, this.size = 48, super.key});

  final Playlist playlist;
  final double size;

  static const _icons = <String, IconData>{
    'MusicNote': Icons.music_note_rounded,
    'Headphones': Icons.headphones_rounded,
    'Album': Icons.album_rounded,
    'Mic': Icons.mic_external_on_rounded,
    'Speaker': Icons.speaker_rounded,
    'Favorite': Icons.favorite_rounded,
    'Piano': Icons.piano_rounded,
    'Queue': Icons.queue_music_rounded,
    // Compatibility with playlists created by early Flutter builds.
    'queue_music': Icons.queue_music_rounded,
    'favorite': Icons.favorite_rounded,
    'star': Icons.star_rounded,
    'nightlife': Icons.nightlife_rounded,
    'headphones': Icons.headphones_rounded,
    'auto_awesome': Icons.auto_awesome_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final path = playlist.coverPath;
    final colorValue = playlist.coverColorValue;
    final hasCustomShape = path != null || colorValue != null;
    final content = switch ((path, colorValue)) {
      (final String imagePath, _) when File(imagePath).existsSync() =>
        Image.file(File(imagePath), fit: BoxFit.cover),
      (_, final int value) => _iconCover(value),
      _ => _PlaylistArtCollage(songs: playlist.songs),
    };

    return SizedBox.square(
      dimension: size,
      child: _CoverShape(
        shape: hasCustomShape ? playlist.coverShape : '',
        referenceSize: size,
        detail1: playlist.coverShapeDetail1,
        detail2: playlist.coverShapeDetail2,
        detail3: playlist.coverShapeDetail3,
        detail4: playlist.coverShapeDetail4,
        child: content,
      ),
    );
  }

  Widget _iconCover(int colorValue) {
    final color = Color(colorValue);
    final iconColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    final rotated = playlist.coverShape.toLowerCase() == 'rotatedpill';
    return ColoredBox(
      color: color,
      child: Center(
        child: Transform.rotate(
          angle: rotated ? -.785398 : 0,
          child: Icon(
            _icons[playlist.coverIconName] ?? Icons.music_note_rounded,
            size: size / 2,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}

class _CoverShape extends StatelessWidget {
  const _CoverShape({
    required this.shape,
    required this.referenceSize,
    required this.child,
    this.detail1,
    this.detail2,
    this.detail3,
    this.detail4,
  });

  final String shape;
  final double referenceSize;
  final Widget child;
  final double? detail1;
  final double? detail2;
  final double? detail3;
  final double? detail4;

  @override
  Widget build(BuildContext context) {
    return switch (shape.toLowerCase()) {
      'circle' => ClipOval(child: child),
      'smoothrect' => ClipRSuperellipse(
        borderRadius: BorderRadius.circular(
          ((detail1 ?? 20) * referenceSize / 200).clamp(0, referenceSize / 2),
        ),
        child: child,
      ),
      'rotatedpill' => Transform.rotate(
        angle: .785398,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: referenceSize * .125),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(referenceSize),
            child: child,
          ),
        ),
      ),
      'star' => Transform.scale(
        scale: detail3 ?? 1,
        child: ClipPath(
          clipper: RoundedStarClipper(
            sides: (detail4 ?? 5).round().clamp(3, 20),
            curve: (detail1 ?? .15).clamp(0, .5),
            rotation: detail2 ?? 0,
          ),
          child: child,
        ),
      ),
      _ => ClipRRect(
        borderRadius: BorderRadius.circular(referenceSize / 6),
        child: child,
      ),
    };
  }
}

class _PlaylistArtCollage extends StatelessWidget {
  const _PlaylistArtCollage({required this.songs});

  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      final colors = Theme.of(context).colorScheme;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colors.secondaryContainer,
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FittedBox(
            child: Icon(
              Icons.queue_music_rounded,
              color: colors.onSecondaryContainer,
            ),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        return switch (songs.length) {
          1 => _circleArt(songs.first, side),
          2 => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _circleArt(songs[0], (side - 2) / 2),
              const SizedBox(height: 2),
              _circleArt(songs[1], (side - 2) / 2),
            ],
          ),
          3 => _threeSongCollage(side),
          _ => Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _circleArt(songs[0], side / 2 - 1)),
                    const SizedBox(width: 2),
                    Expanded(child: _circleArt(songs[1], side / 2 - 1)),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _circleArt(songs[2], side / 2 - 1)),
                    const SizedBox(width: 2),
                    Expanded(child: _circleArt(songs[3], side / 2 - 1)),
                  ],
                ),
              ),
            ],
          ),
        };
      },
    );
  }

  Widget _threeSongCollage(double side) {
    const separation = 2.0;
    final itemSize = (side * 2 / (2 + math.sqrt(3)) - separation)
        .floorToDouble();
    final centerDistance = itemSize + separation;
    final triangleHeight = centerDistance * math.sqrt(3) / 2;
    final collageWidth = centerDistance + itemSize;
    final collageHeight = triangleHeight + itemSize;
    final offsetX = (side - collageWidth) / 2;
    final offsetY = (side - collageHeight) / 2;
    return Stack(
      children: [
        Positioned(
          left: offsetX + (collageWidth - itemSize) / 2,
          top: offsetY,
          child: _circleArt(songs[0], itemSize),
        ),
        Positioned(
          left: offsetX,
          top: offsetY + triangleHeight,
          child: _circleArt(songs[1], itemSize),
        ),
        Positioned(
          left: offsetX + centerDistance,
          top: offsetY + triangleHeight,
          child: _circleArt(songs[2], itemSize),
        ),
      ],
    );
  }

  Widget _circleArt(Song song, double size) {
    return ClipOval(
      child: Artwork(
        colors: song.colors,
        size: size,
        borderRadius: 0,
        mediaStoreId: song.mediaStoreId,
      ),
    );
  }
}
