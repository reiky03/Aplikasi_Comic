package rx

/** Minimal RxJava 1 compatibility surface used only while reflecting APKs. */
open class Observable<T> {
    fun <R> map(transformer: rx.functions.Func1<in T, out R>): Observable<R> = Observable()
}
