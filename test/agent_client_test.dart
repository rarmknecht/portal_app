import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:portal_app/api/agent_client.dart';
import 'package:portal_app/api/models.dart';

/// Canned server: maps "path?query" to (status, json). Records requests.
class _FakeServer implements HttpClientAdapter {
  final Map<String, (int, Object)> routes;
  final List<String> calls = [];
  _FakeServer(this.routes);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? body, Future<void>? cancel) async {
    final key = o.uri.path.replaceFirst('/api/v1', '') +
        (o.uri.query.isEmpty ? '' : '?${o.uri.query}');
    calls.add(key);
    final (status, data) = routes[key] ?? (404, {'detail': 'no route $key'});
    return ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        if (status == 429) 'retry-after': ['60'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

AgentClient _client(_FakeServer server) {
  final dio = Dio(BaseOptions(baseUrl: 'http://x/api/v1'))..httpClientAdapter = server;
  return AgentClient('http://x', dio: dio);
}

Map<String, Object?> _entry(String name, String path, {String type = 'folder'}) =>
    {'name': name, 'path': path, 'type': type, 'size': null, 'mtime': 1.0};

void main() {
  group('resolvePath', () {
    test('walks library then folders by name to a fresh token', () async {
      final server = _FakeServer({
        '/libraries': (200, {'libraries': [{'name': 'Videos', 'path': 'L2'}]}),
        '/browse?path=L2': (200, {'entries': [_entry('2025', 'F2'), _entry('x.mp4', 'V', type: 'video')]}),
        '/browse?path=F2': (200, {'entries': [_entry('trip', 'T2')]}),
      });
      expect(await _client(server).resolvePath(['Videos', '2025', 'trip']), 'T2');
      expect(server.calls, ['/libraries', '/browse?path=L2', '/browse?path=F2']);
    });

    test('library root needs only the libraries call', () async {
      final server = _FakeServer({
        '/libraries': (200, {'libraries': [{'name': 'Music', 'path': 'M2'}]}),
      });
      expect(await _client(server).resolvePath(['Music']), 'M2');
    });

    test('throws PathGoneException naming the missing step', () async {
      final server = _FakeServer({
        '/libraries': (200, {'libraries': [{'name': 'Videos', 'path': 'L2'}]}),
        '/browse?path=L2': (200, {'entries': []}),
      });
      expect(
        () => _client(server).resolvePath(['Videos', 'deleted']),
        throwsA(isA<PathGoneException>().having((e) => e.name, 'name', 'deleted')),
      );
      expect(() => _client(server).resolvePath(['Nope']), throwsA(isA<PathGoneException>()));
    });
  });

  group('error classification', () {
    Future<Object> failure(int status) async {
      final server = _FakeServer({'/libraries': (status, {'detail': 'x'})});
      try {
        await _client(server).libraries();
      } catch (e) {
        return e;
      }
      fail('expected an error');
    }

    test('400 is a stale token, others are not', () async {
      expect(AgentClient.isStaleToken(await failure(400)), isTrue);
      expect(AgentClient.isStaleToken(await failure(404)), isFalse);
      expect(AgentClient.isStaleToken(await failure(401)), isFalse);
      expect(AgentClient.isStaleToken(null), isFalse);
    });

    test('describeError gives a specific message per status', () async {
      expect(AgentClient.describeError(await failure(401)), contains('token'));
      expect(AgentClient.describeError(await failure(429)), contains('60 seconds'));
      expect(AgentClient.describeError(await failure(400)), contains('Reconnect'));
      expect(AgentClient.describeError(await failure(404)), contains('Not found'));
      expect(AgentClient.describeError(const PathGoneException('trip')), contains('"trip"'));
    });
  });
}
