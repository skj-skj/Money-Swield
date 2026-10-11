package com.skj.expense.tracker.my_expense_tracker_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The plain parts of SmsChannel (phase-9a.md §12, Kotlin). */
class SmsChannelTest {

    @Test
    fun aRowWithoutSenderBodyOrDateIsSkipped() {
        assertNull(SmsRows.of(address = null, body = "Rs 5 debited", date = 1L))
        assertNull(SmsRows.of(address = "VM-ABCBNK-S", body = null, date = 1L))
        assertNull(SmsRows.of(address = "VM-ABCBNK-S", body = "x", date = null))
    }

    @Test
    fun aRowKeepsItsValues() {
        assertEquals(
            mapOf("address" to "VM-ABCBNK-S", "body" to "", "date" to 5L),
            SmsRows.of(address = "VM-ABCBNK-S", body = "", date = 5L),
        )
    }

    @Test
    fun canAskUntilRefusedForGood() {
        // Never asked: the dialog shows.
        assertTrue(SmsPermissionRule.canAsk(granted = false, askedBefore = false, showRationale = false))
        // Refused once: Android wants a rationale and shows it again.
        assertTrue(SmsPermissionRule.canAsk(granted = false, askedBefore = true, showRationale = true))
        // Refused twice ("Don't allow"): only the settings page can grant it.
        assertFalse(SmsPermissionRule.canAsk(granted = false, askedBefore = true, showRationale = false))
        // Granted (e.g. in Settings after that): nothing to ask.
        assertTrue(SmsPermissionRule.canAsk(granted = true, askedBefore = true, showRationale = false))
    }
}
