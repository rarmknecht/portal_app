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
  late Future<List<DirEntry>> _entries;
  String _sortOrder = 'name';

  @override
  void initState() {
    super.initState();
    _sortOrder = widget.prefs.sortOrder;
    _entries = _load();
  }

  Future<List<DirEntry>> _load() async {
    final entries = await widget.client.browse(widget.path);
    return _sort(entries);
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
      _entries = _load();
    });
  }

  void _open(DirEntry entry) {
    if (entry.isFolder) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BrowseScreen(
            client: widget.client,
            prefs: widget.prefs,
            path: entry.path,
            title: entry.name,
          ),
        ),
      );
      return;
    }
    switch (entry.type) {
      case 'video':
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(
            url: widget.client.streamUrl(entry.path),
            title: entry.name,
          ),
        ));
      case 'audio':
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => AudioPlayerScreen(
            url: widget.client.streamUrl(entry.path),
            title: entry.name,
          ),
        ));
      case 'photo':
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => PhotoViewerScreen(
            url: widget.client.streamUrl(entry.path),
            title: entry.name,
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
      body: FutureBuilder<List<DirEntry>>(
        future: _entries,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text('${snap.error}'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => setState(() => _entries = _load()),
                  child: const Text('Retry'),
                ),
              ]),
            );
          }
          final entries = snap.data!;
          if (entries.isEmpty) {
            return const Center(child: Text('Empty folder'));
          }
          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final e = entries[i];
              return MediaTile(
                entry: e,
                thumbnailUrl: e.isMedia ? widget.client.thumbnailUrl(e.path) : null,
                onTap: () => _open(e),
              );
            },
          );
        },
      ),
    );
  }
}
