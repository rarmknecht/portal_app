import 'package:flutter/material.dart';
import '../api/agent_client.dart';
import '../api/models.dart';
import '../services/prefs_service.dart';
import '../widgets/media_tile.dart';
import 'video_player_screen.dart';
import 'audio_player_screen.dart';
import 'photo_viewer_screen.dart';

class BrowseScreen extends StatefulWidget {
  final AgentClient client;
  final PrefsService prefs;
  final String path;
  final String title;

  const BrowseScreen({
    super.key,
    required this.client,
    required this.prefs,
    required this.path,
    required this.title,
  });

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  List<DirEntry> _entries = [];
  bool _loading = true;
  String? _error;
  String _sortOrder = 'name';
  String _viewMode = 'list';

  // All non-folder items in the current view, in display order.
  List<DirEntry> get _mediaItems => _entries.where((e) => e.isMedia).toList();

  @override
  void initState() {
    super.initState();
    _sortOrder = widget.prefs.sortOrder;
    _viewMode = widget.prefs.viewMode;
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final raw = await widget.client.browse(widget.path);
      if (mounted) setState(() { _entries = _sort(raw); _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  List<DirEntry> _sort(List<DirEntry> entries) {
    final folders = entries.where((e) => e.isFolder).toList();
    final files = entries.where((e) => !e.isFolder).toList();
    int compare(DirEntry a, DirEntry b) => switch (_sortOrder) {
      'date' => b.mtime.compareTo(a.mtime),
      'size' => (b.size ?? 0).compareTo(a.size ?? 0),
      _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    };
    folders.sort(compare);
    files.sort(compare);
    return [...folders, ...files];
  }

  void _setSortOrder(String order) {
    widget.prefs.saveSortOrder(order);
    setState(() {
      _sortOrder = order;
      _entries = _sort(_entries);
    });
  }

  void _toggleView() {
    final mode = _viewMode == 'list' ? 'grid' : 'list';
    widget.prefs.saveViewMode(mode);
    setState(() => _viewMode = mode);
  }

  void _open(DirEntry entry) {
    if (entry.isFolder) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => BrowseScreen(
          client: widget.client,
          prefs: widget.prefs,
          path: entry.path,
          title: entry.name,
        ),
      ));
      return;
    }

    final siblings = _mediaItems;
    final index = siblings.indexWhere((e) => e.path == entry.path);

    switch (entry.type) {
      case 'video':
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(
            siblings: siblings,
            initialIndex: index < 0 ? 0 : index,
            streamUrlBuilder: widget.client.streamUrl,
            headers: widget.client.authHeaders,
          ),
        ));
      case 'audio':
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => AudioPlayerScreen(
            url: widget.client.streamUrl(entry.path),
            headers: widget.client.authHeaders,
            mediaId: entry.path,
            title: entry.name,
          ),
        ));
      case 'photo':
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => PhotoViewerScreen(
            siblings: siblings,
            initialIndex: index < 0 ? 0 : index,
            streamUrlBuilder: widget.client.streamUrl,
            headers: widget.client.authHeaders,
          ),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(_viewMode == 'list' ? Icons.grid_view : Icons.view_list),
            tooltip: _viewMode == 'list' ? 'Grid view' : 'List view',
            onPressed: _toggleView,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: _setSortOrder,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'name', child: Text('Sort by name')),
              PopupMenuItem(value: 'date', child: Text('Sort by date')),
              PopupMenuItem(value: 'size', child: Text('Sort by size')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 12),
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: const Text('Retry')),
                ]))
              : _entries.isEmpty
                  ? const Center(child: Text('Empty folder'))
                  : _viewMode == 'grid'
                      ? _grid()
                      : _list(),
    );
  }

  Widget _list() => ListView.builder(
        itemCount: _entries.length,
        itemBuilder: (context, i) {
          final e = _entries[i];
          return MediaTile(
            entry: e,
            thumbnailUrl: e.isMedia ? widget.client.thumbnailUrl(e.path) : null,
            headers: widget.client.authHeaders,
            onTap: () => _open(e),
          );
        },
      );

  Widget _grid() => GridView.builder(
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 140,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: _entries.length,
        itemBuilder: (context, i) {
          final e = _entries[i];
          return MediaGridTile(
            entry: e,
            thumbnailUrl: e.isMedia ? widget.client.thumbnailUrl(e.path) : null,
            headers: widget.client.authHeaders,
            onTap: () => _open(e),
          );
        },
      );
}
