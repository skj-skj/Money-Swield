package com.skj.expense.tracker.my_expense_tracker_app

import java.io.File
import java.io.IOException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

/**
 * Joining the report's PDF parts. The parts are built here the way Skia writes
 * them: a catalog, an info dictionary and a balanced page tree whose nodes'
 * object order isn't the page order.
 */
class PdfJoinTest {
    @get:Rule
    val folder = TemporaryFolder()

    private val latin1 = Charsets.ISO_8859_1

    /** A PDF of [objects] (object 1 first), with [root] and [info]. */
    private fun pdf(name: String, objects: List<String>, root: Int, info: Int): File {
        val out = StringBuilder("%PDF-1.4\n%âãÏÓ\n")
        val offsets = objects.mapIndexed { i, body ->
            val at = out.length
            out.append("${i + 1} 0 obj\n$body\nendobj\n")
            at
        }
        val xrefAt = out.length
        out.append("xref\n0 ${objects.size + 1}\n0000000000 65535 f \n")
        for (at in offsets) out.append(String.format("%010d 00000 n \n", at))
        out.append("trailer\n<</Size ${objects.size + 1}\n/Root $root 0 R\n/Info $info 0 R>>\n")
        out.append("startxref\n$xrefAt\n%%EOF\n")
        return folder.newFile(name).apply { writeBytes(out.toString().toByteArray(latin1)) }
    }

    private fun stream(text: String) = "<</Length ${text.length}>> stream\n$text\nendstream"

    private fun page(parent: Int, contents: Int) =
        "<</Type /Page\n/Parent $parent 0 R\n/Contents $contents 0 R>>"

    /**
     * Three pages under two nodes listed out of object order: the root's
     * kids are node 4 (pages A, B) then node 3 (page C).
     */
    private fun treePart(name: String, tag: String) = pdf(
        name,
        listOf(
            "<</Producer (Skia/PDF)>>",
            "<</Type /Pages\n/Count 3\n/Kids [4 0 R 3 0 R]>>",
            "<</Type /Pages\n/Parent 2 0 R\n/Count 1\n/Kids [7 0 R]>>",
            "<</Type /Pages\n/Parent 2 0 R\n/Count 2\n/Kids [5 0 R 6 0 R]>>",
            page(4, 9),
            page(4, 10),
            page(3, 11),
            "<</Type /Catalog\n/Pages 2 0 R>>",
            stream("${tag}A"),
            stream("${tag}B"),
            stream("${tag}C"),
        ),
        root = 8,
        info = 1,
    )

    /** The joined file's pages, each as its content stream's text. */
    private fun pagesOf(file: File): List<String> {
        val text = String(file.readBytes(), latin1)
        val xrefAt = text.substringAfterLast("startxref\n").substringBefore("\n").toInt()
        val lines = text.substring(xrefAt).lines()
        val size = lines[1].split(" ")[1].toInt()
        val offsets = lines.drop(3).take(size - 1).map { it.substring(0, 10).toInt() }
        fun obj(n: Int): String {
            val at = offsets[n - 1]
            assertTrue("xref of $n", text.startsWith("$n 0 obj\n", at))
            return text.substring(at, text.indexOf("endobj", at))
        }
        fun refOf(dict: String, key: String) =
            Regex("""/$key (\d+) 0 R""").find(dict)!!.groupValues[1].toInt()

        val root = refOf(text.substringAfterLast("trailer"), "Root")
        val pages = refOf(obj(root), "Pages")
        val tree = obj(pages)
        val kids = Regex("""(\d+) 0 R""").findAll(tree.substringAfter("/Kids [")).map {
            it.groupValues[1].toInt()
        }.toList()
        assertTrue(tree.contains("/Count ${kids.size}"))
        return kids.map { kid ->
            val dict = obj(kid)
            assertTrue("$kid is a page: $dict", dict.contains("/Type /Page\n"))
            assertEquals(pages, refOf(dict, "Parent"))
            obj(refOf(dict, "Contents")).substringAfter("stream\n").substringBefore("\nendstream")
        }
    }

    /**
     * Regression (2026-10-11): the join took every `/Pages` node's kids as
     * pages, in object order, so a long report listed emptied nodes as
     * pages (qpdf: "/Type key should be /Page") and could reorder pages.
     */
    @Test
    fun pagesFollowEachPartsTreeInOrder() {
        val out = folder.newFile("joined.pdf")
        PdfJoin.join(listOf(treePart("a.pdf", "1"), treePart("b.pdf", "2")), out)
        assertEquals(listOf("1A", "1B", "1C", "2A", "2B", "2C"), pagesOf(out))
    }

    @Test
    fun aFlatTreeJoinsToo() {
        val flat = pdf(
            "flat.pdf",
            listOf(
                "<</Producer (Skia/PDF)>>",
                "<</Type /Pages\n/Count 1\n/Kids [3 0 R]>>",
                page(2, 5),
                "<</Type /Catalog\n/Pages 2 0 R>>",
                stream("F"),
            ),
            root = 4,
            info = 1,
        )
        val out = folder.newFile("joined.pdf")
        PdfJoin.join(listOf(flat, treePart("t.pdf", "T")), out)
        assertEquals(listOf("F", "TA", "TB", "TC"), pagesOf(out))
    }

    @Test(expected = IOException::class)
    fun aKidThatIsNoPageThrows() {
        val bad = pdf(
            "bad.pdf",
            listOf(
                "<</Producer (Skia/PDF)>>",
                "<</Type /Pages\n/Count 1\n/Kids [1 0 R]>>",
                "<</Type /Catalog\n/Pages 2 0 R>>",
            ),
            root = 3,
            info = 1,
        )
        PdfJoin.join(listOf(bad), folder.newFile("joined.pdf"))
    }
}
