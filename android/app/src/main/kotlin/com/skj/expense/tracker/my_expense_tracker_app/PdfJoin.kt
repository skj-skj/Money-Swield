package com.skj.expense.tracker.my_expense_tracker_app

import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.RandomAccessFile

/**
 * Joins PDFs that Android's `PdfDocument` wrote into one (phase-8.md §12a,
 * owner 2026-10-11): a report is written in parts of a hundred pages, so
 * memory stays bounded however long it is, then joined here.
 *
 * Only for these files, not any PDF: they are PDF 1.4 with a classic
 * `xref` table, no object streams, a `/Catalog` and a page tree (checked
 * on the Oppo, Android 14, and with `qpdf --check`). Skia balances that
 * tree: past a few pages the root's kids are `/Pages` nodes, not pages, and
 * the nodes' object order isn't the page order, so each part's tree is
 * walked from its catalog to list the pages in order. Each part's objects
 * are copied with their numbers moved past the previous parts'; references
 * are rewritten in the dictionaries only, never inside stream data; the
 * parts' `/Pages` nodes, `/Catalog` and `/Info` become empty dictionaries,
 * and one `/Pages` holding every page in order is written with a new
 * catalog. Anything unexpected throws: the caller deletes what it wrote.
 */
object PdfJoin {
    private val ref = Regex("""(\d+) 0 R""")
    private val streamStart = Regex(""">>\s*stream\r?\n""")
    private val latin1 = Charsets.ISO_8859_1

    /** A part's trailer (its last bytes) and its object count. */
    private class Part(val file: File, val size: Int, val trailer: String)

    fun join(files: List<File>, out: File) {
        // Only the trailers first (object counts for the numbering); each
        // part's body is read when it is copied, so one part at a time is
        // in memory, as when it was drawn.
        val parts = files.map { file ->
            val trailer = trailerOf(file)
            val size = Regex("""/Size (\d+)""").find(trailer)?.groupValues?.get(1)?.toInt()
                ?: throw IOException("no /Size in ${file.name}")
            Part(file, size, trailer)
        }
        val total = parts.sumOf { it.size - 1 }
        val pages = total + 1
        val catalog = total + 2
        val kids = mutableListOf<Int>()
        val offsets = LongArray(catalog)
        FileOutputStream(out).use { file ->
            var position = 0L
            fun write(s: String) {
                val bytes = s.toByteArray(latin1)
                file.write(bytes)
                position += bytes.size
            }
            write("%PDF-1.4\n%âãÏÓ\n")
            var base = 0
            for (part in parts) {
                // Byte for byte as text: ISO-8859-1 maps every byte to one char.
                val text = String(part.file.readBytes(), latin1)
                val info = Regex("""/Info (\d+) 0 R""").find(part.trailer)?.groupValues?.get(1)?.toInt()
                // "xref", "0 N", then object 0's entry, then 1 … N-1.
                val entries = text.substring(text.lastIndexOf("\nxref") + 1)
                    .lineSequence().drop(3).take(part.size - 1).toList()
                val objs = entries.map { entry ->
                    val at = entry.substring(0, 10).trim().toInt()
                    text.substring(at, text.indexOf("endobj", at) + "endobj".length)
                }
                fun dictOf(n: Int): String {
                    val obj = objs.getOrNull(n - 1) ?: throw IOException("no object $n")
                    return streamStart.find(obj)?.let { obj.substring(0, it.range.first) } ?: obj
                }
                val root = Regex("""/Root (\d+) 0 R""").find(part.trailer)?.groupValues?.get(1)?.toInt()
                    ?: throw IOException("no /Root")
                val top = Regex("""/Pages (\d+) 0 R""").find(dictOf(root))?.groupValues?.get(1)?.toInt()
                    ?: throw IOException("no /Pages")
                val nodes = mutableSetOf<Int>()
                // Depth first, kids in their order: the pages in reading order.
                fun walk(n: Int) {
                    val dict = dictOf(n)
                    if ("/Type /Pages" in dict) {
                        if (!nodes.add(n)) throw IOException("page tree loops at $n")
                        val list = Regex("""/Kids \[([^\]]*)]""").find(dict)?.groupValues?.get(1)
                            ?: throw IOException("no /Kids in $n")
                        ref.findAll(list).forEach { walk(it.groupValues[1].toInt()) }
                    } else if (Regex("""/Type /Page\b""").containsMatchIn(dict)) {
                        kids += n + base
                    } else {
                        throw IOException("$n is not a page")
                    }
                }
                walk(top)
                for ((i, obj) in objs.withIndex()) {
                    val n = i + 1
                    val id = n + base
                    offsets[id - 1] = position
                    if (n in nodes || n == root || n == info) {
                        write("$id 0 obj\n<<>>\nendobj\n")
                    } else {
                        write(renumber(obj, base, pages) + "\n")
                    }
                }
                base += part.size - 1
            }
            check(base == total) { "parts changed size" }
            offsets[pages - 1] = position
            write("$pages 0 obj\n<</Type /Pages\n/Count ${kids.size}\n/Kids [${kids.joinToString(" ") { "$it 0 R" }}]>>\nendobj\n")
            offsets[catalog - 1] = position
            write("$catalog 0 obj\n<</Type /Catalog\n/Pages $pages 0 R>>\nendobj\n")
            val xrefAt = position
            val xref = StringBuilder("xref\n0 ${catalog + 1}\n0000000000 65535 f \n")
            for (offset in offsets) xref.append(String.format("%010d 00000 n \n", offset))
            xref.append("trailer\n<</Size ${catalog + 1}\n/Root $catalog 0 R>>\nstartxref\n$xrefAt\n%%EOF\n")
            write(xref.toString())
            file.fd.sync()
        }
    }

    /**
     * The end of [file] from its last `trailer` on: read from the file's
     * tail, the whole file only when the trailer isn't within it.
     */
    private fun trailerOf(file: File): String {
        RandomAccessFile(file, "r").use { f ->
            val length = f.length()
            val tail = minOf(length, TAIL.toLong()).toInt()
            val bytes = ByteArray(tail)
            f.seek(length - tail)
            f.readFully(bytes)
            val text = String(bytes, latin1)
            val at = text.lastIndexOf("trailer")
            if (at >= 0) return text.substring(at)
        }
        val text = String(file.readBytes(), latin1)
        val at = text.lastIndexOf("trailer")
        if (at < 0) throw IOException("no trailer in ${file.name}")
        return text.substring(at)
    }

    /** Bytes read from a part's end to find its trailer. */
    private const val TAIL = 4096

    /**
     * [obj] (`n 0 obj … endobj`) with its number and every reference in its
     * dictionary moved by [base]; a page's `/Parent` becomes [pages]. Stream
     * data is copied byte for byte.
     */
    private fun renumber(obj: String, base: Int, pages: Int): String {
        val split = streamStart.find(obj)?.range?.first ?: obj.length
        val head = obj.substring(0, split)
        val tail = obj.substring(split)
        val id = head.substringBefore(" 0 obj").trim().toInt()
        var dict = head.substringAfter(" 0 obj")
        dict = ref.replace(dict) { "${it.groupValues[1].toInt() + base} 0 R" }
        dict = Regex("""/Parent \d+ 0 R""").replace(dict, "/Parent $pages 0 R")
        return "${id + base} 0 obj$dict$tail"
    }
}
