package com.skj.expense.tracker.my_expense_tracker_app

import java.io.IOException
import org.junit.Assert.assertEquals
import org.junit.Test

/** How a background photo call's outcome becomes the channel's answer. */
class CallAnswerTest {

    @Test
    fun aValueIsAnswered() {
        assertEquals(CallAnswer.Value(42L), CallAnswer.of { 42L })
    }

    @Test
    fun eachKnownFailureHasItsCode() {
        val cause = IOException("bad header")
        assertEquals(
            CallAnswer.Error("notAnImage", cause.toString()),
            CallAnswer.of { throw NotAnImage(cause) },
        )
        assertEquals(
            CallAnswer.Error("noSpace", cause.toString()),
            CallAnswer.of { throw NoSpace(cause) },
        )
        assertEquals("ioError", (CallAnswer.of { throw cause } as CallAnswer.Error).code)
    }

    /**
     * Out of memory while turning or encoding a large picture (after the
     * decode) is an Error, not an Exception: uncaught on the channel's
     * executor thread it would kill the app, and the Dart call would never
     * be answered. It must answer `tooLarge` like a decode that ran out.
     */
    @Test
    fun outOfMemoryIsTooLargeNotACrash() {
        val answer = CallAnswer.of { throw OutOfMemoryError("Failed to allocate a 50331660 byte allocation") }
        assertEquals("tooLarge", (answer as CallAnswer.Error).code)
    }
}
