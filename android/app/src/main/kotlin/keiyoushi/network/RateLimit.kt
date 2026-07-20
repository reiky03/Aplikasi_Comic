package keiyoushi.network

import android.os.SystemClock
import java.io.IOException
import java.util.ArrayDeque
import java.util.concurrent.locks.Condition
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock
import kotlin.time.Duration
import kotlin.time.Duration.Companion.milliseconds
import kotlin.time.Duration.Companion.seconds
import okhttp3.Call
import okhttp3.HttpUrl
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.Response

/**
 * Compatibility helper used by newer Keiyoushi extensions.
 *
 * Tachiyomi/Mihon provides this from its extension core. Kizen only needs the
 * runtime behavior: space requests so extension APKs that call `rateLimit(...)`
 * can instantiate and run without pulling in the whole host app.
 */
fun OkHttpClient.Builder.rateLimit(
    permits: Int,
    period: Duration = 1.seconds,
    interval: Duration = Duration.ZERO,
    shouldLimit: (HttpUrl) -> Boolean = { true },
): OkHttpClient.Builder = apply {
    val rule = RateLimitRule(permits, period, interval, shouldLimit)
    val existing = networkInterceptors()
        .filterIsInstance<RateLimitInterceptor>()
        .firstOrNull()
    if (existing != null) {
        existing.addRule(rule)
        return@apply
    }

    if (interceptors().none { it === RateLimitInterceptor.TaggingInterceptor }) {
        addInterceptor(RateLimitInterceptor.TaggingInterceptor)
    }
    addNetworkInterceptor(RateLimitInterceptor(rule))
}

private class RateLimitRule(
    val permits: Int,
    val period: Duration,
    val interval: Duration,
    val shouldLimit: (HttpUrl) -> Boolean,
)

private class RateLimitInterceptor(rule: RateLimitRule) : Interceptor {
    private class RateLimitTag(var applied: Boolean = false)

    object TaggingInterceptor : Interceptor {
        override fun intercept(chain: Interceptor.Chain): Response {
            val request = chain.request().newBuilder()
                .tag(RateLimitTag::class.java, RateLimitTag())
                .build()
            return chain.proceed(request)
        }
    }

    private class Limit(
        val permits: Int,
        val period: Duration,
        val interval: Duration,
        val shouldLimit: (HttpUrl) -> Boolean,
    ) {
        val queue = ArrayDeque<Duration>(permits.coerceAtLeast(1))
        val lock = ReentrantLock(true)
        val retryCondition: Condition = lock.newCondition()
        var lastDispatchTime: Duration? = null
    }

    private val limits = mutableListOf(
        Limit(
            permits = rule.permits.coerceAtLeast(1),
            period = rule.period,
            interval = rule.interval,
            shouldLimit = rule.shouldLimit,
        ),
    )

    fun addRule(rule: RateLimitRule) {
        limits += Limit(
            permits = rule.permits.coerceAtLeast(1),
            period = rule.period,
            interval = rule.interval,
            shouldLimit = rule.shouldLimit,
        )
    }

    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()
        val limit = limits.firstOrNull { it.shouldLimit(request.url) }
            ?: return chain.proceed(request)
        val state = request.tag(RateLimitTag::class.java)
        if (state?.applied == true) return chain.proceed(request)

        limit.acquireSlot(chain.call())
        state?.applied = true
        return chain.proceed(request)
    }

    private fun Limit.acquireSlot(call: Call) = lock.withLock {
        while (true) {
            if (call.isCanceled()) throw IOException("Canceled")
            val now = SystemClock.elapsedRealtime().milliseconds
            while (queue.isNotEmpty() && now - queue.first() >= period) {
                queue.removeFirst()
            }

            val windowWait = if (queue.size < permits) {
                Duration.ZERO
            } else {
                period - (now - queue.first())
            }
            val intervalWait = if (lastDispatchTime == null) {
                Duration.ZERO
            } else {
                interval - (now - lastDispatchTime!!)
            }
            val waitTime = maxOf(windowWait, intervalWait, Duration.ZERO)

            if (waitTime == Duration.ZERO) {
                val timestamp = SystemClock.elapsedRealtime().milliseconds
                queue.addLast(timestamp)
                lastDispatchTime = timestamp
                return@withLock
            }
            retryCondition.awaitNanos(waitTime.inWholeNanoseconds)
        }
    }
}
