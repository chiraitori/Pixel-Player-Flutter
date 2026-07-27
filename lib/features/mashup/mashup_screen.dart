import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/models/song.dart';
import '../../core/state/app_controller.dart';
import '../../shared/widgets/artwork.dart';

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
  double crossfader = 0;
  double volumeOne = .8;
  double volumeTwo = .8;
  double speedOne = 1;
  double speedTwo = 1;

  @override
  void dispose() {
    playerOne.dispose();
    playerTwo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DJ Space')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 40),
        children: [
          _Deck(
            number: 1,
            song: deckOne,
            playing: onePlaying,
            volume: volumeOne,
            speed: speedOne,
            onLoad: () => _chooseSong(1),
            onPlayPause: () => _toggleDeck(1),
            onVolume: (value) {
              setState(() => volumeOne = value);
              _syncVolumes();
            },
            onSpeed: (value) {
              setState(() => speedOne = value);
              playerOne.setSpeed(value);
            },
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Text(
                    'Crossfader',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Row(
                    children: [
                      const Text('Deck 1'),
                      Expanded(
                        child: Slider(
                          value: crossfader,
                          min: -1,
                          max: 1,
                          onChanged: (value) {
                            setState(() => crossfader = value);
                            _syncVolumes();
                          },
                        ),
                      ),
                      const Text('Deck 2'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _Deck(
            number: 2,
            song: deckTwo,
            playing: twoPlaying,
            volume: volumeTwo,
            speed: speedTwo,
            onLoad: () => _chooseSong(2),
            onPlayPause: () => _toggleDeck(2),
            onVolume: (value) {
              setState(() => volumeTwo = value);
              _syncVolumes();
            },
            onSpeed: (value) {
              setState(() => speedTwo = value);
              playerTwo.setSpeed(value);
            },
          ),
        ],
      ),
    );
  }

  void _chooseSong(int deck) {
    final songs = AppScope.of(context).songs;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .68,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'Select a song',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: songs.length,
                itemBuilder: (context, index) {
                  final song = songs[index];
                  return ListTile(
                    leading: Artwork(
                      colors: song.colors,
                      size: 52,
                      borderRadius: 10,
                      mediaStoreId: song.mediaStoreId,
                    ),
                    title: Text(song.title),
                    subtitle: Text(song.artist),
                    onTap: () {
                      _loadDeck(deck, song);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadDeck(int deck, Song song) async {
    final uri = song.playbackUri;
    if (uri == null) return;
    final player = deck == 1 ? playerOne : playerTwo;
    await player.setAudioSource(AudioSource.uri(uri));
    if (!mounted) return;
    setState(() {
      if (deck == 1) {
        deckOne = song;
        onePlaying = false;
      } else {
        deckTwo = song;
        twoPlaying = false;
      }
    });
    _syncVolumes();
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
    final leftGain = ((1 - crossfader) / 2).clamp(0.0, 1.0);
    final rightGain = ((1 + crossfader) / 2).clamp(0.0, 1.0);
    playerOne.setVolume(volumeOne * leftGain);
    playerTwo.setVolume(volumeTwo * rightGain);
  }
}

class _Deck extends StatelessWidget {
  const _Deck({
    required this.number,
    required this.song,
    required this.playing,
    required this.volume,
    required this.speed,
    required this.onLoad,
    required this.onPlayPause,
    required this.onVolume,
    required this.onSpeed,
  });

  final int number;
  final Song? song;
  final bool playing;
  final double volume;
  final double speed;
  final VoidCallback onLoad;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onVolume;
  final ValueChanged<double> onSpeed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deck $number', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(
              children: [
                song == null
                    ? InkWell(
                        onTap: onLoad,
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.playlist_add_rounded,
                            size: 42,
                          ),
                        ),
                      )
                    : Artwork(
                        colors: song!.colors,
                        size: 104,
                        borderRadius: 18,
                        mediaStoreId: song!.mediaStoreId,
                      ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song?.title ?? 'No song loaded',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(song?.artist ?? 'Choose a track'),
                      Slider(
                        value: .26,
                        onChanged: song == null ? null : (_) {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: song == null ? null : () {},
                  child: const Text('<<'),
                ),
                IconButton(
                  onPressed: song == null ? onLoad : onPlayPause,
                  icon: Icon(
                    playing
                        ? Icons.pause_circle_rounded
                        : Icons.play_circle_rounded,
                  ),
                  iconSize: 54,
                ),
                OutlinedButton(
                  onPressed: song == null ? null : () {},
                  child: const Text('>>'),
                ),
              ],
            ),
            _DeckSlider(
              label: 'Volume',
              value: volume,
              onChanged: song == null ? null : onVolume,
            ),
            _DeckSlider(
              label: 'Speed',
              value: speed,
              min: .5,
              max: 2,
              onChanged: song == null ? null : onSpeed,
              suffix: '${speed.toStringAsFixed(1)}×',
            ),
          ],
        ),
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
    this.suffix,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 60, child: Text(label)),
        Expanded(
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
        if (suffix != null) SizedBox(width: 38, child: Text(suffix!)),
      ],
    );
  }
}
