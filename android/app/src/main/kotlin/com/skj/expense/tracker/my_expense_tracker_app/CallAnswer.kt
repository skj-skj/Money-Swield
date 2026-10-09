package com.skj.expense.tracker.my_expense_tracker_app

/** The picture can't be decoded: the channel's `notAnImage`. */
class NotAnImage(cause: Throwable?) : Exception(cause)

/** The phone's storage is full: the channel's `noSpace`. */
class NoSpace(cause: Throwable) : Exception(cause)

/**
 * The answer to one method call that ran in the background: a value, or an
 * error code from `photo_service.dart`'s `PhotoError` with a message for
 * the log. Plain Kotlin, so a JVM unit test can check it.
 */
sealed class CallAnswer {
    data class Value(val value: Any?) : CallAnswer()

    data class Error(val code: String, val message: String) : CallAnswer()

    companion object {
        /**
         * Runs [work] and turns what it throws into an [Error] answer.
         *
         * [OutOfMemoryError] is caught too, wherever it happens (decoding,
         * turning or encoding a large picture): it is an Error, not an
         * Exception, and uncaught on the channel's executor thread it would
         * kill the app with the Dart call never answered. Other Errors are
         * bugs and are left to crash.
         */
        fun of(work: () -> Any?): CallAnswer =
            try {
                Value(work())
            } catch (e: NotAnImage) {
                Error("notAnImage", e.cause.toString())
            } catch (e: NoSpace) {
                Error("noSpace", e.cause.toString())
            } catch (e: OutOfMemoryError) {
                Error("tooLarge", "The picture is too large: $e")
            } catch (e: Exception) {
                Error("ioError", e.toString())
            }
    }
}
