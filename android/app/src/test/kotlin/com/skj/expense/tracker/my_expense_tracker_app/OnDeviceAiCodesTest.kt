package com.skj.expense.tracker.my_expense_tracker_app

import org.junit.Assert.assertEquals
import org.junit.Test

/** The on-device AI channel's words (phase-9b.md §11, Kotlin). */
class OnDeviceAiCodesTest {

    @Test
    fun errorCodesMapToWhatTheScannerActsOn() {
        assertEquals("background", OnDeviceAiCodes.errorOf(30))
        assertEquals("busy", OnDeviceAiCodes.errorOf(9))
        assertEquals("quota", OnDeviceAiCodes.errorOf(27))
        // REQUEST_TOO_LARGE, NOT_AVAILABLE, UNKNOWN: the regex reads that SMS.
        assertEquals("failed", OnDeviceAiCodes.errorOf(12))
        assertEquals("failed", OnDeviceAiCodes.errorOf(8))
        assertEquals("failed", OnDeviceAiCodes.errorOf(0))
    }

    @Test
    fun featureStatusMapsToTheChannelsStatus() {
        assertEquals("unavailable", OnDeviceAiCodes.statusOf(0))
        assertEquals("downloadable", OnDeviceAiCodes.statusOf(1))
        assertEquals("downloading", OnDeviceAiCodes.statusOf(2))
        assertEquals("available", OnDeviceAiCodes.statusOf(3))
        assertEquals("unavailable", OnDeviceAiCodes.statusOf(99))
    }

    @Test
    fun theStableModelWinsThenAnAvailablePreview() {
        assertEquals(OnDeviceAiCodes.Choice("available", false), OnDeviceAiCodes.choose(3, null))
        // The owner's Pixel: stable downloadable, preview installed.
        assertEquals(OnDeviceAiCodes.Choice("available", true), OnDeviceAiCodes.choose(1, 3))
        // Neither in: the stable model's status, so its download is offered.
        assertEquals(OnDeviceAiCodes.Choice("downloadable", false), OnDeviceAiCodes.choose(1, 1))
        assertEquals(OnDeviceAiCodes.Choice("downloading", false), OnDeviceAiCodes.choose(2, 0))
        assertEquals(OnDeviceAiCodes.Choice("unavailable", false), OnDeviceAiCodes.choose(0, 0))
    }
}
