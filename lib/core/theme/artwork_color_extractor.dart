import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

/// Dart port of PixelPlayer's `ColorRoles.selectSeedColorArgbFromPixels`.
///
/// The Kotlin app deliberately does more than choose a conventional "vibrant"
/// swatch. It quantizes the complete artwork, scores colors by population and
/// HCT chroma, biases the result toward a representative artwork color, then
/// refines the winning seed against nearby source pixels.
Future<Color?> extractPixelPlayerArtworkSeed(Uint8List encodedArtwork) async {
  if (encodedArtwork.isEmpty) return null;

  ui.Codec? sourceCodec;
  ui.Codec? scaledCodec;
  ui.Image? sourceImage;
  ui.Image? image;
  try {
    sourceCodec = await ui.instantiateImageCodec(encodedArtwork);
    sourceImage = (await sourceCodec.getNextFrame()).image;

    if (sourceImage.width > 128 || sourceImage.height > 128) {
      final scale =
          128 / sourceImage.width.clamp(sourceImage.height, double.infinity);
      final width = (sourceImage.width * scale).round().clamp(1, 128);
      final height = (sourceImage.height * scale).round().clamp(1, 128);
      scaledCodec = await ui.instantiateImageCodec(
        encodedArtwork,
        targetWidth: width,
        targetHeight: height,
        allowUpscaling: false,
      );
      image = (await scaledCodec.getNextFrame()).image;
    } else {
      image = sourceImage;
    }

    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytes == null) return null;
    final pixels = _rgbaToArgb(bytes.buffer.asUint8List());
    if (pixels.isEmpty) return null;
    final seed = await _selectSeedColorArgbFromPixels(pixels);
    return Color(seed);
  } finally {
    if (image != null && !identical(image, sourceImage)) image.dispose();
    sourceImage?.dispose();
    scaledCodec?.dispose();
    sourceCodec?.dispose();
  }
}

List<int> _rgbaToArgb(Uint8List rgba) {
  final pixels = List<int>.filled(rgba.length ~/ 4, 0, growable: false);
  for (var source = 0, target = 0; source + 3 < rgba.length; source += 4) {
    pixels[target++] =
        (rgba[source + 3] << 24) |
        (rgba[source] << 16) |
        (rgba[source + 1] << 8) |
        rgba[source + 2];
  }
  return pixels;
}

Future<int> _selectSeedColorArgbFromPixels(List<int> pixels) async {
  final fallback = _averageColorArgb(pixels);
  final quantized = await QuantizerCelebi().quantize(pixels, 128);
  final colorsToPopulation = quantized.colorToCount;

  if (_isMostlyNeutralArtwork(colorsToPopulation) &&
      _isArgbNearGrayscale(fallback)) {
    return fallback;
  }

  final representative = _calculateRepresentativeArtworkColor(pixels);
  final ranked = _scoreQuantizedColors(
    colorsToPopulation,
    fallback,
    representative,
  );
  final selected = ranked.isEmpty ? fallback : ranked.first;
  return _refineSeedColorArgb(selected, pixels, representative);
}

