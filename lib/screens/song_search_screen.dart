import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/song_db_service.dart';

/// A screen for searching songs and pushing their lyrics as slides.
///
/// Designed to integrate with [HomeScreen] via a tab or side-panel.
/// Call [onSlidePush] to send a slide text to the projector output,
/// just as the Bible verse push works.
class SongSearchScreen extends StatefulWidget {
  /// Called with a slide text string when the user taps a slide to push.
  final void Function(String slideText) onSlidePush;

  const SongSearchScreen({super.key, required this.onSlidePush});

  @override
  State<SongSearchScreen> createState() => _SongSearchScreenState();
}

class _SongSearchScreenState extends State<SongSearchScreen> {
  final _db = SongDbService();
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  List<Song> _results = [];
  List<Song> _recent = [];
  Song? _selectedSong;
  SongLyrics? _selectedLyrics;
  bool _loading = false;
  bool _loadingLyrics = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    try {
      final recent = await _db.getRecentSongs(limit: 15);
      if (mounted) setState(() => _recent = recent);
    } catch (e) {
      // Recent songs are optional — silently ignore errors
    }
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final results = await _db.searchSongs(query);
      if (mounted) {
        setState(() {
          _results = results;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Search failed: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _selectSong(Song song) async {
    setState(() {
      _selectedSong = song;
      _selectedLyrics = null;
      _loadingLyrics = true;
    });
    try {
      final lyrics = await _db.getLyrics(song.id);
      if (mounted) {
        setState(() {
          _selectedLyrics = lyrics;
          _loadingLyrics = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingLyrics = false;
          _error = 'Could not load lyrics: $e';
        });
      }
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedSong = null;
      _selectedLyrics = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(),
        if (_error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(_error, style: TextStyle(color: Colors.red.shade400)),
          ),
        Expanded(
          child: _selectedSong != null ? _buildLyricsView() : _buildSongList(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _searchCtrl,
        focusNode: _searchFocus,
        decoration: InputDecoration(
          hintText: 'Search songs by title or author…',
          prefixIcon: const Icon(Icons.music_note_outlined),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtrl.clear();
                    _clearSelection();
                    setState(() => _results = []);
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          isDense: true,
        ),
        onChanged: (v) {
          if (v.isEmpty) {
            setState(() => _results = []);
            _clearSelection();
          } else {
            _search(v);
          }
        },
      ),
    );
  }

  Widget _buildSongList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final list = _searchCtrl.text.isEmpty ? _recent : _results;
    final isRecent = _searchCtrl.text.isEmpty;

    if (list.isEmpty && _searchCtrl.text.isEmpty) {
      return const Center(
        child: Text('Search for a song above',
            style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isRecent && list.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Recently Used',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: Colors.grey),
            ),
          ),
        Expanded(
          child: ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final song = list[i];
              return ListTile(
                leading: const Icon(Icons.library_music_outlined),
                title: Text(song.title),
                subtitle: song.author.isNotEmpty ? Text(song.author) : null,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _selectSong(song),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLyricsView() {
    final song = _selectedSong!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        ListTile(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _clearSelection,
          ),
          title: Text(song.title,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: song.author.isNotEmpty ? Text(song.author) : null,
        ),
        const Divider(height: 1),
        // Slides
        Expanded(
          child: _loadingLyrics
              ? const Center(child: CircularProgressIndicator())
              : _selectedLyrics == null
                  ? const Center(child: Text('No lyrics found'))
                  : _buildSlidesList(_selectedLyrics!),
        ),
      ],
    );
  }

  Widget _buildSlidesList(SongLyrics lyrics) {
    if (lyrics.sections.isEmpty) {
      return const Center(child: Text('No slides available'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: lyrics.sections.length,
      itemBuilder: (context, i) {
        final section = lyrics.sections[i];
        return _SlideCard(
          section: section,
          onPush: () => widget.onSlidePush(section.toSlideText()),
        );
      },
    );
  }
}

class _SlideCard extends StatelessWidget {
  final SongSection section;
  final VoidCallback onPush;

  const _SlideCard({required this.section, required this.onPush});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPush,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      section.label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                    ),
                  ),
                  Tooltip(
                    message: 'Push to screen',
                    child: Icon(
                      Icons.present_to_all,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                section.toSlideText(),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
