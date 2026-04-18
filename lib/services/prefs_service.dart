import 'package:shared_preferences/shared_preferences.dart';
import '../api/models.dart';

const _kAgent = 'agent_address';
const _kLastLibrary = 'last_library';
const _kSortOrder = 'sort_order';

class PrefsService {
  final SharedPreferences _prefs;

  PrefsService(this._prefs);

  static Future<PrefsService> create() async =>
      PrefsService(await SharedPreferences.getInstance());

  AgentInfo? get savedAgent {
    final v = _prefs.getString(_kAgent);
    if (v == null) return null;
    try {
      return AgentInfo.fromPrefs(v);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveAgent(AgentInfo agent) =>
      _prefs.setString(_kAgent, agent.toPrefsString());

  String? get lastLibraryPath => _prefs.getString(_kLastLibrary);
  Future<void> saveLastLibrary(String path) => _prefs.setString(_kLastLibrary, path);

  String get sortOrder => _prefs.getString(_kSortOrder) ?? 'name';
  Future<void> saveSortOrder(String order) => _prefs.setString(_kSortOrder, order);
}