List<int> _scoreQuantizedColors(
  Map<int, int> colorsToPopulation,
  int fallback,
  _RepresentativeArtworkColor? representative,
) {
  if (colorsToPopulation.isEmpty) return <int>[fallback];

  final colorsHct = <Hct>[];
  final huePopulation = List<int>.filled(360, 0);
  var populationSum = 0.0;
  for (final entry in colorsToPopulation.entries) {
    if (entry.value <= 0) continue;
    final hct = Hct.fromInt(entry.key);
    colorsHct.add(hct);
    huePopulation[_sanitizeDegreesInt(hct.hue.floor())] += entry.value;
    populationSum += entry.value;
  }
  if (populationSum <= 0) return <int>[fallback];

  final excitedProportions = List<double>.filled(360, 0);
  for (var hue = 0; hue < 360; hue++) {
    final proportion = huePopulation[hue] / populationSum;
    for (var neighbor = hue - 14; neighbor <= hue + 15; neighbor++) {
      excitedProportions[_sanitizeDegreesInt(neighbor)] += proportion;
    }
  }

  final scored = <_ScoredHct>[];
  for (final hct in colorsHct) {
    final hue = _sanitizeDegreesInt(hct.hue.round());
    final excitedProportion = excitedProportions[hue];
    if (hct.chroma < 5 || excitedProportion <= 0.01) continue;

    final proportionScore = excitedProportion * 100 * 0.7;
    final chromaWeight = hct.chroma < 48 ? 0.1 : 0.3;
    final chromaScore = (hct.chroma - 48) * chromaWeight;
    final fidelityScore = representative == null
        ? 0.0
        : _representativeFidelityScore(hct, representative.hct);
    final excessChromaPenalty = representative == null
        ? 0.0
        : _excessChromaPenalty(hct, representative.hct);
    scored.add(
      _ScoredHct(
        hct,
        proportionScore + chromaScore + fidelityScore - excessChromaPenalty,
      ),
    );
  }
  if (scored.isEmpty) return <int>[fallback];
  scored.sort((a, b) => b.score.compareTo(a.score));

  final chosen = <Hct>[];
  for (var difference = 90; difference >= 15; difference--) {
    chosen.clear();
    for (final candidate in scored) {
      final duplicateHue = chosen.any(
        (item) =>
            MathUtils.differenceDegrees(candidate.hct.hue, item.hue) <
            difference,
      );
      if (!duplicateHue) chosen.add(candidate.hct);
      if (chosen.length >= 4) break;
    }
    if (chosen.length >= 4) break;
  }
  return chosen.isEmpty
      ? <int>[fallback]
      : chosen.map((color) => color.toInt()).toList(growable: false);
}

_RepresentativeArtworkColor? _calculateRepresentativeArtworkColor(
  List<int> pixels,
) {
  var totalRed = 0.0;
  var totalGreen = 0.0;
  var totalBlue = 0.0;
  var totalWeight = 0.0;
  var representativePixelCount = 0;

  for (final argb in pixels) {
    final alpha = (argb >> 24) & 0xff;
    if (alpha < 28) continue;
    final red = (argb >> 16) & 0xff;
    final green = (argb >> 8) & 0xff;
    final blue = argb & 0xff;
    if (red + green + blue <= 36) continue;

    final hct = Hct.fromInt(argb);
    if (hct.chroma < 10) continue;
    final weight =
        1 + ((hct.chroma - 10) / 24).clamp(0, double.infinity) + hct.tone / 100;
    totalRed += red * weight;
    totalGreen += green * weight;
    totalBlue += blue * weight;
    totalWeight += weight;
    representativePixelCount++;
  }

  if (totalWeight <= 0 || representativePixelCount / pixels.length < 0.04) {
    return null;
  }
  final argb =
      0xff000000 |
      ((totalRed / totalWeight).round().clamp(0, 255) << 16) |
      ((totalGreen / totalWeight).round().clamp(0, 255) << 8) |
      (totalBlue / totalWeight).round().clamp(0, 255);
  return _RepresentativeArtworkColor(argb, Hct.fromInt(argb));
}

double _representativeFidelityScore(Hct candidate, Hct representative) {
  final hueDistance = MathUtils.differenceDegrees(
    candidate.hue,
    representative.hue,
  );
  final chromaDistance = (candidate.chroma - representative.chroma).abs();
  final toneDistance = (candidate.tone - representative.tone).abs();
  final hueScore = ((90 - hueDistance).clamp(0, double.infinity) / 90) * 18;
  final chromaScore =
      ((32 - chromaDistance).clamp(0, double.infinity) / 32) * 7;
  final toneScore = ((28 - toneDistance).clamp(0, double.infinity) / 28) * 3;
  return hueScore + chromaScore + toneScore;
}

double _excessChromaPenalty(Hct candidate, Hct representative) {
  final excessChroma = candidate.chroma - representative.chroma - 18;
  return excessChroma <= 0 ? 0 : excessChroma * 0.18;
}

