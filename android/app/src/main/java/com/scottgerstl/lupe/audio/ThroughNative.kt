package com.scottgerstl.lupe.audio

/** libLupeThrough.so (app/src/main/cpp/through/through_engine.cpp): the AAudio engine. One engine per process. */
object ThroughNative {
    private val loaded: Boolean by lazy { runCatching { System.loadLibrary("LupeThrough") }.isSuccess }

    /** Starts both streams; 0, or an AAudio error code (negative). inDevice/outDevice 0: the phone's choice. inRate 0: the input's own rate. */
    fun start(inDevice: Int, inRate: Int, exclusiveIn: Boolean, exclusiveOut: Boolean, outDevice: Int = 0): Int =
        if (!loaded) -1 else nativeStart(inDevice, inRate, exclusiveIn, exclusiveOut, outDevice)

    fun stop() { if (loaded) nativeStop() }

    fun stats(): ThroughStats {
        if (!loaded) return ThroughStats()
        val a = DoubleArray(ThroughStats.COUNT)
        nativeStats(a)
        return ThroughStats.from(a)
    }

    fun error(): String = if (!loaded) "The audio engine didn't load" else nativeError()

    @JvmStatic private external fun nativeStart(inDevice: Int, inRate: Int, exclusiveIn: Boolean, exclusiveOut: Boolean, outDevice: Int): Int
    @JvmStatic private external fun nativeStop()
    @JvmStatic private external fun nativeStats(out: DoubleArray)
    @JvmStatic private external fun nativeError(): String
}
