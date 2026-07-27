import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_color_utilities/hct/hct.dart';
import 'package:material_color_utilities/palettes/tonal_palette.dart';

import 'pixelplay_colors.dart';

abstract final class PixelPlayTheme {
  static ThemeData light({ColorScheme? scheme}) => _build(
    scheme != null ? _harmonize(scheme) : _fallbackScheme(Brightness.light),
  );

  static ThemeData dark({ColorScheme? scheme}) => _build(
    scheme != null ? _harmonize(scheme) : _fallbackScheme(Brightness.dark),
  );

  static ThemeData fromColorScheme(ColorScheme scheme) => _build(scheme);

  /// The Android bridge supplies the original dynamic color roles but not
  /// Flutter's newer tone-based surface containers. Recover the neutral
  /// palette so tonal elevation remains visible like it is in Compose.
  static ColorScheme _harmonize(ColorScheme dynamic) {
    final neutral = TonalPalette.fromHct(
      Hct.fromInt(dynamic.surface.toARGB32()),
    );
    Color tone(int value) => Color(neutral.get(value));
    final dark = dynamic.brightness == Brightness.dark;

    return dynamic.copyWith(
      surface: tone(dark ? 6 : 98),
      surfaceDim: tone(dark ? 6 : 87),
      surfaceBright: tone(dark ? 24 : 98),
      surfaceContainerLowest: tone(dark ? 4 : 100),
      surfaceContainerLow: tone(dark ? 10 : 96),
      surfaceContainer: tone(dark ? 12 : 94),
      surfaceContainerHigh: tone(dark ? 17 : 92),
      surfaceContainerHighest: tone(dark ? 22 : 90),
    );
  }

  /// Fallback when no dynamic colors are available (e.g. emulators, old Android).
  static ColorScheme _fallbackScheme(Brightness brightness) {
    final source = brightness == Brightness.dark ? _darkScheme : _lightScheme;
    return ColorScheme.fromSeed(
      seedColor: source.primary,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.expressive,
      contrastLevel: .05,
    );
  }

