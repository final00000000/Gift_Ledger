package com.giftmoney.gift_ledger

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.IOException

class MainActivity: FlutterActivity() {
    private val fileSaverChannelName = "com.giftmoney.gift_ledger/file_saver"
    private val appInstallerChannelName = "com.giftmoney.gift_ledger/app_installer"
    private val appInfoChannelName = "com.giftmoney.gift_ledger/app_info"
    private val requestCodeCreateDocument = 43411

    private var pendingResult: MethodChannel.Result? = null
    private var pendingSourcePath: String? = null
    private var pendingInstallResult: MethodChannel.Result? = null
    private var pendingInstallPath: String? = null
    private var awaitingInstallPermission = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, fileSaverChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveAs" -> handleSaveAs(call.arguments, result)
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, appInstallerChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installApk" -> handleInstallApk(call.arguments, result)
                    "canInstallPackages" -> result.success(!requiresInstallPermission())
                    "openInstallPermissionSettings" -> handleOpenInstallPermissionSettings(result)
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, appInfoChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPreferredAbi" -> result.success(getPreferredAbi())
                    else -> result.notImplemented()
                }
            }
    }

    private fun getPreferredAbi(): String? {
        val supportedAbis = Build.SUPPORTED_ABIS ?: return null
        return supportedAbis.firstOrNull { abi ->
            abi.equals("arm64-v8a", ignoreCase = true) ||
                abi.equals("armeabi-v7a", ignoreCase = true)
        } ?: supportedAbis.firstOrNull()
    }

    private fun handleOpenInstallPermissionSettings(result: MethodChannel.Result) {
        if (!requiresInstallPermission()) {
            result.success(true)
            return
        }

        val permissionIntent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
            data = Uri.parse("package:$packageName")
        }

        try {
            startActivity(permissionIntent)
            result.success(true)
        } catch (e: Exception) {
            result.error(
                "INSTALL_PERMISSION_INTENT_FAILED",
                e.message ?: "无法打开安装授权页面",
                null,
            )
        }
    }

    private fun handleInstallApk(arguments: Any?, result: MethodChannel.Result) {
        val args = arguments as? Map<*, *> ?: run {
            result.error("BAD_ARGS", "Arguments must be a map", null)
            return
        }

        val filePath = args["filePath"] as? String
        if (filePath.isNullOrBlank()) {
            result.error("BAD_ARGS", "filePath required", null)
            return
        }

        val apkFile = File(filePath)
        if (!apkFile.exists()) {
            result.error("FILE_NOT_FOUND", "安装包不存在", null)
            return
        }

        if (pendingInstallResult != null) {
            result.error("IN_PROGRESS", "已有安装流程正在进行中", null)
            return
        }

        if (requiresInstallPermission()) {
            pendingInstallResult = result
            pendingInstallPath = filePath
            awaitingInstallPermission = true

            val permissionIntent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                data = Uri.parse("package:$packageName")
            }

            try {
                startActivity(permissionIntent)
            } catch (e: Exception) {
                clearPendingInstall()
                result.error(
                    "INSTALL_PERMISSION_INTENT_FAILED",
                    e.message ?: "无法打开安装授权页面",
                    null,
                )
            }
            return
        }

        launchInstallApk(apkFile, result)
    }

    private fun launchInstallApk(apkFile: File, result: MethodChannel.Result) {
        val apkUri = try {
            FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.fileprovider",
                apkFile,
            )
        } catch (e: Exception) {
            result.error("URI_FAILED", e.message ?: "安装包 URI 创建失败", null)
            return
        }

        val installIntent = Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
            data = apkUri
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            putExtra(Intent.EXTRA_RETURN_RESULT, false)
        }

        val resolvedActivities = packageManager.queryIntentActivities(
            installIntent,
            PackageManager.MATCH_DEFAULT_ONLY,
        )
        if (resolvedActivities.isEmpty()) {
            result.error("NO_INSTALLER", "当前设备未找到可用的系统安装器", null)
            return
        }

        val preferredPackage = resolvePreferredInstallerPackage(resolvedActivities)
        if (!preferredPackage.isNullOrBlank()) {
            installIntent.setPackage(preferredPackage)
        }

        try {
            startActivity(installIntent)
            result.success(true)
        } catch (e: Exception) {
            result.error("INSTALL_INTENT_FAILED", e.message ?: "系统安装器启动失败", null)
        }
    }

    private fun requiresInstallPermission(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
    }

    private fun resolvePreferredInstallerPackage(
        resolvedActivities: List<android.content.pm.ResolveInfo>,
    ): String? {
        val packageNames = resolvedActivities
            .mapNotNull { it.activityInfo?.packageName }
            .distinct()

        fun pickByKeyword(keyword: String): String? {
            return packageNames.firstOrNull { packageName ->
                packageName.contains(keyword, ignoreCase = true)
            }
        }

        return pickByKeyword("packageinstaller")
            ?: pickByKeyword("appmarket")
    }

    private fun clearPendingInstall() {
        pendingInstallResult = null
        pendingInstallPath = null
        awaitingInstallPermission = false
    }

    private fun resumePendingInstallIfPossible() {
        val result = pendingInstallResult ?: return
        val installPath = pendingInstallPath
        clearPendingInstall()

        if (installPath.isNullOrBlank()) {
            result.error("BAD_ARGS", "安装包路径缺失", null)
            return
        }

        val apkFile = File(installPath)
        if (!apkFile.exists()) {
            result.error("FILE_NOT_FOUND", "安装包不存在", null)
            return
        }

        launchInstallApk(apkFile, result)
    }

    override fun onResume() {
        super.onResume()

        if (!awaitingInstallPermission) {
            return
        }

        if (requiresInstallPermission()) {
            val result = pendingInstallResult
            clearPendingInstall()
            result?.error(
                "INSTALL_PERMISSION_DENIED",
                "请先允许“随礼记”安装应用后重试。",
                null,
            )
            return
        }

        resumePendingInstallIfPossible()
    }

    private fun handleSaveAs(arguments: Any?, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("IN_PROGRESS", "Another save operation is in progress", null)
            return
        }

        val args = arguments as? Map<*, *> ?: run {
            result.error("BAD_ARGS", "Arguments must be a map", null)
            return
        }

        val sourcePath = args["sourcePath"] as? String
        val fileName = args["fileName"] as? String
        val mimeType = args["mimeType"] as? String

        if (sourcePath.isNullOrBlank() || fileName.isNullOrBlank() || mimeType.isNullOrBlank()) {
            result.error("BAD_ARGS", "sourcePath/fileName/mimeType required", null)
            return
        }

        pendingResult = result
        pendingSourcePath = sourcePath

        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            putExtra(Intent.EXTRA_TITLE, fileName)
        }

        try {
            startActivityForResult(intent, requestCodeCreateDocument)
        } catch (e: Exception) {
            pendingResult = null
            pendingSourcePath = null
            result.error("INTENT_FAILED", e.message, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode != requestCodeCreateDocument) return

        val result = pendingResult
        val sourcePath = pendingSourcePath
        pendingResult = null
        pendingSourcePath = null

        if (result == null || sourcePath.isNullOrBlank()) return

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }

        val destUri = data.data!!
        try {
            val outputStream = contentResolver.openOutputStream(destUri)
                ?: throw IOException("Cannot open output stream")

            outputStream.use { output ->
                FileInputStream(File(sourcePath)).use { input ->
                    input.copyTo(output)
                }
            }

            result.success(true)
        } catch (e: Exception) {
            result.error("SAVE_FAILED", e.message, null)
        }
    }
}
