import 'package:flutter/material.dart';
import '../api/agent_client.dart';
import '../api/models.dart';
import '../services/prefs_service.dart';
import 'browse_screen.dart';
import 'discovery_screen.dart';

class LibraryListScreen extends StatefulWidget {
  final AgentClient client;
  final PrefsService prefs;
  final AgentInfo agentInfo;

  const LibraryListScreen({
    super.key,
    required this.client,
    required this.prefs,
    required this.agentInfo,
  });

  @override
  State<LibraryListScreen> createState() => _LibraryListScreenState();
}

class _LibraryListScreenState extends State<LibraryListScreen> {
  late Future<List<Library>> _libraries;

  @override
  void initState() {
    super.initState();
    _libraries = widget.client.libraries();
  }

  void _disconnect() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => DiscoveryScreen(prefs: widget.prefs)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Libraries — ${widget.agentInfo.host}'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Disconnect', onPressed: _disconnect),
        ],
      ),
      body: FutureBuilder<List<Library>>(
        future: _libraries,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off, size: 48),
                  const SizedBox(height: 16),
                  Text('Could not reach agent', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('${snap.error}', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => setState(() => _libraries = widget.client.libraries()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          final libs = snap.data!;
          if (libs.isEmpty) {
            return const Center(child: Text('No libraries configured on agent.'));
          }
          return ListView.builder(
            itemCount: libs.length,
            itemBuilder: (context, i) {
              final lib = libs[i];
              return ListTile(
                leading: const Icon(Icons.folder_open, size: 36),
                title: Text(lib.name),
                subtitle: Text(lib.path, style: Theme.of(context).textTheme.bodySmall),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  widget.prefs.saveLastLibrary(lib.path);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BrowseScreen(
                        client: widget.client,
                        prefs: widget.prefs,
                        path: lib.path,
                        title: lib.name,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
