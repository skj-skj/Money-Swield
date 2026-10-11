package com.skj.expense.tracker.my_expense_tracker_app

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.provider.Telephony
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * `expense_tracker/sms` (phase-9a.md §6.4): reads bank SMS from the inbox
 * and asks for READ_SMS. Own code, no plugin (P9a-26), in both flavors;
 * the permission itself is declared only in the flavor manifests, and
 * `status.built` reads the merged manifest, so play built with `-PnoSms`
 * hides the feature without a BuildConfig flag.
 *
 * The app only reads: rows go to Dart for one scan and are never written
 * anywhere (phase-9a.md P9a-19).
 */
class SmsChannel(messenger: BinaryMessenger, context: Context) :
    MethodChannel.MethodCallHandler {

    private val appContext = context.applicationContext
    private val channel = MethodChannel(messenger, NAME)
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    private var activity: Activity? = null

    /** The permission dialog's call, while open: one at a time. */
    private var pending: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler(this)
    }

    fun attach(activity: Activity) {
        this.activity = activity
    }

    /**
     * Like [PendingActivityCall.detach]: when the activity goes away for
     * good with the dialog open, the call is answered with the state as it
     * is, so a later request isn't refused as busy.
     */
    fun detach(activity: Activity) {
        if (this.activity !== activity) return
        this.activity = null
        if (activity.isFinishing && !activity.isChangingConfigurations) {
            pending?.success(isGranted())
            pending = null
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(
                mapOf(
                    "built" to isBuilt(),
                    "granted" to isGranted(),
                    "canAsk" to canAsk(),
                ),
            )
            "request" -> request(result)
            "openSettings" -> openSettings(result)
            "read" -> read(
                call.argument<Number>("sinceMs")!!.toLong(),
                call.argument<Number>("limit")!!.toInt(),
                result,
            )
            else -> result.notImplemented()
        }
    }

    /** Whether the merged manifest asks for READ_SMS. */
    private fun isBuilt(): Boolean {
        val info = appContext.packageManager.getPackageInfo(
            appContext.packageName,
            PackageManager.GET_PERMISSIONS,
        )
        return info.requestedPermissions?.contains(Manifest.permission.READ_SMS) == true
    }

    private fun isGranted(): Boolean =
        appContext.checkSelfPermission(Manifest.permission.READ_SMS) ==
            PackageManager.PERMISSION_GRANTED

    private fun canAsk(): Boolean = SmsPermissionRule.canAsk(
        granted = isGranted(),
        askedBefore = prefs().getBoolean(ASKED_KEY, false),
        showRationale = activity?.shouldShowRequestPermissionRationale(
            Manifest.permission.READ_SMS,
        ) ?: true,
    )

    private fun request(result: MethodChannel.Result) {
        if (isGranted()) {
            result.success(true)
            return
        }
        if (pending != null) {
            result.error("busy", "The permission dialog is already open", null)
            return
        }
        val activity = activity
        if (activity == null) {
            result.error("noActivity", "The app is not in front", null)
            return
        }
        pending = result
        // Device-local, not in the database: a backup must not carry it to
        // another phone (phase-9a.md §6.4).
        prefs().edit().putBoolean(ASKED_KEY, true).apply()
        activity.requestPermissions(arrayOf(Manifest.permission.READ_SMS), REQUEST_CODE)
    }

    /** From [MainActivity.onRequestPermissionsResult]; whether it was ours. */
    fun onRequestPermissionsResult(requestCode: Int): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val call = pending ?: return true
        pending = null
        call.success(isGranted())
        return true
    }

    private fun openSettings(result: MethodChannel.Result) {
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", appContext.packageName, null),
        )
        val from = activity
        if (from != null) {
            from.startActivity(intent)
        } else {
            appContext.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
        result.success(null)
    }

    /**
     * Inbox rows with `date >= sinceMs`, oldest first, at most [limit], on
     * a background thread. The limit is applied while reading the cursor,
     * not as SQL `LIMIT` in the sort order, which providers needn't honour.
     */
    private fun read(sinceMs: Long, limit: Int, result: MethodChannel.Result) {
        io.execute {
            val answer = try {
                val rows = ArrayList<Map<String, Any>>()
                appContext.contentResolver.query(
                    Telephony.Sms.Inbox.CONTENT_URI,
                    arrayOf(Telephony.Sms.ADDRESS, Telephony.Sms.BODY, Telephony.Sms.DATE),
                    "${Telephony.Sms.DATE} >= ?",
                    arrayOf(sinceMs.toString()),
                    "${Telephony.Sms.DATE} ASC",
                )?.use { cursor ->
                    val address = cursor.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
                    val body = cursor.getColumnIndexOrThrow(Telephony.Sms.BODY)
                    val date = cursor.getColumnIndexOrThrow(Telephony.Sms.DATE)
                    while (rows.size < limit && cursor.moveToNext()) {
                        SmsRows.of(
                            address = if (cursor.isNull(address)) null else cursor.getString(address),
                            body = if (cursor.isNull(body)) null else cursor.getString(body),
                            date = if (cursor.isNull(date)) null else cursor.getLong(date),
                        )?.let(rows::add)
                    }
                }
                CallAnswer.Value(rows)
            } catch (e: SecurityException) {
                CallAnswer.Error("noPermission", e.toString())
            } catch (e: Exception) {
                CallAnswer.Error("ioError", e.toString())
            }
            main.post {
                when (answer) {
                    is CallAnswer.Value -> result.success(answer.value)
                    is CallAnswer.Error -> result.error(answer.code, answer.message, null)
                }
            }
        }
    }

    private fun prefs() = appContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private companion object {
        const val NAME = "expense_tracker/sms"
        const val REQUEST_CODE = 4301
        const val PREFS = "sms_permission"
        const val ASKED_KEY = "asked_once"
    }
}

/** Plain functions of [SmsChannel], tested on the JVM (`make test-android`). */
object SmsRows {
    /** One inbox row for Dart, or null when it has no sender, body or date. */
    fun of(address: String?, body: String?, date: Long?): Map<String, Any>? {
        if (address == null || body == null || date == null) return null
        return mapOf("address" to address, "body" to body, "date" to date)
    }
}

object SmsPermissionRule {
    /**
     * Whether Android will still show its dialog: always before the first
     * ask; after a refusal only while it wants a rationale. Refused with
     * "Don't allow" twice, it shows nothing and only the app's settings
     * page can grant it (phase-9a.md P9a-30).
     */
    fun canAsk(granted: Boolean, askedBefore: Boolean, showRationale: Boolean): Boolean =
        granted || !askedBefore || showRationale
}
