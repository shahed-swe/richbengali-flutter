package com.richbengali.richbengali

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

/**
 * Tells the server the user declined an incoming call — natively, with NO Flutter
 * engine required.
 *
 * flutter_callkit_incoming only forwards the decline to Dart via
 * `sendEventFlutter(...)`, which needs a live engine that has registered
 * `FlutterCallkitIncoming.onEvent`. That listener lives in the app's main
 * isolate. When the app is CLOSED the call UI is raised by the short-lived FCM
 * background isolate, which is already gone by the time the user taps Decline —
 * so the event was dropped entirely and the CALLER kept ringing until the
 * server's 45s timeout.
 *
 * This receiver listens for the same decline broadcast and POSTs /calls/reject
 * itself. Both the auth token and the API base are mirrored into plain
 * SharedPreferences by the Dart side (shared_preferences stores keys with a
 * "flutter." prefix), so no engine is needed to read them.
 */
class CallDeclineReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "CallDeclineReceiver"
        private const val PREFS = "FlutterSharedPreferences"
        private const val KEY_TOKEN = "flutter.@auth_token"
        private const val KEY_API_BASE = "flutter.@api_base"
        // Keys used by flutter_callkit_incoming's own bundle.
        private const val EXTRA_DATA = "EXTRA_CALLKIT_INCOMING_DATA"
        private const val EXTRA_EXTRA = "EXTRA_CALLKIT_EXTRA"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val data: Bundle = intent.getBundleExtra(EXTRA_DATA) ?: return

        // Our real ids travel in the `extra` map we set when showing the call.
        @Suppress("DEPRECATION")
        val extra = data.getSerializable(EXTRA_EXTRA) as? HashMap<*, *>
        val callId = extra?.get("callId")?.toString().orEmpty()
        val callerId = extra?.get("callerId")?.toString().orEmpty()

        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val token = prefs.getString(KEY_TOKEN, null)
        val apiBase = prefs.getString(KEY_API_BASE, null)?.trimEnd('/')

        if (token.isNullOrEmpty() || apiBase.isNullOrEmpty()) {
            Log.w(TAG, "no token/apiBase stored — cannot report decline")
            return
        }

        // Keep the broadcast alive while the request runs.
        val pending = goAsync()
        Thread {
            try {
                val url = URL("$apiBase/calls/reject")
                val conn = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    connectTimeout = 8000
                    readTimeout = 8000
                    doOutput = true
                    setRequestProperty("Content-Type", "application/json")
                    setRequestProperty("Authorization", "Bearer $token")
                }
                val body = JSONObject()
                    .put("callId", callId)
                    .put("callerId", callerId)
                    .toString()
                OutputStreamWriter(conn.outputStream).use { it.write(body) }
                Log.i(TAG, "decline reported natively: HTTP ${conn.responseCode} callId=$callId")
                conn.disconnect()
            } catch (e: Exception) {
                Log.e(TAG, "failed to report decline: ${e.message}")
            } finally {
                pending.finish()
            }
        }.start()
    }
}
