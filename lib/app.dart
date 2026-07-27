import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'core/state/app_controller.dart';
import 'core/theme/pixelplay_theme.dart';
import 'features/setup/setup_screen.dart';
import 'features/shell/app_shell.dart';

class PixelPlayApp extends StatefulWidget {
  const PixelPlayApp({
    this.skipSetup = false,
    this.platformServicesEnabled = true,
    super.key,
  });

  final bool skipSetup;
  final bool platformServicesEnabled;

  @override
  State<PixelPlayApp> createState() => _PixelPlayAppState();
}

class _PixelPlayAppState extends State<PixelPlayApp> {
  late final AppController _controller;
  late ThemeMode _themeMode;
  late bool _initialized;
  late bool _setupComplete;

  @override
  void initState() {
    super.initState();
    _controller = AppController(setupComplete: widget.skipSetup)
      ..addListener(_refresh);
    _themeMode = _controller.themeMode;
    _initialized = _controller.initialized;
    _setupComplete = _controller.setupComplete;
    _controller.initialize(
      ignoreStoredSetup: widget.skipSetup,
      platformServicesEnabled: widget.platformServicesEnabled,
    );
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() {
    final nextThemeMode = _controller.themeMode;
    final nextInitialized = _controller.initialized;
    final nextSetupComplete = _controller.setupComplete;
    if (nextThemeMode == _themeMode &&
        nextInitialized == _initialized &&
        nextSetupComplete == _setupComplete) {
      return;
    }
    _themeMode = nextThemeMode;
    _initialized = nextInitialized;
    _setupComplete = nextSetupComplete;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: _controller,
      child: DynamicColorBuilder(
        builder: (lightDynamic, darkDynamic) => MaterialApp(
          title: 'PixelPlayer',
          debugShowCheckedModeBanner: false,
          theme: PixelPlayTheme.light(scheme: lightDynamic),
          darkTheme: PixelPlayTheme.dark(scheme: darkDynamic),
          themeMode: _themeMode,
          home: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween(begin: .97, end: 1.0).animate(animation),
                  child: child,
                ),
              );
            },
            child: !_initialized
                ? const _AppLoadingScreen(key: ValueKey('app-loading'))
                : _setupComplete
                ? const AppShell(key: ValueKey('app-shell'))
                : const SetupScreen(key: ValueKey('setup')),
          ),
        ),
      ),
    );
  }
}

class _AppLoadingScreen extends StatelessWidget {
  const _AppLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox.square(
          dimension: 32,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
  }
}
