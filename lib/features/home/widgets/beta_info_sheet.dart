import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_info.dart';

class BetaInfoSheet extends StatelessWidget {
  const BetaInfoSheet({super.key});

  static final Uri _issues = Uri.parse(
    'https://github.com/chiraitori/Pixel-Player-Flutter/issues',
  );
  static final Uri _report = Uri.parse(
    'https://github.com/chiraitori/Pixel-Player-Flutter/issues/new/choose',
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 120),
            children: [
              Text(
                'Beta 0.7.5',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 26,
                child: CustomPaint(
                  painter: _SineWavePainter(
                    colors.tertiary.withValues(alpha: .75),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _WelcomeCard(colors: colors),
              const SizedBox(height: 14),
              _GitHubCard(
                onOpenIssues: () => launchUrl(_issues),
                onReport: () => launchUrl(_report),
              ),
              const SizedBox(height: 14),
              const _FaqCard(
                title: 'What to expect',
                summary:
                    'What beta builds can change, break, or improve while testing.',
                icon: Icons.whatshot_rounded,
                initiallyExpanded: true,
                children: [
                  'Bugs, crashes, or incomplete features may occur unexpectedly.',
                  'Some features may change or be removed without notice.',
                  'Beta builds may be more unstable than release versions.',
                  'Always check for updates before reporting a known issue.',
                ],
              ),
              const SizedBox(height: 14),
              const _FaqCard(
                title: 'How to report',
                summary: 'A quick checklist before opening a new issue.',
                icon: Icons.search_rounded,
                children: [
                  'Search existing open and closed issues to avoid duplicates.',
                  'Update to the latest PixelPlayer version and confirm the problem still happens.',
                  'Restart the app and confirm the problem persists.',
                  'Try to reproduce it and write down the exact steps.',
                  'Bug report: Something behaves incorrectly.',
                  'Feature request: Add a new feature or improvement.',
                ],
              ),
              const SizedBox(height: 14),
              const _FaqCard(
                title: 'Bug report',
                summary:
                    'Copy these fields when something behaves incorrectly or crashes.',
                icon: Icons.bug_report_rounded,
                errorAccent: true,
                children: [
                  'Short summary:',
                  'Expected behavior:',
                  'Current behavior:',
                  'Steps to play/reproduce: 1. 2. 3.',
                  'How often does it happen? Always / Sometimes / Rarely.',
                  'Screenshot / video and logs / stack trace, if available.',
                  'PixelPlayer version, install source, Android version, and device model.',
                ],
              ),
              const SizedBox(height: 14),
              const _FaqCard(
                title: 'Feature request',
                summary:
                    'Copy these fields when you want a new feature or improvement.',
                icon: Icons.lightbulb_rounded,
                children: [
                  'Problem statement: What problem are you trying to solve?',
                  'Proposed solution: How should it work?',
                  'Alternatives considered: Any other approaches?',
                  'Scope: Which screens or flows are affected?',
                  'Mockup or reference image if available.',
                ],
              ),
              const SizedBox(height: 14),
              const _FaqCard(
                title: 'Titles, privacy, and scope',
                summary: 'Make the report easy to triage and safe to share.',
                icon: Icons.gavel_rounded,
                children: [
                  'Use a focused title that names the screen and the problem.',
                  'Avoid generic reports like “It doesn’t work”.',
                  'Keep unrelated problems in separate issues.',
                  'Remove personal or private information from logs and screenshots.',
                ],
              ),
              const SizedBox(height: 14),
              const _FaqCard(
                title: 'Nightly builds',
                summary:
                    'How nightlies differ from releases, and what to include when they break.',
                icon: Icons.nights_stay_rounded,
                children: [
                  'Nightlies are generated from the latest commit and may include unfinished changes or regressions.',
                  'Mention the build date, workflow run, or commit SHA in reports.',
                  'Check whether the issue also happens on the latest official release.',
                ],
              ),
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
              onPressed: () => launchUrl(_report),
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              icon: const Icon(Icons.bug_report_rounded),
              label: const Text('Report issue or crash'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    colors.primary,
                    colors.primary.withValues(alpha: .65),
                  ],
                ),
              ),
              child: Text(
                'β',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome to PixelPlayer ${AppInfo.version}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You’re using a beta build that may contain bugs, crashes, '
                    'or experimental features. Help us improve by reporting issues.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GitHubCard extends StatelessWidget {
  const _GitHubCard({required this.onOpenIssues, required this.onReport});

  final VoidCallback onOpenIssues;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.secondaryContainer.withValues(alpha: .55),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.code_rounded),
                const SizedBox(width: 10),
                Text(
                  'GitHub issue shortcut',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Search first, then open a focused report for bugs, crashes, '
              'requests, or questions.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onOpenIssues,
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Open existing issues'),
                ),
                FilledButton.icon(
                  onPressed: onReport,
                  icon: const Icon(Icons.bug_report_rounded),
                  label: const Text('Report issue'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqCard extends StatefulWidget {
  const _FaqCard({
    required this.title,
    required this.summary,
    required this.icon,
    required this.children,
    this.initiallyExpanded = false,
    this.errorAccent = false,
  });

  final String title;
  final String summary;
  final IconData icon;
  final List<String> children;
  final bool initiallyExpanded;
  final bool errorAccent;

  @override
  State<_FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<_FaqCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = widget.errorAccent ? colors.error : colors.primary;
    return Material(
      color: widget.errorAccent
          ? colors.surfaceContainerHighest
          : colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(widget.icon, color: accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.summary,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? .5 : 0,
                    duration: const Duration(milliseconds: 240),
                    child: const Icon(Icons.expand_more_rounded),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _expanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Column(
                          children: [
                            const Divider(),
                            for (final line in widget.children)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 7),
                                      child: Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: accent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(line)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SineWavePainter extends CustomPainter {
  const _SineWavePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final path = Path();
    for (var x = 0.0; x <= size.width; x += 1) {
      final y =
          size.height / 2 + math.sin((x / size.width) * math.pi * 2 * 7.6) * 4;
      x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SineWavePainter oldDelegate) =>
      color != oldDelegate.color;
}