  static ThemeData _build(ColorScheme scheme) {
    const family = 'GoogleSansFlex';
    final brightness = scheme.brightness;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: family,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
    );
    const quickMotion = Duration(milliseconds: 140);
    const expressiveMotion = Duration(milliseconds: 200);
    final interactiveShape = WidgetStateProperty.resolveWith<OutlinedBorder>((
      states,
    ) {
      if (states.contains(WidgetState.pressed)) {
        return RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
      }
      if (states.contains(WidgetState.selected)) {
        return RoundedRectangleBorder(borderRadius: BorderRadius.circular(24));
      }
      return const StadiumBorder();
    });
    final buttonText = WidgetStatePropertyAll(
      base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      textTheme: base.textTheme.copyWith(
        displayLarge: const TextStyle(
          fontFamily: family,
          fontSize: 64,
          height: 1.1,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
        ),
        displayMedium: const TextStyle(
          fontFamily: family,
          fontSize: 44,
          height: 1.15,
          fontWeight: FontWeight.w700,
          letterSpacing: -.5,
        ),
        displaySmall: const TextStyle(
          fontFamily: family,
          fontSize: 36,
          height: 1.2,
          fontWeight: FontWeight.w700,
        ),
        headlineLarge: const TextStyle(
          fontFamily: family,
          fontSize: 32,
          height: 1.25,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: const TextStyle(
          fontFamily: family,
          fontSize: 28,
          height: 36 / 28,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: const TextStyle(
          fontFamily: family,
          fontSize: 24,
          height: 32 / 24,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: const TextStyle(
          fontFamily: family,
          fontSize: 22,
          height: 28 / 22,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: const TextStyle(
          fontFamily: family,
          fontSize: 18,
          height: 24 / 18,
          fontWeight: FontWeight.w600,
          letterSpacing: .15,
        ),
        titleSmall: const TextStyle(
          fontFamily: family,
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w600,
          letterSpacing: .1,
        ),
        bodyLarge: const TextStyle(
          fontFamily: family,
          fontSize: 16,
          height: 1.5,
          letterSpacing: .15,
        ),
        bodyMedium: const TextStyle(
          fontFamily: family,
          fontSize: 14,
          height: 20 / 14,
          letterSpacing: .25,
        ),
        labelLarge: const TextStyle(
          fontFamily: family,
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w700,
          letterSpacing: .1,
        ),
        labelMedium: const TextStyle(
          fontFamily: family,
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w600,
          letterSpacing: .5,
        ),
      ),
      appBarTheme: AppBarTheme(
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          animationDuration: expressiveMotion,
          minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          shape: interactiveShape,
          textStyle: buttonText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          animationDuration: expressiveMotion,
          minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          shape: interactiveShape,
          textStyle: buttonText,
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          animationDuration: expressiveMotion,
          minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          shape: interactiveShape,
          textStyle: buttonText,
          side: WidgetStateProperty.resolveWith((states) {
            final color = states.contains(WidgetState.focused)
                ? scheme.primary
                : scheme.outline;
            return BorderSide(color: color, width: 1.2);
          }),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          animationDuration: quickMotion,
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          shape: interactiveShape,
          textStyle: buttonText,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          animationDuration: expressiveMotion,
          minimumSize: const WidgetStatePropertyAll(Size.square(48)),
          iconSize: const WidgetStatePropertyAll(24),
          shape: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.pressed)
                ? RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  )
                : const CircleBorder();
          }),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 1,
        hoverElevation: 1,
        highlightElevation: 0,
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        smallSizeConstraints: const BoxConstraints.tightFor(
          width: 48,
          height: 48,
        ),
        sizeConstraints: const BoxConstraints.tightFor(width: 64, height: 64),
        largeSizeConstraints: const BoxConstraints.tightFor(
          width: 80,
          height: 80,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontFamily: family,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          );
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        modalBackgroundColor: scheme.surfaceContainerLow,
        modalBarrierColor: scheme.scrim.withValues(alpha: .52),
        showDragHandle: true,
        dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: .4),
        dragHandleSize: const Size(32, 4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 12,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: .55),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        constraints: const BoxConstraints(minHeight: 56),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.secondaryContainer,
        disabledColor: scheme.onSurface.withValues(alpha: .08),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        showCheckmark: true,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          animationDuration: expressiveMotion,
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      popupMenuTheme: PopupMenuThemeData(
        elevation: 0,
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: .7),
        thickness: 1,
        space: 1,
      ),
      sliderTheme: base.sliderTheme.copyWith(
        trackHeight: 8,
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: .12),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? Colors.transparent
              : scheme.outline;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(4),
        radius: const Radius.circular(99),
        thumbColor: WidgetStatePropertyAll(
          scheme.primary.withValues(alpha: .55),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: ShapeDecoration(
          color: scheme.inverseSurface,
          shape: const StadiumBorder(),
        ),
        textStyle: base.textTheme.labelMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
    );
  }

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: PixelPlayColors.purplePrimary,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFF5D2867),
    onPrimaryContainer: Color(0xFFFFD6FF),
    primaryFixed: Color(0xFFE8DDFF),
    primaryFixedDim: Color(0xFFCFBCFF),
    onPrimaryFixed: Color(0xFF22005D),
    onPrimaryFixedVariant: Color(0xFF4F378B),
    secondary: PixelPlayColors.pink,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFF713047),
    onSecondaryContainer: Color(0xFFFFD9E2),
    secondaryFixed: Color(0xFFFFD9E2),
    secondaryFixedDim: Color(0xFFF0B7C6),
    onSecondaryFixed: Color(0xFF3B071D),
    tertiary: PixelPlayColors.orange,
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFF713522),
    onTertiaryContainer: Color(0xFFFFDBD0),
    tertiaryFixed: Color(0xFFFFDBD0),
    tertiaryFixedDim: Color(0xFFFFB5A0),
    onTertiaryFixed: Color(0xFF3B0900),
    error: Color(0xFFFF5252),
    onError: Colors.white,
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: PixelPlayColors.purpleDark,
    onSurface: PixelPlayColors.lightPurple,
    onSurfaceVariant: Color(0xFFD6C2D9),
    surfaceContainerLowest: Color(0xFF0F0B13),
    surfaceContainerLow: Color(0xFF1B1422),
    surfaceContainer: Color(0xFF231A2C),
    surfaceContainerHigh: Color(0xFF2D2238),
    surfaceContainerHighest: Color(0xFF382B46),
    outline: Color(0xFF9F8C9F),
    outlineVariant: Color(0xFF514351),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFFF0DDED),
    onInverseSurface: Color(0xFF352D35),
    inversePrimary: Color(0xFFDFA8E8),
    surfaceTint: PixelPlayColors.purplePrimary,
  );

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: PixelPlayColors.lightPrimary,
    onPrimary: Colors.white,
    primaryContainer: PixelPlayColors.lightPrimaryContainer,
    onPrimaryContainer: PixelPlayColors.lightOnPrimaryContainer,
    primaryFixed: Color(0xFFE8DDFF),
    primaryFixedDim: Color(0xFFCFBCFF),
    onPrimaryFixed: Color(0xFF22005D),
    onPrimaryFixedVariant: Color(0xFF4F378B),
    secondary: PixelPlayColors.pink,
    onSecondary: Colors.white,
    secondaryContainer: Color(0x26F06292),
    onSecondaryContainer: Color(0xD9F06292),
    secondaryFixed: Color(0xFFFFD9E2),
    secondaryFixedDim: Color(0xFFF0B7C6),
    onSecondaryFixed: Color(0xFF3B071D),
    tertiary: PixelPlayColors.orange,
    onTertiary: Colors.black,
    tertiaryContainer: Color(0xFFFFDBD0),
    onTertiaryContainer: Color(0xFF3A0B00),
    tertiaryFixed: Color(0xFFFFDBD0),
    tertiaryFixedDim: Color(0xFFFFB5A0),
    onTertiaryFixed: Color(0xFF3B0900),
    error: Color(0xFFD32F2F),
    onError: Colors.white,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: PixelPlayColors.lightBackground,
    onSurface: PixelPlayColors.lightOnSurface,
    onSurfaceVariant: PixelPlayColors.lightOnSurfaceVariant,
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF7F2FA),
    surfaceContainer: Color(0xFFF3EDF7),
    surfaceContainerHigh: Color(0xFFECE6F0),
    surfaceContainerHighest: Color(0xFFE6E0E9),
    outline: PixelPlayColors.lightOutline,
    outlineVariant: Color(0x9978659A),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFF332F38),
    onInverseSurface: Color(0xFFF6EFF7),
    inversePrimary: Color(0xFFC9B9FF),
    surfaceTint: PixelPlayColors.lightPrimary,
  );
}
