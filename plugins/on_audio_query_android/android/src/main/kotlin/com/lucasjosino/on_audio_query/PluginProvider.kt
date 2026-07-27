package com.lucasjosino.on_audio_query

import android.app.Activity
import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

class SafeResult(private val delegate: MethodChannel.Result) : MethodChannel.Result {
    private var hasReplied = false

    @Synchronized
    override fun success(result: Any?) {
        if (!hasReplied) {
            hasReplied = true
            delegate.success(result)
        }
    }

    @Synchronized
    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
        if (!hasReplied) {
            hasReplied = true
            delegate.error(errorCode, errorMessage, errorDetails)
        }
    }

    @Synchronized
    override fun notImplemented() {
        if (!hasReplied) {
            hasReplied = true
            delegate.notImplemented()
        }
    }
}

/**
 * A singleton used to define all variables/methods that will be used on all plugin.
 *
 * The singleton will provider the ability to 'request' required variables/methods on any moment.
 *
 * All variables/methods should be defined after plugin initialization (activity/context) and
 * dart request (call/result).
 */
object PluginProvider {
    private const val ERROR_MESSAGE =
        "Tried to get one of the methods but the 'PluginProvider' has not initialized"

    /**
    * Define if 'warn' level will show more detailed logging.
    *
    * Will be used when a query produce some error.
    */
    var showDetailedLog: Boolean = false

    private lateinit var context: WeakReference<Context>

    private lateinit var activity: WeakReference<Activity>

    private lateinit var call: WeakReference<MethodCall>

    private lateinit var result: WeakReference<MethodChannel.Result>

    /**
     * Used to define the current [Activity] and [Context].
     *
     * Should be defined once.
     */
    fun set(activity: Activity) {
        this.context = WeakReference(activity.applicationContext)
        this.activity = WeakReference(activity)
    }

    /**
     * Used to define the current dart request.
     *
     * Should be defined/redefined on every [MethodChannel.MethodCallHandler.onMethodCall] request.
     */
    fun setCurrentMethod(call: MethodCall, result: MethodChannel.Result) {
        this.call = WeakReference(call)
        val safe = if (result is SafeResult) result else SafeResult(result)
        this.result = WeakReference(safe)
    }

    /**
     * The current plugin 'context'. Defined once.
     *
     * @throws UninitializedPluginProviderException
     * @return [Context]
     */
    fun context(): Context {
        return this.context.get() ?: throw UninitializedPluginProviderException(ERROR_MESSAGE)
    }

    /**
     * The current plugin 'activity'. Defined once.
     *
     * @throws UninitializedPluginProviderException
     * @return [Activity]
     */
    fun activity(): Activity {
        return this.activity.get() ?: throw UninitializedPluginProviderException(ERROR_MESSAGE)
    }

    /**
     * The current plugin 'call'. Will be replace with newest dart request.
     *
     * @throws UninitializedPluginProviderException
     * @return [MethodCall]
     */
    fun call(): MethodCall {
        return this.call.get() ?: throw UninitializedPluginProviderException(ERROR_MESSAGE)
    }

    /**
     * The current plugin 'result'. Will be replace with newest dart request.
     *
     * @throws UninitializedPluginProviderException
     * @return [MethodChannel.Result]
     */
    fun result(): MethodChannel.Result {
        return this.result.get() ?: throw UninitializedPluginProviderException(ERROR_MESSAGE)
    }

    class UninitializedPluginProviderException(msg: String) : Exception(msg)
}