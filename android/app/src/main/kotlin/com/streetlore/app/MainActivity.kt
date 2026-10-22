package com.streetlore.app

import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.appwidget.AppWidgetManager
import android.content.Context
import com.oguzhnatly.flutter_android_auto.FAAConstants
import io.flutter.embedding.engine.FlutterEngineCache

class MainActivity : FlutterActivity() {
    private val CHANNEL = "streetlore/widget"

    override fun onCreate(savedInstanceState: Bundle?) {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine? =
        FlutterEngineCache.getInstance().get(FAAConstants.flutterEngineId)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        FlutterEngineCache.getInstance().put(FAAConstants.flutterEngineId, flutterEngine)
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "update") {
                    try {
                        // broadcast an update intent so the widget provider refreshes
                        val intent = Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                        intent.setPackage(applicationContext.packageName)
                        applicationContext.sendBroadcast(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("widget_update_failed", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
