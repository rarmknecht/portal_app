class AgentInfo {
  final String host;
  final int port;

  const AgentInfo({required this.host, required this.port});

  String get baseUrl => 'http://$host:$port';

  factory AgentInfo.fromPrefs(String stored) {
    final parts = stored.split(':');
    return AgentInfo(host: parts[0], port: int.parse(parts[1]));
  }

  String toPrefsString() => '$host:$port';
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
