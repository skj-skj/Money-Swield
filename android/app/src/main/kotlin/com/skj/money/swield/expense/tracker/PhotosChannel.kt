package com.skj.money.swield.expense.tracker

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ImageDecoder
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.provider.MediaStore
import android.provider.OpenableColumns
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream
import java.util.concurrent.Executors

/**
 * `money_swield/photos`: Android's own camera and photo picker, reading a
 * picture's size, resizing and JPEG-encoding it in native code, copying one
 * into `Pictures/` for the user, and free space.
 *
 * No permission is needed for any of it, so the manifest declares none: the
 * camera app writes into our FileProvider file (declaring `CAMERA` without
 * holding it would make the camera intent throw); the picker grants read access
 * to what was picked; MediaStore lets an app add pictures to `Pictures/`
 * without a permission.
 *
 * The app's own photos are plain files in app-specific storage, handled by
 * Dart; this class only reads a source (a picker URI or a file) and writes
 * the file Dart names.
 */
class PhotosChannel(messenger: BinaryMessenger, context: Context) :
    MethodChannel.MethodCallHandler {

    private val appContext = context.applicationContext
    private val channel = MethodChannel(messenger, NAME)

    /** One thread for file work, so two stages never hold two bitmaps. */
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    /** The camera or the picker, while open. */
    val dialog = PendingActivityCall(REQUEST_CODE)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "capture" -> capture(call.argument<String>("path")!!, result)
            "pick" -> pick(call.argument<Number>("maxItems")!!.toInt(), result)
            "inspect" -> runInBackground(result) {
                inspect(call.argument<String>("source")!!)
            }
            "preview" -> runInBackground(result) {
                preview(
                    call.argument<String>("source")!!,
                    call.argument<String>("destination")!!,
                )
            }
            "stage" -> runInBackground(result) {
                stage(
                    source = call.argument<String>("source")!!,
                    destination = call.argument<String>("destination")!!,
                    width = call.argument<Number>("width")?.toInt(),
                    height = call.argument<Number>("height")?.toInt(),
                    quality = call.argument<Number>("quality")?.toInt() ?: 85,
                    quarterTurns = call.argument<Number>("quarterTurns")?.toInt() ?: 0,
                )
            }
            "saveToPictures" -> runInBackground(result) {
                saveToPictures(
                    sourcePath = call.argument<String>("sourcePath")!!,
                    folder = call.argument<String>("folder")!!,
                    displayName = call.argument<String>("displayName")!!,
                    mimeType = call.argument<String>("mimeType")!!,
                    dateTakenMs = call.argument<Number>("dateTakenMs")!!.toLong(),
                    exifDateTime = call.argument<String>("exifDateTime")!!,
                    exifOffset = call.argument<String>("exifOffset")!!,
                )
            }
            "freeBytes" -> runInBackground(result) {
                StatFs(call.argument<String>("path")!!).availableBytes
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Opens the camera app with [path] (in `photos_staging/`) as its
     * output. True when a picture was taken (a non-empty file), false when
     * cancelled. `noCamera` when no app takes pictures.
     */
    private fun capture(path: String, result: MethodChannel.Result) {
        val file = File(path)
        val uri = try {
            file.parentFile?.mkdirs()
            FileProvider.getUriForFile(appContext, "${appContext.packageName}.photos", file)
        } catch (e: Exception) {
            result.error("ioError", e.toString(), null)
            return
        }
        val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
            putExtra(MediaStore.EXTRA_OUTPUT, uri)
            // ClipData too: some camera apps only get the grant through it.
            clipData = ClipData.newRawUri("", uri)
            addFlags(
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        }
        dialog.start(
            result,
            intent,
            onResult = { resultCode, _ ->
                result.success(resultCode == Activity.RESULT_OK && file.length() > 0)
            },
            onDropped = { result.success(false) },
            onLaunchError = { e ->
                val code = if (e is ActivityNotFoundException) "noCamera" else "noActivity"
                result.error(code, e.toString(), null)
            },
        )
    }

    /**
     * Android's photo picker for at most [maxItems] images, through androidx's
     * contracts: the system picker, else an installed Play services one, else
     * the document picker, which ignores the limit — Dart then uses the first
     * ones only. The picked URIs, in order; empty when cancelled.
     */
    private fun pick(maxItems: Int, result: MethodChannel.Result) {
        val request = PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
        // PickMultipleVisualMedia needs at least 2.
        val multiple = if (maxItems >= 2) ActivityResultContracts.PickMultipleVisualMedia(maxItems) else null
        val single = ActivityResultContracts.PickVisualMedia()
        val intent = multiple?.createIntent(appContext, request)
            ?: single.createIntent(appContext, request)
        dialog.start(
            result,
            intent,
            onResult = { resultCode, data ->
                val uris = if (multiple != null) {
                    multiple.parseResult(resultCode, data)
                } else {
                    listOfNotNull(single.parseResult(resultCode, data))
                }
                result.success(uris.map { it.toString() })
            },
            onDropped = { result.success(emptyList<String>()) },
            onLaunchError = { e -> result.error("noActivity", e.toString(), null) },
        )
    }

    /**
     * A picture's size as it is shown (EXIF orientation applied), its type
     * and its byte count, from its header only.
     */
    private fun inspect(source: String): Map<String, Any> {
        val header = readHeader(source)
        return mapOf(
            "width" to header.width,
            "height" to header.height,
            "mimeType" to header.mimeType,
            "bytes" to sizeOf(source),
        )
    }

    private class Header(val width: Int, val height: Int, val mimeType: String)

    private class HeaderRead : RuntimeException()

    /**
     * Reads the header through [ImageDecoder] and stops before decoding any
     * pixels. ImageDecoder applies the EXIF orientation itself (checked on the
     * Oppo), and its size is the size as shown.
     */
    private fun readHeader(source: String): Header {
        var header: Header? = null
        try {
            ImageDecoder.decodeBitmap(sourceOf(source)) { _, info, _ ->
                header = Header(info.size.width, info.size.height, info.mimeType)
                throw HeaderRead()
            }
        } catch (_: HeaderRead) {
            // Expected: only the header was wanted.
        } catch (e: IOException) {
            throw NotAnImage(e)
        }
        return header ?: throw NotAnImage(null)
    }

    /** The review screen's small copy: at most 1080 px, JPEG 80. */
    private fun preview(source: String, destination: String): Map<String, Any> {
        val header = readHeader(source)
        val (w, h) = fitWithin(header.width, header.height, PREVIEW_EDGE)
        return encode(source, destination, w, h, quality = 80, quarterTurns = 0)
    }

    /**
     * Writes [source] to [destination]: as it is when [width] is null
     * (KeepBytes), else decoded at [width] × [height] (the size after
     * [quarterTurns]), turned, and JPEG-encoded at [quality].
     */
    private fun stage(
        source: String,
        destination: String,
        width: Int?,
        height: Int?,
        quality: Int,
        quarterTurns: Int,
    ): Map<String, Any> {
        if (width == null || height == null) {
            writeAtomically(destination) { out -> openSource(source).use { it.copyTo(out, BUFFER) } }
            return mapOf("bytes" to File(destination).length())
        }
        return encode(source, destination, width, height, quality, quarterTurns)
    }

    /**
     * Decodes [source] scaled so that, once turned by [quarterTurns], it is
     * [width] × [height]; then JPEG at [quality]. One bitmap at a time, two
     * while turning. Transparent pixels (a PNG) become white, not JPEG's black.
     */
    private fun encode(
        source: String,
        destination: String,
        width: Int,
        height: Int,
        quality: Int,
        quarterTurns: Int,
    ): Map<String, Any> {
        val turns = ((quarterTurns % 4) + 4) % 4
        // Decoded before turning, so an odd turn swaps the sides.
        val (decodeW, decodeH) = if (turns % 2 == 1) height to width else width to height
        var bitmap = try {
            ImageDecoder.decodeBitmap(sourceOf(source)) { decoder, _, _ ->
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                decoder.setTargetSize(decodeW, decodeH)
            }
        } catch (e: IOException) {
            throw NotAnImage(e)
        }
        try {
            if (turns != 0) {
                val turned = Bitmap.createBitmap(
                    bitmap, 0, 0, bitmap.width, bitmap.height,
                    Matrix().apply { postRotate(90f * turns) }, true,
                )
                if (turned !== bitmap) bitmap.recycle()
                bitmap = turned
            }
            if (bitmap.hasAlpha()) {
                val opaque = Bitmap.createBitmap(bitmap.width, bitmap.height, Bitmap.Config.ARGB_8888)
                Canvas(opaque).apply {
                    drawColor(Color.WHITE)
                    drawBitmap(bitmap, 0f, 0f, null)
                }
                bitmap.recycle()
                bitmap = opaque
            }
            writeAtomically(destination) { out ->
                if (!bitmap.compress(Bitmap.CompressFormat.JPEG, quality, out)) {
                    throw IOException("JPEG encoding failed")
                }
            }
            return mapOf(
                "bytes" to File(destination).length(),
                "width" to bitmap.width,
                "height" to bitmap.height,
            )
        } finally {
            bitmap.recycle()
        }
    }

    /**
     * Writes [destination] through `<destination>.partial`, flushed to the
     * disk, then renamed: a file at [destination] is always complete.
     */
    private fun writeAtomically(destination: String, write: (FileOutputStream) -> Unit) {
        val target = File(destination)
        val partial = File("$destination.partial")
        target.parentFile?.mkdirs()
        try {
            FileOutputStream(partial).use { out ->
                write(out)
                out.flush()
                out.fd.sync()
            }
            if (!partial.renameTo(target)) throw IOException("Can't rename $partial")
        } catch (e: Throwable) {
            // An Error too (out of memory while encoding): no partial left.
            partial.delete()
            throw if (e is Exception && isNoSpace(e)) NoSpace(e) else e
        }
    }

    /**
     * Copies [sourcePath] into `Pictures/<folder>/` as a new picture named
     * [displayName] (owner rev 5). Only ever **inserts**: an existing picture
     * is never queried, opened, changed or deleted, so a user's file can't be
     * touched; a name already there is renamed by MediaStore ("name (1).jpg").
     * If the copy fails, the one item inserted here is deleted. Returns the
     * name MediaStore gave it.
     */
    private fun saveToPictures(
        sourcePath: String,
        folder: String,
        displayName: String,
        mimeType: String,
        dateTakenMs: Long,
        exifDateTime: String,
        exifOffset: String,
    ): String {
        val resolver = appContext.contentResolver
        val collection = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Images.Media.MIME_TYPE, mimeType)
            put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/$folder/")
            put(MediaStore.Images.Media.DATE_TAKEN, dateTakenMs)
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        val item = resolver.insert(collection, values) ?: throw IOException("MediaStore refused the picture")
        try {
            val out = resolver.openOutputStream(item, "w") ?: throw IOException("Can't write the picture")
            out.use { stream -> File(sourcePath).inputStream().use { it.copyTo(stream, BUFFER) } }
            if (mimeType == "image/jpeg") stampDate(item, exifDateTime, exifOffset)
            resolver.update(
                item,
                ContentValues().apply { put(MediaStore.Images.Media.IS_PENDING, 0) },
                null,
                null,
            )
        } catch (e: Exception) {
            try {
                resolver.delete(item, null, null)
            } catch (_: Exception) {
                // Best effort; the error below is what matters.
            }
            throw if (isNoSpace(e)) NoSpace(e) else e
        }
        // The item we just inserted, read back for its final name.
        resolver.query(item, arrayOf(MediaStore.Images.Media.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) return cursor.getString(0) ?: displayName
        }
        return displayName
    }

    /**
     * Writes the expense's moment into the saved copy's EXIF
     * (`DateTimeOriginal` and its offset), so galleries file it on the
     * expense's day. MediaStore's own `DATE_TAKEN` can't do it: on the Oppo
     * (Android 14) a value an app writes is dropped when the file is scanned,
     * and the scan reads EXIF. Only the copy in Pictures/ gets it; the app's
     * own file is never changed. Best effort: a picture whose EXIF can't be
     * written is still saved.
     */
    private fun stampDate(item: Uri, dateTime: String, offset: String) {
        try {
            appContext.contentResolver.openFileDescriptor(item, "rw")?.use { fd ->
                ExifInterface(fd.fileDescriptor).apply {
                    setAttribute(ExifInterface.TAG_DATETIME_ORIGINAL, dateTime)
                    setAttribute(ExifInterface.TAG_OFFSET_TIME_ORIGINAL, offset)
                    saveAttributes()
                }
            }
        } catch (e: Exception) {
            android.util.Log.w("PhotosChannel", "Couldn't date the saved picture: $e")
        }
    }

    private fun sourceOf(source: String): ImageDecoder.Source =
        if (source.startsWith("content://")) {
            ImageDecoder.createSource(appContext.contentResolver, Uri.parse(source))
        } else {
            ImageDecoder.createSource(File(source))
        }

    private fun openSource(source: String): InputStream =
        if (source.startsWith("content://")) {
            appContext.contentResolver.openInputStream(Uri.parse(source))
                ?: throw IOException("Can't read $source")
        } else {
            File(source).inputStream()
        }

    /** The source's byte count: the provider's size, else counted. */
    private fun sizeOf(source: String): Long {
        if (!source.startsWith("content://")) return File(source).length()
        val uri = Uri.parse(source)
        appContext.contentResolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst() && !cursor.isNull(0)) return cursor.getLong(0)
        }
        var total = 0L
        openSource(source).use { input ->
            val buffer = ByteArray(BUFFER)
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                total += read
            }
        }
        return total
    }

    private fun isNoSpace(e: Exception): Boolean =
        generateSequence<Throwable>(e) { it.cause }.any { it.message?.contains("ENOSPC") == true }

    /** Runs [work] off the main thread and posts its answer back on it. */
    private fun runInBackground(result: MethodChannel.Result, work: () -> Any?) {
        io.execute {
            when (val answer = CallAnswer.of(work)) {
                is CallAnswer.Value -> main.post { result.success(answer.value) }
                is CallAnswer.Error -> main.post { result.error(answer.code, answer.message, null) }
            }
        }
    }

    companion object {
        const val NAME = "money_swield/photos"
        private const val REQUEST_CODE = 0x5E8
        private const val BUFFER = 64 * 1024
        private const val PREVIEW_EDGE = 1080

        /** [w] × [h] scaled down to fit a [edge] × [edge] box, never up. */
        fun fitWithin(w: Int, h: Int, edge: Int): Pair<Int, Int> {
            val scale = minOf(1.0, edge.toDouble() / maxOf(w, h))
            return maxOf(1, Math.round(w * scale).toInt()) to maxOf(1, Math.round(h * scale).toInt())
        }
    }
}
