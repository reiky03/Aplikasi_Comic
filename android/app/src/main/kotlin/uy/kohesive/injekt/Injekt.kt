package uy.kohesive.injekt

import android.app.Application
import eu.kanade.tachiyomi.network.NetworkHelper
import kotlinx.serialization.json.Json
import uy.kohesive.injekt.api.InjektScope
import java.lang.reflect.Type

private var application: Application? = null
private val networkHelper by lazy { NetworkHelper() }
private val jsonInstance by lazy {
    Json {
        ignoreUnknownKeys = true
        isLenient = true
        explicitNulls = false
    }
}

private fun resolveApp(): Application? {
    if (application != null) return application
    return runCatching {
        val atClass = Class.forName("android.app.ActivityThread")
        val method = atClass.getMethod("currentApplication")
        (method.invoke(null) as? Application)?.also { application = it }
    }.getOrNull()
}

private val scope = object : InjektScope {
    override fun getInstance(type: Type): Any {
        val typeName = type.toString()
        if (typeName.contains("kotlinx.serialization.json.Json")) {
            return jsonInstance
        }
        if (typeName.contains("NetworkHelper")) {
            return networkHelper
        }
        val app = resolveApp()
        if (typeName.contains("Application") || typeName.contains("Context")) {
            return app ?: error("Kizen application belum dipasang ke Injekt bridge")
        }
        return app ?: networkHelper
    }
}

object Injekt : InjektScope by scope

val injekt: InjektScope
    get() = scope

fun installApplication(value: Application) {
    application = value
}
