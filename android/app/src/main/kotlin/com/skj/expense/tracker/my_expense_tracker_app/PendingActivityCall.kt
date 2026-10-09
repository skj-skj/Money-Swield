package com.skj.expense.tracker.my_expense_tracker_app

import android.app.Activity
import android.content.Intent

/**
 * One activity started for a result on behalf of a method call, at most
 * one at a time (phase-3.md §7, phase-6.md R8). Shared by the documents
 * and photos channels, each with its own [requestCode].
 *
 * The channels live with the cached engine, so they outlive any one
 * activity: [MainActivity] attaches itself in `onCreate`, detaches in
 * `onDestroy` and forwards `onActivityResult`. If Android recreates the
 * activity while the dialog is open (a configuration change), the new
 * activity delivers the result to the same pending call.
 */
class PendingActivityCall(private val requestCode: Int) {

    private class Pending(
        val onResult: (resultCode: Int, data: Intent?) -> Unit,
        val onDropped: () -> Unit,
    )

    private var activity: Activity? = null
    private var pending: Pending? = null

    val isBusy: Boolean get() = pending != null

    fun attach(activity: Activity) {
        this.activity = activity
    }

    /**
     * When the activity goes away for good with a dialog still open, the
     * call is answered as cancelled ([onDropped] of [start]): otherwise
     * every later call would fail with `busy` until the process dies. A
     * configuration change keeps it.
     */
    fun detach(activity: Activity) {
        if (this.activity !== activity) return
        this.activity = null
        if (activity.isFinishing && !activity.isChangingConfigurations) {
            val call = pending
            pending = null
            call?.onDropped?.invoke()
        }
    }

    /**
     * Starts [intent] for a result. Answers the call itself with `busy`
     * while another is open and `noActivity` when the app isn't in front;
     * [onLaunchError] gets the exception when the activity can't be
     * started (no app handles the intent). Otherwise exactly one of
     * [onResult] (the activity finished) or [onDropped] (our activity went
     * away for good first) runs later.
     */
    fun start(
        result: io.flutter.plugin.common.MethodChannel.Result,
        intent: Intent,
        onResult: (resultCode: Int, data: Intent?) -> Unit,
        onDropped: () -> Unit,
        onLaunchError: (Exception) -> Unit,
    ) {
        if (pending != null) {
            result.error("busy", "Another dialog is already open", null)
            return
        }
        val activity = activity
        if (activity == null) {
            result.error("noActivity", "The app is not in front", null)
            return
        }
        pending = Pending(onResult, onDropped)
        try {
            activity.startActivityForResult(intent, requestCode)
        } catch (e: Exception) {
            pending = null
            onLaunchError(e)
        }
    }

    /**
     * Delivers an activity result. Returns whether it was ours, so
     * [MainActivity] can still pass the others on.
     */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != this.requestCode) return false
        val call = pending ?: return true
        pending = null
        call.onResult(resultCode, data)
        return true
    }
}
