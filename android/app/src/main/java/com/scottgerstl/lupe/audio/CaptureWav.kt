package com.scottgerstl.lupe.audio

import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

/** A 32-bit float stereo WAV (WAVE_FORMAT_IEEE_FLOAT), exactly the samples AAudio gave: zeros stay zeros. */
object CaptureWav {
    fun bytes(interleaved: FloatArray, rate: Int): ByteArray {
        val data = interleaved.size * 4
        val b = ByteBuffer.allocate(44 + data).order(ByteOrder.LITTLE_ENDIAN)
        b.put("RIFF".toByteArray()).putInt(36 + data).put("WAVE".toByteArray())
        b.put("fmt ".toByteArray()).putInt(16).putShort(3).putShort(2).putInt(rate).putInt(rate * 8).putShort(8).putShort(32)
        b.put("data".toByteArray()).putInt(data)
        for (v in interleaved) b.putFloat(v)
        return b.array()
    }

    fun write(f: File, interleaved: FloatArray, rate: Int) = f.writeBytes(bytes(interleaved, rate))
}
