import 'dart:convert';

class AgentInfo {
  final String scheme; // http | https
  final String host;
  final int port;
  final String token;

  static const defaultPort = 7842;

  const AgentInfo({
    required this.host,
    required this.port,
    this.token = '',
    this.scheme = 'http',
  });

  String get baseUrl {
    // Bare IPv6 literals need brackets inside a URL.
    final h = host.contains(':') && !host.startsWith('[') ? '[$host]' : host;
    return '$scheme://$h:$port';
  }

  /// Human-readable host:port without the token.
  String get label => '$host:$port';

  AgentInfo copyWith({String? token, String? scheme, String? host, int? port}) =>
      AgentInfo(
        host: host ?? this.host,
        port: port ?? this.port,
        token: token ?? this.token,
        scheme: scheme ?? this.scheme,
      );

  /// Build from what a user typed. Accepts a bare host or IP, `host:port`,
  /// or a full `http://` / `https://` URL (so a TLS-terminating proxy or
  /// Tailscale Serve can front the agent). [portText] is the separate port
  /// field; a port embedded in the host text wins over it. Returns null
  /// when there is no usable host.
  static AgentInfo? fromUserInput(String hostText, String portText, {String token = ''}) {
    var text = hostText.trim();
    if (text.isEmpty) return null;
    var scheme = 'http';
    int? port = int.tryParse(portText.trim());

    if (text.contains('://')) {
      final uri = Uri.tryParse(text);
      if (uri == null || uri.host.isEmpty) return null;
      if (uri.scheme != 'http' && uri.scheme != 'https') return null;
      scheme = uri.scheme;
      text = uri.host;
      if (uri.hasPort) {
        port = uri.port;
      } else if (port == null || port == defaultPort) {
        // A URL without an explicit port means the scheme's default port.
        port = scheme == 'https' ? 443 : 80;
      }
    } else {
      // host:port with a single colon (IPv6 literals have several; leave those alone).
      final colons = ':'.allMatches(text).length;
      if (colons == 1) {
        final idx = text.indexOf(':');
        final p = int.tryParse(text.substring(idx + 1));
        if (p != null) {
          port = p;
          text = text.substring(0, idx);
        }
      }
      text = text.replaceAll(RegExp(r'^\[|\]$'), '');
    }
    final finalPort = port ?? defaultPort;
    if (finalPort < 1 || finalPort > 65535) return null;
    return AgentInfo(host: text, port: finalPort, token: token, scheme: scheme);
  }

  /// Parse the stored form. [token] is supplied by the caller because it is
  /// kept in secure storage, not alongside host and port.
  factory AgentInfo.fromPrefs(String stored, {String token = ''}) {
    try {
      final j = jsonDecode(stored) as Map<String, dynamic>;
      return AgentInfo(
        host: j['host'] as String,
        port: j['port'] as int,
        // Legacy records carried the token inline; PrefsService migrates it out.
        token: token.isNotEmpty ? token : ((j['token'] as String?) ?? ''),
        scheme: (j['scheme'] as String?) ?? 'http',
      );
    } catch (_) {
      // Legacy "host:port" format — use lastIndexOf to handle IPv6 addresses.
      final idx = stored.lastIndexOf(':');
      if (idx < 0) return AgentInfo(host: stored, port: defaultPort, token: token);
      return AgentInfo(
        host: stored.substring(0, idx),
        port: int.tryParse(stored.substring(idx + 1)) ?? defaultPort,
        token: token,
      );
    }
  }

  /// Stored form: never includes the token.
  String toPrefsString() =>
      jsonEncode({'scheme': scheme, 'host': host, 'port': port});
}

class Library {
  final String name;
  final String path;

  const Library({required this.name, required this.path});

  factory Library.fromJson(Map<String, dynamic> j) =>
      Library(name: j['name'] as String, path: j['path'] as String);
}

class DirEntry {
  final String name;
  final String path;
  final String type; // folder | video | audio | photo | other
  final int? size;
  final double mtime;

  const DirEntry({
    required this.name,
    required this.path,
    required this.type,
    this.size,
    required this.mtime,
  });

  bool get isFolder => type == 'folder';
  bool get isMedia => type == 'video' || type == 'audio' || type == 'photo';

  factory DirEntry.fromJson(Map<String, dynamic> j) => DirEntry(
        name: j['name'] as String,
        path: j['path'] as String,
        type: j['type'] as String,
        size: j['size'] as int?,
        mtime: (j['mtime'] as num).toDouble(),
      );
}

class MediaMetadata {
  final String path;
  final String name;
  final int size;
  final double mtime;
  final String type;
  final double? duration;
  final String? codec;

  const MediaMetadata({
    required this.path,
    required this.name,
    required this.size,
    required this.mtime,
    required this.type,
    this.duration,
    this.codec,
  });

  factory MediaMetadata.fromJson(Map<String, dynamic> j) => MediaMetadata(
        path: j['path'] as String,
        name: j['name'] as String,
        size: j['size'] as int,
        mtime: (j['mtime'] as num).toDouble(),
        type: j['type'] as String,
        duration: j['duration'] != null ? (j['duration'] as num).toDouble() : null,
        codec: j['codec'] as String?,
      );
}
