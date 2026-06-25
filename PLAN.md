# RichBengali — Flutter Port Plan

A pixel-faithful Flutter rewrite of the `richb-rn` React Native app (a dating + chat + Agora video-calling app). Same UI, same icons, same backend contract, iOS-compatible.

---

## 0. Source app at a glance

- **RN 0.81 / React 19** bare CLI app, package id `com.richbengali.app`, v2.0.3.
- **UI:** gluestack-ui/themed + gluestack-style + NativeWind (Tailwind v3). Brand pink `#e91d7c`, brand purple `#402e91`. System fonts only (no bundled fonts).
- **Icons:** `lucide-react-native` (the only icon set actually used). ~60 distinct icons.
- **State:** Redux Toolkit (one `auth` slice, persisted) + RTK Query (all server data, tag-based cache) + one Zustand store (`useCallOverlay`, in-call UI + beauty settings).
- **Networking:** RTK Query over `fetchBaseQuery`, JWT `Authorization: Bearer`, global logout on 401.
- **Realtime:** Socket.IO client (chat + call signaling). Custom socket protocol, NOT CometChat (CometChat code is dead).
- **Media:** `react-native-agora` 4.6 (audio/video + beauty filters/virtual background). `react-native-webrtc` is an unused leftover.
- **Calling UX:** CallKeep (CallKit / Android ConnectionService) + iOS VoIP push (PushKit) + FCM + Notifee in-call notifications.
- **Screens:** 13 screen files + 1 global call overlay. 5 bottom tabs (Home, Favorites, Chats, Plans[male-only], Me), each (except Plans) wrapping its own native-stack.
- **Env (NOT in repo — `.env` uncommitted):** `EXPO_PUBLIC_API_BASE`, `EXPO_PUBLIC_AGORA_APP_ID`. Sentry DSN hardcoded.

---

## 1. Technology decisions (Flutter)

| Concern | RN (source) | Flutter (chosen) | Why |
|---|---|---|---|
| **State management** | Redux Toolkit + RTK Query + Zustand | **Riverpod 2 (`flutter_riverpod` + `riverpod_annotation`)** | Maps cleanly to all three: `Notifier` = redux slice, `AsyncNotifier` + `ref.invalidate(tag)` = RTK Query tag invalidation, a global `Notifier` = the Zustand call store. One coherent model instead of three. |
| **Networking** | RTK Query / fetchBaseQuery | **`dio`** + a thin repository layer + Riverpod providers | `dio` interceptors replicate `prepareHeaders` (Bearer injection) and the 401→logout wrapper exactly. |
| **Navigation** | React Navigation (nested native-stacks per tab) | **`go_router` `StatefulShellRoute.indexedStack`** | Native support for a bottom-tab shell where each tab keeps its own independent navigation stack — a 1:1 match for the RN structure. Also handles the `richbengali://` deep links. |
| **Realtime** | socket.io-client | **`socket_io_client` ^2** | Same event/emit contract. A singleton service exposed via Riverpod. |
| **Video/voice** | react-native-agora 4.6 | **`agora_rtc_engine` ^6** | Official Flutter SDK; supports beauty effects, virtual background, face-shape beauty, `AgoraVideoView`. |
| **Native call UI** | react-native-callkeep | **`flutter_callkit_incoming`** | CallKit (iOS) + custom incoming-call screen (Android), self-managed mode. |
| **iOS VoIP push** | react-native-voip-push-notification | **`flutter_voip_push_notification`** (or native PushKit channel) | PushKit token + incoming VoIP payloads. |
| **FCM** | @react-native-firebase/messaging | **`firebase_messaging`** + `firebase_core` | Foreground/background/data messages. |
| **Local/in-call notifications** | @notifee/react-native | **`flutter_local_notifications`** (full-screen intent on Android) | In-call + chat notifications. |
| **Secure token** | react-native-encrypted-storage | **`flutter_secure_storage`** | Keychain / Keystore. |
| **Key-value (user, beauty, pending call)** | AsyncStorage | **`shared_preferences`** | Mirror of the AsyncStorage writes. |
| **Persisted state** | redux-persist (whitelist `auth`) | Persist only auth via secure storage + prefs on change | Same persistence surface. |
| **JWT decode** | jwt-decode | **`jwt_decoder`** | Extract `id` from token for socket auth. |
| **Image pick/upload** | react-native-image-picker / document-picker | **`image_picker`** + `dio` multipart | Profile photos, avatar. |
| **Gradients** | react-native-linear-gradient | Flutter `LinearGradient` in `BoxDecoration` | Native. |
| **Blur (frosted glass)** | @react-native-community/blur | `BackdropFilter` + `ImageFilter.blur` | Native; iOS frosted, Android dark fallback to match source. |
| **Swipe-to-delete** | gesture-handler `Swipeable` | `flutter_slidable` (or `Dismissible`) | Chat list row delete. |
| **Sliders** | community/slider + custom PanResponder | `Slider` / custom `GestureDetector` | Beauty settings. |
| **Env config** | dotenv + babel inline | **`flutter_dotenv`** (`.env`) + `--dart-define` for CI | `EXPO_PUBLIC_API_BASE`, `EXPO_PUBLIC_AGORA_APP_ID`. |
| **Crash reporting** | @sentry/react-native | **`sentry_flutter`** | Same DSN. |
| **Device/version info** | react-native-device-info | **`package_info_plus`** + `device_info_plus` | VersionService (force re-login on app upgrade). |
| **Keep awake / orientation / capture-protect** | keep-awake / orientation-locker / capture-protection | `wakelock_plus`, `flutter_screenutil`-free orientation via `SystemChrome`, `no_screenshot`/`screen_protector` | Call-screen behaviors. |
| **Icons** | lucide-react-native | **`lucide_icons` pub package** (1:1 names) | Same glyphs; fall back to bundled SVGs for the animated logo via `flutter_svg`. |

