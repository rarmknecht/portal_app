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
  final _tokenController = TextEditingController();

  List<AgentInfo> _found = [];
  bool _scanning = false;
  bool _connecting = false;
  String? _connectError;

  @override
  void initState() {
    super.initState();
    // Fire-and-forget — UI renders immediately regardless of outcome.
    _tryResumeLastAgent();
    _startScan();
  }

  Future<void> _tryResumeLastAgent() async {
    final saved = widget.prefs.savedAgent;
    if (saved == null) return;
    try {
      final ok = await AgentClient(saved.baseUrl, token: saved.token)
          .health()
          .timeout(const Duration(seconds: 3));
      if (ok && mounted) _navigate(saved);
    } catch (_) {
      // Saved agent unreachable — stay on discovery screen.
    }
  }

  Future<void> _startScan() async {
    if (!mounted) return;
    setState(() => _scanning = true);
    try {
      await _discovery
          .start((agents) {
            if (mounted) setState(() => _found = agents);
          })
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // mDNS unavailable or timed out — manual entry still works.
    }
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _connectManual() async {
    final agent = AgentInfo.fromUserInput(
      _hostController.text,
      _portController.text,
      token: _tokenController.text.trim(),
    );
    if (agent == null) {
      setState(() => _connectError = 'Enter a host, IP address, or http(s):// URL.');
      return;
    }
    setState(() { _connecting = true; _connectError = null; });
    try {
      final ok = await AgentClient(agent.baseUrl, token: agent.token)
          .health()
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      if (ok) {
        await widget.prefs.saveAgent(agent);
        _navigate(agent);
      } else {
        setState(() => _connectError = 'Agent responded but reported an error.');
      }
    } catch (_) {
      if (mounted) setState(() => _connectError = 'Could not reach ${agent.label} — is the agent running?');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<AgentInfo?> _promptToken(AgentInfo base) async {
    final ctrl = TextEditingController();
    final result = await showDialog<AgentInfo>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(base.host),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter the server token, or leave blank if not set.'),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Token (optional)',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => Navigator.pop(
                ctx,
                base.copyWith(token: ctrl.text.trim()),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              base.copyWith(token: ctrl.text.trim()),
            ),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  void _navigate(AgentInfo agent) {
    _discovery.stop();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LibraryListScreen(
          client: AgentClient(agent.baseUrl, token: agent.token),
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
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Portal'),
        actions: [
          if (_scanning)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Found via mDNS ──────────────────────────────────────
          if (_found.isNotEmpty) ...[
            _sectionLabel('Found on network'),
            const SizedBox(height: 8),
            ..._found.map((a) => Card(
              child: ListTile(
                leading: const Icon(Icons.dns),
                title: Text(a.host),
                subtitle: Text('Port ${a.port}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final agent = await _promptToken(a);
                  if (agent == null || !mounted) return;
                  await widget.prefs.saveAgent(agent);
                  if (mounted) _navigate(agent);
                },
              ),
            )),
            const SizedBox(height: 24),
          ],

          // ── Manual entry ────────────────────────────────────────
          _sectionLabel('Connect manually'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _hostController,
                decoration: const InputDecoration(
                  labelText: 'Host, IP, or https:// URL',
                  hintText: '192.168.1.100',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _connectManual(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 90,
              child: TextField(
                controller: _portController,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _connectManual(),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: _tokenController,
            decoration: const InputDecoration(
              labelText: 'Token (optional)',
              hintText: 'Leave blank if server has no token set',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _connectManual(),
          ),

          if (_connectError != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _connectError!,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ],

          const SizedBox(height: 16),
          FilledButton(
            onPressed: _connecting ? null : _connectManual,
            child: _connecting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Connect'),
          ),

          const SizedBox(height: 32),
          Text(
            _scanning
                ? 'Scanning for Portal agents on your network…'
                : _found.isEmpty
                    ? 'No agents found via mDNS. Enter the host above.'
                    : '${_found.length} agent${_found.length == 1 ? '' : 's'} found.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      );
}
