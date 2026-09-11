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
  static const _vinylKey = 'wave.appearance.vinyl.v1';
  static const _visualizerKey = 'wave.appearance.visualizer.v1';
  static const _automixKey = 'wave.playback.automix.v1';

  SharedPreferences? _prefs;

  WaveSkin _skin = WaveSkin.appleMusic;
  bool _ambientMotion = true;
  bool _showVinyl = false;
  bool _showVisualizer = false;
  bool _automix = false;

  WaveSkin get skin => _skin;

  /// Whether the background keeps drifting. Independent of [skin] so the
  /// aurora can be held still — it is the one thing on screen that never stops
  /// moving, and that is not for everyone.
  bool get ambientMotion => _ambientMotion;

  /// Spins a record out from behind the cover on Now Playing. Off by default,
  /// because Apple Music has no such thing and the point of the default skin is
  /// to match it.
  bool get showVinyl => _showVinyl;

  /// Draws the synthesised bar visualiser under the title on Now Playing. Off
  /// for the same reason as [showVinyl].
  bool get showVisualizer => _showVisualizer;

  /// Fades one track into the next instead of cutting between them.
  bool get automix => _automix;

  /// True when the artwork should drive the palette of the whole interface.
  bool get usesLiveColour => _skin == WaveSkin.aurora;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _skin = WaveSkin.fromKey(_prefs?.getString(_skinKey));
    _ambientMotion = _prefs?.getBool(_motionKey) ?? true;
    _showVinyl = _prefs?.getBool(_vinylKey) ?? false;
    _showVisualizer = _prefs?.getBool(_visualizerKey) ?? false;
    _automix = _prefs?.getBool(_automixKey) ?? false;
    notifyListeners();
  }

  Future<void> setSkin(WaveSkin skin) async {
    if (_skin == skin) return;
    _skin = skin;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_skinKey, skin.key);
  }

  Future<void> setAmbientMotion(bool value) =>
      _setFlag(_motionKey, value, (v) => _ambientMotion = v, _ambientMotion);

  Future<void> setShowVinyl(bool value) =>
      _setFlag(_vinylKey, value, (v) => _showVinyl = v, _showVinyl);

  Future<void> setShowVisualizer(bool value) => _setFlag(
    _visualizerKey,
    value,
    (v) => _showVisualizer = v,
    _showVisualizer,
  );

  Future<void> setAutomix(bool value) =>
      _setFlag(_automixKey, value, (v) => _automix = v, _automix);

  Future<void> _setFlag(
    String key,
    bool value,
    void Function(bool) assign,
    bool current,
  ) async {
    if (current == value) return;
    assign(value);
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(key, value);
  }
}
