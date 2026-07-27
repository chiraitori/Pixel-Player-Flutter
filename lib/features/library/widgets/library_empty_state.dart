import 'package:flutter/material.dart';

class LibraryEmptyState extends StatelessWidget {
  const LibraryEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 224),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              shape: const CircleBorder(),
              color: colors.secondaryContainer.withValues(alpha: .55),
              elevation: 2,
              child: SizedBox.square(
                dimension: 56,
                child: Icon(icon, size: 24, color: colors.onSecondaryContainer),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontFamily: 'GoogleSansFlex',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
