import 'package:flutter/material.dart';

import '../../core/services/artwork_cache.dart';

class Artwork extends StatelessWidget {
  const Artwork({
    required this.colors,
    this.size,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 18,
    this.iconSize,
    this.heroTag,
    this.mediaStoreId,
    super.key,
  });

  final List<Color> colors;
  final double? size;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final double? iconSize;
  final Object? heroTag;
  final int? mediaStoreId;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width ?? size,
      height: height ?? size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: .22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -18,
            top: -14,
            child: _Disc(color: Colors.white.withValues(alpha: .12), size: 88),
          ),
          Positioned(
            left: -28,
            bottom: -32,
            child: _Disc(color: Colors.black.withValues(alpha: .12), size: 110),
          ),
          Center(
            child: Icon(
              Icons.music_note_rounded,
              color: Colors.white.withValues(alpha: .9),
              size: iconSize ?? ((size ?? 100) * .36),
            ),
          ),
        ],
      ),
    );
    final id = mediaStoreId;
    final art = id == null
        ? placeholder
        : FutureBuilder(
            future: ArtworkCache.bytesForId(id),
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              if (bytes == null || bytes.isEmpty) return placeholder;
              return ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: Image.memory(
                  bytes,
                  width: width ?? size ?? double.infinity,
                  height: height ?? size ?? double.infinity,
                  fit: fit,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) => placeholder,
                ),
              );
            },
          );
    if (heroTag == null) return art;
    return Hero(tag: heroTag!, child: art);
  }
}

class _Disc extends StatelessWidget {
  const _Disc({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
