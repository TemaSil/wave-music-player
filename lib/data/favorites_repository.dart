import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'track.dart';

/// Locally persisted "liked" tracks, newest first.
class FavoritesRepository extends ChangeNotifier {
  static const _key = 'wave.favorites.v1';

  final List<Track> _tracks = [];
  final Set<String> _uids = {};
  SharedPreferences? _prefs;

  List<Track> get tracks => List.unmodifiable(_tracks);
  int get length => _tracks.length;
  bool contains(Track track) => _uids.contains(track.uid);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs?.getStringList(_key) ?? const [];
    _tracks
      ..clear()
      ..addAll(
        raw.map((e) {
          try {
            return Track.fromJson(jsonDecode(e) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        }).whereType<Track>(),
      );
    _uids
      ..clear()
      ..addAll(_tracks.map((t) => t.uid));
    notifyListeners();
  }

  /// Returns true when the track ended up liked.
  bool toggle(Track track) {
    final liked = !_uids.contains(track.uid);
    if (liked) {
      _tracks.insert(0, track);
      _uids.add(track.uid);
    } else {
      _tracks.removeWhere((t) => t.uid == track.uid);
      _uids.remove(track.uid);
    }
    notifyListeners();
    unawaited(_persist());
    return liked;
  }

  Future<void> _persist() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setStringList(
      _key,
      _tracks.map((t) => jsonEncode(t.toJson())).toList(),
    );
  }
}
