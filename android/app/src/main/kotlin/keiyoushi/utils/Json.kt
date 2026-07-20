package keiyoushi.utils

import java.io.InputStream
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.encodeToJsonElement
import kotlinx.serialization.serializer
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import okio.buffer
import okio.source
import uy.kohesive.injekt.Injekt
import uy.kohesive.injekt.api.get

val jsonInstance: Json = Injekt.get()

val JSON_MEDIA_TYPE = "application/json".toMediaType()

inline fun <reified T> String.parseAs(json: Json = jsonInstance): T =
    json.decodeFromString(this)

inline fun <reified T> String.parseAs(
    json: Json = jsonInstance,
    transform: (String) -> String,
): T = transform(this).parseAs(json)

inline fun <reified T> Response.parseAs(json: Json = jsonInstance): T = use {
    json.decodeFromString(it.body.string())
}

inline fun <reified T> Response.parseAs(
    json: Json = jsonInstance,
    transform: (String) -> String,
): T = use {
    it.body.string().parseAs(json, transform)
}

inline fun <reified T> JsonElement.parseAs(json: Json = jsonInstance): T =
    json.decodeFromJsonElement(this)

inline fun <reified T> InputStream.parseAs(json: Json = jsonInstance): T = use {
    json.decodeFromString(it.source().buffer().readUtf8())
}

inline fun <reified T> T.toJsonString(json: Json = jsonInstance): String =
    json.encodeToString(this)

inline fun <reified T> T.toJsonRequestBody(json: Json = jsonInstance): RequestBody =
    toJsonString(json).toRequestBody(JSON_MEDIA_TYPE)

inline fun <reified T> T.toJsonElement(json: Json = jsonInstance): JsonElement =
    json.encodeToJsonElement(serializer(), this)
