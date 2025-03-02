import 'package:shared_preferences/shared_preferences.dart';

class ScratchStorageService {
  static final ScratchStorageService _instance = ScratchStorageService._internal();
  factory ScratchStorageService() => _instance;
  ScratchStorageService._internal();

  static const String _scratchedRegionsKey = 'scratched_regions';
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> saveScratched(String regionId) async {
    if (_prefs == null) await init();
    
    final scratched = _prefs!.getStringList(_scratchedRegionsKey) ?? [];
    if (!scratched.contains(regionId)) {
      scratched.add(regionId);
      await _prefs!.setStringList(_scratchedRegionsKey, scratched);
    }
  }

  List<String> getScratched() {
    return _prefs?.getStringList(_scratchedRegionsKey) ?? [];
  }

  Future<void> clearScratched() async {
    if (_prefs == null) await init();
    await _prefs!.remove(_scratchedRegionsKey);
  }
}
