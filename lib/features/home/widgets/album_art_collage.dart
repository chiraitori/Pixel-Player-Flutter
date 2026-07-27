import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/song.dart';
import '../../../core/theme/rounded_star_clipper.dart';
import '../../../shared/widgets/artwork.dart';

enum CollagePattern {
  cosmicSwirl('cosmic_swirl', 'Cosmic Swirl'),
  honeycombGroove('honeycomb_groove', 'Honeycomb Groove'),
  vinylStack('vinyl_stack', 'Vinyl Stack'),
  pixelMosaic('pixel_mosaic', 'Pixel Mosaic'),
  stardustScatter('stardust_scatter', 'Stardust Scatter');

  const CollagePattern(this.storageKey, this.label);

  final String storageKey;
  final String label;

  static CollagePattern fromStorageKey(String? value) =>
      values.where((pattern) => pattern.storageKey == value).firstOrNull ??
      cosmicSwirl;
}

class AlbumArtCollage extends StatefulWidget {
  const AlbumArtCollage({
    required this.songs,
    required this.onSongTap,
    this.height = 400,
    this.padding = 14,
    this.pattern = CollagePattern.cosmicSwirl,
    this.autoRotate = false,
    super.key,
  });

  final List<Song> songs;
  final ValueChanged<Song> onSongTap;
  final double height;
  final double padding;
  final CollagePattern pattern;
  final bool autoRotate;

  @override
  State<AlbumArtCollage> createState() => _AlbumArtCollageState();
}

class _AlbumArtCollageState extends State<AlbumArtCollage> {
  static int _rotationIndex = -1;
  late CollagePattern _activePattern;

  @override
  void initState() {
    super.initState();
    if (widget.autoRotate) {
      _rotationIndex = (_rotationIndex + 1) % CollagePattern.values.length;
      _activePattern = CollagePattern.values[_rotationIndex];
    } else {
      _activePattern = widget.pattern;
    }
  }

