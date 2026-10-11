package com.skj.expense.tracker.my_expense_tracker_app

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import android.os.Handler
import android.os.Looper
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

/**
 * `expense_tracker/report_pdf`: writes a report's PDF with Android's
 * `PdfDocument` (phase-8.md §6.4, plan A). Dart sends a layout-free
 * document (every string formatted, see report_pdf.dart); this lays it out
 * on A4 pages and draws it with the system's text stack, so Hindi
 * conjuncts and colour emoji come out right (probed on the Oppo, §12a).
 *
 * Two passes: the first only measures, to count the pages for "Page 3 of
 * 12"; the second draws. A single-line cell is drawn with `drawText`
 * (shaped like any text); only a cell too wide for its column goes through
 * a `StaticLayout` (2 lines at most, then "…"). Progress every 10 pages;
 * Cancel is checked between pages; a failure or a cancel deletes the file.
 */
class ReportPdfChannel(messenger: BinaryMessenger, context: Context) :
    MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, NAME)
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    @Volatile private var cancelled: String? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "write" -> {
                val id = call.argument<String>("id")!!
                val json = call.argument<String>("jsonPath")!!
                val out = call.argument<String>("outPath")!!
                io.execute {
                    val file = File(out)
                    try {
                        val doc = JSONObject(File(json).readText())
                        // Parts beside the JSON, outside the shared folder.
                        val parts = File(File(json).parentFile, "parts-$id")
                        val pages = Writer(doc, id, parts).write(file)
                        main.post { result.success(pages) }
                    } catch (e: Cancelled) {
                        file.delete()
                        main.post { result.error("cancelled", null, null) }
                    } catch (e: Throwable) {
                        // An Error too (out of memory): no partial file left.
                        file.delete()
                        main.post { result.error("failed", e.toString(), null) }
                    }
                }
            }
            "cancel" -> {
                cancelled = call.argument<String>("id")
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private class Cancelled : Exception()

    private class TableLayout(
        val widths: FloatArray,
        val end: BooleanArray,
        val headerHeight: Float,
        val rowHeights: FloatArray,
    )

    private inner class Writer(
        private val doc: JSONObject,
        private val id: String,
        private val partsDir: File,
    ) {
        private val title = paint(20f, bold = true)
        private val heading = paint(16f, bold = true)
        private val body = paint(BODY)
        private val bold = paint(BODY, bold = true)
        private val muted = paint(BODY, color = MUTED)
        private val footerPaint = paint(8f, color = MUTED)
        private val shade = Paint().apply { color = SHADE }
        private val line = Paint().apply { color = LINE; strokeWidth = 0.5f }

        /** The part being drawn. */
        private var pdf: PdfDocument? = null
        private var page: PdfDocument.Page? = null
        private var canvas: Canvas? = null
        private var pageNo = 0
        private var pages = 0
        private var y = 0f

        /** The parts written so far, in order. */
        private val parts = mutableListOf<File>()

        /**
         * Each table's measurements, by block index: taken in the counting
         * pass and reused by the drawing pass, so every cell is measured
         * once (50,000 rows: most of the writing time is text measuring).
         */
        private val tables = HashMap<Int, TableLayout>()

        /**
         * Measures, then draws in parts of [PART_PAGES] pages, each written
         * to its own file and closed (a `PdfDocument` keeps every page in
         * memory until it is written: ~250 KB a page on the Oppo), then
         * joins them ([PdfJoin]). The parts are deleted however it ends.
         */
        fun write(file: File): Int {
            pages = layout(draw = false)
            partsDir.mkdirs()
            pdf = PdfDocument()
            try {
                layout(draw = true)
                writePart()
                if (parts.size == 1) {
                    parts.single().copyTo(file, overwrite = true)
                } else {
                    PdfJoin.join(parts, file)
                }
            } finally {
                pdf?.close()
                partsDir.deleteRecursively()
            }
            return pages
        }

        /** The pages drawn since the last part, as the next part's file. */
        private fun writePart() {
            val document = pdf!!
            val part = File(partsDir, "part-${parts.size}.pdf")
            FileOutputStream(part).use { document.writeTo(it) }
            document.close()
            parts += part
            pdf = null
        }

        /** Lays the document out; draws when [draw]. Returns the pages. */
        private fun layout(draw: Boolean): Int {
            pageNo = 0
            newPage(draw)
            val blocks = doc.getJSONArray("blocks")
            for (i in 0 until blocks.length()) {
                val block = blocks.getJSONObject(i)
                when (block.getString("t")) {
                    "title" -> text(block.getString("text"), title, draw, after = 6f)
                    "heading" -> text(block.getString("text"), heading, draw, before = 14f, after = 4f)
                    "text" -> text(
                        block.getString("text"),
                        if (block.optBoolean("muted")) muted else body,
                        draw,
                        after = 3f,
                    )
                    "chart" -> chart(block, draw)
                    "table" -> table(i, block, draw)
                }
            }
            endPage(draw)
            return pageNo
        }

        private fun newPage(draw: Boolean) {
            if (cancelled == id) throw Cancelled()
            pageNo++
            y = MARGIN
            if (draw) {
                val p = pdf!!.startPage(PdfDocument.PageInfo.Builder(WIDTH, HEIGHT, pageNo).create())
                page = p
                canvas = p.canvas
            }
        }

        private fun endPage(draw: Boolean) {
            if (!draw) return
            val c = canvas!!
            val footer = doc.getString("footer")
                .replace("{page}", "$pageNo").replace("{pages}", "$pages")
            val w = footerPaint.measureText(footer)
            c.drawText(footer, (WIDTH - w) / 2, HEIGHT - MARGIN / 2, footerPaint)
            pdf!!.finishPage(page!!)
            if (pageNo % PART_PAGES == 0 && pageNo < pages) {
                writePart()
                pdf = PdfDocument()
            }
            if (pageNo % 10 == 0 || pageNo == pages) {
                val done = pageNo
                main.post {
                    channel.invokeMethod("progress", mapOf("id" to id, "page" to done, "pages" to pages))
                }
            }
        }

        /** Room left above the footer. */
        private fun room() = BOTTOM - y

        private fun breakPage(draw: Boolean) {
            endPage(draw)
            newPage(draw)
        }

        private fun text(s: String, p: TextPaint, draw: Boolean, before: Float = 0f, after: Float = 0f) {
            val layout = StaticLayout.Builder.obtain(s, 0, s.length, p, CONTENT.toInt())
                .setAlignment(Layout.Alignment.ALIGN_NORMAL).build()
            if (before + layout.height > room() && y > MARGIN) breakPage(draw)
            if (y > MARGIN) y += before
            if (draw) {
                val c = canvas!!
                c.save(); c.translate(MARGIN, y); layout.draw(c); c.restore()
            }
            y += layout.height + after
        }

        /**
         * A chart and its legend (owner, 2026-10-10): `bars` (a row per
         * slice: name, bar, value), or a `pie` / `donut` with the legend at
         * its right. Rows past the page's end go on the next page.
         */
        private fun chart(block: JSONObject, draw: Boolean) {
            val slices = block.getJSONArray("slices")
            val n = slices.length()
            if (n == 0) return
            val kind = block.optString("kind", "bars")
            val row = 15f
            val round = kind != "bars"
            // The graphic and as many rows as fit beside it start together.
            val first = if (round) maxOf(DONUT, minOf(n, 6) * row) else minOf(n, 3) * row
            if (first + 8f > room()) breakPage(draw)
            if (round && draw) round(block, kind == "donut")
            val legendX = if (round) MARGIN + DONUT + 16f else MARGIN
            val legendWidth = MARGIN + CONTENT - legendX
            val top = y
            var maxF = 0.0
            for (i in 0 until n) maxF = maxOf(maxF, slices.getJSONObject(i).getDouble("f"))
            for (i in 0 until n) {
                if (row > room()) breakPage(draw)
                if (draw) {
                    val s = slices.getJSONObject(i)
                    val c = canvas!!
                    val swatch = Paint().apply { color = Color.parseColor(s.getString("color")) }
                    val value = s.getString("value")
                    val vw = body.measureText(value)
                    c.drawText(value, legendX + legendWidth - vw, y + 11, body)
                    if (round) {
                        c.drawRect(legendX, y + 3, legendX + 9, y + 12, swatch)
                        drawLabel(s.getString("label"), legendX + 14, legendWidth - vw - 24)
                    } else {
                        val labelWidth = legendWidth * 0.35f
                        drawLabel(s.getString("label"), legendX, labelWidth - 6)
                        val barRoom = legendWidth - labelWidth - vw - 12
                        val f = if (maxF > 0) s.getDouble("f") / maxF else 0.0
                        val w = maxOf(2f, (barRoom * f).toFloat())
                        c.drawRect(legendX + labelWidth, y + 3, legendX + labelWidth + w, y + 12, swatch)
                    }
                }
                y += row
            }
            if (round) y = maxOf(y, top + DONUT)
            y += 8f
        }

        private fun drawLabel(label: String, x: Float, width: Float) {
            val text = TextUtils.ellipsize(label, body, maxOf(width, 10f), TextUtils.TruncateAt.END).toString()
            canvas!!.drawText(text, x, y + 11, body)
        }

        /** A pie, or a donut with the total in its hole, at the top left. */
        private fun round(block: JSONObject, donut: Boolean) {
            val c = canvas!!
            val slices = block.getJSONArray("slices")
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            val inset = if (donut) DONUT * 0.45f / 4 else 0f
            if (donut) {
                paint.style = Paint.Style.STROKE
                paint.strokeWidth = DONUT * 0.45f / 2
            }
            val oval = RectF(MARGIN + inset, y + inset, MARGIN + DONUT - inset, y + DONUT - inset)
            // Sweeps and gap from Dart (ringSweeps, as the card's donut): a
            // small slice keeps its minimum instead of vanishing.
            val gap = block.optDouble("gap", 0.0).toFloat()
            var start = -90f
            for (i in 0 until slices.length()) {
                val s = slices.getJSONObject(i)
                val sweep = s.getDouble("sweep").toFloat()
                paint.color = Color.parseColor(s.getString("color"))
                c.drawArc(oval, start, sweep, !donut, paint)
                start += sweep + gap
            }
            if (!donut) return
            val center = block.getString("center")
            val cw = bold.measureText(center)
            val scale = minOf(1f, DONUT * 0.5f / cw)
            c.save()
            c.translate(MARGIN + DONUT / 2, y + DONUT / 2)
            c.scale(scale, scale)
            c.drawText(center, -cw / 2, BODY / 3, bold)
            c.restore()
        }

        private fun table(index: Int, block: JSONObject, draw: Boolean) {
            val header = block.getJSONArray("header")
            val rows = block.getJSONArray("rows")
            val t = tables.getOrPut(index) { measure(block) }
            fun drawHeader() {
                drawRow(header, t.widths, t.end, bold, 0, draw, under = t.headerHeight)
                y += t.headerHeight
            }
            if (t.headerHeight * 2 > room()) breakPage(draw)
            drawHeader()
            for (r in 0 until rows.length()) {
                val row = rows.getJSONObject(r)
                val style = row.getString("style")
                val h = t.rowHeights[r]
                // A group line is never a page's last line: it needs its
                // first row below it.
                val next = if (style == "group" && r + 1 < rows.length()) t.rowHeights[r + 1] else 0f
                if (h + next > room()) {
                    breakPage(draw)
                    drawHeader()
                }
                if (draw && style != "row") {
                    canvas!!.drawRect(MARGIN, y, MARGIN + CONTENT, y + h, shade)
                }
                val p = if (style == "row") body else bold
                drawRow(row.getJSONArray("cells"), t.widths, t.end, p, row.optInt("indent"), draw, under = null)
                y += h
            }
            y += 6f
        }

        /** A table's column widths and row heights, measured once. */
        private fun measure(block: JSONObject): TableLayout {
            val columns = block.getJSONArray("columns")
            val header = block.getJSONArray("header")
            val rows = block.getJSONArray("rows")
            val n = columns.length()
            val end = BooleanArray(n) { columns.getJSONObject(it).getBoolean("end") }
            val widths = FloatArray(n) { (columns.getJSONObject(it).getDouble("w") * CONTENT).toFloat() }
            fitNumbers(widths, end, header, rows)
            val heights = FloatArray(rows.length()) { r ->
                val row = rows.getJSONObject(r)
                val p = if (row.getString("style") == "row") body else bold
                rowHeight(row.getJSONArray("cells"), widths, p, row.optInt("indent"))
            }
            return TableLayout(widths, end, rowHeight(header, widths, bold, 0), heights)
        }

        /** Number columns as wide as their widest text, taken from the widest text column. */
        private fun fitNumbers(widths: FloatArray, end: BooleanArray, header: JSONArray, rows: JSONArray) {
            for (col in widths.indices) {
                if (!end[col]) continue
                var widest = bold.measureText(header.optString(col))
                for (r in 0 until rows.length()) {
                    val cells = rows.getJSONObject(r).getJSONArray("cells")
                    widest = maxOf(widest, bold.measureText(cells.optString(col)))
                }
                val need = widest + PAD * 2
                if (need > widths[col]) {
                    val donor = widths.indices.filter { !end[it] }.maxByOrNull { widths[it] } ?: continue
                    val take = minOf(need - widths[col], widths[donor] - 40f)
                    if (take > 0) {
                        widths[col] += take
                        widths[donor] -= take
                    }
                }
            }
        }

        private fun rowHeight(cells: JSONArray, widths: FloatArray, p: TextPaint, indent: Int): Float {
            var lines = 1
            for (col in widths.indices) {
                val s = cells.optString(col)
                val room = widths[col] - PAD * 2 - if (col == 0) indent * INDENT else 0f
                if (p.measureText(s) > room) lines = 2
            }
            return lines * LINE_HEIGHT + PAD * 2
        }

        /** A row's cells; [under] is the row's height when a line goes under it. */
        private fun drawRow(
            cells: JSONArray, widths: FloatArray, end: BooleanArray, p: TextPaint,
            indent: Int, draw: Boolean, under: Float?,
        ) {
            if (!draw) return
            val c = canvas!!
            var x = MARGIN
            for (col in widths.indices) {
                val s = cells.optString(col)
                val shift = if (col == 0) indent * INDENT else 0f
                val room = widths[col] - PAD * 2 - shift
                val w = p.measureText(s)
                if (w <= room) {
                    val left = if (end[col]) x + widths[col] - PAD - w else x + PAD + shift
                    c.drawText(s, left, y + PAD + BODY, p)
                } else {
                    val layout = StaticLayout.Builder.obtain(s, 0, s.length, p, room.toInt().coerceAtLeast(1))
                        .setMaxLines(2).setEllipsize(TextUtils.TruncateAt.END)
                        .setAlignment(if (end[col]) Layout.Alignment.ALIGN_OPPOSITE else Layout.Alignment.ALIGN_NORMAL)
                        .build()
                    c.save(); c.translate(x + PAD + shift, y + PAD); layout.draw(c); c.restore()
                }
                x += widths[col]
            }
            if (under != null) c.drawLine(MARGIN, y + under, MARGIN + CONTENT, y + under, line)
        }
    }

    companion object {
        const val NAME = "expense_tracker/report_pdf"

        /** Pages per part (memory: about 25 MB of recorded pages each). */
        private const val PART_PAGES = 100

        // A4 portrait in points, 36 pt margins (P8-21).
        private const val WIDTH = 595
        private const val HEIGHT = 842
        private const val MARGIN = 36f
        private const val CONTENT = WIDTH - 2 * MARGIN
        private const val BOTTOM = HEIGHT - MARGIN - 14f
        private const val BODY = 10f
        private const val LINE_HEIGHT = 13f
        private const val PAD = 3f
        private const val INDENT = 10f
        private const val DONUT = 120f
        private val MUTED = Color.rgb(0x60, 0x60, 0x60)
        private val SHADE = Color.rgb(0xF0, 0xF0, 0xF0)
        private val LINE = Color.rgb(0xB0, 0xB0, 0xB0)

        private fun paint(size: Float, bold: Boolean = false, color: Int = Color.BLACK) =
            TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                textSize = size
                this.color = color
                if (bold) typeface = Typeface.DEFAULT_BOLD
            }
    }
}
