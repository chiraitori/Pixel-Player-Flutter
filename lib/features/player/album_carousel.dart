import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/song.dart';
import '../../shared/widgets/artwork.dart';

class AlbumCarousel extends StatefulWidget {
  const AlbumCarousel({
    required this.currentSong,
    required this.queue,
    required this.isPlaying,
    required this.onSongSelected,
    this.onArtworkTap,
    this.viewportFraction = .8,
    super.key,
  });

  final Song currentSong;
  final List<Song> queue;
  final bool isPlaying;
  final ValueChanged<Song> onSongSelected;
  final ValueChanged<Song>? onArtworkTap;
  final double viewportFraction;

  @override
  State<AlbumCarousel> createState() => _AlbumCarouselState();
}

class _AlbumCarouselState extends State<AlbumCarousel> {
  late PageController _pageController;
  bool _userDragActive = false;
  bool _programmaticScroll = false;

  int get _currentIndex {
    final index = widget.queue.indexWhere(
      (item) => item.id == widget.currentSong.id,
    );
    return index < 0 ? 0 : index;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: _currentIndex,
      viewportFraction: widget.queue.length == 1 ? 1 : widget.viewportFraction,
    );
  }

  @override
  void didUpdateWidget(covariant AlbumCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldFraction = oldWidget.queue.length == 1
        ? 1.0
        : oldWidget.viewportFraction;
    final newFraction = widget.queue.length == 1
        ? 1.0
        : widget.viewportFraction;
    if (oldFraction != newFraction) {
      _pageController.dispose();
      _pageController = PageController(
        initialPage: _currentIndex,
        viewportFraction: newFraction,
      );
      return;
    }

    final page = _pageController.hasClients
        ? (_pageController.page ?? _pageController.initialPage).round()
        : _pageController.initialPage;
    if (page == _currentIndex || _userDragActive) return;
    _programmaticScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_pageController.hasClients) return;
      await _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      _programmaticScroll = false;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectSettledPage() {
    if (!_userDragActive ||
        _programmaticScroll ||
        !_pageController.hasClients) {
      _userDragActive = false;
      return;
    }
    _userDragActive = false;
    final index = (_pageController.page ?? 0).round().clamp(
      0,
      widget.queue.length - 1,
    );
    final selected = widget.queue[index];
    if (selected.id != widget.currentSong.id) {
      HapticFeedback.heavyImpact();
      widget.onSongSelected(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.queue.isEmpty) return const SizedBox.shrink();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedScale(
      scale: widget.isPlaying ? 1 : .95,
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 260),
      curve: Curves.fastOutSlowIn,
      child: Listener(
        onPointerDown: (_) => _userDragActive = true,
        child: NotificationListener<ScrollEndNotification>(
          onNotification: (notification) {
            _selectSettledPage();
            return false;
          },
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.queue.length,
            // Kotlin's ONE_PEEK multi-browse carousel is start-aligned. Keeping
            // padEnds disabled produces one trailing peek instead of two
            // centered half-peeks; NO_PEEK remains a full-width page.
            padEnds: widget.viewportFraction >= .999,
            itemBuilder: (context, index) {
              final song = widget.queue[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: index == _currentIndex && widget.onArtworkTap != null
                      ? () => widget.onArtworkTap!(song)
                      : null,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final artworkSize = constraints.biggest.shortestSide;
                        return Artwork(
                          colors: song.colors,
                          size: artworkSize,
                          borderRadius: 16,
                          iconSize: 82,
                          mediaStoreId: song.mediaStoreId,
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
