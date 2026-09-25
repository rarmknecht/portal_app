import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:portal_app/api/models.dart';
import 'package:portal_app/main.dart';
import 'package:portal_app/services/prefs_service.dart';

void main() {
  group('AgentInfo.fromUserInput', () {
    test('bare host uses the port field', () {
      final a = AgentInfo.fromUserInput('192.168.1.10', '7842')!;
      expect(a.scheme, 'http');
      expect(a.host, '192.168.1.10');
      expect(a.port, 7842);
      expect(a.baseUrl, 'http://192.168.1.10:7842');
    });

    test('host:port overrides the port field', () {
      final a = AgentInfo.fromUserInput('redbeast.local:9000', '7842')!;
      expect(a.host, 'redbeast.local');
      expect(a.port, 9000);
    });

    test('https URL keeps its scheme and default port', () {
      final a = AgentInfo.fromUserInput('https://portal.example.ts.net', '7842')!;
      expect(a.scheme, 'https');
      expect(a.port, 443);
      expect(a.baseUrl, 'https://portal.example.ts.net:443');
    });

    test('URL with explicit port', () {
      final a = AgentInfo.fromUserInput('http://10.0.0.5:7842/', '1')!;
      expect(a.port, 7842);
    });

    test('IPv6 literal is bracketed in the URL', () {
      final a = AgentInfo.fromUserInput('fd00::1', '7842')!;
      expect(a.baseUrl, 'http://[fd00::1]:7842');
    });

    test('rejects empty input and unsupported schemes', () {
      expect(AgentInfo.fromUserInput('', '7842'), isNull);
      expect(AgentInfo.fromUserInput('ftp://x', '7842'), isNull);
    });
  });

  group('PrefsService connections', () {
    Future<(PrefsService, SharedPreferences, InMemoryTokenStore)> make(
        [Map<String, Object> initial = const {}, InMemoryTokenStore? store]) async {
      SharedPreferences.setMockInitialValues(initial);
      final prefs = await SharedPreferences.getInstance();
      final s = store ?? InMemoryTokenStore();
      return (await PrefsService.create(prefs: prefs, tokenStore: s), prefs, s);
    }

    test('token is stored in the token store, never in prefs', () async {
      final (svc, prefs, store) = await make();
      await svc.saveConnection(const AgentInfo(host: 'h', port: 1, token: 'secret'));

      expect(prefs.getString('connections'), isNot(contains('secret')));
      expect(await store.read('token:http://h:1'), 'secret');
      expect(svc.lastConnection?.token, 'secret');
    });

    test('saving the same host again updates the tile and moves it first', () async {
      final (svc, _, _) = await make();
      await svc.saveConnection(const AgentInfo(host: 'a', port: 1, token: 't1'));
      await svc.saveConnection(const AgentInfo(host: 'b', port: 1));
      await svc.saveConnection(const AgentInfo(host: 'a', port: 1, token: 't2'));

      expect(svc.connections.map((c) => c.host), ['a', 'b']);
      expect(svc.connections.first.token, 't2');
      expect(svc.lastConnection?.host, 'a');
    });

    test('disconnect keeps the tile but stops auto-resume', () async {
      final (svc, _, _) = await make();
      await svc.saveConnection(const AgentInfo(host: 'a', port: 1));
      await svc.clearLastConnection();
      expect(svc.connections, hasLength(1));
      expect(svc.lastConnection, isNull);
    });

    test('forgetting a connection removes its token', () async {
      final (svc, _, store) = await make();
      final a = const AgentInfo(host: 'a', port: 1, token: 'x');
      await svc.saveConnection(a);
      await svc.removeConnection(a);
      expect(svc.connections, isEmpty);
      expect(svc.lastConnection, isNull);
      expect(await store.read('token:http://a:1'), isNull);
    });

    test('connections survive a restart with their tokens', () async {
      final store = InMemoryTokenStore();
      final (svc, prefs, _) = await make({}, store);
      await svc.saveConnection(const AgentInfo(host: 'a', port: 1, token: 'x', scheme: 'https'));

      final again = await PrefsService.create(prefs: prefs, tokenStore: store);
      expect(again.connections.single.token, 'x');
      expect(again.connections.single.scheme, 'https');
      expect(again.lastConnection?.id, 'https://a:1');
    });

    test('legacy inline token is migrated into a saved connection', () async {
      final (svc, prefs, store) = await make({
        'agent_address': '{"host":"h","port":7842,"token":"legacy"}',
      });
      expect(svc.connections.single.baseUrl, 'http://h:7842');
      expect(svc.lastConnection?.token, 'legacy');
      expect(await store.read('token:http://h:7842'), 'legacy');
      expect(prefs.getString('agent_address'), isNull);
      expect(prefs.getString('connections'), isNot(contains('legacy')));
    });

    test('previous single-connection layout is migrated', () async {
      final store = InMemoryTokenStore();
      await store.write('agent_token', 'prev');
      final (svc, _, _) = await make({
        'agent_address': '{"scheme":"http","host":"h","port":7842}',
      }, store);
      expect(svc.lastConnection?.token, 'prev');
      expect(await store.read('agent_token'), isNull);
    });
  });

  testWidgets('saved connections render as tiles', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final svc = await PrefsService.create(prefs: prefs, tokenStore: InMemoryTokenStore());
    await svc.saveConnection(const AgentInfo(host: 'redbeast', port: 7842, token: 't'));
    await svc.clearLastConnection();

    await tester.pumpWidget(PortalApp(prefs: svc));
    await tester.pump();

    expect(find.text('Saved connections'), findsOneWidget);
    expect(find.text('redbeast'), findsOneWidget);
    expect(find.textContaining('token saved'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('app boots to the discovery screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final svc = await PrefsService.create(prefs: prefs, tokenStore: InMemoryTokenStore());

    await tester.pumpWidget(PortalApp(prefs: svc));
    await tester.pump();

    expect(find.text('Connect manually'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Connect'), findsOneWidget);

    // Let the 5 s discovery timeout fire so no timer is left pending.
    await tester.pump(const Duration(seconds: 6));
  });
}
