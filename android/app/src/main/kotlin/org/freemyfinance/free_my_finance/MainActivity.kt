package org.freemyfinance.free_my_finance

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Bundle
import android.util.Base64
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterFragmentActivity() {
    private val iconChannel = "org.freemyfinance.free_my_finance/app_icons"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestHighRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        window.decorView.post { requestHighRefreshRate() }
    }

    private fun requestHighRefreshRate() {
        val highest = display?.supportedModes?.maxOfOrNull { it.refreshRate } ?: 60f
        window.attributes = window.attributes.apply { preferredRefreshRate = minOf(144f, highest) }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, iconChannel).setMethodCallHandler { call, result ->
            Thread {
                try {
                    when (call.method) {
                        "listApps" -> {
                            val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
                            @Suppress("DEPRECATION")
                            val apps = packageManager.queryIntentActivities(intent, 0)
                                .map { mapOf("name" to it.loadLabel(packageManager).toString(), "packageName" to it.activityInfo.packageName) }
                                .distinctBy { it["packageName"] }
                                .sortedBy { it["name"]?.lowercase() }
                            runOnUiThread { result.success(apps) }
                        }
                        "loadIcon" -> {
                            val packageName = call.argument<String>("packageName") ?: throw IllegalArgumentException("Missing package name")
                            val drawable = packageManager.getApplicationIcon(packageName)
                            val bitmap = Bitmap.createBitmap(96, 96, Bitmap.Config.ARGB_8888)
                            val canvas = Canvas(bitmap)
                            drawable.setBounds(0, 0, 96, 96)
                            drawable.draw(canvas)
                            val stream = ByteArrayOutputStream()
                            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                            bitmap.recycle()
                            val encoded = Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
                            runOnUiThread { result.success(encoded) }
                        }
                        else -> runOnUiThread { result.notImplemented() }
                    }
                } catch (error: Exception) {
                    runOnUiThread { result.error("APP_ICON_ERROR", error.message ?: "Unable to read app icon", null) }
                }
            }.start()
        }
    }
}
