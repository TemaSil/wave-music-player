import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The two looks the app can wear.
enum WaveSkin {
  /// Faithful Apple Music: pure black, Music red, glass reserved for chrome.
  appleMusic('apple_music', 'Apple Music', 'Чёрный фон, красный акцент'),

  /// Wave's own look: the drifting aurora field, tinted by the artwork of
  /// whatever is playing.
  aurora('aurora', 'Живые цвета', 'Фон и акценты берутся из обложки');

  const WaveSkin(this.key, this.label, this.description);

  final String key;
  final String label;
  final String description;

  static WaveSkin fromKey(String? key) =>
      values.firstWhere((s) => s.key == key, orElse: () => appleMusic);
}

/// User-visible appearance settings, persisted on the device.
class AppearanceController extends ChangeNotifier {
  static const _skinKey = 'wave.appearance.skin.v1';
  static const _motionKey = 'wave.appearance.motion.v1';

  SharedPreferences? _prefs;

  WaveSkin _skin = WaveSkin.appleMusic;
  bool _ambientMotion = true;

  WaveSkin get skin => _skin;

  /// Whether the background keeps drifting. Independent of [skin] so the
  /// aurora can be held still — it is the one thing on screen that never stops
  /// moving, and that is not for everyone.
  bool get ambientMotion => _ambientMotion;

  /// True when the artwork should drive the palette of the whole interface.
  bool get usesLiveColour => _skin == WaveSkin.aurora;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _skin = WaveSkin.fromKey(_prefs?.getString(_skinKey));
    _ambientMotion = _prefs?.getBool(_motionKey) ?? true;
    notifyListeners();
  }

  Future<void> setSkin(WaveSkin skin) async {
    if (_skin == skin) return;
    _skin = skin;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_skinKey, skin.key);
  }

  Future<void> setAmbientMotion(bool value) async {
    if (_ambientMotion == value) return;
    _ambientMotion = value;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(_motionKey, value);
  }
}
