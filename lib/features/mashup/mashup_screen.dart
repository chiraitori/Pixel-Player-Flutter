import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/models/song.dart';
import '../../core/state/app_controller.dart';
import '../../shared/widgets/artwork.dart';

/// Flutter counterpart of Kotlin's two-deck [MashupScreen].
class MashupScreen extends StatefulWidget {
  const MashupScreen({super.key});

  @override
  State<MashupScreen> createState() => _MashupScreenState();
}

class _MashupScreenState extends State<MashupScreen> {
  final playerOne = AudioPlayer();
  final playerTwo = AudioPlayer();
  Song? deckOne;
  Song? deckTwo;
  bool onePlaying = false;
  bool twoPlaying = false;
  bool _loadingOne = false;
  bool _loadingTwo = false;
  double crossfader = 0;
  double volumeOne = .8;
  double volumeTwo = .8;
  double speedOne = 1;
  double speedTwo = 1;
  double progressOne = 0;
  double progressTwo = 0;
  Duration durationOne = Duration.zero;
  Duration durationTwo = Duration.zero;
  late final StreamSubscription<Duration> _positionOneSubscription;
  late final StreamSubscription<Duration> _positionTwoSubscription;

  @override
  void initState() {
    super.initState();
    _positionOneSubscription = playerOne.positionStream.listen(
      (position) => _updateProgress(1, position),
    );
    _positionTwoSubscription = playerTwo.positionStream.listen(
      (position) => _updateProgress(2, position),
    );
  }

  @override
  void dispose() {
    _positionOneSubscription.cancel();
    _positionTwoSubscription.cancel();
    playerOne.dispose();
    playerTwo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mashup'),
        backgroundColor: Theme.of(
          context,
        ).colorScheme.surface.withValues(alpha: .8),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          _Deck(
            number: 1,
            song: deckOne,
            playing: onePlaying,
            loading: _loadingOne,
            progress: progressOne,
            volume: volumeOne,
            speed: speedOne,
            onLoad: () => _chooseSong(1),
            onPlayPause: () => _toggleDeck(1),
            onSeek: (value) => _seekDeck(1, value),
            onNudge: (amount) => _nudgeDeck(1, amount),
            onVolume: (value) {
              setState(() => volumeOne = value);
              _syncVolumes();
            },
            onSpeed: (value) {
              setState(() => speedOne = value);
              unawaited(playerOne.setSpeed(value));
            },
          ),
          const SizedBox(height: 16),
          _Deck(
            number: 2,
            song: deckTwo,
            playing: twoPlaying,
            loading: _loadingTwo,
            progress: progressTwo,
            volume: volumeTwo,
            speed: speedTwo,
            onLoad: () => _chooseSong(2),
            onPlayPause: () => _toggleDeck(2),
            onSeek: (value) => _seekDeck(2, value),
            onNudge: (amount) => _nudgeDeck(2, amount),
            onVolume: (value) {
              setState(() => volumeTwo = value);
              _syncVolumes();
            },
            onSpeed: (value) {
              setState(() => speedTwo = value);
              unawaited(playerTwo.setSpeed(value));
            },
          ),
          const SizedBox(height: 16),
          _Crossfader(
            value: crossfader,
            onChanged: (value) {
              setState(() => crossfader = value);
              _syncVolumes();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _chooseSong(int deck) {
    final songs = AppScope.of(context).songs;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) => _SongPickerSheet(
        songs: songs,
        onSelected: (song) {
          Navigator.pop(context);
          unawaited(_loadDeck(deck, song));
        },
      ),
    );
  }

  Future<void> _loadDeck(int deck, Song song) async {
    final uri = song.playbackUri;
    if (uri == null) return;
    final player = deck == 1 ? playerOne : playerTwo;
    setState(() {
      if (deck == 1) _loadingOne = true;
      if (deck == 2) _loadingTwo = true;
    });
    try {
      final duration = await player.setAudioSource(AudioSource.uri(uri));
      if (!mounted) return;
      setState(() {
        if (deck == 1) {
          deckOne = song;
          onePlaying = false;
          progressOne = 0;
          durationOne = duration ?? Duration.zero;
        } else {
          deckTwo = song;
          twoPlaying = false;
          progressTwo = 0;
          durationTwo = duration ?? Duration.zero;
        }
      });
      _syncVolumes();
    } finally {
      if (mounted) {
        setState(() {
          if (deck == 1) _loadingOne = false;
          if (deck == 2) _loadingTwo = false;
        });
      }
    }
  }

  void _updateProgress(int deck, Duration position) {
    if (!mounted) return;
    final duration = deck == 1 ? durationOne : durationTwo;
    if (duration.inMilliseconds <= 0) return;
    final progress = (position.inMilliseconds / duration.inMilliseconds)
        .clamp(0.0, 1.0)
        .toDouble();
    setState(() {
      if (deck == 1) {
        progressOne = progress;
      } else {
        progressTwo = progress;
      }
    });
  }

  Future<void> _seekDeck(int deck, double progress) async {
    final player = deck == 1 ? playerOne : playerTwo;
    final duration = deck == 1 ? durationOne : durationTwo;
    if (duration.inMilliseconds <= 0) return;
    await player.seek(
      Duration(milliseconds: (duration.inMilliseconds * progress).round()),
    );
  }

  Future<void> _nudgeDeck(int deck, int milliseconds) async {
    final player = deck == 1 ? playerOne : playerTwo;
    final duration = deck == 1 ? durationOne : durationTwo;
    if (duration.inMilliseconds <= 0) return;
    final next = (player.position.inMilliseconds + milliseconds)
        .clamp(0, duration.inMilliseconds)
        .toInt();
    await player.seek(Duration(milliseconds: next));
  }

  Future<void> _toggleDeck(int deck) async {
    final player = deck == 1 ? playerOne : playerTwo;
    final hasSong = deck == 1 ? deckOne != null : deckTwo != null;
    if (!hasSong) {
      _chooseSong(deck);
      return;
    }
    if (player.playing) {
      await player.pause();
    } else {
      await player.play();
    }
    if (!mounted) return;
    setState(() {
      if (deck == 1) {
        onePlaying = player.playing;
      } else {
        twoPlaying = player.playing;
      }
    });
  }

  void _syncVolumes() {
    final leftGain = ((1 - crossfader) / 2).clamp(0.0, 1.0).toDouble();
    final rightGain = ((1 + crossfader) / 2).clamp(0.0, 1.0).toDouble();
    unawaited(playerOne.setVolume(volumeOne * leftGain));
    unawaited(playerTwo.setVolume(volumeTwo * rightGain));
  }
}

class _Deck extends StatelessWidget {
  const _Deck({
    required this.number,
    required this.song,
    required this.playing,
    required this.loading,
    required this.progress,
    required this.volume,
    required this.speed,
    required this.onLoad,
    required this.onPlayPause,
    required this.onSeek,
    required this.onNudge,
    required this.onVolume,
    required this.onSpeed,
  });

