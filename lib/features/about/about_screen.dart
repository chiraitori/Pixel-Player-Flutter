import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_info.dart';
import '../../shared/widgets/collapsible_common_top_bar.dart';
import 'open_source_licenses_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          CollapsibleCommonTopBar(
            title: 'About',
            onBack: () => Navigator.maybePop(context),
            expandedHeight: 170,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
            sliver: SliverList.list(
              children: const [
                _HeroCard(),
                SizedBox(height: 18),
                _Signals(),
                SizedBox(height: 28),
                _SectionTitle(
                  title: 'Maintainer',
                  subtitle: 'The person behind PixelPlayer.',
                ),
                SizedBox(height: 10),
                _ContributorCard(
                  contributors: [
                    _ContributorData(
                      name: 'Theo Vilardo',
                      role: 'Creator and maintainer',
                      detail:
                          'Building PixelPlayer with direct community feedback.',
                      handle: 'theovilardo',
                      localAvatar: 'assets/images/theveloper_icon.png',
                    ),
                  ],
                ),
                SizedBox(height: 28),
                _SectionTitle(
                  title: 'Community spotlight',
                  subtitle: 'Recognition for collaborators with major impact.',
                ),
                SizedBox(height: 10),
                _ContributorCard(
                  contributors: [
                    _ContributorData(
                      name: '@lostf1sh',
                      role: 'Most active contributor',
                      detail:
                          'Has contributed enormously across core features, architecture and reliability.',
                      handle: 'lostf1sh',
                    ),
                    _ContributorData(
                      name: '@cromaguy',
                      role: 'Rhythm developer',
                      detail:
                          'Developer of Rhythm and key community supporter.',
                      handle: 'cromaguy',
                    ),
                    _ContributorData(
                      name: '@ColbyCabrera',
                      role: 'Early contributor',
                      detail:
                          'Helped shape PixelPlayer in the first stages of the app.',
                      handle: 'ColbyCabrera',
                    ),
                  ],
                ),
                SizedBox(height: 28),
                _SectionTitle(
                  title: 'Licenses and notices',
                  subtitle:
                      'Attribution for dependencies and earlier contributions.',
                ),
                SizedBox(height: 10),
                _LicenseCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Image.asset(
              'assets/images/pixelplay_icon.webp',
              width: 116,
              height: 116,
            ),
            const SizedBox(height: 18),
            Text(
              'PixelPlayer',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: colors.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Open source music player built with its community.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: colors.onPrimaryContainer.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Text('Version ${AppInfo.version}'),
            ),
            const SizedBox(height: 22),
            const Row(
              children: [
                Expanded(
                  child: _SocialChip(
                    icon: Icons.code_rounded,
                    label: 'GitHub',
                    subtitle: 'Repository',
                    url: 'https://github.com/chiraitori/Pixel-Player-Flutter',
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _SocialChip(
                    icon: Icons.telegram,
                    label: 'Telegram',
                    subtitle: 'Support',
                    url: 'https://t.me/thevelopersupport',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialChip extends StatelessWidget {
  const _SocialChip({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.url,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () =>
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
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

class _Signals extends StatelessWidget {
  const _Signals();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _Signal(Icons.public_rounded, 'Open source')),
        SizedBox(width: 8),
        Expanded(child: _Signal(Icons.auto_awesome_rounded, 'Community first')),
        SizedBox(width: 8),
        Expanded(
          child: _Signal(Icons.palette_rounded, 'Material 3 expressive'),
        ),
      ],
    );
  }
}

class _Signal extends StatelessWidget {
  const _Signal(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          Text(
            subtitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContributorCard extends StatelessWidget {
  const _ContributorCard({required this.contributors});

  final List<_ContributorData> contributors;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            for (var index = 0; index < contributors.length; index++) ...[
              _ContributorRow(
                name: contributors[index].name,
                role: contributors[index].role,
                detail: contributors[index].detail,
                handle: contributors[index].handle,
                localAvatar: contributors[index].localAvatar,
              ),
              if (index != contributors.length - 1) const Divider(height: 28),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContributorData {
  const _ContributorData({
    required this.name,
    required this.role,
    required this.detail,
    required this.handle,
    this.localAvatar,
  });

  final String name;
  final String role;
  final String detail;
  final String handle;
  final String? localAvatar;
}

class _ContributorRow extends StatelessWidget {
  const _ContributorRow({
    required this.name,
    required this.role,
    required this.detail,
    required this.handle,
    this.localAvatar,
  });

  final String name;
  final String role;
  final String detail;
  final String handle;
  final String? localAvatar;

  @override
  Widget build(BuildContext context) {
    final avatar = localAvatar;
    return Row(
      children: [
        ClipOval(
          child: avatar != null
              ? Image.asset(avatar, width: 62, height: 62, fit: BoxFit.cover)
              : Image.network(
                  'https://github.com/$handle.png?size=144',
                  width: 62,
                  height: 62,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 62,
                    height: 62,
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: const Icon(Icons.person_rounded),
                  ),
                ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(role),
              Text(
                detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => launchUrl(
            Uri.parse('https://github.com/$handle'),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.open_in_new_rounded),
        ),
      ],
    );
  }
}

class _LicenseCard extends StatelessWidget {
  const _LicenseCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(18),
        leading: const Icon(Icons.article_rounded, size: 34),
        title: const Text('Open source licenses'),
        subtitle: const Text('Review libraries and third-party notices'),
        trailing: const Icon(Icons.arrow_forward_rounded),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const OpenSourceLicensesScreen(),
          ),
        ),
      ),
    );
  }
}
