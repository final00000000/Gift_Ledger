package com.giftmoney.gift_ledger

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.IOException

class MainActivity: FlutterActivity() {
    private val fileSaverChannelName = "com.giftmoney.gift_ledger/file_saver"
    private val requestCodeCreateDocument = 43411

    private var pendingResult: MethodChannel.Result? = null
    private var pendingSourcePath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, fileSaverChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveAs" -> handleSaveAs(call.arguments, result)
                    else -> result.notImplemented()
                }
            }
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
