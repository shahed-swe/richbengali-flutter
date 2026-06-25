# RichBengali Flutter — Setup Checklist

This document lists every **manual step** that cannot be automated in code.
The Flutter/Dart code (Phases 1-8) is complete and compiles.

---

## 1. Fill in `.env`

Create (or edit) `richb-flutter/.env`:

```
EXPO_PUBLIC_API_BASE=https://your-api-base-url
EXPO_PUBLIC_AGORA_APP_ID=your-agora-app-id
```

Without these two values the app boots but API calls and video/audio calls fail.

---

## 2. Android — Enable Firebase (google-services)

### 2a. Drop in `google-services.json`

Place your Firebase project's `google-services.json` at:

```
android/app/google-services.json
```

### 2b. Apply the google-services Gradle plugin

**`android/build.gradle.kts`** — add the classpath:

```kotlin
buildscript {
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")   // ← add this
    }
}
```

**`android/app/build.gradle.kts`** — apply the plugin (at the top, after the Flutter plugin):

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")   // ← add this
}
```

Then run:

```bash
flutter clean && flutter pub get && flutter build apk --debug
```

---

## 3. iOS — Full setup on Mac

All steps below must be done on a Mac with Xcode installed.

### 3a. Drop in `GoogleService-Info.plist`

1. In Xcode, open `ios/Runner.xcworkspace`.
2. Drag `GoogleService-Info.plist` (from Firebase console) into the **Runner** group
   (make sure "Add to targets: Runner" is checked).

### 3b. Enable Capabilities in Xcode

Select **Runner** target → **Signing & Capabilities** → `+` Capability:

| Capability | Required for |
|---|---|
| Push Notifications | FCM + APNs |
| Background Modes | Check: **Voice over IP**, **Audio, AirPlay, and Picture in Picture**, **Remote notifications** |

### 3c. APNs / VoIP certificates

In the **Apple Developer portal** (`developer.apple.com`):

1. Create an **APNs Auth Key** (`.p8`) for `com.richbengali.app` and upload it in
   Firebase console → Project Settings → Cloud Messaging → iOS app.
2. Create a **VoIP Services Certificate** for `com.richbengali.app`.
   Download and import into your Mac's Keychain, then upload in your push-server config.

### 3d. Set signing team

In Xcode → Runner target → **Signing & Capabilities**:
- Set **Team** to your Apple Developer account.
- Xcode will auto-manage provisioning profiles if "Automatically manage signing" is ticked.

### 3e. pod install

```bash
cd ios
pod install
cd ..
```

> Re-run `pod install` whenever you add or remove Flutter packages.

### 3f. Build and test on device

```bash
flutter run            # picks up the connected iPhone
# or open ios/Runner.xcworkspace in Xcode and hit ▶
```

---

## 4. Sentry

Sentry is already wired in `lib/main.dart` with the project DSN.
No additional setup is needed unless you want environment tagging:

```dart
options.environment = kReleaseMode ? 'production' : 'development';
```

---

## 5. Deep links — quick test

### Android

```bash
adb shell am start \
  -W -a android.intent.action.VIEW \
  -d "richbengali://payout?status=success" \
  com.richbengali.app
```

### iOS (Simulator)

```bash
xcrun simctl openurl booted "richbengali://payout?status=success"
```

---

## 6. Running the app

```bash
# Android
flutter run -d <android-device-id>

# iOS (must be on a Mac with Xcode)
flutter run -d <ios-device-id>

# Release APK (Android)
flutter build apk --release

# Release IPA (iOS — Mac only)
flutter build ipa --release
```

---

## 7. Remaining TODOs (nice-to-have)

- Add a `CallKitLogo` image asset (40×40 PDF/PNG) in `ios/Runner/Assets.xcassets`
  for the CallKit native UI app-icon mask.
- Consider raising `tracesSampleRate` in Sentry to `1.0` in staging and `0.2` in
  production (already `0.2` in code).
- After Firebase is wired, remove the `try/catch` guards around
  `FirebaseMessaging.onBackgroundMessage` in `lib/main.dart` (or keep them — they
  are harmless).
