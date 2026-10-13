package com.skj.money.swield.expense.tracker

import android.content.Context
import android.util.Log
import com.google.mlkit.genai.common.DownloadStatus
import com.google.mlkit.genai.common.GenAiException
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.GenerativeModel
import com.google.mlkit.genai.prompt.ModelConfig
import com.google.mlkit.genai.prompt.ModelPreference
import com.google.mlkit.genai.prompt.ModelReleaseStage
import com.google.mlkit.genai.prompt.TextPart
import com.google.mlkit.genai.prompt.generateContentRequest
import com.google.mlkit.genai.prompt.generationConfig
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout

/**
 * `money_swield/on_device_ai`, play only: Gemini Nano through AICore, with
 * ML Kit's GenAI Prompt API. The foss build has a class with this name that
 * answers `unavailable` and holds no Google code (`src/foss`).
 *
 * The SMS text is handed to the model on the phone and the answer goes back to
 * Dart; nothing is written or logged.
 */
class OnDeviceAi(messenger: BinaryMessenger, @Suppress("UNUSED_PARAMETER") context: Context) :
    MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, NAME)

    /**
     * Answers go back on the main thread; ML Kit's calls suspend. Whatever
     * escapes a call's own catch is logged, never thrown: an uncaught exception
     * in a coroutine on the main thread crashes the app (seen in a release
     * build). Dart times such a call out.
     */
    private val scope = CoroutineScope(
        SupervisorJob() + Dispatchers.Main +
            CoroutineExceptionHandler { _, e -> Log.w(TAG, "call failed: ${codeOf(e)}") },
    )

    /**
     * The "fast" model (`nano-v4-fast` on the Pixel 11 Pro): one short JSON
     * answer per SMS, about 0.7 s each, so speed matters more than the full
     * model's quality (gate).
     */
    private val stable: GenerativeModel by lazy { client(ModelReleaseStage.STABLE) }

    /**
     * The same model's preview release. The owner's Pixel runs an AICore
     * build whose model is installed as a preview: the stable one reads
     * `downloadable` and its download never answers there (gate, 2026-10-12).
     * Used only when the stable model isn't available and this one is
     * (OnDeviceAiCodes.choose).
     */
    private val preview: GenerativeModel by lazy { client(ModelReleaseStage.PREVIEW) }

    /** What [status] chose last; prompts go to it. */
    private var chosen: GenerativeModel? = null

    /** The model download running, if any: one at a time. */
    private var downloading: Job? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> scope.launch { result.success(status()) }
            "download" -> download(result)
            "prompt" -> prompt(
                call.argument<String>("text")!!,
                call.argument<Number>("timeoutMs")!!.toLong(),
                result,
            )
            else -> result.notImplemented()
        }
    }

    /**
     * `available` / `downloadable` / `downloading` / `unavailable`. Creating
     * a client can throw too (ML Kit not set up: a release build without
     * proguard-play.pro threw a NullPointerException here), so all of it is
     * inside the catch: no model, never a crash.
     */
    private suspend fun status(): String = try {
        val stableStatus = featureStatus(stable)
        val previewStatus =
            if (stableStatus == OnDeviceAiCodes.AVAILABLE) null else featureStatus(preview)
        val choice = OnDeviceAiCodes.choose(stableStatus, previewStatus)
        chosen = if (choice.preview) preview else stable
        choice.status
    } catch (e: CancellationException) {
        throw e
    } catch (e: Exception) {
        Log.w(TAG, "status failed: ${codeOf(e)}")
        chosen = null
        "unavailable"
    }

    /**
     * `checkStatus()`, or UNAVAILABLE when AICore is missing or too old. A
     * Binder call to AICore, so off the main thread (as Google's AI Edge
     * Gallery does).
     */
    private suspend fun featureStatus(model: GenerativeModel): Int = try {
        withContext(Dispatchers.IO) { model.checkStatus() }
    } catch (e: CancellationException) {
        throw e
    } catch (e: Exception) {
        Log.w(TAG, "checkStatus failed: ${codeOf(e)}")
        OnDeviceAiCodes.UNAVAILABLE
    }

    /**
     * Downloads the stable model (only when the user turns the AI on). Answers
     * `true` when it is in, an error when it failed; it may take long, or (seen
     * on the owner's Pixel) never answer, so Dart never waits on it: it shows
     * "Downloading the model…" and reads [status] again. A second call while
     * one runs answers `true` at once.
     */
    private fun download(result: MethodChannel.Result) {
        if (downloading?.isActive == true) {
            result.success(true)
            return
        }
        downloading = scope.launch {
            var answered = false
            try {
                stable.download().collect { status ->
                    when (status) {
                        is DownloadStatus.DownloadCompleted -> if (!answered) {
                            answered = true
                            result.success(true)
                        }
                        is DownloadStatus.DownloadFailed -> if (!answered) {
                            answered = true
                            result.error("failed", "download: ${codeOf(status.e)}", null)
                        }
                        else -> {}
                    }
                }
                if (!answered) result.success(true)
            } catch (e: Exception) {
                if (!answered) result.error("failed", "download: ${codeOf(e)}", null)
            }
        }
    }

    /**
     * One prompt, answered with the model's text, or an error whose code is
     * `background`, `busy`, `quota`, `timeout` or `failed`. The message holds
     * ML Kit's number only, never the text.
     */
    private fun prompt(text: String, timeoutMs: Long, result: MethodChannel.Result) {
        scope.launch {
            try {
                // Dart reads the status before a scan; this covers a prompt
                // without one (a restarted engine).
                if (chosen == null) status()
                val model = chosen ?: stable
                val response = withTimeout(timeoutMs) {
                    model.generateContent(
                        generateContentRequest(TextPart(text)) {
                            // One answer, the likeliest: the same SMS reads
                            // the same way, and nothing creative is wanted.
                            temperature = 0f
                            topK = 1
                            candidateCount = 1
                            maxOutputTokens = MAX_OUTPUT_TOKENS
                        },
                    )
                }
                result.success(response.candidates.firstOrNull()?.text ?: "")
            } catch (e: TimeoutCancellationException) {
                result.error("timeout", "after $timeoutMs ms", null)
            } catch (e: GenAiException) {
                result.error(OnDeviceAiCodes.errorOf(e.errorCode), "code ${e.errorCode}", null)
            } catch (e: Exception) {
                result.error("failed", e.javaClass.simpleName, null)
            }
        }
    }

    private fun client(releaseStage: Int): GenerativeModel = Generation.getClient(
        generationConfig {
            modelConfig = ModelConfig.builder().apply {
                preference = ModelPreference.FAST
                this.releaseStage = releaseStage
            }.build()
        },
    )

    private fun codeOf(e: Throwable): String =
        if (e is GenAiException) "code ${e.errorCode}" else e.javaClass.simpleName

    private companion object {
        const val NAME = "money_swield/on_device_ai"
        const val TAG = "OnDeviceAi"

        /** The JSON answer is under 100 tokens; this caps a rambling one. */
        const val MAX_OUTPUT_TOKENS = 256
    }
}
