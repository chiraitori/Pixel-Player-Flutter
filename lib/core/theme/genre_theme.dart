import 'package:flutter/material.dart';

@immutable
class GenreThemeColor {
  const GenreThemeColor(this.container, this.onContainer);

  final Color container;
  final Color onContainer;
}

abstract final class GenreTheme {
  static const _unknownDark = GenreThemeColor(
    Color(0xFF3A3B42),
    Color(0xFFF2F1F6),
  );
  static const _unknownLight = GenreThemeColor(
    Color(0xFFE5E5EA),
    Color(0xFF1B1B20),
  );

  static const _dark = <GenreThemeColor>[
    GenreThemeColor(Color(0xFF004A77), Color(0xFFC2E7FF)),
    GenreThemeColor(Color(0xFF7D5260), Color(0xFFFFD8E4)),
    GenreThemeColor(Color(0xFF633B48), Color(0xFFFFD8EC)),
    GenreThemeColor(Color(0xFF004F58), Color(0xFF88FAFF)),
    GenreThemeColor(Color(0xFF324F34), Color(0xFFCBEFD0)),
    GenreThemeColor(Color(0xFF6E4E13), Color(0xFFFFDEAC)),
    GenreThemeColor(Color(0xFF3F474D), Color(0xFFDEE3EB)),
    GenreThemeColor(Color(0xFF4A4458), Color(0xFFE8DEF8)),
    GenreThemeColor(Color(0xFF7D2B2B), Color(0xFFFFB4AB)),
    GenreThemeColor(Color(0xFF5B6300), Color(0xFFDDF669)),
    GenreThemeColor(Color(0xFF005047), Color(0xFF8CF4E6)),
    GenreThemeColor(Color(0xFF4F378B), Color(0xFFEADDFF)),
    GenreThemeColor(Color(0xFF8B4A62), Color(0xFFFFD9E2)),
    GenreThemeColor(Color(0xFF725C00), Color(0xFFFFE084)),
    GenreThemeColor(Color(0xFF00213B), Color(0xFF99CBFF)),
    GenreThemeColor(Color(0xFF23507D), Color(0xFFD1E4FF)),
    GenreThemeColor(Color(0xFF93000A), Color(0xFFFFDAD6)),
    GenreThemeColor(Color(0xFF45464F), Color(0xFFC4C6D0)),
    GenreThemeColor(Color(0xFF5D3F75), Color(0xFFE8B6FF)),
    GenreThemeColor(Color(0xFF7A5900), Color(0xFFFFDEA5)),
  ];

  static const _light = <GenreThemeColor>[
    GenreThemeColor(Color(0xFFD7E3FF), Color(0xFF005AC1)),
    GenreThemeColor(Color(0xFFFFD8E4), Color(0xFF631835)),
    GenreThemeColor(Color(0xFFFFD8EC), Color(0xFF631B4B)),
    GenreThemeColor(Color(0xFFCCE8EA), Color(0xFF004F58)),
    GenreThemeColor(Color(0xFFCBEFD0), Color(0xFF042106)),
    GenreThemeColor(Color(0xFFFFDEAC), Color(0xFF281900)),
    GenreThemeColor(Color(0xFFEFF1F7), Color(0xFF44474F)),
    GenreThemeColor(Color(0xFFE8DEF8), Color(0xFF1D192B)),
    GenreThemeColor(Color(0xFFFFB4AB), Color(0xFF690005)),
    GenreThemeColor(Color(0xFFDDF669), Color(0xFF2F3300)),
    GenreThemeColor(Color(0xFF8CF4E6), Color(0xFF00201C)),
    GenreThemeColor(Color(0xFFEADDFF), Color(0xFF21005D)),
    GenreThemeColor(Color(0xFFFFD9E2), Color(0xFF3B071D)),
    GenreThemeColor(Color(0xFFFFE084), Color(0xFF231B00)),
    GenreThemeColor(Color(0xFF99CBFF), Color(0xFF003258)),
    GenreThemeColor(Color(0xFFD1E4FF), Color(0xFF051C36)),
    GenreThemeColor(Color(0xFFFFDAD6), Color(0xFF410002)),
    GenreThemeColor(Color(0xFFE2E2E9), Color(0xFF191C20)),
    GenreThemeColor(Color(0xFFF2DAFF), Color(0xFF2C004F)),
    GenreThemeColor(Color(0xFFFFDEA5), Color(0xFF261900)),
  ];

  static GenreThemeColor reference(
    String genre, {
    required Brightness brightness,
  }) {
    final id = normalizeId(genre);
    if (_isUnknown(id)) {
      return brightness == Brightness.dark ? _unknownDark : _unknownLight;
    }
    final palette = brightness == Brightness.dark ? _dark : _light;
    final index = _javaHash(id).abs() % palette.length;
    return palette[index];
  }

  static ColorScheme colorScheme(
    String genre, {
    required Brightness brightness,
  }) {
    final referenceColor = reference(genre, brightness: brightness);
    return ColorScheme.fromSeed(
      seedColor: referenceColor.container,
      brightness: brightness,
      dynamicSchemeVariant: _isUnknown(normalizeId(genre))
          ? DynamicSchemeVariant.monochrome
          : DynamicSchemeVariant.tonalSpot,
    );
  }

  static String normalizeId(String genre) =>
      genre.trim().toLowerCase().replaceAll(' ', '_').replaceAll('/', '_');

  static bool _isUnknown(String id) => id == 'unknown' || id == 'unknown_genre';

  /// Kotlin/JVM `String.hashCode`, used by the original genre palette mapper.
  static int _javaHash(String value) {
    var hash = 0;
    for (final codeUnit in value.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0xffffffff;
    }
    return hash >= 0x80000000 ? hash - 0x100000000 : hash;
  }
}
