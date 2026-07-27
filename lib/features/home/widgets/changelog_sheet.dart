import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ChangelogSheet extends StatelessWidget {
  const ChangelogSheet({super.key});

  static final Uri _changelog = Uri.parse(
    'https://github.com/chiraitori/Pixel-Player-Flutter/blob/main/CHANGELOG.md',
  );

  static const _versions = <_ChangelogVersion>[
    _ChangelogVersion(
      version: '0.7.5-beta',
      date: '2026-06-13',
      sections: [
        _ChangelogSection(
          title: 'What’s New',
          items: [
            'Google Drive integration with player lifecycle management.',
            'Batch song metadata editing (tags and cover art).',
            'AI lyrics translation with customizable Wear OS preferences.',
            'Lag diagnostic tool and multi-selection on Search screen.',
            'Arabic & Turkish support, with localized HTTP URL local-network options.',
          ],
        ),
        _ChangelogSection(
          title: 'Improvements',
          items: [
            'Drastic battery saving (audio offload and UI polling gates).',
            'Optimized queue management (faster insertions and explicit indexing).',
            'Material 3 Expressive motion animations for transition screens.',
            'Refactored library synchronization via throttled scanning.',
          ],
        ),
        _ChangelogSection(
          title: 'Fixes',
          items: [
            'Resolved stuttering/skipping playback lags and buffering issues.',
            'Fixed external song deletion sync and metadata consistency.',
            'Fixed memory issues, crashes, and layout glitches on Wear OS and phone.',
          ],
        ),
      ],
    ),
    _ChangelogVersion(
      version: '0.7.0-beta',
      date: '2026-05-25',
      sections: [
        _ChangelogSection(
          title: 'What’s New',
          items: [
            'Material 3 Expressive redesign across the player and library.',
            'New artist, album, genre, playlist, and statistics experiences.',
            'Expanded lyrics, transitions, streaming, and account tools.',
          ],
        ),
        _ChangelogSection(
          title: 'Improvements',
          items: [
            'Improved library performance, media scanning, and playback reliability.',
            'Refined compact navigation and miniplayer behavior.',
          ],
        ),
      ],
    ),
    _ChangelogVersion(
      version: '0.6.0-beta',
      date: '2026-03-05',
      sections: [
        _ChangelogSection(
          title: 'What’s New',
          items: [
            'Expanded local music library tools and playback customization.',
          ],
        ),
      ],
    ),
    _ChangelogVersion(
      version: '0.5.0-beta',
      date: '2026-01-14',
      sections: [
        _ChangelogSection(
          title: 'Improvements',
          items: ['Player, metadata, and performance refinements.'],
        ),
      ],
    ),
    _ChangelogVersion(
      version: '0.4.0-beta',
      date: '2025-12-15',
      sections: [
        _ChangelogSection(
          title: 'Improvements',
          items: ['Interface and playback improvements.'],
        ),
      ],
    ),
    _ChangelogVersion(
      version: '0.3.0-beta',
      date: '2025-10-28',
      sections: [
        _ChangelogSection(
          title: 'What’s New',
          items: ['New library and player capabilities.'],
        ),
      ],
    ),
    _ChangelogVersion(
      version: '0.2.0-beta',
      date: '2024-09-15',
      sections: [
        _ChangelogSection(
          title: 'Added',
          items: ['Early PixelPlayer beta features and foundations.'],
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
            children: [
              Text(
                'Changelog',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 28,
                child: CustomPaint(
                  painter: _ChangelogWavePainter(
                    colors.primary.withValues(alpha: .75),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (var index = 0; index < _versions.length; index++) ...[
                _VersionItem(
                  version: _versions[index],
                  initiallyExpanded: index == 0,
                ),
                if (index != _versions.length - 1) const SizedBox(height: 24),
              ],
            ],
          ),
          IgnorePointer(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, colors.surfaceContainerLow],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: FloatingActionButton.extended(
              onPressed: () => launchUrl(_changelog),
              backgroundColor: colors.tertiaryContainer,
              foregroundColor: colors.onTertiaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              icon: const Icon(Icons.code_rounded),
              label: const Text('View on GitHub'),
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionItem extends StatefulWidget {
  const _VersionItem({required this.version, required this.initiallyExpanded});

  final _ChangelogVersion version;
  final bool initiallyExpanded;

  @override
  State<_VersionItem> createState() => _VersionItemState();
}

class _VersionItemState extends State<_VersionItem> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    widget.version.version,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  widget.version.date,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _expanded ? .5 : 0,
                  duration: const Duration(milliseconds: 240),
                  child: const Icon(Icons.expand_more_rounded),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < widget.version.sections.length;
                        index++
                      ) ...[
                        _Category(section: widget.version.sections[index]),
                        if (index != widget.version.sections.length - 1)
                          const SizedBox(height: 14),
                      ],
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _Category extends StatelessWidget {
  const _Category({required this.section});

  final _ChangelogSection section;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHigh,
      elevation: 0,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < section.items.length; index++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(section.items[index])),
                ],
              ),
              if (index != section.items.length - 1) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChangelogVersion {
  const _ChangelogVersion({
    required this.version,
    required this.date,
    required this.sections,
  });

  final String version;
  final String date;
  final List<_ChangelogSection> sections;
}

class _ChangelogSection {
  const _ChangelogSection({required this.title, required this.items});

  final String title;
  final List<String> items;
}

class _ChangelogWavePainter extends CustomPainter {
  const _ChangelogWavePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final path = Path();
    for (var x = 0.0; x <= size.width; x++) {
      final y =
          size.height / 2 + math.sin((x / size.width) * math.pi * 2 * 7.6) * 4;
      x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ChangelogWavePainter oldDelegate) =>
      color != oldDelegate.color;
}
