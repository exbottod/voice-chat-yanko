package com.exbottod.voice_chat_yanko

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Jembatan pembaruan APK: memberi tahu lokasi APK yang terpasang, menggabungkan
 * file selisih (patch BSDIFF40) dengan APK lama, lalu membuka pemasang Android.
 */
class UpdateBridge(private val context: Context) {

    companion object {
        const val CHANNEL = "yanko/update"
    }

    private val io = Executors.newSingleThreadExecutor()

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "apkPath" -> result.success(context.applicationInfo.sourceDir)
                    "canInstall" -> result.success(canInstall())
                    "openInstallSettings" -> {
                        openInstallSettings()
                        result.success(true)
                    }
                    "applyPatch" -> {
                        val oldPath = call.argument<String>("old") ?: ""
                        val patchPath = call.argument<String>("patch") ?: ""
                        val outPath = call.argument<String>("out") ?: ""
                        io.execute {
                            val hasil = try {
                                BsPatch.terapkan(File(oldPath), File(patchPath), File(outPath)).ok
                            } catch (e: Exception) {
                                false
                            }
                            Handler(Looper.getMainLooper()).post { result.success(hasil) }
                        }
                    }
                    "install" -> {
                        val apk = call.argument<String>("apk") ?: ""
                        result.success(install(apk))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun canInstall(): Boolean = try {
        if (Build.VERSION.SDK_INT >= 26) {
            context.packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    } catch (e: Exception) {
        true
    }

    private fun openInstallSettings() {
        try {
            val intent = if (Build.VERSION.SDK_INT >= 26) {
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:" + context.packageName),
                )
            } else {
                Intent(Settings.ACTION_SECURITY_SETTINGS)
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        } catch (e: Exception) {
            try {
                context.startActivity(
                    Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
            } catch (ignored: Exception) {
            }
        }
    }

    /** Buka pemasang Android. false = izin "pasang dari aplikasi ini" belum ada. */
    private fun install(apkPath: String): Boolean {
        return try {
            val file = File(apkPath)
            if (!file.exists() || file.length() <= 0L) {
                return false
            }
            if (!canInstall()) {
                openInstallSettings()
                return false
            }
            val uri = FileProvider.getUriForFile(
                context,
                context.packageName + ".updateprovider",
                file,
            )
            val intent = Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }
}
