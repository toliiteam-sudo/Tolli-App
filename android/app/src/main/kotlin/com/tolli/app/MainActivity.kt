package com.tolli.app

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.tolii.app/location_settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openLocationSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val fallbackIntent = Intent(Settings.ACTION_SETTINGS)
                            fallbackIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(fallbackIntent)
                            result.success(true)
                        } catch (ex: Exception) {
                            result.error("UNAVAILABLE", "Cannot open settings", ex.localizedMessage)
                        }
                    }
                }
                "openAppSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        val uri = Uri.fromParts("package", packageName, null)
                        intent.data = uri
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Cannot open app settings", e.localizedMessage)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
