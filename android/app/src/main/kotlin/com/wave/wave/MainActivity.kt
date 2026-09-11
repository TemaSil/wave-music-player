package com.wave.wave

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity

/**
 * AudioServiceActivity rather than FlutterActivity: the media session needs the
 * activity to survive being launched from the notification and the lock screen,
 * which is what this subclass arranges.
 */
class MainActivity : AudioServiceActivity() {
    private companion object {
        const val NOTIFICATION_PERMISSION_REQUEST = 1001
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Android 13 hides the media notification — and with it the lock screen
        // controls — unless POST_NOTIFICATIONS has been granted at runtime, and
        // neither audio_service nor just_audio_background asks for it.
        //
        // Asked in Kotlin rather than through a permissions plugin on purpose:
        // the obvious package pulls in an Android library that compiles against
        // SDK 37, which the Gradle plugin this Flutter release ships cannot
        // build. One permission is not worth being blocked on someone else's
        // toolchain.
        //
        // The version check stays inline with the calls it guards, which is the
        // shape lint recognises for APIs above minSdk.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted =
                checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                    PackageManager.PERMISSION_GRANTED
            if (!granted) {
                requestPermissions(
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    NOTIFICATION_PERMISSION_REQUEST,
                )
            }
        }
    }
}
