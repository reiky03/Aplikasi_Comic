package uy.kohesive.injekt.api

import java.lang.reflect.Type
import java.lang.reflect.ParameterizedType

open class FullTypeReference<T> : TypeReference {
    override fun getType(): Type =
        (javaClass.genericSuperclass as? ParameterizedType)
            ?.actualTypeArguments
            ?.firstOrNull()
            ?: Any::class.java
}
