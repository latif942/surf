import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math' as math;

void main() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const SurfaceMusic());
}

// ─── COLORS ────────────────────────────────────────────────────
const kBg = Color(0xFF080810);
const kCard = Color(0xFF12121F);
const kPurple = Color(0xFF9D4EDD);
const kPurpleLight = Color(0xFFBB77FF);
const kPurpleDark = Color(0xFF5A189A);
const kAccent = Color(0xFFE040FB);
const kText = Color(0xFFF0E6FF);
const kSubtext = Color(0xFF8878AA);

// ─── MUSIC STATE ───────────────────────────────────────────────
class MusicState {
  static SongModel? currentSong;
  static AudioPlayer? player;
  static List<SongModel> queue = [];
  static int currentIndex = 0;

  static void playSong(SongModel song, List<SongModel> songs) async {
    currentSong = song;
    queue = songs;
    currentIndex = songs.indexOf(song);
    player ??= AudioPlayer();
    await player!.setAudioSource(AudioSource.uri(Uri.parse(song.uri!)));
    player!.play();
  }

  static void next() {
    if (queue.isEmpty) return;
    currentIndex = (currentIndex + 1) % queue.length;
    playSong(queue[currentIndex], queue);
  }

  static void previous() {
    if (queue.isEmpty) return;
    currentIndex = (currentIndex - 1 + queue.length) % queue.length;
    playSong(queue[currentIndex], queue);
  }
}

