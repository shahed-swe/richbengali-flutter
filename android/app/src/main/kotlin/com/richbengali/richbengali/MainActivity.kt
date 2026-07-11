package com.richbengali.richbengali

import io.agora.agora_rtc_ng.AgoraPIPFlutterActivity

// Extends Agora's PiP-aware activity so Picture-in-Picture (floating call
// window) works on Android. Requires android:supportsPictureInPicture="true"
// on this activity in AndroidManifest.xml.
class MainActivity : AgoraPIPFlutterActivity()