int _refineSeedColorArgb(
  int candidateArgb,
  List<int> pixels,
  _RepresentativeArtworkColor? representative,
) {
  final candidateHct = Hct.fromInt(candidateArgb);
  var totalRed = 0.0;
  var totalGreen = 0.0;
  var totalBlue = 0.0;
  var totalWeight = 0.0;
  var matchingPixelCount = 0;

  for (final argb in pixels) {
    final alpha = (argb >> 24) & 0xff;
    if (alpha < 28) continue;
    final red = (argb >> 16) & 0xff;
    final green = (argb >> 8) & 0xff;
    final blue = argb & 0xff;
    if (red + green + blue <= 36) continue;

    final hct = Hct.fromInt(argb);
    if (hct.chroma < 5) continue;
    final hueDistance = MathUtils.differenceDegrees(candidateHct.hue, hct.hue);
    if (hueDistance > 32) continue;
    final weight =
        1 +
        (32 - hueDistance) / 32 +
        ((hct.chroma - 5) / 32).clamp(0, double.infinity);
    totalRed += red * weight;
    totalGreen += green * weight;
    totalBlue += blue * weight;
    totalWeight += weight;
    matchingPixelCount++;
  }
  if (totalWeight <= 0 || matchingPixelCount / pixels.length < 0.08) {
    return candidateArgb;
  }

  final localAverage =
      0xff000000 |
      ((totalRed / totalWeight).round().clamp(0, 255) << 16) |
      ((totalGreen / totalWeight).round().clamp(0, 255) << 8) |
      (totalBlue / totalWeight).round().clamp(0, 255);
  final localHct = Hct.fromInt(localAverage);
  if (MathUtils.differenceDegrees(candidateHct.hue, localHct.hue) > 32) {
    return candidateArgb;
  }

  final refined = _blendArgb(candidateArgb, localAverage, 0.42);
  if (representative == null) return refined;
  return MathUtils.differenceDegrees(localHct.hue, representative.hct.hue) <= 90
      ? _blendArgb(refined, representative.argb, 0.21)
      : refined;
}

int _blendArgb(int first, int second, double ratio) {
  final safeRatio = ratio.clamp(0, 1);
  final inverse = 1 - safeRatio;
  int channel(int shift) =>
      ((((first >> shift) & 0xff) * inverse) +
              (((second >> shift) & 0xff) * safeRatio))
          .round()
          .clamp(0, 255);
  return (channel(24) << 24) |
      (channel(16) << 16) |
      (channel(8) << 8) |
      channel(0);
}

int _averageColorArgb(List<int> pixels) {
  var totalRed = 0;
  var totalGreen = 0;
  var totalBlue = 0;
  for (final argb in pixels) {
    totalRed += (argb >> 16) & 0xff;
    totalGreen += (argb >> 8) & 0xff;
    totalBlue += argb & 0xff;
  }
  final size = pixels.length;
  return 0xff000000 |
      ((totalRed ~/ size).clamp(0, 255) << 16) |
      ((totalGreen ~/ size).clamp(0, 255) << 8) |
      (totalBlue ~/ size).clamp(0, 255);
}

bool _isMostlyNeutralArtwork(Map<int, int> colorsToPopulation) {
  if (colorsToPopulation.isEmpty) return false;
  var totalPopulation = 0.0;
  var neutralPopulation = 0.0;
  var highChromaPopulation = 0.0;
  var weightedChroma = 0.0;
  for (final entry in colorsToPopulation.entries) {
    if (entry.value <= 0) continue;
    final population = entry.value.toDouble();
    final chroma = Hct.fromInt(entry.key).chroma;
    totalPopulation += population;
    weightedChroma += chroma * population;
    if (chroma <= 8) neutralPopulation += population;
    if (chroma >= 18) highChromaPopulation += population;
  }
  if (totalPopulation <= 0) return false;
  return neutralPopulation / totalPopulation >= 0.92 &&
      highChromaPopulation / totalPopulation <= 0.03 &&
      weightedChroma / totalPopulation <= 9;
}

bool _isArgbNearGrayscale(int argb) {
  final red = (argb >> 16) & 0xff;
  final green = (argb >> 8) & 0xff;
  final blue = argb & 0xff;
  return <int>[
        (red - green).abs(),
        (green - blue).abs(),
        (red - blue).abs(),
      ].reduce((a, b) => a > b ? a : b) <=
      10;
}

int _sanitizeDegreesInt(int degrees) {
  final sanitized = degrees % 360;
  return sanitized < 0 ? sanitized + 360 : sanitized;
}

class _ScoredHct {
  const _ScoredHct(this.hct, this.score);

  final Hct hct;
  final double score;
}

class _RepresentativeArtworkColor {
  const _RepresentativeArtworkColor(this.argb, this.hct);

  final int argb;
  final Hct hct;
}
