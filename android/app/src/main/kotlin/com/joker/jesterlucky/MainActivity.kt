package com.joker.jesterlucky

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// ============================================================
// MainActivity — WebView file-upload bridge
// ============================================================
// The Dart side routes <input type="file"> chooser calls over the
// `jester/pick` MethodChannel; here we open a native chooser and
// return the resulting content:// URIs. No file_picker dependency —
// see .cursor/rules/gray_part_pitfalls.md §1 for why we do this
// ourselves instead of pulling in the plugin.
// ============================================================
class MainActivity : FlutterActivity() {
    // Mirrored in lib/curtain/reader_stage.dart. Rename atomically.
    private val bridgeName = "jester/pick"
    private val chooserCode = 0x4C55 // "LU"

    private var pending: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, bridgeName)
            .setMethodCallHandler { call, result ->
                if (call.method == "choose") {
                    val multiple = call.argument<Boolean>("multiple") ?: false
                    val mimes = call.argument<List<String>>("mimeTypes") ?: emptyList()
                    launchChooser(multiple, mimes, result)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun launchChooser(
        multiple: Boolean,
        mimes: List<String>,
        result: MethodChannel.Result,
    ) {
        // Resolve any abandoned request before starting a new one so a
        // stale pending callback never receives a mismatched activity
        // result.
        pending?.success(emptyList<String>())
        pending = result

        val valid = mimes.filter { it.contains("/") }
        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple)
            when {
                valid.isEmpty() -> type = "*/*"
                valid.size == 1 -> type = valid[0]
                else -> {
                    type = "*/*"
                    putExtra(Intent.EXTRA_MIME_TYPES, valid.toTypedArray())
                }
            }
        }

        try {
            startActivityForResult(Intent.createChooser(intent, null), chooserCode)
        } catch (e: Exception) {
            pending = null
            result.success(emptyList<String>())
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != chooserCode) return

        val handoff = pending
        pending = null
        if (handoff == null) return

        if (resultCode != Activity.RESULT_OK || data == null) {
            handoff.success(emptyList<String>())
            return
        }

        val collected = ArrayList<String>()
        val clip = data.clipData
        if (clip != null) {
            for (i in 0 until clip.itemCount) {
                collected.add(clip.getItemAt(i).uri.toString())
            }
        } else {
            data.data?.let { collected.add(it.toString()) }
        }
        handoff.success(collected)
    }
}