**State management = Riverpod. UI = a custom design-token theme (no Cupertino/Material default look) reproducing the gluestack/Tailwind styling exactly. Icons = lucide via `lucide_icons`.**

---

## 2. UI / theme strategy (pixel-faithful)

Build a central design system under `lib/theme/` so screens read like the RN ones:

- `app_colors.dart` — every hex token extracted from the source (brand pink `#e91d7c`, purple `#402e91`, full gray scale `#f9fafb…#111827`, greens `#22c55e/#16a34a/#059669`, rose `#f43f5e`, danger `#ef4444/#ff3b30`, call darks `#0b141a/#000`, card backgrounds, etc.).
- `app_gradients.dart` — the 8 named gradient recipes (background decorative, Me header indigo→pink→rose, Save button pink→purple, Plans header rose→pink→orange, Earnings header green, chat send rose→rose-400, Say-Hi rose→orange, PayoutModal indigo→pink).
- `app_text_styles.dart` — system font (SF Pro iOS / Roboto Android), the weight + size scale (`text-4xl`…`text-2xs`/8px), weights 400–900.
- `app_radius.dart` / `app_spacing.dart` — radii (full/24/16/12/8, sheet-top 30, plans-header-bottom 48) and the Tailwind-derived spacing (4/8/12/16/24).
- `app_theme.dart` — a `ThemeData` wiring the above; default scaffold background white with the global `BackgroundGradient` stack behind every screen.

Shared widgets under `lib/widgets/` mirror the RN reusable components 1:1: `AppHeader`, `HeaderRight`, `AnimatedLogo` (animated SVG/CustomPainter), `BackgroundGradient`, `UserCard`, `ConversationRow`, `EmptyState`, `Skeleton`, `PlanCard`, `EarningsOverlay`, `ImageViewer`, `PayoutModal`, `BeautySettingsModal`, `UserFilters`, `MinimizedCall`, `PhotosGrid`, `ExtendedFields`, plus chat bubble/composer widgets.

**iOS parity:** custom-styled widgets (not platform-adaptive) so the look is identical on iOS and Android, exactly like the RN app. Frosted-glass blur enabled on iOS, dark fallback on Android — matching the source's per-platform behavior.

---

## 3. Project structure

