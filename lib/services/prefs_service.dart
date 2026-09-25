import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/models.dart';

// Current keys.
const _kConnections = 'connections'; // JSON list of {scheme, host, port}
const _kLast = 'last_connection'; // id of the connection to auto-resume
const _kLastLibrary = 'last_library';
const _kSortOrder = 'sort_order';
const _kViewMode = 'view_mode';
const _kTokenPrefix = 'token:'; // secure store key = prefix + connection id

// Keys from earlier builds, read once and migrated.
const _kLegacyAgent = 'agent_address';
const _kLegacyToken = 'agent_token';

/// Where API tokens live. Kept behind an interface so tests and platforms
/// without a Keystore can substitute an in-memory store.
abstract class TokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Android Keystore-backed storage via flutter_secure_storage.
class SecureTokenStore implements TokenStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(migrateWithBackup: true),
  );

  const SecureTokenStore();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class InMemoryTokenStore implements TokenStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

class PrefsService {
  final SharedPreferences _prefs;
  final TokenStore _tokens;

  /// Saved connections in most-recently-used order, tokens included.
  final List<AgentInfo> _connections;

  PrefsService._(this._prefs, this._tokens, this._connections);

  /// Load preferences and every saved connection's token. Also migrates the
  /// single-connection layout of earlier builds (and, before that, a token
  /// stored inline in SharedPreferences) into the current layout.
  static Future<PrefsService> create({
    SharedPreferences? prefs,
    TokenStore? tokenStore,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final store = tokenStore ?? const SecureTokenStore();

    final connections = <AgentInfo>[];
    final raw = p.getString(_kConnections);
    if (raw != null) {
      try {
        for (final j in jsonDecode(raw) as List) {
          final m = j as Map<String, dynamic>;
          final base = AgentInfo(
            scheme: (m['scheme'] as String?) ?? 'http',
            host: m['host'] as String,
            port: m['port'] as int,
          );
          connections.add(base.copyWith(token: await _readToken(store, base.id)));
        }
      } catch (_) {
        connections.clear();
      }
    }

    final svc = PrefsService._(p, store, connections);
    await svc._migrateLegacy();
    return svc;
  }

  static Future<String> _readToken(TokenStore store, String id) async {
    try {
      return await store.read(_kTokenPrefix + id) ?? '';
    } catch (_) {
      return ''; // Keystore unavailable — behave as if no token were saved.
    }
  }

  Future<void> _migrateLegacy() async {
    final raw = _prefs.getString(_kLegacyAgent);
    if (raw == null) return;

    // Token: the build before this one kept it under a single secure key;
    // the one before that kept it inline in the JSON.
    var token = '';
    try {
      token = await _tokens.read(_kLegacyToken) ?? '';
    } catch (_) {}
    if (token.isEmpty) {
      try {
        token = ((jsonDecode(raw) as Map<String, dynamic>)['token'] as String?) ?? '';
      } catch (_) {}
    }

    AgentInfo agent;
    try {
      agent = AgentInfo.fromPrefs(raw, token: token);
    } catch (_) {
      agent = AgentInfo(host: raw, port: AgentInfo.defaultPort, token: token);
    }
    await saveConnection(agent);

    await _prefs.remove(_kLegacyAgent);
    try {
      await _tokens.delete(_kLegacyToken);
    } catch (_) {}
  }

  // ── Connections ─────────────────────────────────────────────────────

  List<AgentInfo> get connections => List.unmodifiable(_connections);

  /// The connection to try automatically at launch, if any.
  AgentInfo? get lastConnection {
    final id = _prefs.getString(_kLast);
    if (id == null) return null;
    for (final c in _connections) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Upsert [agent] (matched by scheme/host/port), move it to the front,
  /// and mark it as the one to auto-resume.
  Future<void> saveConnection(AgentInfo agent) async {
    _connections.removeWhere((c) => c.id == agent.id);
    _connections.insert(0, agent);
    await _persistConnections();
    await _prefs.setString(_kLast, agent.id);
    if (agent.token.isEmpty) {
      await _tokens.delete(_kTokenPrefix + agent.id);
    } else {
      await _tokens.write(_kTokenPrefix + agent.id, agent.token);
    }
  }

  Future<void> removeConnection(AgentInfo agent) async {
    _connections.removeWhere((c) => c.id == agent.id);
    await _persistConnections();
    if (_prefs.getString(_kLast) == agent.id) await _prefs.remove(_kLast);
    await _tokens.delete(_kTokenPrefix + agent.id);
  }

  /// Stop auto-resuming at launch but keep the saved tile.
  Future<void> clearLastConnection() => _prefs.remove(_kLast);

  Future<void> _persistConnections() => _prefs.setString(
        _kConnections,
        jsonEncode([
          for (final c in _connections) {'scheme': c.scheme, 'host': c.host, 'port': c.port},
        ]),
      );

  // ── Browsing preferences ────────────────────────────────────────────

  String? get lastLibraryPath => _prefs.getString(_kLastLibrary);
  Future<void> saveLastLibrary(String path) => _prefs.setString(_kLastLibrary, path);

  String get sortOrder => _prefs.getString(_kSortOrder) ?? 'name';
  Future<void> saveSortOrder(String order) => _prefs.setString(_kSortOrder, order);

  /// 'list' or 'grid'.
  String get viewMode => _prefs.getString(_kViewMode) ?? 'list';
  Future<void> saveViewMode(String mode) => _prefs.setString(_kViewMode, mode);
}
