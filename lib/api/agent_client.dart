import 'package:dio/dio.dart';
import 'models.dart';

class AgentClient {
  final String baseUrl;
  final String token;
  final Dio _dio;

  AgentClient(this.baseUrl, {this.token = ''})
      : _dio = _buildDio(baseUrl, token);

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

  Future<List<DirEntry>> search(String library, String query) async {
    final res = await _dio.get('/search', queryParameters: {'library': library, 'q': query});
    final list = res.data['results'] as List;
    return list.map((e) => DirEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  String thumbnailUrl(String path, {int size = 320}) =>
      '$baseUrl/api/v1/thumbnail?path=${Uri.encodeQueryComponent(path)}&size=$size';

  String streamUrl(String path) =>
      '$baseUrl/api/v1/stream?path=${Uri.encodeQueryComponent(path)}';
}
