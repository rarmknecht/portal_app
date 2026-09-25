import 'package:dio/dio.dart';
import 'models.dart';

class AgentClient {
  final String baseUrl;
  final String token;
  final Dio _dio;

  /// [dio] is injectable for tests; production builds its own.
  AgentClient(this.baseUrl, {this.token = '', Dio? dio})
      : _dio = dio ?? _buildDio(baseUrl, token);

  /// Headers every request must carry. Media players and image loaders are
  /// handed bare URLs plus these headers, so the token never appears in a
  /// URL — URLs end up in the media session, on-disk image caches, and
  /// player error messages; headers do not.
  Map<String, String> get authHeaders =>
      token.isEmpty ? const {} : {'Authorization': 'Bearer $token'};

  static Dio _buildDio(String baseUrl, String token) {
    final dio = Dio(BaseOptions(
      baseUrl: '$baseUrl/api/v1',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 30),
    ));
    if (token.isNotEmpty) {
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
      ));
    }
    return dio;
  }

  Future<bool> health() async {
    try {
      final res = await _dio.get('/health');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<Library>> libraries() async {
    final res = await _dio.get('/libraries');
    final list = res.data['libraries'] as List;
    return list.map((e) => Library.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<DirEntry>> browse(String path) async {
    final res = await _dio.get('/browse', queryParameters: {'path': path});
    final list = res.data['entries'] as List;
    return list.map((e) => DirEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<MediaMetadata> metadata(String path) async {
    final res = await _dio.get('/metadata', queryParameters: {'path': path});
    return MediaMetadata.fromJson(res.data as Map<String, dynamic>);
  }

  /// Re-derive a path token from a trail of names: the library name
  /// followed by each folder name. Path tokens are minted per server
  /// process, so after a restart every token the app holds is stale (the
  /// server answers 400); the names still identify the same place.
  /// Throws [PathGoneException] if any step no longer exists.
  Future<String> resolvePath(List<String> crumbs) async {
    if (crumbs.isEmpty) throw const PathGoneException('');
    final libs = await libraries();
    final lib = libs.where((l) => l.name == crumbs.first).firstOrNull;
    if (lib == null) throw PathGoneException(crumbs.first);
    var token = lib.path;
    for (final name in crumbs.skip(1)) {
      final entries = await browse(token);
      final next = entries.where((e) => e.isFolder && e.name == name).firstOrNull;
      if (next == null) throw PathGoneException(name);
      token = next.path;
    }
    return token;
  }

  /// True when the server no longer recognises a path token (400 from the
  /// path registry). Distinct from 404, which means the file itself is gone.
  static bool isStaleToken(Object? error) =>
      error is DioException && error.response?.statusCode == 400;

  /// Short, user-facing explanation of a request failure.
  static String describeError(Object? error) {
    if (error is PathGoneException) {
      return error.name.isEmpty
          ? 'This location no longer exists on the server.'
          : '"${error.name}" no longer exists on the server.';
    }
    if (error is DioException) {
      switch (error.response?.statusCode) {
        case 401:
          return 'The server rejected the token (401).';
        case 429:
          final wait = error.response?.headers.value('retry-after');
          return 'Too many failed attempts; the server is throttling this phone. '
              'Wait ${wait != null ? '$wait seconds' : 'a minute'} and try again.';
        case 400:
          return 'The server no longer recognises this location. Reconnect and try again.';
        case 404:
          return 'Not found on the server.';
        case 415:
          return 'The server will not stream this file type.';
        case null:
          return 'Could not reach the agent — is it running?';
        default:
          return 'Server error (${error.response!.statusCode}).';
      }
    }
    return '$error';
  }

  String thumbnailUrl(String path, {int size = 320}) =>
      '$baseUrl/api/v1/thumbnail?path=${Uri.encodeQueryComponent(path)}&size=$size';

  String streamUrl(String path) =>
      '$baseUrl/api/v1/stream?path=${Uri.encodeQueryComponent(path)}';
}
