package uy.kohesive.injekt

import android.app.Application
import kotlinx.serialization.json.Json
import uy.kohesive.injekt.api.InjektScope
import java.lang.reflect.Type

private var application: Application? = null

private val scope = object : InjektScope {
    override fun getInstance(type: Type): Any {
        val typeName = type.typeName
        if (typeName.contains("kotlinx.serialization.json.Json")) {
            return Json {
                ignoreUnknownKeys = true
                isLenient = true
            }
        }
        return application ?: error("Kizen application belum dipasang ke Injekt bridge")
    }
}

object Injekt : InjektScope by scope

val injekt: InjektScope
    get() = scope

fun installApplication(value: Application) {
    application = value
}
