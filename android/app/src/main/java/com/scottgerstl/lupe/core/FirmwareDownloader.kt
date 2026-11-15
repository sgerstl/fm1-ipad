package com.scottgerstl.lupe.core

import android.content.Context
import android.os.Handler
import android.os.Looper
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

/**
 * Fetches the firmware file the core asks for (android/core Firmware.swift): while the `firmware` area is
 * "downloading" and carries a `download`, this gets that file over HTTPS into the app's cache and hands its path to
 * the core (`firmwareFile`). The core keeps it only if it is exactly the file Lupe pins (its SHA-256); this class
 * checks nothing but where it comes from. Only github.com (Lupe's release) is ever asked, and only for an install the
 * person started.
 */
object FirmwareDownloader {
    private val main = Handler(Looper.getMainLooper())
    @Volatile private var cache: File? = null
    @Volatile private var fetching: String? = null

    fun start(context: Context) { cache = context.applicationContext.cacheDir }

    /** The `firmware` area as JSON, on whatever thread Swift published it. */
    fun onFirmware(json: String) {
        val dl = try { Json.parseToJsonElement(json).jsonObject["download"]?.jsonObject } catch (_: Exception) { null } ?: return
        val url = dl["url"]?.jsonPrimitive?.content ?: return
        val which = dl["firmware"]?.jsonPrimitive?.content ?: return
        val name = dl["fileName"]?.jsonPrimitive?.content ?: return
        val size = dl["size"]?.jsonPrimitive?.content?.toLongOrNull() ?: 0L
        if (fetching == url) return
        fetching = url
        Thread({ fetch(url, which, name, size) }, "LupeFirmwareDownload").start()
    }

    private fun send(build: kotlinx.serialization.json.JsonObjectBuilder.() -> Unit) {
        val text = buildJsonObject(build).toString()
        main.post { LupeNative.intent(text) }               // intents go in on the UI thread
    }

    private fun fetch(url: String, which: String, name: String, size: Long) {
        try {
            require(url.startsWith("https://github.com/")) { "not Lupe's release" }
            val dir = cache ?: error("no storage")
            val part = File(dir, "$name.part")
            val conn = URL(url).openConnection() as HttpURLConnection
            conn.connectTimeout = 15_000; conn.readTimeout = 30_000
            conn.instanceFollowRedirects = true                 // GitHub sends the file from its storage host
            try {
                val code = conn.responseCode
                if (code !in 200..299) error("GitHub answered $code")
                val total = if (conn.contentLengthLong > 0) conn.contentLengthLong else size
                var got = 0L; var said = 0
                conn.inputStream.use { input ->
                    part.outputStream().use { out ->
                        val buf = ByteArray(16_384)
                        while (true) {
                            val n = input.read(buf); if (n < 0) break
                            out.write(buf, 0, n); got += n
                            // far more than the pinned file: not it (the core would refuse it anyway)
                            if (size > 0 && got > size * 2) error("the file is larger than expected")
                            val pct = if (total > 0) (got * 20 / total).toInt() else 0
                            if (pct != said) { said = pct; send { put("intent", JsonPrimitive("firmwareDownloadProgress")); put("progress", JsonPrimitive(pct / 20.0)) } }
                        }
                    }
                }
            } finally { conn.disconnect() }
            val file = File(dir, name)
            if (!part.renameTo(file)) { part.copyTo(file, overwrite = true); part.delete() }
            send { put("intent", JsonPrimitive("firmwareFile")); put("which", JsonPrimitive(which)); put("path", JsonPrimitive(file.absolutePath)) }
        } catch (e: Exception) {
            val why = when (e) {
                is java.net.UnknownHostException, is java.net.ConnectException, is java.net.SocketTimeoutException -> "no internet connection"
                else -> e.message ?: e.javaClass.simpleName
            }
            send { put("intent", JsonPrimitive("firmwareDownloadFailed")); put("message", JsonPrimitive(why)) }
        } finally {
            fetching = null
        }
    }
}
