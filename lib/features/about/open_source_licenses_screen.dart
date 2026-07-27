import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OpenSourceLicensesScreen extends StatefulWidget {
  const OpenSourceLicensesScreen({super.key});

  @override
  State<OpenSourceLicensesScreen> createState() =>
      _OpenSourceLicensesScreenState();
}

class _OpenSourceLicensesScreenState extends State<OpenSourceLicensesScreen> {
  late Future<List<_PackageLicenses>> _packages;

  @override
  void initState() {
    super.initState();
    _packages = _loadLicenses();
  }

  Future<List<_PackageLicenses>> _loadLicenses() async {
    final grouped = <String, List<LicenseEntry>>{};
    await for (final entry in LicenseRegistry.licenses) {
      for (final package in entry.packages) {
        grouped.putIfAbsent(package, () => []).add(entry);
      }
    }
    final result = [
      for (final entry in grouped.entries)
        _PackageLicenses(entry.key, entry.value),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Open source licenses'),
        actions: [
          TextButton(
            onPressed: () => _showThirdPartyNotices(context),
            child: const Text('Notices'),
          ),
        ],
      ),
      body: FutureBuilder<List<_PackageLicenses>>(
        future: _packages,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _LicenseError(
              onRetry: () => setState(() => _packages = _loadLicenses()),
            );
          }
          final packages = snapshot.data ?? const [];
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: packages.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final package = packages[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 7,
                ),
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.secondaryContainer,
                  child: const Icon(Icons.code_rounded),
                ),
                title: Text(
                  package.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${package.entries.length} license'
                  '${package.entries.length == 1 ? '' : 's'}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _LicenseDetailScreen(package: package),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showThirdPartyNotices(BuildContext context) async {
    final noticeText = await rootBundle
        .loadString('assets/THIRD_PARTY_NOTICES.md')
        .catchError((_) => 'Unable to load third-party notices.');
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      useSafeArea: false,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.transparent,
        child: SafeArea(
          minimum: const EdgeInsets.all(20),
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                  child: Row(
                    children: [
                      Text(
                        'Third-party notices',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SelectionArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        noticeText,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LicenseDetailScreen extends StatelessWidget {
  const _LicenseDetailScreen({required this.package});

  final _PackageLicenses package;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(package.name)),
      body: SelectionArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
          itemCount: package.entries.length,
          separatorBuilder: (_, _) => const Divider(height: 32),
          itemBuilder: (context, index) {
            final paragraphs = package.entries[index].paragraphs.toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final paragraph in paragraphs)
                  Padding(
                    padding: EdgeInsets.only(
                      left: paragraph.indent * 14,
                      bottom: 12,
                    ),
                    child: Text(paragraph.text),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LicenseError extends StatelessWidget {
  const _LicenseError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 52),
            const SizedBox(height: 16),
            Text(
              'Licenses could not be loaded',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _PackageLicenses {
  const _PackageLicenses(this.name, this.entries);

  final String name;
  final List<LicenseEntry> entries;
}
