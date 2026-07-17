package rx.functions

fun interface Func1<T, R> {
    fun call(value: T): R
}
