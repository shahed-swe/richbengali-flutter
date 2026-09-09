package com.richbengali.richbengali

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.agora.agora_rtc_ng.AgoraPIPFlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Extends Agora's PiP-aware activity so Picture-in-Picture (floating call
// window) works on Android. Requires android:supportsPictureInPicture="true"
// on this activity in AndroidManifest.xml.
class MainActivity : AgoraPIPFlutterActivity() {

    // -------------------------------------------------------------------------
    // OEM setup channel.
    //
    // Chinese-OEM skins (Xiaomi/MIUI+HyperOS, Oppo/Realme ColorOS, Vivo, Huawei)
    // kill backgrounded apps and block background window starts. Two of those
    // settings have NO Android API and cannot be requested with a normal
    // permission dialog:
    //   • Autostart — without it the OEM kills the app and it stops receiving FCM
    //     entirely, so messages and calls never arrive once the app is closed.
    //   • "Display pop-up windows while running in background" — without it the
    //     full-screen intent is blocked, so an incoming call cannot ring
    //     full-screen (on Android 14+ the CallStyle notification is rejected
    //     outright and NO call UI appears at all).
    // The only thing an app can do is take the user straight to those screens,
    // which is what these methods are for.
    // -------------------------------------------------------------------------
    private val oemChannel = "com.richbengali.oem"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, oemChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getManufacturer" -> result.success(Build.MANUFACTURER.lowercase())

                    "openAutostartSettings" -> result.success(openFirstAvailable(autostartTargets()))

                    "openBackgroundPopupSettings" -> result.success(openBackgroundPopup())

                    "openBatterySettings" -> result.success(openBatterySettings())

                    "openAppDetails" -> result.success(openAppDetails())

                    else -> result.notImplemented()
                }
            }
    }

    /** Try each component in order; launch the first one that exists. */
    private fun openFirstAvailable(targets: List<ComponentName>): Boolean {
        for (cn in targets) {
            try {
                val intent = Intent().apply {
                    component = cn
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                if (intent.resolveActivity(packageManager) != null) {
                    startActivity(intent)
                    return true
                }
            } catch (_: Exception) {
                // try the next candidate
            }
        }
        return openAppDetails()
    }

    private fun autostartTargets(): List<ComponentName> = listOf(
        // Xiaomi / Redmi / POCO (MIUI, HyperOS)
        ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"),
        // Oppo / Realme (ColorOS)
        ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
        ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity"),
        ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity"),
        // Vivo
        ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"),
        ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"),
        // Huawei / Honor
        ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
        ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity"),
        // Letv / others
        ComponentName("com.letv.android.letvsafe", "com.letv.android.letvsafe.AutobootManageActivity"),
    )

    /**
     * "Display pop-up windows while running in background". On MIUI this lives in
     * the per-app permission editor, so we can deep-link straight to this app's
     * page; elsewhere fall back to the app details screen.
     */
    private fun openBackgroundPopup(): Boolean {
        try {
            val intent = Intent("miui.intent.action.APP_PERM_EDITOR").apply {
                setClassName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.permissions.PermissionsEditorActivity",
                )
                putExtra("extra_pkgname", packageName)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                return true
            }
        } catch (_: Exception) {
        }
        return openAppDetails()
    }

    private fun openBatterySettings(): Boolean {
        // Ask to be exempted from battery optimisation (standard Android dialog).
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                if (intent.resolveActivity(packageManager) != null) {
                    startActivity(intent)
                    return true
                }
            }
        } catch (_: Exception) {
        }
        return openAppDetails()
    }

    private fun openAppDetails(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.fromParts("package", packageName, null)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }
}
