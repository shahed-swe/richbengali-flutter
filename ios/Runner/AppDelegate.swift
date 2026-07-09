import AVFoundation
import CallKit
import Flutter
import PushKit
import UIKit

// =============================================================================
//  AppDelegate
//
//  Phase 8 additions:
//  • Registers for PushKit (VoIP push) via PKPushRegistry.
//  • Forwards VoIP tokens to Dart via the "com.richbengali.voip" MethodChannel.
//  • Receives incoming VoIP pushes and reports them to CallKit so iOS shows the
//    native incoming-call UI even when the app is killed.
//  • Forwards the CallKit "answer" / "end" events to Dart so the in-app UI
//    reacts accordingly.
//
//  MANUAL XCODE STEPS (required on Mac before shipping):
//  1. Select Runner target → Signing & Capabilities → "+ Capability":
//       • Push Notifications
//       • Background Modes → tick: Voice over IP, Audio, Remote notifications
//  2. In Apple Developer portal: create a VoIP Services Certificate + APNs Auth Key
//     for com.richbengali.app and upload/associate in Xcode / App Store Connect.
//  3. Drop GoogleService-Info.plist into ios/Runner/ (Xcode → "Add Files to Runner")
//     then run `cd ios && pod install` from the Mac terminal.
//  4. Set DEVELOPMENT_TEAM in Signing & Capabilities to your Apple team ID.
// =============================================================================

@main
@objc class AppDelegate: FlutterAppDelegate {

    // -------------------------------------------------------------------------
    // CallKit provider — one provider per app lifetime.
    // -------------------------------------------------------------------------
    private var callProvider: CXProvider?
    private var callController = CXCallController()

    // VoIP push registry
    private var voipRegistry: PKPushRegistry?

    // Flutter MethodChannel (set up after engine is ready)
    private var voipChannel: FlutterMethodChannel?

    // Track active call UUID so CallKit events can reference it.
    private var activeCallUUID: UUID?

    // -------------------------------------------------------------------------
    // application(_:didFinishLaunchingWithOptions:)
    // -------------------------------------------------------------------------
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // Register Flutter plugins first (mandatory).
        GeneratedPluginRegistrant.register(with: self)

        // Set up the VoIP MethodChannel after the Flutter engine is running.
        if let controller = window?.rootViewController as? FlutterViewController {
            voipChannel = FlutterMethodChannel(
                name: "com.richbengali.voip",
                binaryMessenger: controller.binaryMessenger
            )
            voipChannel?.setMethodCallHandler { [weak self] call, result in
                self?.handleDartCall(call, result: result)
            }
        }

        // Configure CallKit CXProvider.
        let config = CXProviderConfiguration()
        config.supportsVideo = true
        config.maximumCallsPerCallGroup = 1
        config.maximumCallGroups = 1
        config.supportedHandleTypes = [.generic]
        // App icon mask shown in CallKit UI (use a 40×40 PDF or PNG named
        // "CallKitLogo" in Assets.xcassets — optional but recommended).
        // config.iconTemplateImageData = UIImage(named: "CallKitLogo")?.pngData()

        callProvider = CXProvider(configuration: config)
        callProvider?.setDelegate(self, queue: nil)

        // Register for VoIP push notifications via PushKit.
        voipRegistry = PKPushRegistry(queue: .main)
        voipRegistry?.delegate = self
        voipRegistry?.desiredPushTypes = [.voIP]

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // -------------------------------------------------------------------------
    // Handle MethodChannel calls FROM Dart (e.g. end call from Dart UI)
    // -------------------------------------------------------------------------
    private func handleDartCall(_ call: FlutterMethodCall, result: FlutterResult) {
        switch call.method {
        case "endCallKit":
            if let uuid = activeCallUUID {
                let endAction = CXEndCallAction(call: uuid)
                let transaction = CXTransaction(action: endAction)
                callController.request(transaction) { _ in }
                activeCallUUID = nil
            }
            result(nil)

        case "answerCallKit":
            // Dart told us the user tapped Answer inside the Flutter UI —
            // report to CallKit that the call is now connected.
            if let uuid = activeCallUUID {
                callProvider?.reportOutgoingCall(with: uuid, connectedAt: Date())
            }
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // -------------------------------------------------------------------------
    // Internal: report an incoming call to CallKit.
    // Called from the PushKit delegate when a VoIP push arrives.
    // -------------------------------------------------------------------------
    private func reportIncomingCall(uuid: UUID, callerName: String, hasVideo: Bool) {
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: callerName)
        update.localizedCallerName = callerName
        update.hasVideo = hasVideo
        update.supportsHolding = false
        update.supportsDTMF = false

        callProvider?.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error = error {
                debugPrint("[AppDelegate] reportNewIncomingCall error: \(error)")
            }
        }
    }
}

