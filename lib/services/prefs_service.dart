import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/models.dart';

const _kAgent = 'agent_address';
const _kLastLibrary = 'last_library';
const _kSortOrder = 'sort_order';
const _kToken = 'agent_token';

/// Where the API token lives. Kept behind an interface so tests and
/// platforms without a Keystore can substitute an in-memory store.
abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

/// Android Keystore-backed storage via flutter_secure_storage.
class SecureTokenStore implements TokenStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(migrateWithBackup: true),
  );

  const SecureTokenStore();

  @override
  Future<String?> read() => _storage.read(key: _kToken);

  @override
  Future<void> write(String token) => _storage.write(key: _kToken, value: token);

  @override
  Future<void> delete() => _storage.delete(key: _kToken);
}

class InMemoryTokenStore implements TokenStore {
  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String token) async => _value = token;

  @override
  Future<void> delete() async => _value = null;
}

class PrefsService {
  final SharedPreferences _prefs;
  final TokenStore _tokens;
  String _token;

  PrefsService._(this._prefs, this._tokens, this._token);

  /// Load preferences and the token. Moves a token that an older build
  /// stored inline in SharedPreferences into the secure store, so it is no
  /// longer sitting in a plain XML file.
  static Future<PrefsService> create({
    SharedPreferences? prefs,
    TokenStore? tokenStore,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final store = tokenStore ?? const SecureTokenStore();
    var token = '';
    try {
      token = await store.read() ?? '';
    } catch (_) {
      // Keystore unavailable — behave as if no token were saved.
    }

    final raw = p.getString(_kAgent);
    if (raw != null) {
      final legacy = _legacyInlineToken(raw);
      if (legacy != null) {
        if (token.isEmpty) {
          token = legacy;
          try {
            await store.write(legacy);
          } catch (_) {}
        }
        // Rewrite without the token even if the secure write failed: a
        // token we cannot protect is better re-entered than left in plain text.
        final agent = AgentInfo.fromPrefs(raw);
        await p.setString(_kAgent, agent.toPrefsString());
      }
    }
    return PrefsService._(p, store, token);
  }

  static String? _legacyInlineToken(String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final t = j['token'] as String?;
      return (t != null && t.isNotEmpty) ? t : null;
    } catch (_) {
      return null;
    }
  }

  AgentInfo? get savedAgent {
    final v = _prefs.getString(_kAgent);
    if (v == null) return null;
    try {
      return AgentInfo.fromPrefs(v, token: _token);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveAgent(AgentInfo agent) async {
    await _prefs.setString(_kAgent, agent.toPrefsString());
    _token = agent.token;
    if (agent.token.isEmpty) {
      await _tokens.delete();
    } else {
      await _tokens.write(agent.token);
    }
  }

  Future<void> clearAgent() async {
    await _prefs.remove(_kAgent);
    _token = '';
    await _tokens.delete();
  }

  String? get lastLibraryPath => _prefs.getString(_kLastLibrary);
  Future<void> saveLastLibrary(String path) => _prefs.setString(_kLastLibrary, path);

  String get sortOrder => _prefs.getString(_kSortOrder) ?? 'name';
  Future<void> saveSortOrder(String order) => _prefs.setString(_kSortOrder, order);
}