```
richb-flutter/
  lib/
    main.dart                 # bootstrap: dotenv, Firebase, Sentry, ProviderScope, runApp
    app.dart                  # MaterialApp.router + theme + global call overlay stack
    router/                   # go_router config, StatefulShellRoute, deep links, auth redirect
    theme/                    # colors, gradients, text styles, radius, spacing, theme
    core/
      env.dart                # EXPO_PUBLIC_API_BASE, AGORA_APP_ID
      dio_client.dart         # dio + auth interceptor + 401→logout
      storage.dart            # secure storage + shared_prefs wrappers
      jwt.dart                # decode id from token
    models/                   # User, Me, Message, Conversation, Notification, Plan, Transaction, Payout, Photo, Refs
    data/                     # repositories: auth, users, relations, messages, notifications, stripe, payouts, agora
    state/                    # Riverpod providers/notifiers: auth, me, users, conversations, messages,
                              #   notifications, callOverlay, socket, plans, earnings
    services/
      socket_service.dart     # socket.io lifecycle + event handlers
      call_service.dart       # Agora engine lifecycle + beauty filters
      callkit_service.dart    # flutter_callkit_incoming wiring
      push_service.dart       # FCM + VoIP push + token sync
      voip_handler.dart       # background/killed-state call recovery
    screens/
      auth/    login, register, forgot
      tabs/    home, favorites, chats, chat_detail, user_detail, me, earnings, payout, subscription, plans
      call/    ongoing_call_screen  (global overlay)
    widgets/                  # shared components (see §2)
  assets/                     # logo.png/svg, sounds (zego_incoming/outgoing.mp3), images
  ios/                        # Info.plist perms, Podfile, capabilities (configured on Windows, built on Mac)
  android/                    # permissions, FCM, foreground service, full-screen intent
  .env                        # API base + Agora app id (gitignored)
  pubspec.yaml
```

---

## 4. Build phases

1. **Scaffold + theme + design system** — `flutter create`, pubspec deps, `lib/theme/*`, `BackgroundGradient`, `AppHeader`, `AnimatedLogo`, env + dio + storage + jwt core. *(Reviewable: a themed shell.)*
2. **Navigation + auth** — go_router StatefulShell (5 tabs + per-tab stacks, male-only Plans), auth redirect gating, Login/Register/Forgot screens wired to `/auth/*` endpoints, token persistence. *(Reviewable: log in end-to-end.)*
3. **Core data + discovery** — models, repositories, Riverpod providers, Home (filters + UserCard grid), Favorites, UserDetail, Me (profile edit + PhotosGrid + ExtendedFields).
4. **Chat** — Conversations list (swipe-delete), ChatDetail (custom bubbles/composer), Socket.IO realtime (chat events), permission/upsell gate.
5. **Calling** — Agora engine, OngoingCallScreen (outgoing/incoming/connecting/ongoing, draggable PiP, controls, beauty modal, earnings overlay), call signaling over socket, MinimizedCall bar.
6. **Push + native call UX** — FCM, VoIP/PushKit, CallKit incoming UI, Notifee-equivalent notifications, token sync, background handlers.
7. **Monetization** — Plans (Stripe checkout via URL), Earnings (paginated, withdrawals), PayoutModal, Subscription/Payout result screens, deep-link return.
8. **Polish + iOS config** — Info.plist permissions (camera/mic/photos/contacts), background modes (voip/audio/fetch/remote-notification), Podfile, app icons/splash, Sentry, VersionService, capture-protection, keep-awake.

Each phase implemented by **Sonnet 4.6 agents in high reasoning mode**, reviewed before moving on.

---

## 5. Verification

- Per phase: `flutter analyze` clean + manual run on **Android** (Windows can build/run Android) against the real backend.
- iOS: code kept iOS-safe; `Info.plist`/`Podfile`/capabilities fully configured. Final `flutter build ios` + simulator/device test must run on **macOS/Xcode** (cannot be done from Windows).
- End-to-end smoke against `richbengali-backend`: login → discover → open profile → chat (realtime) → place a call (Agora media) → earnings/plans.

---

## 6. Open items needing your input

1. **Project location/name** — default: new sibling folder `richb-flutter` (this doc's location).
2. **Env values** — need `EXPO_PUBLIC_API_BASE` (REST + socket URL) and `EXPO_PUBLIC_AGORA_APP_ID` to produce a runnable build (the RN `.env` is not in the repo). Until provided, I'll wire placeholders.
3. **Backend** — assumes the Flutter app targets the **same** `richbengali-backend` (same REST + socket contract). Confirm.
4. **iOS builds** — require a Mac; do you have access for the final iOS compile/test, or should I just guarantee the code + project config are iOS-ready?