// ─── APP ───────────────────────────────────────────────────────
class SurfaceMusic extends StatelessWidget {
  const SurfaceMusic({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SurfaceMusic',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.dark(
          primary: kPurple,
          secondary: kAccent,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

// ─── MAIN SCREEN ───────────────────────────────────────────────
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _navController;

  @override
  void initState() {
    super.initState();
    _navController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _navController.dispose();
    super.dispose();
  }

  final List<Widget> _screens = [
    const SongFinderScreen(),
    const PlaylistScreen(),
    const NowPlayingScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(_currentIndex),
          child: _screens[_currentIndex],
        ),
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        border: Border(
          top: BorderSide(color: kPurple.withValues(alpha: 0.15), width: 1),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.graphic_eq_rounded, 'Library'),
              _navItem(1, Icons.queue_music_rounded, 'Playlists'),
              _navItem(2, Icons.waves_rounded, 'Playing'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final selected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? kPurple.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 250),
              child: Icon(
                icon,
                color: selected ? kPurpleLight : kSubtext,
                size: 22,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? kPurpleLight : kSubtext,
                letterSpacing: 0.5,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SONG FINDER ───────────────────────────────────────────────
class SongFinderScreen extends StatefulWidget {
  const SongFinderScreen({super.key});

  @override
  State<SongFinderScreen> createState() => _SongFinderScreenState();
}

class _SongFinderScreenState extends State<SongFinderScreen>
    with SingleTickerProviderStateMixin {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  List<SongModel> _songs = [];
  List<SongModel> _filtered = [];
  final TextEditingController _search = TextEditingController();
  late AnimationController _headerController;
  late Animation<double> _headerFade;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _headerFade = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    );
    _requestPermission();
    _headerController.forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    await Permission.audio.request();
    await Permission.storage.request();
    final songs = await _audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
    );
    setState(() {
      _songs = songs;
      _filtered = songs;
    });
  }

  void _filterSongs(String query) {
    setState(() {
      _filtered = _songs
          .where((s) =>
              s.title.toLowerCase().contains(query.toLowerCase()) ||
              (s.artist ?? '').toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _headerFade,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [kPurpleLight, kAccent],
                      ).createShader(bounds),
                      child: const Text(
                        'SurfaceMusic',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_songs.length} tracks in your library',
                      style: const TextStyle(
                        color: kSubtext,
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSearchBar(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: _filtered.isEmpty
                ? SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 80),
                        child: Column(
                          children: [
                            Icon(Icons.music_off_rounded,
                                size: 48,
                                color: kSubtext.withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            const Text('No songs found',
                                style: TextStyle(color: kSubtext)),
                          ],
                        ),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _SongTile(
                        song: _filtered[index],
                        index: index,
                        onTap: () {
                          MusicState.playSong(_filtered[index], _filtered);
                          setState(() {});
                        },
                        isPlaying:
                            MusicState.currentSong?.id == _filtered[index].id,
                      ),
                      childCount: _filtered.length,
                    ),
                  ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPurple.withValues(alpha: 0.2)),
      ),
      child: TextField(
        controller: _search,
        onChanged: _filterSongs,
        style: const TextStyle(color: kText, fontSize: 15),
        decoration: const InputDecoration(
          hintText: 'Search songs, artists...',
          hintStyle: TextStyle(color: kSubtext, fontSize: 15),
          prefixIcon: Icon(Icons.search_rounded, color: kPurple, size: 20),
          border: InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

// ─── SONG TILE ─────────────────────────────────────────────────
class _SongTile extends StatefulWidget {
  final SongModel song;
  final int index;
  final VoidCallback onTap;
  final bool isPlaying;

  const _SongTile({
    required this.song,
    required this.index,
    required this.onTap,
    required this.isPlaying,
  });

  @override
  State<_SongTile> createState() => _SongTileState();
}

class _SongTileState extends State<_SongTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = _controller;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.reverse(),
      onTapUp: (_) {
        _controller.forward();
        widget.onTap();
      },
      onTapCancel: () => _controller.forward(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.isPlaying
                ? kPurple.withValues(alpha: 0.12)
                : kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isPlaying
                  ? kPurple.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              _buildArtwork(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.song.title,
                      style: TextStyle(
                        color: widget.isPlaying ? kPurpleLight : kText,
                        fontWeight: widget.isPlaying
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.song.artist ?? 'Unknown Artist',
                      style: const TextStyle(
                          color: kSubtext, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (widget.isPlaying)
                const _WaveAnimation()
              else
                const Icon(Icons.play_arrow_rounded,
                    color: kSubtext, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArtwork() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: widget.isPlaying
            ? const LinearGradient(
                colors: [kPurpleDark, kPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: widget.isPlaying ? null : const Color(0xFF1E1E32),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: QueryArtworkWidget(
          id: widget.song.id,
          type: ArtworkType.AUDIO,
          keepOldArtwork: true,
          nullArtworkWidget: Icon(
            Icons.music_note_rounded,
            color: widget.isPlaying ? Colors.white : kSubtext,
            size: 22,
          ),
        ),
      ),
    );
  }
}

// ─── WAVE ANIMATION ────────────────────────────────────────────
class _WaveAnimation extends StatefulWidget {
  const _WaveAnimation();

  @override
  State<_WaveAnimation> createState() => _WaveAnimationState();
}

class _WaveAnimationState extends State<_WaveAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(3, (i) {
              final height = 6 +
                  10 *
                      math.sin(
                          (_controller.value * 2 * math.pi) + i * 1.2);
              return Container(
                width: 3,
                height: height.abs() + 4,
                decoration: BoxDecoration(
                  color: kPurpleLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

// ─── NOW PLAYING ───────────────────────────────────────────────
class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotateController;
  late AnimationController _pulseController;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final song = MusicState.currentSong;
    final player = MusicState.player;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          children: [
            const SizedBox(height: 32),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [kPurpleLight, kAccent],
              ).createShader(bounds),
              child: const Text(
                'Now Playing',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 3,
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Album Art
            ScaleTransition(
              scale: _pulse,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [kPurpleDark, Color(0xFF1A0533)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kPurple.withValues(alpha: 0.4),
                      blurRadius: 50,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: AnimatedBuilder(
                  animation: _rotateController,
                  builder: (context, child) => Transform.rotate(
                    angle: _rotateController.value * 2 * math.pi,
                    child: child,
                  ),
                  child: ClipOval(
                    child: song != null
                        ? QueryArtworkWidget(
                            id: song.id,
                            type: ArtworkType.AUDIO,
                            keepOldArtwork: true,
                            nullArtworkWidget: const Icon(
                              Icons.music_note_rounded,
                              size: 80,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.music_note_rounded,
                            size: 80,
                            color: Colors.white,
                          ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Song Info
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Column(
                key: ValueKey(song?.id),
                children: [
                  Text(
                    song?.title ?? 'Nothing playing',
                    style: const TextStyle(
                      color: kText,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    song?.artist ?? '—',
                    style: const TextStyle(
                      color: kSubtext,
                      fontSize: 14,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),

            // Progress Bar
            if (player != null)
              StreamBuilder<Duration>(
                stream: player.positionStream,
                builder: (context, snapshot) {
                  final position = snapshot.data ?? Duration.zero;
                  final duration = player.duration ?? Duration.zero;
                  final progress = duration.inMilliseconds > 0
                      ? position.inMilliseconds /
                          duration.inMilliseconds
                      : 0.0;

                  return Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: kCard,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: progress.clamp(0.0, 1.0),
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [kPurple, kAccent],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_fmt(position),
                              style: const TextStyle(
                                  color: kSubtext, fontSize: 12)),
                          Text(_fmt(duration),
                              style: const TextStyle(
                                  color: kSubtext, fontSize: 12)),
                        ],
                      ),
                    ],
                  );
                },
              ),

            const SizedBox(height: 32),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ControlButton(
                  icon: Icons.skip_previous_rounded,
                  size: 32,
                  onTap: () {
                    MusicState.previous();
                    setState(() {});
                  },
                ),
                const SizedBox(width: 20),
                StreamBuilder<bool>(
                  stream: player?.playingStream,
                  builder: (context, snapshot) {
                    final playing = snapshot.data ?? false;
                    return GestureDetector(
                      onTap: () {
                        if (playing) {
                          player?.pause();
                        } else {
                          player?.play();
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [kPurple, kAccent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: kPurple.withValues(alpha: 0.5),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 20),
                _ControlButton(
                  icon: Icons.skip_next_rounded,
                  size: 32,
                  onTap: () {
                    MusicState.next();
                    setState(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ─── CONTROL BUTTON ────────────────────────────────────────────
class _ControlButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.size,
    required this.onTap,
  });

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.85,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.reverse(),
      onTapUp: (_) {
        _controller.forward();
        widget.onTap();
      },
      onTapCancel: () => _controller.forward(),
      child: ScaleTransition(
        scale: _controller,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: kCard,
            border: Border.all(
                color: kPurple.withValues(alpha: 0.2)),
          ),
          child: Icon(widget.icon, color: kText, size: widget.size),
        ),
      ),
    );
  }
}

// ─── PLAYLIST ──────────────────────────────────────────────────
class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  final List<Map<String, dynamic>> _playlists = [];
  final TextEditingController _nameController = TextEditingController();

  void _createPlaylist() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New Playlist',
              style: TextStyle(
                color: kText,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: kPurple.withValues(alpha: 0.3)),
              ),
              child: TextField(
                controller: _nameController,
                style: const TextStyle(color: kText),
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Playlist name...',
                  hintStyle: TextStyle(color: kSubtext),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () {
                  if (_nameController.text.isNotEmpty) {
                    setState(() {
                      _playlists.add({
                        'name': _nameController.text,
                        'songs': <SongModel>[],
                      });
                    });
                    _nameController.clear();
                    Navigator.pop(context);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [kPurple, kAccent],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Create',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [kPurpleLight, kAccent],
                  ).createShader(bounds),
                  child: const Text(
                    'Playlists',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _createPlaylist,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kPurple, kAccent],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _playlists.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: kPurple.withValues(alpha: 0.1),
                            ),
                            child: const Icon(
                              Icons.queue_music_rounded,
                              size: 36,
                              color: kPurple,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No playlists yet',
                            style: TextStyle(
                              color: kText,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Tap + to create your first playlist',
                            style: TextStyle(
                                color: kSubtext, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _playlists.length,
                      itemBuilder: (context, index) {
                        final playlist = _playlists[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: kCard,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: kPurple.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  gradient: const LinearGradient(
                                    colors: [kPurpleDark, kPurple],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.queue_music_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      playlist['name'],
                                      style: const TextStyle(
                                        color: kText,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${(playlist['songs'] as List).length} songs',
                                      style: const TextStyle(
                                        color: kSubtext,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: kSubtext,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}