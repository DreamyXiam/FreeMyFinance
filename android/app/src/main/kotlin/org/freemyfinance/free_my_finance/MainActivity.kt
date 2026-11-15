package org.freemyfinance.free_my_finance

import android.content.Intent
import android.app.DownloadManager
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Bundle
import android.os.Build
import android.os.Environment
import android.net.Uri
import android.util.Base64
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private val iconChannel = "org.freemyfinance.free_my_finance/app_icons"
    private val downloadChannel = "org.freemyfinance.free_my_finance/update_download"

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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, downloadChannel).setMethodCallHandler { call, result ->
            try {
                val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
                when (call.method) {
                    "start" -> {
                        val url = call.argument<String>("url") ?: throw IllegalArgumentException("Missing URL")
                        val version = call.argument<String>("version") ?: throw IllegalArgumentException("Missing version")
                        val uri = Uri.parse(url)
                        if (uri.scheme != "https" || uri.host.isNullOrBlank() ||
                            !uri.path.orEmpty().lowercase().endsWith(".apk") ||
                            !Regex("\\d+\\.\\d+\\.\\d+").matches(version)) {
                            throw IllegalArgumentException("Invalid HTTPS APK URL")
                        }
                        val request = DownloadManager.Request(uri)
                            .setTitle("FreeMyFinance $version")
                            .setDescription("正在下载应用更新")
                            .setMimeType("application/vnd.android.package-archive")
                            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                            .setDestinationInExternalFilesDir(this, Environment.DIRECTORY_DOWNLOADS,
                                "FreeMyFinance-v$version-${System.currentTimeMillis()}.apk")
                        result.success(manager.enqueue(request))
                    }
                    "status" -> {
                        val id = call.argument<Number>("id")?.toLong()
                            ?: throw IllegalArgumentException("Missing download ID")
                        manager.query(DownloadManager.Query().setFilterById(id)).use { cursor ->
                            if (!cursor.moveToFirst()) throw IllegalArgumentException("Download not found")
                            val status = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
                            val state = when (status) {
                                DownloadManager.STATUS_SUCCESSFUL -> "success"
                                DownloadManager.STATUS_FAILED -> "failed"
                                else -> "running"
                            }
                            result.success(mapOf(
                                "state" to state,
                                "downloaded" to cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)),
                                "total" to cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
                            ))
                        }
                    }
                    "open" -> {
                        val id = call.argument<Number>("id")?.toLong()
                            ?: throw IllegalArgumentException("Missing download ID")
                        manager.query(DownloadManager.Query().setFilterById(id)).use { cursor ->
                            if (!cursor.moveToFirst() ||
                                cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS)) != DownloadManager.STATUS_SUCCESSFUL) {
                                throw IllegalArgumentException("Download incomplete")
                            }
                            val localUri = Uri.parse(cursor.getString(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_LOCAL_URI)))
                            val file = File(localUri.path ?: throw IllegalArgumentException("Download path missing")).canonicalFile
                            val directory = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)?.canonicalFile
                                ?: throw IllegalArgumentException("Download directory missing")
                            if (!file.path.startsWith(directory.path + File.separator) || file.length() < 1048576) {
                                throw IllegalArgumentException("Downloaded APK is invalid")
                            }
                            val magic = ByteArray(4)
                            if (file.inputStream().use { it.read(magic) } != 4 ||
                                !magic.contentEquals(byteArrayOf(0x50, 0x4b, 0x03, 0x04))) {
                                throw IllegalArgumentException("Downloaded file is not an APK")
                            }
                            @Suppress("DEPRECATION")
                            val flags = if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES
                                else PackageManager.GET_SIGNATURES
                            @Suppress("DEPRECATION")
                            val archive = packageManager.getPackageArchiveInfo(file.path, flags)
                                ?: throw IllegalArgumentException("APK package unreadable")
                            @Suppress("DEPRECATION")
                            val installed = packageManager.getPackageInfo(packageName, flags)
                            if (archive.packageName != packageName) throw IllegalArgumentException("APK package mismatch")
                            @Suppress("DEPRECATION")
                            val newSigners = if (Build.VERSION.SDK_INT >= 28) archive.signingInfo?.apkContentsSigners
                                else archive.signatures
                            @Suppress("DEPRECATION")
                            val currentSigners = if (Build.VERSION.SDK_INT >= 28) installed.signingInfo?.apkContentsSigners
                                else installed.signatures
                            if (newSigners.isNullOrEmpty() || currentSigners.isNullOrEmpty() ||
                                newSigners.size != currentSigners.size ||
                                newSigners.any { candidate -> currentSigners.none { it.toByteArray().contentEquals(candidate.toByteArray()) } }) {
                                throw IllegalArgumentException("APK signing certificate mismatch")
                            }
                            @Suppress("DEPRECATION")
                            val newCode = if (Build.VERSION.SDK_INT >= 28) archive.longVersionCode else archive.versionCode.toLong()
                            @Suppress("DEPRECATION")
                            val currentCode = if (Build.VERSION.SDK_INT >= 28) installed.longVersionCode else installed.versionCode.toLong()
                            if (newCode <= currentCode) throw IllegalArgumentException("APK version is not newer")
                        }
                        val uri = manager.getUriForDownloadedFile(id)
                            ?: throw IllegalArgumentException("Download incomplete")
                        val intent = Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
                            data = uri
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("UPDATE_DOWNLOAD_ERROR", error.message ?: "Unable to download update", null)
            }
        }
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