  @override
  void didUpdateWidget(covariant AlbumArtCollage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.autoRotate && widget.pattern != oldWidget.pattern) {
      _activePattern = widget.pattern;
    } else if (widget.autoRotate && !oldWidget.autoRotate) {
      _rotationIndex = (_rotationIndex + 1) % CollagePattern.values.length;
      _activePattern = CollagePattern.values[_rotationIndex];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.songs.isEmpty) return const SizedBox.shrink();
    final songs = List<Song>.generate(
      6,
      (index) => widget.songs[index % widget.songs.length],
      growable: false,
    );
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.all(widget.padding),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final unit = math.min(300.0, widget.height);
            final configs = _configs(
              _activePattern,
              unit,
              constraints.maxHeight,
            );
            final topHeight = constraints.maxHeight * .6;
            final bottomHeight = constraints.maxHeight * .4;
            return Column(
              children: [
                SizedBox(
                  height: topHeight,
                  width: double.infinity,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (var index = 0; index < 3; index++)
                        _CollageTile(
                          song: songs[index],
                          config: configs[index],
                          onTap: () => widget.onSongTap(songs[index]),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  height: bottomHeight,
                  width: double.infinity,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (var index = 3; index < configs.length; index++)
                        _CollageTile(
                          song: songs[index],
                          config: configs[index],
                          onTap: () => widget.onSongTap(songs[index]),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CollageTile extends StatelessWidget {
  const _CollageTile({
    required this.song,
    required this.config,
    required this.onTap,
  });

  final Song song;
  final _CollageConfig config;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget image = Artwork(
      colors: song.colors,
      mediaStoreId: song.mediaStoreId,
      borderRadius: 0,
    );
    image = switch (config.shape) {
      _CollageShape.circle => ClipOval(child: image),
      _CollageShape.rounded => ClipRRect(
        borderRadius: BorderRadius.circular(config.radius),
        child: image,
      ),
      _CollageShape.capsule => ClipRRect(
        borderRadius: BorderRadius.circular(
          math.min(config.width, config.height) / 2,
        ),
        child: image,
      ),
      _CollageShape.star => ClipPath(
        clipper: RoundedStarClipper(
          sides: config.sides,
          curve: config.curve,
          rotation: config.starRotation,
        ),
        child: image,
      ),
    };

    return Align(
      alignment: config.alignment,
      child: Transform.translate(
        offset: Offset(config.offsetX, config.offsetY),
        child: Transform.rotate(
          angle: config.rotation * math.pi / 180,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: SizedBox(
              width: config.width,
              height: config.height,
              child: image,
            ),
          ),
        ),
      ),
    );
  }
}

enum _CollageShape { circle, rounded, capsule, star }

class _CollageConfig {
  const _CollageConfig({
    required this.width,
    required this.height,
    required this.alignment,
    this.rotation = 0,
    this.shape = _CollageShape.circle,
    this.radius = 0,
    this.sides = 6,
    this.curve = .09,
    this.starRotation = 0,
    this.offsetX = 0,
    this.offsetY = 0,
  });

  final double width;
  final double height;
  final Alignment alignment;
  final double rotation;
  final _CollageShape shape;
  final double radius;
  final int sides;
  final double curve;
  final double starRotation;
  final double offsetX;
  final double offsetY;
}

List<_CollageConfig> _configs(
  CollagePattern pattern,
  double unit,
  double boxHeight,
) => switch (pattern) {
  CollagePattern.cosmicSwirl => [
    _CollageConfig(
      width: unit * .48,
      height: unit * .8,
      alignment: Alignment.center,
      rotation: 45,
      shape: _CollageShape.capsule,
    ),
    _CollageConfig(
      width: unit * .24,
      height: unit * .24,
      alignment: Alignment.topLeft,
      offsetX: 15,
      offsetY: boxHeight * .05,
    ),
    _CollageConfig(
      width: unit * .24,
      height: unit * .24,
      alignment: Alignment.bottomRight,
      offsetX: -15,
      offsetY: -boxHeight * .05,
    ),
    _CollageConfig(
      width: unit * .35,
      height: unit * .35,
      alignment: Alignment.topLeft,
      rotation: -20,
      shape: _CollageShape.rounded,
      radius: 20,
      offsetX: 30,
      offsetY: boxHeight * .1,
    ),
    _CollageConfig(
      width: unit * .9,
      height: unit * .9,
      alignment: Alignment.bottomRight,
      shape: _CollageShape.star,
      sides: 6,
      curve: .09,
      starRotation: 45,
      offsetX: 42,
    ),
  ],
  CollagePattern.honeycombGroove => [
    _CollageConfig(
      width: unit * .7,
      height: unit * .7,
      alignment: Alignment.center,
      shape: _CollageShape.star,
      sides: 6,
      curve: .05,
    ),
    _CollageConfig(
      width: unit * .22,
      height: unit * .22,
      alignment: Alignment.topRight,
      rotation: 15,
      shape: _CollageShape.rounded,
      radius: 16,
      offsetX: -9,
      offsetY: boxHeight * .04,
    ),
    _CollageConfig(
      width: unit * .18,
      height: unit * .18,
      alignment: Alignment.bottomLeft,
      offsetX: 12,
      offsetY: -boxHeight * .04,
    ),
    _CollageConfig(
      width: unit * .55,
      height: unit * .55,
      alignment: Alignment.bottomLeft,
      rotation: -10,
      shape: _CollageShape.star,
      sides: 6,
      curve: .05,
      starRotation: 30,
      offsetX: 6,
      offsetY: -boxHeight * .02,
    ),
    _CollageConfig(
      width: unit * .42,
      height: unit * .55,
      alignment: Alignment.topRight,
      rotation: 30,
      shape: _CollageShape.capsule,
      offsetX: -18,
      offsetY: boxHeight * .03,
    ),
  ],
  CollagePattern.vinylStack => [
    _CollageConfig(
      width: unit * .55,
      height: unit * .55,
      alignment: Alignment.centerLeft,
      offsetX: 6,
    ),
    _CollageConfig(
      width: unit * .38,
      height: unit * .38,
      alignment: Alignment.centerRight,
      offsetX: -12,
      offsetY: -boxHeight * .08,
    ),
    _CollageConfig(
      width: unit * .15,
      height: unit * .15,
      alignment: Alignment.topRight,
      rotation: -45,
      shape: _CollageShape.capsule,
      offsetX: -6,
      offsetY: boxHeight * .43,
    ),
    _CollageConfig(
      width: unit * .5,
      height: unit * .5,
      alignment: Alignment.center,
      offsetX: 70,
      offsetY: -boxHeight * .02,
    ),
    _CollageConfig(
      width: unit * .35,
      height: unit * .35,
      alignment: Alignment.bottomLeft,
      shape: _CollageShape.star,
      sides: 8,
      curve: .06,
      starRotation: 22,
      offsetX: 15,
      offsetY: -boxHeight * .03,
    ),
  ],
  CollagePattern.pixelMosaic => [
    _CollageConfig(
      width: unit * .42,
      height: unit * .65,
      alignment: Alignment.topLeft,
      shape: _CollageShape.rounded,
      radius: 24,
      offsetX: 9,
      offsetY: boxHeight * .02,
    ),
    _CollageConfig(
      width: unit * .52,
      height: unit * .42,
      alignment: Alignment.topRight,
      rotation: 8,
      shape: _CollageShape.rounded,
      radius: 20,
      offsetX: -12,
      offsetY: boxHeight * .06,
    ),
    _CollageConfig(
      width: unit * .52,
      height: unit * .12,
      alignment: Alignment.bottomRight,
      rotation: -5,
      shape: _CollageShape.rounded,
      radius: 12,
      offsetX: -18,
      offsetY: -boxHeight * .05,
    ),
    _CollageConfig(
      width: unit * .42,
      height: unit * .52,
      alignment: Alignment.bottomRight,
      rotation: -12,
      shape: _CollageShape.rounded,
      radius: 28,
      offsetX: -6,
      offsetY: -boxHeight * .02,
    ),
    _CollageConfig(
      width: unit * .5,
      height: unit * .48,
      alignment: Alignment.topLeft,
      rotation: 5,
      shape: _CollageShape.rounded,
      radius: 16,
      offsetX: 12,
      offsetY: boxHeight * .04,
    ),
  ],
  CollagePattern.stardustScatter => [
    _CollageConfig(
      width: unit * .65,
      height: unit * .65,
      alignment: Alignment.center,
      rotation: 10,
      shape: _CollageShape.star,
      sides: 5,
      curve: .12,
    ),
    _CollageConfig(
      width: unit * .22,
      height: unit * .22,
      alignment: Alignment.topLeft,
      offsetX: 12,
      offsetY: boxHeight * .03,
    ),
    _CollageConfig(
      width: unit * .26,
      height: unit * .26,
      alignment: Alignment.bottomRight,
      shape: _CollageShape.star,
      sides: 4,
      curve: .18,
      starRotation: 45,
      offsetX: -18,
    ),
    _CollageConfig(
      width: unit * .5,
      height: unit * .5,
      alignment: Alignment.centerRight,
      rotation: -15,
      shape: _CollageShape.star,
      sides: 8,
      curve: .04,
      offsetX: -12,
    ),
    _CollageConfig(
      width: unit * .5,
      height: unit * .42,
      alignment: Alignment.bottomLeft,
      rotation: 25,
      shape: _CollageShape.capsule,
      offsetX: 18,
      offsetY: -boxHeight * .03,
    ),
  ],
};
