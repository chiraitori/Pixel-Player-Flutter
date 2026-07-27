import 'package:flutter/material.dart';

class GenreTitlePresentation {
  const GenreTitlePresentation({
    required this.firstLine,
    required this.style,
    this.secondLine,
  });

  final String firstLine;
  final String? secondLine;
  final TextStyle style;
}

GenreTitlePresentation resolveGenreTitle(String genre, {required bool grid}) {
  final words = genre.trim().split(RegExp(r'\s+'));
  String first = genre;
  String? second;
  if (grid && genre.length > 12 && words.length > 1) {
    var bestIndex = 1;
    var bestDifference = genre.length;
    for (var index = 1; index < words.length; index++) {
      final left = words.take(index).join(' ');
      final right = words.skip(index).join(' ');
      final difference = (left.length - right.length).abs();
      if (difference < bestDifference) {
        bestDifference = difference;
        bestIndex = index;
      }
    }
    first = words.take(bestIndex).join(' ');
    second = words.skip(bestIndex).join(' ');
  }
  final length = max(first.length, second?.length ?? 0);
  final size = grid
      ? (length > 13 ? 18.0 : (length > 9 ? 21.0 : 24.0))
      : (length > 22 ? 21.0 : 24.0);
  return GenreTitlePresentation(
    firstLine: first,
    secondLine: second,
    style: TextStyle(
      fontFamily: 'GoogleSansFlex',
      fontSize: size,
      height: .96,
      fontWeight: FontWeight.w800,
      letterSpacing: -.25,
    ),
  );
}

int max(int a, int b) => a > b ? a : b;
