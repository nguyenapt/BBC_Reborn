import 'dart:async';
import 'package:flutter/material.dart';
import '../models/episode.dart';
import '../services/language_manager.dart';
import '../services/local_database_service.dart';
import '../services/episode_detail_open_helper.dart';
import '../widgets/episode_row.dart';

class EpisodeSearchScreen extends StatefulWidget {
  const EpisodeSearchScreen({super.key});

  @override
  State<EpisodeSearchScreen> createState() => _EpisodeSearchScreenState();
}

class _EpisodeSearchScreenState extends State<EpisodeSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final LocalDatabaseService _db = LocalDatabaseService();
  final LanguageManager _languageManager = LanguageManager();

  Timer? _debounce;
  List<Episode> _results = [];
  bool _isSearching = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final results = await _db.searchEpisodes(trimmed, limit: 100);
      if (!mounted) return;
      setState(() {
        _results = results;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _error = e.toString();
      });
    }
  }

  void _openEpisode(Episode episode) {
    EpisodeDetailOpenHelper.open(
      context: context,
      episode: episode,
      categoryEpisodes: _results,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _languageManager,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_languageManager.getText('searchEpisodes')),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _controller,
                  onChanged: _onQueryChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: _languageManager.getText('searchHint'),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _buildResults(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResults() {
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(_languageManager.getText('searching')),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_controller.text.trim().isEmpty) {
      return Center(
        child: Text(_languageManager.getText('searchEmptyHint')),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Text(_languageManager.getText('noSearchResults')),
      );
    }

    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final episode = _results[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: EpisodeRow(
            episode: episode,
            onTap: () => _openEpisode(episode),
            languageManager: _languageManager,
            isLatest: index == 0,
          ),
        );
      },
    );
  }
}
