package com.skj.expense.tracker.my_expense_tracker_app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream
import java.util.concurrent.Executors

/**
 * `expense_tracker/documents`: the system save and open dialogs (Storage
 * Access Framework) and the app version, for backup and restore
 * (phase-3.md §7). Own code instead of a file-picker plugin (P3-1).
 *
 * Created once, with the cached engine, so it outlives any one activity;
 * the one open dialog is a [PendingActivityCall] (phase-6.md R8).
 */
class DocumentsChannel(messenger: BinaryMessenger, context: Context) :
    MethodChannel.MethodCallHandler {

    private val appContext = context.applicationContext
    private val channel = MethodChannel(messenger, NAME)
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    /** The dialog that is open, if any. At most one at a time. */
    val dialog = PendingActivityCall(REQUEST_CODE)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "appVersion" -> result.success(appVersion())
            "saveDocument" -> {
                val source = call.argument<String>("sourcePath")!!
                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = call.argument<String>("mimeType")!!
                    putExtra(
                        Intent.EXTRA_TITLE,
                        call.argument<String>("suggestedName")!!,
                    )
                }
                startDialog(result, intent, cancelled = false) { uri ->
                    runInBackground(result) {
                        saveTo(uri, source)
                        true
                    }
                }
            }
            "openDocument" -> {
                val mimeTypes = call.argument<List<String>>("mimeTypes")!!
                val destination = call.argument<String>("destinationPath")!!
                val maxBytes = call.argument<Number>("maxBytes")!!.toLong()
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "*/*"
                    putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes.toTypedArray())
                }
                startDialog(result, intent, cancelled = null) { uri ->
                    runInBackground(result) {
                        openFrom(uri, destination, maxBytes)
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Opens a dialog; [onPicked] gets the chosen document. A cancelled or
     * dropped dialog answers [cancelled] (`false` for save, `null` for
     * open).
     */
    private fun startDialog(
        result: MethodChannel.Result,
        intent: Intent,
        cancelled: Any?,
        onPicked: (Uri) -> Unit,
    ) {
        dialog.start(
            result,
            intent,
            onResult = { resultCode, data ->
                val uri = data?.data
                if (resultCode != Activity.RESULT_OK || uri == null) {
                    result.success(cancelled)
                } else {
                    onPicked(uri)
                }
            },
            onDropped = { result.success(cancelled) },
            onLaunchError = { e -> result.error("noDialog", e.toString(), null) },
        )
    }

    /**
     * Copies the zip into the chosen document, then reads it back and
     * compares it byte for byte. A mismatch or an I/O error deletes the
     * document (best effort) and fails the call.
     */
    private fun saveTo(uri: Uri, sourcePath: String) {
        val resolver = appContext.contentResolver
        try {
            // "wt": write and truncate; plain "w" doesn't truncate on some
            // providers.
            val output = resolver.openOutputStream(uri, "wt")
                ?: throw IOException("Can't write to the chosen file")
            output.use { out -> FileInputStream(sourcePath).use { it.copyTo(out, BUFFER) } }
            val input = resolver.openInputStream(uri)
                ?: throw IOException("Can't read the saved file back")
            val same = input.use { saved -> FileInputStream(sourcePath).use { sameBytes(it, saved) } }
            if (!same) throw IOException("The saved file differs from the backup")
        } catch (e: Exception) {
            try {
                DocumentsContract.deleteDocument(resolver, uri)
            } catch (_: Exception) {
                // Best effort: the error below is what matters.
            }
            throw e
        }
    }

    /**
     * Copies the picked document to [destinationPath]. A document above
     * [maxBytes] is refused before copying when the provider reports its
     * size, and the copy stops once it passes [maxBytes] when it doesn't.
     * Either way no file is left behind.
     */
    private fun openFrom(uri: Uri, destinationPath: String, maxBytes: Long): String? {
        val resolver = appContext.contentResolver
        var name: String? = null
        resolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val nameColumn = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                val sizeColumn = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (nameColumn >= 0 && !cursor.isNull(nameColumn)) {
                    name = cursor.getString(nameColumn)
                }
                if (sizeColumn >= 0 && !cursor.isNull(sizeColumn) &&
                    cursor.getLong(sizeColumn) > maxBytes
                ) {
                    throw TooLarge()
                }
            }
        }
        val destination = File(destinationPath)
        destination.parentFile?.mkdirs()
        try {
            val input = resolver.openInputStream(uri)
                ?: throw IOException("Can't read the chosen file")
            input.use { copyAtMost(it, destination, maxBytes) }
        } catch (e: Exception) {
            destination.delete()
            throw e
        }
        return name ?: ""
    }

    private fun copyAtMost(input: InputStream, destination: File, maxBytes: Long) {
        FileOutputStream(destination).use { out ->
            val buffer = ByteArray(BUFFER)
            var total = 0L
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                total += read
                if (total > maxBytes) throw TooLarge()
                out.write(buffer, 0, read)
            }
            out.fd.sync()
        }
    }

    private fun sameBytes(a: InputStream, b: InputStream): Boolean {
        val x = ByteArray(BUFFER)
        val y = ByteArray(BUFFER)
        while (true) {
            val n = readFully(a, x)
            val m = readFully(b, y)
            if (n != m) return false
            if (n == 0) return true
            for (i in 0 until n) if (x[i] != y[i]) return false
        }
    }

    /** Reads until [buffer] is full or the stream ends; returns the count. */
    private fun readFully(input: InputStream, buffer: ByteArray): Int {
        var total = 0
        while (total < buffer.size) {
            val read = input.read(buffer, total, buffer.size - total)
            if (read < 0) break
            total += read
        }
        return total
    }

    /** Runs [work] off the main thread and posts its answer back on it. */
    private fun runInBackground(result: MethodChannel.Result, work: () -> Any?) {
        io.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (_: TooLarge) {
                main.post { result.error("tooLarge", "The file is too large", null) }
            } catch (e: Exception) {
                main.post { result.error("ioError", e.toString(), null) }
            }
        }
    }

    private fun appVersion(): String {
        val info = appContext.packageManager.getPackageInfo(appContext.packageName, 0)
        // longVersionCode needs API 28; minSdk is 29.
        return "${info.versionName}+${info.longVersionCode}"
    }

    private class TooLarge : Exception()

    companion object {
        const val NAME = "expense_tracker/documents"
        private const val REQUEST_CODE = 0x5E7
        private const val BUFFER = 64 * 1024
    }
}
