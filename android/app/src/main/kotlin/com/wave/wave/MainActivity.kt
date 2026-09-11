package com.wave.wave

import com.ryanheise.audioservice.AudioServiceActivity

/// AudioServiceActivity rather than FlutterActivity: the media session needs
/// the activity to survive being launched from the notification and the lock
/// screen, which is what this subclass arranges.
class MainActivity : AudioServiceActivity()
