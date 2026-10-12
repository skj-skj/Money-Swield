package com.skj.expense.tracker.my_expense_tracker_app

/**
 * The words `expense_tracker/on_device_ai` answers with, from ML Kit's numbers.
 * Plain Kotlin in `src/main`, so it is tested on the JVM in both flavors (`make
 * test-android`) and the foss build needs no ML Kit class to compile it.
 *
 * The numbers are copied from ML Kit GenAI 1.0.0-beta4 (`FeatureStatus`,
 * `GenAiException.ErrorCode`, read with javap), not imported: foss has no ML
 * Kit.
 */
object OnDeviceAiCodes {
    const val UNAVAILABLE = 0
    const val DOWNLOADABLE = 1
    const val DOWNLOADING = 2
    const val AVAILABLE = 3

    /** `FeatureStatus` → the channel's `status` answer. */
    fun statusOf(featureStatus: Int): String = when (featureStatus) {
        AVAILABLE -> "available"
        DOWNLOADABLE -> "downloadable"
        DOWNLOADING -> "downloading"
        else -> "unavailable" // UNAVAILABLE, and anything a later ML Kit adds.
    }

    /** The status Dart sees, and whether prompts go to the preview model. */
    data class Choice(val status: String, val preview: Boolean)

    /**
     * The stable model when it is available; else the preview one when
     * **it** is available (the owner's Pixel has only that one installed);
     * else the stable model's status, so a phone that
     * can download it offers that. [preview] is null when not asked (the
     * stable one was available).
     */
    fun choose(stable: Int, preview: Int?): Choice = when {
        stable == AVAILABLE -> Choice("available", preview = false)
        preview == AVAILABLE -> Choice("available", preview = true)
        else -> Choice(statusOf(stable), preview = false)
    }

    /**
     * `GenAiException.errorCode` → the error the scanner acts on: `background`
     * and `busy` stop the AI pass (retried at the next open), `quota` sends the
     * rest of the scan to the regex, anything else is `failed` (the regex reads
     * that one SMS).
     */
    fun errorOf(errorCode: Int): String = when (errorCode) {
        30 -> "background" // BACKGROUND_USE_BLOCKED: not the top app.
        9 -> "busy" // BUSY: also a short quota used up.
        27 -> "quota" // PER_APP_BATTERY_USE_QUOTA_EXCEEDED: the daily one.
        else -> "failed"
    }
}
