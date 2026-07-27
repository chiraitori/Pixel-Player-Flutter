import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/song.dart';
import '../../core/state/app_controller.dart';
import '../../shared/widgets/artwork.dart';
import '../../shared/widgets/song_tile.dart';
import 'album_detail_screen.dart';
import 'genre_detail_screen.dart';

enum MediaDetailType {
  album,
  artist,
  playlist,
  genre,
  dailyMix,
  recentlyPlayed,
}

class MediaDetailScreen extends StatelessWidget {
  const MediaDetailScreen({required this.type, required this.id, super.key});

  final MediaDetailType type;
  final String id;

  @override
  Widget build(BuildContext context) {
    if (type == MediaDetailType.genre) {
      return GenreDetailScreen(genreId: id);
    }
    if (type == MediaDetailType.album) {
      return AlbumDetailScreen(albumId: id);
    }
    final data = _resolve(context);
    final controller = AppScope.of(context);
    final colors = Theme.of(context).colorScheme;
    final allFavorite =
        data.songs.isNotEmpty && data.songs.every(controller.isFavorite);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: type == MediaDetailType.artist ? 390 : 350,
            actions: [
              IconButton(
                onPressed: () => _showOptions(context, data.title),
                icon: const Icon(Icons.more_vert_rounded),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 72, 18),
              title: Text(
                data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [data.colors.first, colors.surface],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 32, bottom: 62),
                      child: type == MediaDetailType.artist
                          ? ClipOval(
                              child: Artwork(
                                colors: data.colors,
                                size: 210,
                                borderRadius: 0,
                                mediaStoreId: data.mediaStoreId,
                              ),
                            )
                          : Artwork(
                              colors: data.colors,
                              size: 210,
                              borderRadius: 26,
                              mediaStoreId: data.mediaStoreId,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.subtitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: data.songs.isEmpty
                            ? null
                            : () => controller.setFavoriteSongs(
                                data.songs,
                                !allFavorite,
                              ),
                        icon: Icon(
                          allFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        onPressed: data.songs.firstOrNull?.playbackUri == null
                            ? null
                            : () => launchUrl(
                                data.songs.first.playbackUri!,
                                mode: LaunchMode.externalApplication,
                              ),
                        icon: const Icon(Icons.folder_open_rounded),
                      ),
                      const Spacer(),
                      FloatingActionButton(
                        heroTag: 'detail-shuffle-$id',
                        onPressed: () =>
                            AppScope.of(context).playShuffled(data.songs),
                        elevation: 0,
                        child: const Icon(Icons.shuffle_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (type == MediaDetailType.artist)
            SliverToBoxAdapter(child: _ArtistAlbums(songs: data.songs)),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 38),
            sliver: SliverList.builder(
              itemCount: data.songs.length,
              itemBuilder: (context, index) => SongTile(
                song: data.songs[index],
                queue: data.songs,
                showTrackNumber: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _MediaDetailData _resolve(BuildContext context) {
    final controller = AppScope.of(context);
    final allSongs = controller.songs;
    const emptyColors = [Color(0xFF4F378B), Color(0xFF7D5260)];
    _MediaDetailData empty(String title) => _MediaDetailData(
      title: title,
      subtitle: 'No songs',
      songs: const [],
      colors: emptyColors,
    );

    return switch (type) {
      MediaDetailType.album => () {
        final matches = controller.albums.where(
          (item) => item.id == id || item.title == id,
        );
        if (matches.isEmpty) return empty(id);
        final album = matches.first;
        return _MediaDetailData(
          title: album.title,
          subtitle:
              '${album.artist} • ${album.songs.first.year} • ${album.songs.length} songs',
          songs: album.songs,
          colors: album.colors,
          mediaStoreId: album.songs.first.mediaStoreId,
        );
      }(),
      MediaDetailType.artist => () {
        final matches = controller.artists.where(
          (item) => item.id == id || item.name == id,
        );
        if (matches.isEmpty) return empty(id);
        final artist = matches.first;
        return _MediaDetailData(
          title: artist.name,
          subtitle:
              '${artist.songs.length} songs • ${_albums(artist.songs)} albums',
          songs: artist.songs,
          colors: artist.colors,
          mediaStoreId: artist.songs.first.mediaStoreId,
        );
      }(),
      MediaDetailType.playlist => () {
        final matches = controller.playlists.where(
          (item) => item.id == id || item.name == id,
        );
        if (matches.isEmpty) return empty(id);
        final playlist = matches.first;
        return _MediaDetailData(
          title: playlist.name,
          subtitle: '${playlist.songs.length} songs • PixelPlay playlist',
          songs: playlist.songs,
          colors: playlist.songs.first.colors,
          mediaStoreId: playlist.songs.first.mediaStoreId,
        );
      }(),
      MediaDetailType.genre => () {
        final songs = allSongs
            .where((song) => song.genre.toLowerCase() == id.toLowerCase())
            .toList();
        if (songs.isEmpty) return empty(id);
        return _MediaDetailData(
          title: id,
          subtitle: '${songs.length} songs • ${_artists(songs)} artists',
          songs: songs,
          colors: songs.first.colors,
          mediaStoreId: songs.first.mediaStoreId,
        );
      }(),
      MediaDetailType.dailyMix => _MediaDetailData(
        title: 'Daily Mix',
        subtitle: 'Made for you • Updated today',
        songs: allSongs.skip(1).take(25).toList(),
        colors: allSongs.isEmpty
            ? emptyColors
            : allSongs.length > 1
            ? allSongs[1].colors
            : allSongs.first.colors,
        mediaStoreId: allSongs.isEmpty
            ? null
            : allSongs.length > 1
            ? allSongs[1].mediaStoreId
            : allSongs.first.mediaStoreId,
      ),
      MediaDetailType.recentlyPlayed => _MediaDetailData(
        title: 'Recently played',
        subtitle: 'Your latest listening history',
        songs: controller.recentlyPlayedSongs,
        colors: controller.recentlyPlayedSongs.isEmpty
            ? emptyColors
            : controller.recentlyPlayedSongs.first.colors,
        mediaStoreId: controller.recentlyPlayedSongs.isEmpty
            ? null
            : controller.recentlyPlayedSongs.first.mediaStoreId,
      ),
    };
  }

  static int _albums(List<Song> songs) =>
      songs.map((song) => song.album).toSet().length;
  static int _artists(List<Song> songs) =>
      songs.map((song) => song.artist).toSet().length;

  void _showOptions(BuildContext context, String title) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const ListTile(
                leading: Icon(Icons.playlist_play_rounded),
                title: Text('Play next'),
              ),
              const ListTile(
                leading: Icon(Icons.queue_music_rounded),
                title: Text('Add to queue'),
              ),
              const ListTile(
                leading: Icon(Icons.playlist_add_rounded),
                title: Text('Add to playlist'),
              ),
              const ListTile(
                leading: Icon(Icons.share_rounded),
                title: Text('Share'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtistAlbums extends StatelessWidget {
  const _ArtistAlbums({required this.songs});

  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    final albums = songs.map((song) => song.album).toSet().toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Albums', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          SizedBox(
            height: 164,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: albums.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final album = albums[index];
                final song = songs.firstWhere((item) => item.album == album);
                return SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Artwork(
                        colors: song.colors,
                        size: 120,
                        borderRadius: 16,
                        mediaStoreId: song.mediaStoreId,
                      ),
                      const SizedBox(height: 6),
                      Text(album, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaDetailData {
  const _MediaDetailData({
    required this.title,
    required this.subtitle,
    required this.songs,
    required this.colors,
    this.mediaStoreId,
  });

  final String title;
  final String subtitle;
  final List<Song> songs;
  final List<Color> colors;
  final int? mediaStoreId;
}