// =============================================================================
//  MARK: - PKPushRegistryDelegate (VoIP push)
// =============================================================================
extension AppDelegate: PKPushRegistryDelegate {

    // Called when PushKit assigns / rotates the VoIP push token.
    func pushRegistry(
        _ registry: PKPushRegistry,
        didUpdate pushCredentials: PKPushCredentials,
        for type: PKPushType
    ) {
        guard type == .voIP else { return }

        let tokenData = pushCredentials.token
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        debugPrint("[AppDelegate] VoIP push token: \(token)")

        // Forward token to Dart so push_service.dart can register it with the server.
        DispatchQueue.main.async { [weak self] in
            self?.voipChannel?.invokeMethod("onVoipToken", arguments: token)
        }
    }

    // Called when an incoming VoIP push arrives (even if app is killed).
    func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType,
        completion: @escaping () -> Void
    ) {
        guard type == .voIP else {
            completion()
            return
        }

        let data = payload.dictionaryPayload

        // Extract caller info from the push payload.
        // Expected shape: { "callerName": "...", "callId": "...", "callType": "audio"|"video" }
        let callerName = data["callerName"] as? String ?? "Unknown"
        let callId     = data["callId"]     as? String ?? UUID().uuidString
        let callType   = data["callType"]   as? String ?? "audio"
        let hasVideo   = callType == "video"

        // We MUST call report before completion() — iOS requires a CallKit report
        // for every VoIP push or the app will be penalised / killed.
        let uuid = UUID()
        activeCallUUID = uuid
        reportIncomingCall(uuid: uuid, callerName: callerName, hasVideo: hasVideo)

        // Forward payload to Dart so the Riverpod call overlay is updated.
        DispatchQueue.main.async { [weak self] in
            self?.voipChannel?.invokeMethod("onVoipCallReceived", arguments: [
                "callId":     callId,
                "callerName": callerName,
                "callType":   callType,
            ])
        }

        completion()
    }

    func pushRegistry(
        _ registry: PKPushRegistry,
        didInvalidatePushTokenFor type: PKPushType
    ) {
        debugPrint("[AppDelegate] VoIP push token invalidated")
    }
}

// =============================================================================
//  MARK: - CXProviderDelegate (CallKit)
// =============================================================================
extension AppDelegate: CXProviderDelegate {

    func providerDidReset(_ provider: CXProvider) {
        debugPrint("[AppDelegate] CallKit provider reset")
        activeCallUUID = nil
    }

    // User tapped "Accept" on the native CallKit UI.
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        debugPrint("[AppDelegate] CallKit: user answered call \(action.callUUID)")
        DispatchQueue.main.async { [weak self] in
            self?.voipChannel?.invokeMethod("onCallKitAnswer", arguments: [
                "callUUID": action.callUUID.uuidString,
            ])
        }
        action.fulfill()
    }

    // User tapped "Decline" or the call was ended from either side.
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        debugPrint("[AppDelegate] CallKit: call ended \(action.callUUID)")
        DispatchQueue.main.async { [weak self] in
            self?.voipChannel?.invokeMethod("onCallKitEnd", arguments: [
                "callUUID": action.callUUID.uuidString,
            ])
        }
        activeCallUUID = nil
        action.fulfill()
    }

    func provider(
        _ provider: CXProvider,
        didActivate audioSession: AVAudioSession
    ) {
        debugPrint("[AppDelegate] CallKit: audio session activated")
        // Agora handles its own audio session; nothing to do here.
    }

    func provider(
        _ provider: CXProvider,
        didDeactivate audioSession: AVAudioSession
    ) {
        debugPrint("[AppDelegate] CallKit: audio session deactivated")
    }
}
