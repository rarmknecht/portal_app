import 'package:flutter/material.dart';
import '../api/agent_client.dart';
import '../api/models.dart';
import '../services/discovery_service.dart';
import '../services/prefs_service.dart';
import 'library_list_screen.dart';

class DiscoveryScreen extends StatefulWidget {
  final PrefsService prefs;

  const DiscoveryScreen({super.key, required this.prefs});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final _discovery = DiscoveryService();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '7842');
  List<AgentInfo> _found = [];
  bool _scanning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tryResumeLastAgent();
    _startScan();
  }

  Future<void> _tryResumeLastAgent() async {
    final saved = widget.prefs.savedAgent;
    if (saved == null) return;
    final ok = await AgentClient(saved.baseUrl).health();
    if (ok && mounted) _navigate(saved);
  }

  Future<void> _startScan() async {
    setState(() => _scanning = true);
    try {
      await _discovery.start((agents) {
        if (mounted) setState(() => _found = agents);
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'mDNS unavailable: $e');
    }
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _connectManual() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 7842;
    if (host.isEmpty) return;
    final agent = AgentInfo(host: host, port: port);
    final ok = await AgentClient(agent.baseUrl).health();
    if (!mounted) return;
    if (ok) {
      await widget.prefs.saveAgent(agent);
      _navigate(agent);
    } else {
      setState(() => _error = 'Could not reach $host:$port');
    }
  }

  void _navigate(AgentInfo agent) {
    _discovery.stop();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LibraryListScreen(
          client: AgentClient(agent.baseUrl),
          prefs: widget.prefs,
          agentInfo: agent,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _discovery.stop();
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Portal'), actions: [
        if (_scanning) const Padding(
          padding: EdgeInsets.all(16),
          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
              ),
            ),

          if (_found.isNotEmpty) ...[
            const Text('Found on network', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._found.map((a) => ListTile(
              leading: const Icon(Icons.dns),
              title: Text(a.host),
              subtitle: Text('Port ${a.port}'),
              onTap: () async {
                await widget.prefs.saveAgent(a);
                _navigate(a);
              },
            )),
            const Divider(height: 32),
          ],

          const Text('Manual entry', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _hostController,
                decoration: const InputDecoration(labelText: 'Host / IP', border: OutlineInputBorder()),
                keyboardType: TextInputType.url,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _portController,
                decoration: const InputDecoration(labelText: 'Port', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          FilledButton(onPressed: _connectManual, child: const Text('Connect')),
        ],
      ),
    );
  }
}
