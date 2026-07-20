package uy.kohesive.injekt.api

inline fun <reified T> InjektFactory.get(): T =
    getInstance(object : FullTypeReference<T>() {}.getType()) as T
