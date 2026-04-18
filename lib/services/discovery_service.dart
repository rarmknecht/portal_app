import 'package:nsd/nsd.dart';
import '../api/models.dart';

class DiscoveryService {
  Discovery? _discovery;
  final List<AgentInfo> _found = [];

  List<AgentInfo> get results => List.unmodifiable(_found);

  Future<void> start(void Function(List<AgentInfo>) onUpdate) async {
    _found.clear();
    _discovery = await startDiscovery('_portal._tcp');
    _discovery!.addListener(() {
      _found.clear();
      for (final service in _discovery!.services) {
        final host = service.host;
        final port = service.port;
        if (host != null && port != null) {
          _found.add(AgentInfo(host: host, port: port));
        }
      }
      onUpdate(results);
    });
  }

  Future<void> stop() async {
    if (_discovery != null) {
      await stopDiscovery(_discovery!);
      _discovery = null;
    }
  }
}
