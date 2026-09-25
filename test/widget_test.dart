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

  group('PrefsService token storage', () {
    test('token is stored in the token store, never in prefs', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = InMemoryTokenStore();
      final svc = await PrefsService.create(prefs: prefs, tokenStore: store);

      await svc.saveAgent(const AgentInfo(host: 'h', port: 1, token: 'secret'));

      expect(prefs.getString('agent_address'), isNot(contains('secret')));
      expect(await store.read(), 'secret');
      expect(svc.savedAgent?.token, 'secret');

      await svc.clearAgent();
      expect(await store.read(), isNull);
      expect(svc.savedAgent, isNull);
    });

    test('legacy inline token is migrated out of prefs', () async {
      SharedPreferences.setMockInitialValues({
        'agent_address': '{"host":"h","port":7842,"token":"legacy"}',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = InMemoryTokenStore();
      final svc = await PrefsService.create(prefs: prefs, tokenStore: store);

      expect(await store.read(), 'legacy');
      expect(prefs.getString('agent_address'), isNot(contains('legacy')));
      expect(svc.savedAgent?.token, 'legacy');
      expect(svc.savedAgent?.baseUrl, 'http://h:7842');
    });
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
