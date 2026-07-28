import 'package:flutter/material.dart';

import '../../core/models/song.dart';
import '../../core/state/app_controller.dart';
import '../../data/providers/navidrome/navidrome_api_service.dart';

/// Source-driven Flutter port of Kotlin's Navidrome/Subsonic dashboard.
class NavidromeDashboardScreen extends StatefulWidget {
  const NavidromeDashboardScreen({super.key});

  @override
  State<NavidromeDashboardScreen> createState() =>
      _NavidromeDashboardScreenState();
}

class _NavidromeDashboardScreenState extends State<NavidromeDashboardScreen> {
  NavidromeApiService? _api;
  List<NavidromePlaylist> _playlists = const [];
  bool _syncing = true;
  String? _message;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _api ??= _createApi(AppScope.of(context));
    if (_syncing) _syncAll();
  }

  NavidromeApiService? _createApi(AppController controller) {
    final server = Uri.tryParse(
      controller.stringSetting('account_navidrome_server', ''),
    );
    final username = controller.stringSetting('account_navidrome_username', '');
    final password = controller.stringSetting(
      'account_navidrome_credential',
      '',
    );
    if (server == null ||
        !server.hasScheme ||
        username.isEmpty ||
        password.isEmpty) {
      return null;
    }
    return NavidromeApiService(
      server: server,
      username: username,
      password: password,
    );
  }

  Future<void> _syncAll() async {
    final api = _api;
    if (api == null) {
      setState(() {
        _syncing = false;
        _message = 'Connect a Subsonic server first.';
      });
      return;
    }
    setState(() {
      _syncing = true;
      _message = 'Syncing playlists…';
    });
    try {
      final playlists = await api.getPlaylists();
      if (!mounted) return;
      setState(() {
        _playlists = playlists;
        _message = '${playlists.length} playlists synced';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = 'Sync failed: $error');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _openPlaylist(NavidromePlaylist playlist) async {
    final api = _api;
    if (api == null) return;
    try {
      final tracks = await api.getPlaylistTracks(playlist.id);
      if (!mounted) return;
      final songs = tracks.map((track) => _song(api, track)).toList();
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        builder: (context) => _TrackSheet(
          playlist: playlist,
          songs: songs,
          onPlay: (song) {
            AppScope.of(this.context).playSong(song, fromQueue: songs);
            Navigator.pop(context);
          },
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load ${playlist.name}: $error')),
      );
    }
  }

  Song _song(NavidromeApiService api, NavidromeTrack track) => Song(
    id: 'navidrome_${track.id}',
    title: track.title,
    artist: track.artist,
    album: track.album,
    genre: track.genre ?? 'Navidrome',
    duration: track.duration,
    colors: const [Color(0xFF1565C0), Color(0xFF81D4FA)],
    year: track.year,
    track: track.track,
    contentUri: api.streamUri(track.id).toString(),
    mimeType: track.contentType,
    bitrate: track.bitRate == null ? null : track.bitRate! * 1000,
    source: SongSource.navidrome,
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final username = AppScope.of(
      context,
    ).stringSetting('account_navidrome_username', 'Subsonic');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subsonic'),
        leading: IconButton.filledTonal(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _syncAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            if (_message != null)
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(16),
                decoration: ShapeDecoration(
                  color: _message!.startsWith('Sync failed')
                      ? colors.errorContainer
                      : colors.primaryContainer,
                  shape: const RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                ),
                child: Row(
                  children: [
                    if (_syncing)
                      const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    Expanded(child: Text(_message!)),
                  ],
                ),
              ),
            Card(
              color: colors.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: colors.primaryContainer,
                      child: Icon(
                        Icons.dns_rounded,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text('${_playlists.length} playlists synced'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: colors.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick actions',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Refresh your cloud playlists and open tracks to play.',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.tonalIcon(
                      onPressed: _syncing ? null : _syncAll,
                      icon: const Icon(Icons.cloud_sync_rounded),
                      label: const Text('Sync library'),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 22, 8, 8),
              child: Text('Playlists'),
            ),
            if (!_syncing && _playlists.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.cloud_queue_rounded, size: 64),
                    SizedBox(height: 16),
                    Text('No playlists found'),
                  ],
                ),
              ),
            for (final playlist in _playlists)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => _openPlaylist(playlist),
                  leading: Icon(
                    Icons.music_note_rounded,
                    color: colors.primary,
                  ),
                  title: Text(playlist.name),
                  subtitle: Text('${playlist.songCount} songs'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrackSheet extends StatelessWidget {
  const _TrackSheet({
    required this.playlist,
    required this.songs,
    required this.onPlay,
  });

  final NavidromePlaylist playlist;
  final List<Song> songs;
  final ValueChanged<Song> onPlay;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .72,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            playlist.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return ListTile(
                onTap: () => onPlay(song),
                leading: Text('${index + 1}'),
                title: Text(song.title),
                subtitle: Text(song.artist),
                trailing: const Icon(Icons.play_arrow_rounded),
              );
            },
          ),
        ),
      ],
    ),
  );
}