  final int number;
  final Song? song;
  final bool playing;
  final bool loading;
  final double progress;
  final double volume;
  final double speed;
  final VoidCallback onLoad;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onSeek;
  final ValueChanged<int> onNudge;
  final ValueChanged<double> onVolume;
  final ValueChanged<double> onSpeed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 4,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    'Deck $number',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: colors.primary),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _DeckArtwork(song: song, disabled: loading, onLoad: onLoad),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song?.title ?? 'No song loaded',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            song?.artist ?? 'Artist',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Slider(
                            value: progress,
                            onChanged: song == null || loading ? null : onSeek,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (song != null && !loading) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    color: colors.surfaceContainerHighest,
                    padding: const EdgeInsets.all(16),
                    child: const Text(
                      'Stem separation is unavailable for this track.',
                    ),
                  ),
                ],
                const Divider(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    OutlinedButton(
                      onPressed: song == null || loading
                          ? null
                          : () => onNudge(-100),
                      child: const Text('<<'),
                    ),
                    SizedBox.square(
                      dimension: 56,
                      child: IconButton(
                        onPressed: song == null || loading
                            ? (loading ? null : onLoad)
                            : onPlayPause,
                        icon: Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        iconSize: 42,
                        tooltip: playing
                            ? 'Pause deck $number'
                            : 'Play deck $number',
                      ),
                    ),
                    OutlinedButton(
                      onPressed: song == null || loading
                          ? null
                          : () => onNudge(100),
                      child: const Text('>>'),
                    ),
                  ],
                ),
                _DeckSlider(
                  label: 'Volume',
                  value: volume,
                  onChanged: song == null || loading ? null : onVolume,
                ),
                _DeckSlider(
                  label: 'Speed',
                  value: speed,
                  min: .5,
                  max: 2,
                  divisions: 14,
                  onChanged: song == null || loading ? null : onSpeed,
                  suffix: '${speed.toStringAsFixed(1)}×',
                ),
              ],
            ),
          ),
          if (loading)
            Positioned.fill(
              child: ColoredBox(
                color: colors.surface.withValues(alpha: .9),
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LinearProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading…'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DeckArtwork extends StatelessWidget {
  const _DeckArtwork({
    required this.song,
    required this.disabled,
    required this.onLoad,
  });

  final Song? song;
  final bool disabled;
  final VoidCallback onLoad;

  @override
  Widget build(BuildContext context) {
    if (song != null) {
      return Artwork(
        colors: song!.colors,
        size: 100,
        borderRadius: 12,
        mediaStoreId: song!.mediaStoreId,
      );
    }
    return InkWell(
      onTap: disabled ? null : onLoad,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.playlist_add_rounded, size: 40),
      ),
    );
  }
}

class _DeckSlider extends StatelessWidget {
  const _DeckSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.suffix,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double>? onChanged;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 60, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        if (suffix != null) SizedBox(width: 40, child: Text(suffix!)),
      ],
    );
  }
}

class _Crossfader extends StatelessWidget {
  const _Crossfader({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Crossfader', style: Theme.of(context).textTheme.titleMedium),
        Row(
          children: [
            const Text('Deck 1'),
            Expanded(
              child: Slider(
                value: value,
                min: -1,
                max: 1,
                onChanged: onChanged,
              ),
            ),
            const Text('Deck 2'),
          ],
        ),
      ],
    );
  }
}

class _SongPickerSheet extends StatelessWidget {
  const _SongPickerSheet({required this.songs, required this.onSelected});

  final List<Song> songs;
  final ValueChanged<Song> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .68,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Select a song',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: songs.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final song = songs[index];
                return ListTile(
                  leading: Artwork(
                    colors: song.colors,
                    size: 40,
                    borderRadius: 8,
                    mediaStoreId: song.mediaStoreId,
                  ),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => onSelected(song),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
