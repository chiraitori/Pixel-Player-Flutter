import 'package:flutter/material.dart';

class FolderBreadcrumb extends StatelessWidget {
  const FolderBreadcrumb({required this.path, required this.onBack, super.key});

  final String? path;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final name = path?.split('/').last ?? 'Folders';
    return Material(
      key: const ValueKey('folder-breadcrumb'),
      color: Theme.of(context).colorScheme.tertiaryContainer,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: path == null ? null : onBack,
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                path == null ? Icons.folder_rounded : Icons.arrow_back_rounded,
              ),
              const SizedBox(width: 8),
              Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }
}
