import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/state/app_controller.dart';
import '../shell/player_internal_navigation_bar.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _pageController = PageController();
  int _page = 0;
  ThemeMode _themeMode = ThemeMode.system;
  bool _compactLibrary = false;
  bool _fullWidthNavigation = false;
  double _navBarCornerRadius = 32;
  bool _mediaGranted = false;
  bool _notificationsGranted = false;
  bool _alarmGranted = false;
  bool _batteryGranted = false;
  bool _initialized = false;
  bool _showCornerRadiusOverlay = false;
  String? _selectedBackupName;

  static const _pages = <_SetupPageInfo>[
    _SetupPageInfo("Let's Go!", Icons.waving_hand_rounded),
    _SetupPageInfo('Music access', Icons.library_music_rounded),
    _SetupPageInfo('Notifications', Icons.notifications_active_rounded),
    _SetupPageInfo('Backup & restore', Icons.settings_backup_restore_rounded),
    _SetupPageInfo('Music folders', Icons.folder_copy_rounded),
    _SetupPageInfo('Choose your look', Icons.palette_rounded),
    _SetupPageInfo('Library layout', Icons.view_carousel_rounded),
    _SetupPageInfo('Navigation bar', Icons.space_bar_rounded),
    _SetupPageInfo('Alarms & timer', Icons.alarm_rounded),
    _SetupPageInfo('Battery usage', Icons.battery_saver_rounded),
    _SetupPageInfo('All set', Icons.check_circle_rounded),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final controller = AppScope.of(context);
    _themeMode = controller.themeMode;
    _compactLibrary = controller.libraryCompactMode;
    _fullWidthNavigation = controller.navBarStyle == PixelNavBarStyle.fullWidth;
    _navBarCornerRadius = controller.navBarCornerRadius;
    _refreshPermissions();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _page == 0 && !_showCornerRadiusOverlay,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_showCornerRadiusOverlay) {
          setState(() => _showCornerRadiusOverlay = false);
          return;
        }
        if (_page > 0) _previous();
      },
      child: Scaffold(
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _pages.length,
                      onPageChanged: (value) => setState(() => _page = value),
                      itemBuilder: (context, index) => AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        switchInCurve: Curves.easeOutCubic,
                        child: _pageContent(index),
                      ),
                    ),
                  ),
                  _SetupBottomBar(
                    currentPage: _page,
                    totalPages: _pages.length,
                    canLeaveCurrentPage: _canLeaveCurrentPage,
                    isLastPage: _page == _pages.length - 1,
                    onNext: _next,
                    onFinish: () => AppScope.of(context).completeSetup(),
                  ),
                ],
              ),
            ),
            if (_showCornerRadiusOverlay)
              _NavBarCornerRadiusOverlay(
                initialRadius: _navBarCornerRadius,
                isFullWidth: _fullWidthNavigation,
                onRadiusChanged: (value) {
                  setState(() => _navBarCornerRadius = value);
                  AppScope.of(context).setNavBarCornerRadius(value);
                },
                onDone: () => setState(() => _showCornerRadiusOverlay = false),
                onBack: () => setState(() => _showCornerRadiusOverlay = false),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pageContent(int index) {
    return switch (index) {
      0 => const _WelcomePage(),
      1 => _PermissionPage(
        title: 'Media Permission',
        body:
            'PixelPlayer needs access to your audio files to build your music library.',
        buttonText: _mediaGranted
            ? 'Permission Granted'
            : 'Grant Media Permission',
        granted: _mediaGranted,
        icons: const [
          Icons.music_note_rounded,
          Icons.album_rounded,
          Icons.collections_bookmark_rounded,
          Icons.person_rounded,
          Icons.playlist_play_rounded,
        ],
        onPressed: _requestMediaPermission,
      ),
      2 => _PermissionPage(
        title: 'Notifications',
        body:
            'Enable notifications to control your music from the lock screen and notification shade.',
        buttonText: _notificationsGranted
            ? 'Permission Granted'
            : 'Enable Notifications',
        granted: _notificationsGranted,
        icons: const [
          Icons.notifications_rounded,
          Icons.skip_next_rounded,
          Icons.play_arrow_rounded,
          Icons.pause_rounded,
          Icons.skip_previous_rounded,
        ],
        onPressed: _requestNotificationPermission,
      ),
      3 => _BackupPage(
        selectedBackupName: _selectedBackupName,
        onImport: _pickBackup,
        onSkip: _next,
      ),
      4 => _FoldersPage(onChoose: _pickMusicDirectory, onSkip: _next),
      5 => _ThemePage(
        selected: _themeMode,
        onChanged: (mode) {
          setState(() => _themeMode = mode);
          AppScope.of(context).setThemeMode(mode);
        },
      ),
      6 => _LibraryLayoutPage(
        compact: _compactLibrary,
        onChanged: (value) {
          setState(() => _compactLibrary = value);
          AppScope.of(context).setLibraryCompactMode(value);
        },
      ),
      7 => _NavigationLayoutPage(
        fullWidth: _fullWidthNavigation,
        onChanged: (value) {
          setState(() => _fullWidthNavigation = value);
          AppScope.of(context).setNavBarStyle(
            value ? PixelNavBarStyle.fullWidth : PixelNavBarStyle.floating,
          );
        },
        onCustomizeRadius: () =>
            setState(() => _showCornerRadiusOverlay = true),
      ),
      8 => _PermissionPage(
        title: 'Alarms & Reminders',
        body:
            'Optional, but recommended if you use Sleep Timer and want PixelPlayer to stop playback exactly on time.',
        buttonText: _alarmGranted ? 'Permission Granted' : 'Grant Permission',
        granted: _alarmGranted,
        icons: const [
          Icons.alarm_rounded,
          Icons.schedule_rounded,
          Icons.hourglass_empty_rounded,
          Icons.notifications_active_rounded,
          Icons.timer_rounded,
        ],
        onPressed: _requestAlarmPermission,
        onSkip: _next,
      ),
      9 => _PermissionPage(
        title: 'Uninterrupted playback',
        body:
            'Remove battery restrictions to keep music playing reliably with the screen off.',
        buttonText: _batteryGranted ? 'Permission Granted' : 'Battery settings',
        granted: _batteryGranted,
        icons: const [
          Icons.battery_saver_rounded,
          Icons.play_arrow_rounded,
          Icons.all_inclusive_rounded,
          Icons.pause_rounded,
          Icons.check_circle_rounded,
        ],
        onPressed: _requestBatteryPermission,
        onSkip: _next,
      ),
      _ => const _FinishPage(),
    };
  }

  bool get _canLeaveCurrentPage {
    if (_page == 1) return _mediaGranted;
    if (_page == 2) return _notificationsGranted;
    return true;
  }

  void _next() {
    if (!_canLeaveCurrentPage) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  void _previous() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _refreshPermissions() async {
    try {
      final media = await Permission.audio.status;
      final notifications = await Permission.notification.status;
      final alarm = await Permission.scheduleExactAlarm.status;
      final battery = await Permission.ignoreBatteryOptimizations.status;
      if (!mounted) return;
      setState(() {
        _mediaGranted = media.isGranted;
        _notificationsGranted = notifications.isGranted;
        _alarmGranted = alarm.isGranted;
        _batteryGranted = battery.isGranted;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _mediaGranted = true;
        _notificationsGranted = true;
      });
    }
  }

  Future<void> _requestMediaPermission() async {
    final status = await Permission.audio.request();
    if (!mounted) return;
    setState(() => _mediaGranted = status.isGranted);
    if (status.isPermanentlyDenied) await openAppSettings();
  }

  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.request();
    if (!mounted) return;
    setState(() => _notificationsGranted = status.isGranted);
    if (status.isPermanentlyDenied) await openAppSettings();
  }

  Future<void> _requestAlarmPermission() async {
    final status = await Permission.scheduleExactAlarm.request();
    if (!mounted) return;
    setState(() => _alarmGranted = status.isGranted);
  }

  Future<void> _requestBatteryPermission() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    if (!mounted) return;
    setState(() => _batteryGranted = status.isGranted);
  }

  Future<void> _pickBackup() async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedBackupName = result.files.first.name;
      });
      if (mounted) {
        _showRestoreDialog(context, result.files.first.name);
      }
    }
  }

  void _showRestoreDialog(BuildContext context, String filename) {
    showDialog(
      context: context,
      builder: (context) => _BackupRestoreDialog(
        filename: filename,
        onRestoreConfirmed: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Backup settings restored successfully'),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickMusicDirectory() async {
    await FilePicker.getDirectoryPath();
  }
}

class _PermissionIconCollage extends StatelessWidget {
  const _PermissionIconCollage({required this.icons});

  final List<IconData> icons;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final iconNrColor = colors.onSurface.withValues(alpha: 0.8);
    final iconNrSdColor = colors.onSurface.withValues(alpha: 0.5);
    final iconHighlightColor = colors.primary;
    final iconTrdColor = colors.tertiary;
    final iconSndColor = colors.secondary;

    return SizedBox(
      height: 220,
      width: double.infinity,
      child: Center(
        child: SizedBox(
          width: 280,
          height: 200,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Center card tilted -15 deg
              if (icons.isNotEmpty)
                Transform.rotate(
                  angle: -15 * math.pi / 180,
                  child: Container(
                    width: 145,
                    height: 145,
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: colors.shadow.withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(22),
                    child: Center(
                      child: Icon(icons[0], size: 68, color: iconSndColor),
                    ),
                  ),
                ),

              // Top-Left Circle (rotated 15 deg)
              if (icons.length > 1)
                Positioned(
                  left: 10,
                  top: 10,
                  child: Transform.rotate(
                    angle: 15 * math.pi / 180,
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHigh,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Icon(icons[1], size: 32, color: iconNrColor),
                    ),
                  ),
                ),

              // Top-Right Card (rotated -20 deg)
              if (icons.length > 3)
                Positioned(
                  right: 15,
                  top: 15,
                  child: Transform.rotate(
                    angle: -20 * math.pi / 180,
                    child: Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Icon(icons[3], size: 40, color: iconNrSdColor),
                    ),
                  ),
                ),

              // Bottom-Left Badge (rotated 10 deg)
              if (icons.length > 4)
                Positioned(
                  left: 20,
                  bottom: 15,
                  child: Transform.rotate(
                    angle: 10 * math.pi / 180,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Icon(icons[4], size: 32, color: iconTrdColor),
                    ),
                  ),
                ),

              // Bottom-Right Circle (rotated 5 deg)
              if (icons.length > 2)
                Positioned(
                  right: 20,
                  bottom: 10,
                  child: Transform.rotate(
                    angle: 5 * math.pi / 180,
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHigh,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Icon(
                        icons[2],
                        size: 32,
                        color: iconHighlightColor,
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
}

class _PermissionPage extends StatelessWidget {
  const _PermissionPage({
    required this.title,
    required this.body,
    required this.buttonText,
    required this.granted,
    required this.icons,
    required this.onPressed,
    this.onSkip,
  });

  final String title;
  final String body;
  final String buttonText;
  final bool granted;
  final List<IconData> icons;
  final VoidCallback onPressed;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      key: ValueKey(title),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontFamily: 'GoogleSansFlex',
                  fontSize: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                body,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
          Expanded(child: _PermissionIconCollage(icons: icons)),
          Column(
            children: [
              if (onSkip != null && !granted)
                TextButton(
                  onPressed: onSkip,
                  child: const Text('Skip for now'),
                ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: granted ? null : onPressed,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  backgroundColor: granted
                      ? colors.surfaceContainerHighest
                      : colors.primaryContainer,
                  foregroundColor: granted
                      ? colors.onSurface.withValues(alpha: 0.6)
                      : colors.onPrimaryContainer,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (granted) ...[
                      const Icon(Icons.check_rounded, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        buttonText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ],
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      key: const ValueKey('welcome'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Transform(
                  transform: Matrix4.diagonal3Values(1.42, 1.0, 1.0),
                  child: const Text(
                    'Welcome',
                    style: TextStyle(
                      fontFamily: 'GoogleSansFlex',
                      fontSize: 42,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Transform(
                  transform: Matrix4.diagonal3Values(1.42, 1.0, 1.0),
                  child: const Text(
                    'to',
                    style: TextStyle(
                      fontFamily: 'GoogleSansFlex',
                      fontSize: 42,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'PixelPlayer',
                  style: TextStyle(
                    fontFamily: 'GoogleSansFlex',
                    fontSize: 46,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(99),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'β',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Beta',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: colors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              width: double.infinity,
              height: 240,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _WelcomeArtPainter(
                        surfaceColor: colors.surface,
                        primaryContainerColor: colors.primaryContainer,
                        secondaryContainerColor: colors.secondaryContainer,
                        tertiaryContainerColor: colors.tertiaryContainer,
                        primaryColor: colors.primary,
                        secondaryColor: colors.secondary,
                        tertiaryColor: colors.tertiary,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _SineWaveLineWidget(
                      color: colors.primary,
                      strokeWidth: 4,
                      amplitude: 6,
                      waves: 7.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Text(
            "Let's get everything set up for you.",
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SineWaveLineWidget extends StatefulWidget {
  const _SineWaveLineWidget({
    required this.color,
    this.strokeWidth = 4.0,
    this.amplitude = 6.0,
    this.waves = 7.6,
  });

  final Color color;
  final double strokeWidth;
  final double amplitude;
  final double waves;

  @override
  State<_SineWaveLineWidget> createState() => _SineWaveLineWidgetState();
}

class _SineWaveLineWidgetState extends State<_SineWaveLineWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(double.infinity, 32),
          painter: _SineWavePainter(
            color: widget.color,
            strokeWidth: widget.strokeWidth,
            amplitude: widget.amplitude,
            waves: widget.waves,
            phase: _controller.value * 2 * math.pi,
          ),
        );
      },
    );
  }
}

class _SineWavePainter extends CustomPainter {
  _SineWavePainter({
    required this.color,
    required this.strokeWidth,
    required this.amplitude,
    required this.waves,
    required this.phase,
  });

  final Color color;
  final double strokeWidth;
  final double amplitude;
  final double waves;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final centerY = size.height / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    const samples = 200;
    final step = size.width / (samples - 1);
    path.moveTo(0, centerY + amplitude * math.sin(phase));

    for (int i = 1; i < samples; i++) {
      final x = i * step;
      final theta = (x / size.width) * (2 * math.pi * waves) + phase;
      final y = centerY + amplitude * math.sin(theta);
      path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SineWavePainter oldDelegate) => true;
}

class _WelcomeArtPainter extends CustomPainter {
  _WelcomeArtPainter({
    required this.surfaceColor,
    required this.primaryContainerColor,
    required this.secondaryContainerColor,
    required this.tertiaryContainerColor,
    required this.primaryColor,
    required this.secondaryColor,
    required this.tertiaryColor,
  });

  final Color surfaceColor;
  final Color primaryContainerColor;
  final Color secondaryContainerColor;
  final Color tertiaryContainerColor;
  final Color primaryColor;
  final Color secondaryColor;
  final Color tertiaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 1536;
    final scaleY = size.height / 1024;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    final p1 = Path()
      ..moveTo(513.7, 78.4)
      ..cubicTo(516.8, 79.2, 518.2, 78.4, 521, 77)
      ..cubicTo(522.1, 76.5, 522.1, 76.5, 523.3, 76)
      ..cubicTo(524.8, 75.3, 526.3, 74.6, 527.8, 73.9)
      ..cubicTo(537.6, 69.9, 549.3, 71.3, 559, 74.7)
      ..cubicTo(564.8, 77.2, 570.1, 79.9, 574.4, 84.6)
      ..cubicTo(577.5, 87.5, 579.5, 87.9, 583.8, 88.5)
      ..cubicTo(592.6, 90.2, 599, 93.1, 605, 100)
      ..cubicTo(605.7, 100.7, 606.4, 101.5, 607.1, 102.3)
      ..cubicTo(612.9, 110.5, 614.1, 117.9, 613, 128)
      ..cubicTo(611.1, 137.2, 605.9, 144.6, 599, 150.9)
      ..cubicTo(596.5, 153.6, 595.3, 156.4, 593.8, 159.8)
      ..cubicTo(587.6, 172.4, 577.4, 178.3, 565.9, 185.7)
      ..cubicTo(564, 187, 562.5, 188.3, 561, 190)
      ..cubicTo(560.9, 192.7, 560.9, 192.7, 561.3, 195.8)
      ..cubicTo(563.5, 217.7, 560.9, 236.3, 547, 254)
      ..cubicTo(546.6, 254.6, 546.1, 255.2, 545.6, 255.9)
      ..cubicTo(537.8, 266, 524.8, 274.5, 512.1, 276.7)
      ..cubicTo(511.1, 276.8, 510.1, 276.9, 509, 277)
      ..cubicTo(510.2, 293, 515.1, 308.1, 522.6, 322.4)
      ..cubicTo(522.9, 323, 523.3, 323.7, 523.6, 324.4)
      ..cubicTo(527.4, 331.3, 532.2, 336.6, 538.4, 341.4)
      ..cubicTo(577.3, 372.7, 596.3, 425.5, 605, 473)
      ..cubicTo(605.1, 473.7, 605.3, 474.4, 605.4, 475.2)
      ..cubicTo(606.9, 483.8, 607.2, 492.2, 607, 501)
      ..cubicTo(610.6, 498.9, 614.2, 496.8, 617.8, 494.8)
      ..cubicTo(618.8, 494.1, 619.9, 493.5, 621, 492.9)
      ..cubicTo(626.4, 489.7, 631.7, 486.6, 636.9, 483.4)
      ..cubicTo(637.8, 482.8, 638.8, 482.2, 639.7, 481.7)
      ..cubicTo(641.4, 480.6, 643.1, 479.5, 644.8, 478.5)
      ..cubicTo(645.6, 478, 646.4, 477.5, 647.2, 477)
      ..cubicTo(647.8, 476.6, 648.5, 476.2, 649.2, 475.8)
      ..cubicTo(651, 475, 651, 475, 654, 476)
      ..cubicTo(655.8, 478.4, 657.4, 480.9, 658.9, 483.4)
      ..cubicTo(659.9, 485, 660.9, 486.6, 661.9, 488.2)
      ..cubicTo(662.4, 489, 663, 489.8, 663.5, 490.6)
      ..cubicTo(665.8, 494.2, 668.2, 497.8, 670.6, 501.4)
      ..cubicTo(671.5, 502.8, 672.5, 504.3, 673.5, 505.8)
      ..cubicTo(674.3, 507, 674.3, 507, 675.1, 508.2)
      ..cubicTo(678.6, 513.4, 682.1, 518.6, 685.5, 523.8)
      ..cubicTo(687.5, 526.7, 689.5, 529.7, 691.5, 532.7)
      ..cubicTo(693.2, 535.4, 693.2, 535.4, 695, 538)
      ..cubicTo(693.2, 542.1, 690.6, 544, 687, 546.4)
      ..cubicTo(685.7, 547.3, 684.4, 548.2, 683.2, 549.1)
      ..cubicTo(682.5, 549.6, 681.8, 550, 681.1, 550.5)
      ..cubicTo(677.5, 553.1, 673.9, 555.7, 670.3, 558.3)
      ..cubicTo(668.7, 559.4, 667.2, 560.5, 665.6, 561.6)
      ..cubicTo(664.9, 562.2, 664.1, 562.8, 663.3, 563.3)
      ..cubicTo(661, 565, 658.8, 566.6, 656.5, 568.2)
      ..cubicTo(645.6, 576.1, 634.8, 584, 624, 592)
      ..cubicTo(626, 603.2, 633.1, 613.2, 640, 622)
      ..cubicTo(640.6, 622.8, 641.2, 623.7, 641.9, 624.5)
      ..cubicTo(648.5, 632.3, 657.6, 637.4, 667, 641)
      ..cubicTo(667.7, 641.3, 668.5, 641.6, 669.2, 642)
      ..cubicTo(685.8, 648.3, 706.3, 643.6, 721.9, 636.9)
      ..cubicTo(731.3, 632.7, 739.5, 627.2, 746.9, 620)
      ..cubicTo(749, 618, 749, 618, 751.6, 616)
      ..cubicTo(788.6, 586.1, 809.2, 524.2, 820, 480)
      ..cubicTo(820.4, 478.5, 820.4, 478.5, 820.7, 477)
      ..cubicTo(822.8, 468.4, 824.3, 459.8, 825.6, 451.1)
      ..cubicTo(825.8, 449.7, 826.1, 448.3, 826.3, 446.9)
      ..cubicTo(826.7, 444.4, 827.1, 441.9, 827.5, 439.3)
      ..cubicTo(827.8, 437.2, 828.2, 435, 828.6, 432.9)
      ..cubicTo(831.3, 415, 830.3, 392.4, 820, 377)
      ..cubicTo(816.4, 373, 813, 371.2, 807.7, 370.7)
      ..cubicTo(803.4, 371.1, 801, 372, 798, 375)
      ..cubicTo(793.2, 381.5, 789.4, 388.7, 786, 396)
      ..cubicTo(786.8, 396.2, 787.7, 396.5, 788.5, 396.8)
      ..cubicTo(794, 398.7, 798.5, 400.4, 802.6, 404.8)
      ..cubicTo(804.8, 409.8, 803.8, 413.8, 802, 418.8)
      ..cubicTo(800.7, 421.9, 799.3, 424.9, 797.9, 428)
      ..cubicTo(797.2, 429.6, 797.2, 429.6, 796.5, 431.2)
      ..cubicTo(795.3, 433.8, 794.2, 436.4, 793, 439)
      ..cubicTo(787.1, 438.3, 781.1, 437.7, 775, 437)
      ..cubicTo(776.2, 433.5, 777.3, 430.1, 778.7, 426.7)
      ..cubicTo(779, 425.9, 779.3, 425.2, 779.7, 424.4)
      ..cubicTo(780, 423.7, 780.3, 422.9, 780.6, 422.1)
      ..cubicTo(781.1, 420.9, 781.1, 420.9, 781.6, 419.8)
      ..cubicTo(782.4, 417.8, 783.2, 415.9, 784, 414)
      ..cubicTo(779.9, 412.3, 775.8, 410.6, 771.7, 408.9)
      ..cubicTo(770.3, 408.3, 768.9, 407.7, 767.5, 407.1)
      ..cubicTo(765.5, 406.3, 763.5, 405.5, 761.5, 404.6)
      ..cubicTo(760.3, 404.1, 759.1, 403.6, 757.9, 403.1)
      ..cubicTo(755.2, 401.9, 755.2, 401.9, 753, 402)
      ..cubicTo(751.8, 404.8, 750.6, 407.6, 749.4, 410.4)
      ..cubicTo(749, 411.3, 748.6, 412.2, 748.2, 413.1)
      ..cubicTo(746.1, 418, 744, 422.9, 741.8, 427.8)
      ..cubicTo(741.2, 429.3, 741.2, 429.3, 740.5, 430.8)
      ..cubicTo(739.7, 432.9, 738.8, 434.9, 737.9, 437)
      ..cubicTo(735.4, 442.7, 733, 448.3, 730.5, 454)
      ..cubicTo(729.1, 457.2, 727.7, 460.4, 726.4, 463.6)
      ..cubicTo(725.7, 465.1, 725.1, 466.6, 724.4, 468.1)
      ..cubicTo(723.5, 470.2, 722.6, 472.2, 721.7, 474.3)
      ..cubicTo(721.2, 475.5, 720.7, 476.6, 720.2, 477.8)
      ..cubicTo(719, 480.9, 718.4, 483.7, 718, 487)
      ..cubicTo(722.9, 489.2, 727.7, 491.4, 732.6, 493.7)
      ..cubicTo(734.2, 494.4, 735.9, 495.2, 737.5, 495.9)
      ..cubicTo(739.9, 497, 742.3, 498.1, 744.7, 499.2)
      ..cubicTo(745.4, 499.5, 746.1, 499.9, 746.9, 500.2)
      ..cubicTo(751.2, 502.2, 755.6, 504.1, 760, 506)
      ..cubicTo(759.6, 511.6, 757.8, 514, 754, 518)
      ..cubicTo(750.9, 519.5, 748.4, 519.2, 745, 519)
      ..cubicTo(742.3, 518.1, 739.9, 517.1, 737.3, 515.9)
      ..cubicTo(736.6, 515.6, 735.9, 515.3, 735.1, 515)
      ..cubicTo(732.9, 513.9, 730.6, 512.9, 728.3, 511.9)
      ..cubicTo(726.8, 511.2, 725.3, 510.5, 723.8, 509.9)
      ..cubicTo(719.5, 507.9, 715.3, 506, 711, 504)
      ..cubicTo(710.1, 503.6, 710.1, 503.6, 709.1, 503.1)
      ..cubicTo(707.4, 502.4, 705.8, 501.6, 704.1, 500.8)
      ..cubicTo(703.2, 500.3, 702.3, 499.9, 701.3, 499.4)
      ..cubicTo(698.6, 497.8, 697.4, 496.8, 696, 494)
      ..cubicTo(696.1, 487.8, 698, 482.9, 700.6, 477.2)
      ..cubicTo(701, 476.4, 701.3, 475.6, 701.7, 474.7)
      ..cubicTo(702.9, 472.1, 704.1, 469.4, 705.3, 466.8)
      ..cubicTo(706.1, 464.9, 707, 463, 707.8, 461.2)
      ..cubicTo(709, 458.4, 710.3, 455.6, 711.5, 452.8)
      ..cubicTo(714.9, 445.3, 718.1, 437.8, 721.4, 430.2)
      ..cubicTo(721.8, 429.1, 722.3, 428, 722.8, 426.9)
      ..cubicTo(725, 421.7, 727.2, 416.5, 729.4, 411.2)
      ..cubicTo(730.5, 408.6, 731.6, 406, 732.7, 403.4)
      ..cubicTo(733.5, 401.6, 734.2, 399.8, 735, 398)
      ..cubicTo(735.5, 396.9, 735.9, 395.8, 736.4, 394.6)
      ..cubicTo(737, 393.2, 737, 393.2, 737.6, 391.7)
      ..cubicTo(739.8, 387.5, 742.1, 384.6, 746, 382)
      ..cubicTo(752.7, 381.1, 757.2, 383.1, 763.3, 385.9)
      ..cubicTo(766.1, 387.2, 766.1, 387.2, 770, 387)
      ..cubicTo(770.5, 386, 771, 385.1, 771.5, 384.1)
      ..cubicTo(777.9, 371.6, 784.3, 361.3, 797.3, 354.9)
      ..cubicTo(805.3, 352.3, 816.2, 352.9, 823.7, 356.6)
      ..cubicTo(836.3, 364.4, 842.6, 376.3, 845.9, 390.5)
      ..cubicTo(851.2, 418, 845.5, 448, 840, 475)
      ..cubicTo(839.8, 475.9, 839.7, 476.7, 839.5, 477.6)
      ..cubicTo(833, 508.6, 820.7, 540.1, 806, 568.1)
      ..cubicTo(805, 570.1, 803.9, 572.1, 802.9, 574.1)
      ..cubicTo(783.6, 612.2, 755.4, 644.2, 714.3, 658.2)
      ..cubicTo(694.8, 664.4, 670.9, 662.5, 652.6, 653.4)
      ..cubicTo(651.7, 652.9, 650.9, 652.5, 650, 652)
      ..cubicTo(649, 651.5, 648, 651, 647, 650.4)
      ..cubicTo(629.7, 640.9, 615.1, 624, 609, 605)
      ..cubicTo(605.3, 607.2, 601.6, 609.5, 597.9, 611.8)
      ..cubicTo(596.8, 612.4, 595.8, 613, 594.7, 613.7)
      ..cubicTo(588.5, 617.4, 588.5, 617.4, 582.4, 621.5)
      ..cubicTo(580, 623, 580, 623, 578, 623)
      ..cubicTo(578, 624.5, 578, 624.5, 578, 626)
      ..cubicTo(578, 635.4, 577.9, 644.7, 577.6, 654.1)
      ..cubicTo(577.5, 655.5, 577.5, 656.9, 577.4, 658.2)
      ..cubicTo(577.3, 661.8, 577.2, 665.3, 577.1, 668.8)
      ..cubicTo(577, 672.5, 576.8, 676.1, 576.7, 679.7)
      ..cubicTo(576.5, 686.8, 576.2, 693.9, 576, 701)
      ..cubicTo(568.4, 702, 560.8, 703, 553, 704)
      ..cubicTo(560.4, 716.9, 567.8, 729.8, 575.5, 742.5)
      ..cubicTo(581.2, 752, 586.8, 761.6, 592.4, 771.3)
      ..cubicTo(596.6, 778.7, 601, 786, 605.4, 793.4)
      ..cubicTo(611.5, 803.4, 617.3, 813.5, 623.1, 823.6)
      ..cubicTo(626.8, 830.2, 630.6, 836.8, 634.4, 843.3)
      ..cubicTo(641.4, 855.1, 648, 867, 654.4, 879.1)
      ..cubicTo(656, 881.9, 657.5, 884.8, 659, 887.6)
      ..cubicTo(678.9, 924.7, 694.2, 964.5, 709.7, 1003.7)
      ..cubicTo(710.7, 1006.1, 711.7, 1008.6, 712.7, 1011.1)
      ..cubicTo(713.1, 1012.1, 713.1, 1012.1, 713.5, 1013.2)
      ..cubicTo(714, 1014.5, 714.6, 1015.8, 715.1, 1017.2)
      ..cubicTo(717, 1021.8, 717, 1021.8, 717, 1024)
      ..cubicTo(553, 1024, 389, 1024, 220, 1024)
      ..cubicTo(222.5, 1017.8, 224.9, 1011.9, 227.8, 1005.9)
      ..cubicTo(228.1, 1005.2, 228.5, 1004.4, 228.8, 1003.7)
      ..cubicTo(229.6, 1002.1, 230.3, 1000.5, 231.1, 999)
      ..cubicTo(232.3, 996.4, 233.5, 993.9, 234.7, 991.4)
      ..cubicTo(236.3, 987.9, 238, 984.5, 239.6, 981)
      ..cubicTo(251.4, 956.2, 262.9, 931.2, 274, 906)
      ..cubicTo(274.5, 904.8, 274.5, 904.8, 275.1, 903.5)
      ..cubicTo(278.5, 895.8, 281.9, 888.1, 285.3, 880.3)
      ..cubicTo(290.3, 868.9, 295.4, 857.4, 300.4, 846)
      ..cubicTo(305.6, 834.3, 310.8, 822.6, 316, 810.9)
      ..cubicTo(318, 806.3, 320, 801.7, 322, 797.2)
      ..cubicTo(332.8, 773, 343.1, 748.6, 353, 724)
      ..cubicTo(353.8, 724.2, 354.6, 724.3, 355.4, 724.5)
      ..cubicTo(369.1, 727.1, 382.6, 729.5, 396.6, 729.5)
      ..cubicTo(397.6, 729.5, 398.6, 729.5, 399.6, 729.5)
      ..cubicTo(405.9, 729.4, 405.9, 729.4, 411, 726)
      ..cubicTo(411.7, 723.8, 411.7, 723.8, 411.6, 721.5)
      ..cubicTo(411.6, 720.3, 411.6, 720.3, 411.6, 719.2)
      ..cubicTo(411.2, 716.8, 411.2, 716.8, 409.1, 715.3)
      ..cubicTo(404.5, 713.4, 400.1, 713.5, 395.1, 713.4)
      ..cubicTo(393, 713.4, 391, 713.3, 388.9, 713.2)
      ..cubicTo(387.9, 713.2, 386.8, 713.2, 385.8, 713.1)
      ..cubicTo(369.7, 712.4, 352.7, 708.7, 338, 702)
      ..cubicTo(337.9, 695.7, 338.3, 689.8, 339.1, 683.5)
      ..cubicTo(339.2, 682.7, 339.3, 681.8, 339.4, 680.9)
      ..cubicTo(339.8, 678.2, 340.1, 675.5, 340.5, 672.8)
      ..cubicTo(340.9, 670, 341.2, 667.3, 341.6, 664.5)
      ..cubicTo(341.8, 662.8, 342, 661.1, 342.2, 659.4)
      ..cubicTo(343, 653.7, 343, 653.7, 343, 648)
      ..cubicTo(341.1, 645.5, 341.1, 645.5, 338.4, 643.2)
      ..cubicTo(334.7, 639.6, 331.2, 636, 327.8, 632.1)
      ..cubicTo(325.6, 629.6, 323.4, 627.1, 321.1, 624.7)
      ..cubicTo(317.1, 620.2, 313.2, 615.7, 309.5, 611)
      ..cubicTo(306.6, 607.5, 303.6, 604.1, 300.6, 600.7)
      ..cubicTo(294.5, 593.7, 288.7, 586.4, 283, 579)
      ..cubicTo(282.5, 578.4, 282.1, 577.8, 281.6, 577.2)
      ..cubicTo(269.8, 561.7, 260.7, 549.1, 262, 529)
      ..cubicTo(264, 515.5, 272.2, 503.7, 279.3, 492.3)
      ..cubicTo(280.8, 489.8, 282.3, 487.4, 283.8, 484.9)
      ..cubicTo(284.2, 484.3, 284.5, 483.7, 284.9, 483.1)
      ..cubicTo(287.8, 478.3, 290.6, 473.6, 293.4, 468.8)
      ..cubicTo(297.8, 461.1, 302.6, 453.7, 307.5, 446.3)
      ..cubicTo(309.1, 443.9, 310.7, 441.4, 312.2, 439)
      ..cubicTo(321.8, 424.2, 331.5, 409.5, 341.6, 395.1)
      ..cubicTo(343, 393, 344.4, 390.9, 345.9, 388.8)
      ..cubicTo(356.4, 373.5, 368.2, 359.4, 381, 346)
      ..cubicTo(381.5, 345.5, 382, 344.9, 382.6, 344.4)
      ..cubicTo(398.5, 327.7, 416.7, 314, 438, 305)
      ..cubicTo(438.8, 304.6, 439.6, 304.3, 440.5, 303.9)
      ..cubicTo(444.8, 302.1, 448.3, 301.5, 453, 302)
      ..cubicTo(455.2, 303.5, 456.9, 304.9, 458.8, 306.8)
      ..cubicTo(471.2, 317.9, 494.4, 337, 512, 337)
      ..cubicTo(511.4, 336.1, 510.9, 335.1, 510.3, 334.1)
      ..cubicTo(500.9, 317.5, 493.5, 299.4, 494, 280)
      ..cubicTo(493.2, 280, 492.5, 280.1, 491.7, 280.1)
      ..cubicTo(474.3, 280.7, 458.6, 275.4, 445.7, 263.6)
      ..cubicTo(441.5, 259.7, 437.6, 255.4, 433.9, 251)
      ..cubicTo(432, 249, 430.1, 247.3, 428, 245.6)
      ..cubicTo(419.3, 238.2, 414.3, 228.4, 410, 218)
      ..cubicTo(409.5, 216.7, 409.5, 216.7, 408.9, 215.4)
      ..cubicTo(406.1, 208, 405.8, 200.3, 405.8, 192.4)
      ..cubicTo(405.7, 191.3, 405.7, 191.3, 405.7, 190.1)
      ..cubicTo(405.7, 186, 406.1, 182.2, 407, 178.2)
      ..cubicTo(408.4, 172.1, 408, 166.1, 407.9, 159.9)
      ..cubicTo(407.6, 134.4, 416.7, 113.1, 434.4, 94.7)
      ..cubicTo(435.2, 93.8, 436.1, 92.9, 437, 92)
      ..cubicTo(438, 91, 438, 91, 439, 90)
      ..cubicTo(459.3, 70.8, 488.6, 67, 513.7, 78.4)
      ..close();
    canvas.drawPath(p1, Paint()..color = primaryContainerColor);

    // Floating Note 1 (White / Surface)
    final p5 = Path()
      ..moveTo(1211, 95)
      ..cubicTo(1216.4, 101.1, 1216.7, 106.9, 1216.6, 114.8)
      ..lineTo(1216.6, 211)
      ..cubicTo(1216.4, 224.7, 1213.3, 232.5, 1206.1, 240.1)
      ..cubicTo(1199, 246.6, 1192, 247.4, 1182.6, 247.3)
      ..cubicTo(1173.8, 246.6, 1166.7, 242.7, 1161, 236)
      ..cubicTo(1156.6, 229.6, 1156, 222.6, 1157, 215)
      ..cubicTo(1159.5, 206.8, 1165.9, 201.4, 1173, 197)
      ..lineTo(1188, 196)
      ..lineTo(1188, 135)
      ..cubicTo(1180.6, 137.5, 1170, 140.8, 1164.1, 142.4)
      ..lineTo(1131, 151)
      ..lineTo(1130.8, 221.7)
      ..cubicTo(1130.9, 251, 1122.3, 261, 1116.1, 267.1)
      ..cubicTo(1108.2, 269.2, 1099.6, 269.6, 1091.2, 269.4)
      ..cubicTo(1084.5, 266.8, 1078, 261.3, 1070.5, 243.1)
      ..cubicTo(1070.7, 236.4, 1073.4, 230.9, 1077.9, 225.9)
      ..cubicTo(1083.6, 220.6, 1096.7, 217.9, 1099.7, 218)
      ..lineTo(1101.8, 182.3)
      ..cubicTo(1101.7, 149.8, 1101.7, 135.1, 1107.7, 117.3)
      ..cubicTo(1111.3, 114.8, 1118.3, 112.6, 1127.3, 110.3)
      ..cubicTo(1146.8, 105.1, 1156.1, 102.5, 1211, 95)
      ..close();
    canvas.drawPath(p5, Paint()..color = primaryColor);

    // Floating Note 2 (Pink / Tertiary)
    final p6 = Path()
      ..moveTo(478, 72)
      ..cubicTo(491.7, 71.3, 504.7, 74, 517, 80)
      ..cubicTo(514, 91.5, 510.3, 109.5, 506.4, 142)
      ..cubicTo(521.7, 159.4, 539.1, 179.1, 547.9, 192.9)
      ..cubicTo(550.2, 207.8, 547.3, 223.8, 542.8, 235.8)
      ..cubicTo(536.9, 248, 526.4, 257.3, 513.9, 262.2)
      ..cubicTo(499.1, 267.3, 483.8, 268.1, 469.2, 261.8)
      ..cubicTo(455.5, 254.9, 443.9, 242.7, 439, 228)
      ..cubicTo(434.7, 213.5, 435.7, 197.9, 442.3, 184.3)
      ..cubicTo(448.3, 173.6, 456.3, 166, 467, 160)
      ..lineTo(477, 157)
      ..lineTo(476.9, 100.6)
      ..cubicTo(476.9, 91, 477.2, 81.6, 478, 72)
      ..close();
    canvas.drawPath(p6, Paint()..color = tertiaryColor);

    // Floating Note 3 (Blue / Secondary)
    final p8 = Path()
      ..moveTo(952, 165)
      ..cubicTo(959, 168.4, 971.1, 178.9, 981.5, 187)
      ..cubicTo(1007.3, 206.5, 1010, 222, 1000.1, 255.9)
      ..cubicTo(993, 261, 987, 260, 985, 251)
      ..cubicTo(986, 249.5, 982, 229, 970.9, 219.4)
      ..lineTo(967, 217)
      ..lineTo(967.3, 291.5)
      ..cubicTo(964.2, 308.7, 958.3, 314.9, 932.7, 323.3)
      ..cubicTo(924.8, 322.7, 911, 314, 905, 291)
      ..cubicTo(907.7, 282.5, 920.7, 272.4, 931.4, 270.8)
      ..lineTo(937.6, 198.3)
      ..cubicTo(937.5, 188.7, 942, 167, 952, 165)
      ..close();
    canvas.drawPath(p8, Paint()..color = secondaryColor);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_WelcomeArtPainter oldDelegate) => false;
}

class _BackupPage extends StatelessWidget {
  const _BackupPage({
    required this.selectedBackupName,
    required this.onImport,
    required this.onSkip,
  });

  final String? selectedBackupName;
  final VoidCallback onImport;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              const SizedBox(height: 16),
              Text(
                'Do you have a backup?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontFamily: 'GoogleSansFlex',
                  fontSize: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'If you already have a PixelPlayer backup, restore it now and skip most of the remaining setup on this device.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
          const Expanded(
            child: _PermissionIconCollage(
              icons: [
                Icons.file_upload_outlined,
                Icons.playlist_play_rounded,
                Icons.description_rounded,
                Icons.settings_rounded,
                Icons.bar_chart_rounded,
              ],
            ),
          ),
          Column(
            children: [
              if (selectedBackupName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Chip(
                    avatar: const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(selectedBackupName!),
                    backgroundColor: colors.primaryContainer,
                  ),
                ),
              TextButton(
                onPressed: onSkip,
                child: Text(
                  'Skip / Not now',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: onImport,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 36,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  backgroundColor: colors.primaryContainer,
                  foregroundColor: colors.onPrimaryContainer,
                ),
                child: const Text(
                  'Import backup',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackupRestoreDialog extends StatefulWidget {
  const _BackupRestoreDialog({
    required this.filename,
    required this.onRestoreConfirmed,
  });

  final String filename;
  final VoidCallback onRestoreConfirmed;

  @override
  State<_BackupRestoreDialog> createState() => _BackupRestoreDialogState();
}

class _BackupRestoreDialogState extends State<_BackupRestoreDialog> {
  final Map<String, bool> _selectedModules = {
    'Playlists & Favorites': true,
    'App Settings & Theme': true,
    'Listening History': true,
    'Synced Lyrics': true,
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selectedCount = _selectedModules.values.where((e) => e).length;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Restore backup',
            style: TextStyle(
              fontFamily: 'GoogleSansFlex',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.filename,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.primary),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select modules to restore ($selectedCount of ${_selectedModules.length}):',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ..._selectedModules.keys.map(
              (key) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: colors.primary,
                title: Text(
                  key,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                value: _selectedModules[key],
                onChanged: (val) {
                  setState(() => _selectedModules[key] = val ?? false);
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: selectedCount > 0 ? widget.onRestoreConfirmed : null,
          child: const Text('Restore selected'),
        ),
      ],
    );
  }
}

class _FoldersPage extends StatelessWidget {
  const _FoldersPage({required this.onChoose, required this.onSkip});

  final VoidCallback onChoose;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              const SizedBox(height: 16),
              Text(
                'Excluded folders',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontFamily: 'GoogleSansFlex',
                  fontSize: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'All folders are scanned by default. Pick any locations you want to ignore when building your library.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
          const Expanded(
            child: _PermissionIconCollage(
              icons: [
                Icons.folder_open_rounded,
                Icons.music_note_rounded,
                Icons.folder_copy_rounded,
                Icons.create_new_folder_rounded,
                Icons.audio_file_rounded,
              ],
            ),
          ),
          Column(
            children: [
              TextButton(
                onPressed: onSkip,
                child: Text(
                  'Skip / Not now',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: onChoose,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 36,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  backgroundColor: colors.primaryContainer,
                  foregroundColor: colors.onPrimaryContainer,
                ),
                child: const Text(
                  'Choose folders to ignore',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemePage extends StatelessWidget {
  const _ThemePage({required this.selected, required this.onChanged});

  final ThemeMode selected;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text(
            'App Theme',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontFamily: 'GoogleSansFlex',
              fontSize: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Pick the look you want before you start exploring your library.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 28),
          _ThemeModeOptionCard(
            selected: selected == ThemeMode.dark,
            title: 'Dark',
            description: 'The default Material 3 dark look for PixelPlayer.',
            icon: Icons.dark_mode_rounded,
            recommended: true,
            onTap: () => onChanged(ThemeMode.dark),
          ),
          const SizedBox(height: 12),
          _ThemeModeOptionCard(
            selected: selected == ThemeMode.light,
            title: 'Light',
            description: 'A brighter Material 3 look across the app.',
            icon: Icons.light_mode_rounded,
            onTap: () => onChanged(ThemeMode.light),
          ),
          const SizedBox(height: 12),
          _ThemeModeOptionCard(
            selected: selected == ThemeMode.system,
            title: 'Follow system',
            description: "Match your phone's current appearance setting.",
            icon: Icons.phone_android_rounded,
            onTap: () => onChanged(ThemeMode.system),
          ),
          const SizedBox(height: 24),
          Text(
            'You can change this later in Settings > Appearance > App Theme.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeModeOptionCard extends StatelessWidget {
  const _ThemeModeOptionCard({
    required this.selected,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    this.recommended = false,
  });

  final bool selected;
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colors.primaryContainer.withValues(alpha: 0.7)
          : colors.surfaceContainer,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: selected ? colors.primary : colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: selected
                      ? colors.onPrimary
                      : colors.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (recommended) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? colors.primary
                              : colors.primaryContainer,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          'Recommended',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: selected
                                ? colors.onPrimary
                                : colors.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: selected
                      ? colors.primary
                      : colors.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: colors.onPrimary,
                        )
                      : Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colors.onSurfaceVariant.withValues(
                              alpha: 0.35,
                            ),
                            shape: BoxShape.circle,
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
}

class _LibraryLayoutPage extends StatelessWidget {
  const _LibraryLayoutPage({required this.compact, required this.onChanged});

  final bool compact;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text(
            'Library Layout',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontFamily: 'GoogleSansFlex',
              fontSize: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Choose your preferred way to navigate your library.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 28),
          _LibraryHeaderPreview(compact: compact),
          const SizedBox(height: 28),
          Card(
            elevation: 0,
            color: colors.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => onChanged(!compact),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Compact Mode',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            compact
                                ? 'Using minimal pill navigation'
                                : 'Using standard tab row',
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(value: compact, onChanged: onChanged),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'You can change this later in Settings > Appearance > Library Navigation.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryHeaderPreview extends StatelessWidget {
  const _LibraryHeaderPreview({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        child: compact
            ? Container(
                key: const ValueKey('compact'),
                padding: const EdgeInsets.all(24),
                alignment: Alignment.topLeft,
                child: IntrinsicHeight(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(26),
                            bottomLeft: Radius.circular(26),
                            topRight: Radius.circular(6),
                            bottomRight: Radius.circular(6),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.music_note_rounded,
                              size: 22,
                              color: colors.onPrimaryContainer,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Songs',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: colors.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            bottomLeft: Radius.circular(6),
                            topRight: Radius.circular(26),
                            bottomRight: Radius.circular(26),
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 22,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Container(
                key: const ValueKey('tabs'),
                padding: const EdgeInsets.all(24),
                alignment: Alignment.topLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Library',
                      style: TextStyle(
                        fontFamily: 'GoogleSansFlex',
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final tab in ['SONGS', 'ALBUMS', 'ARTISTS'])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Text(
                                      tab,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: tab == 'SONGS'
                                            ? colors.primary
                                            : colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  if (tab == 'SONGS') ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      width: 16,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color: colors.primary,
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _NavigationLayoutPage extends StatelessWidget {
  const _NavigationLayoutPage({
    required this.fullWidth,
    required this.onChanged,
    required this.onCustomizeRadius,
  });

  final bool fullWidth;
  final ValueChanged<bool> onChanged;
  final VoidCallback onCustomizeRadius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text(
            'Navigation bar',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontFamily: 'GoogleSansFlex',
              fontSize: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Choose how the navigation surface sits above the system edge.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          _NavBarPreview(fullWidth: fullWidth),
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            color: colors.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onChanged(!fullWidth),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Floating navigation bar',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                !fullWidth
                                    ? 'Floating pill with custom rounded corners'
                                    : 'Full width bar attached to bottom edge',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: !fullWidth,
                          onChanged: (val) => onChanged(!val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: onCustomizeRadius,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.rounded_corner_rounded, size: 18),
                      label: const Text('Customize corner radius'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Navigation style can be changed in settings.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBarPreview extends StatelessWidget {
  const _NavBarPreview({required this.fullWidth});

  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: colors.surfaceBright,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 200,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: fullWidth ? 0 : 16,
                vertical: fullWidth ? 0 : 12,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 72,
                decoration: BoxDecoration(
                  color: colors.surfaceContainer,
                  borderRadius: BorderRadius.vertical(
                    top: const Radius.circular(28),
                    bottom: Radius.circular(fullWidth ? 0 : 28),
                  ),
                  boxShadow: fullWidth
                      ? null
                      : [
                          BoxShadow(
                            color: colors.shadow.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _PreviewNavItem(Icons.home_rounded, 'Home', true),
                    _PreviewNavItem(Icons.search_rounded, 'Search', false),
                    _PreviewNavItem(
                      Icons.library_music_rounded,
                      'Library',
                      false,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewNavItem extends StatelessWidget {
  const _PreviewNavItem(this.icon, this.label, this.selected);

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: selected ? colors.primary : colors.onSurfaceVariant),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? colors.primary : colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _NavBarCornerRadiusOverlay extends StatefulWidget {
  const _NavBarCornerRadiusOverlay({
    required this.initialRadius,
    required this.isFullWidth,
    required this.onRadiusChanged,
    required this.onDone,
    required this.onBack,
  });

  final double initialRadius;
  final bool isFullWidth;
  final ValueChanged<double> onRadiusChanged;
  final VoidCallback onDone;
  final VoidCallback onBack;

  @override
  State<_NavBarCornerRadiusOverlay> createState() =>
      _NavBarCornerRadiusOverlayState();
}

class _NavBarCornerRadiusOverlayState
    extends State<_NavBarCornerRadiusOverlay> {
  late double _radius;

  @override
  void initState() {
    super.initState();
    _radius = widget.initialRadius;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: Material(
        color: colors.surface,
        child: SafeArea(
          child: Column(
            children: [
              // Header matching Screenshot 4
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: widget.onBack,
                    ),
                    FilledButton.icon(
                      onPressed: widget.onDone,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primaryContainer,
                        foregroundColor: colors.onPrimaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text(
                        'Done',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      const Text(
                        'Adjust Corner Radius',
                        style: TextStyle(
                          fontFamily: 'GoogleSansFlex',
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Match the navbar shape's corners with your device's physical corners for a seamless look.",
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Spacer(),
                      // Control Box (Matching Screenshot 4)
                      Card(
                        elevation: 0,
                        color: colors.surfaceContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Corner Radius',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () {
                                      setState(() => _radius = 32);
                                      widget.onRadiusChanged(32);
                                    },
                                    style: TextButton.styleFrom(
                                      backgroundColor: colors.tertiaryContainer,
                                      foregroundColor:
                                          colors.onTertiaryContainer,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 6,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.refresh_rounded,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'Reset',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Icon(
                                    Icons.crop_square_rounded,
                                    color: colors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Slider(
                                      value: _radius,
                                      min: 0,
                                      max: 48,
                                      divisions: 48,
                                      activeColor: colors.primaryContainer,
                                      onChanged: (val) {
                                        setState(() => _radius = val);
                                        widget.onRadiusChanged(val);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${_radius.round()} dp',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Bottom Nav Bar Preview Box (Matching Screenshot 4)
                      Container(
                        width: double.infinity,
                        height: 72,
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(_radius),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinishPage extends StatelessWidget {
  const _FinishPage();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      key: const ValueKey('finish'),
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            height: 220,
            child: _PermissionIconCollage(
              icons: [
                Icons.check_rounded,
                Icons.favorite_rounded,
                Icons.favorite_rounded,
                Icons.settings_rounded,
                Icons.celebration_rounded,
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'All Set!',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontFamily: 'GoogleSansFlex',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "You're ready to enjoy your music.",
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SetupBottomBar extends StatelessWidget {
  const _SetupBottomBar({
    required this.currentPage,
    required this.totalPages,
    required this.canLeaveCurrentPage,
    required this.isLastPage,
    required this.onNext,
    required this.onFinish,
  });

  final int currentPage;
  final int totalPages;
  final bool canLeaveCurrentPage;
  final bool isLastPage;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = canLeaveCurrentPage;

    // Morphing corners matching Kotlin SetupBottomBar
    final radii = switch (currentPage % 3) {
      0 => const [50.0, 50.0, 50.0, 50.0], // Circle
      1 => const [26.0, 26.0, 26.0, 26.0], // Rounded Square
      _ => const [18.0, 50.0, 18.0, 50.0], // Leaf shape
    };

    return Material(
      elevation: 8,
      color: colors.surfaceContainer,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.5),
                      end: Offset.zero,
                    ).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: Text(
                  currentPage == 0
                      ? "Let's Go!"
                      : 'Step $currentPage of ${totalPages - 1}',
                  key: ValueKey(currentPage),
                  style: currentPage == 0
                      ? Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        )
                      : Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                ),
              ),
            ),
            AnimatedRotation(
              turns: currentPage.toDouble(),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                width: 64,
                height: 56,
                decoration: BoxDecoration(
                  color: enabled
                      ? colors.primaryContainer
                      : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(radii[0]),
                    topRight: Radius.circular(radii[1]),
                    bottomLeft: Radius.circular(radii[2]),
                    bottomRight: Radius.circular(radii[3]),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const ValueKey('setup-next'),
                    onTap: enabled ? (isLastPage ? onFinish : onNext) : null,
                    child: AnimatedRotation(
                      turns: -currentPage.toDouble(),
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        isLastPage
                            ? (enabled
                                  ? Icons.check_rounded
                                  : Icons.close_rounded)
                            : Icons.arrow_forward_rounded,
                        color: enabled
                            ? colors.onPrimaryContainer
                            : colors.onSurface.withValues(alpha: .58),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupPageInfo {
  const _SetupPageInfo(this.title, this.icon);

  final String title;
  final IconData icon;
}
