// SPDX-License-Identifier: GPL-3.0-or-later
package com.musicon.musicon

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.net.SocketTimeoutException
import java.net.URI
import java.net.UnknownHostException
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import okhttp3.Call
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import javax.net.ssl.SSLException

/** Spotify-only HTTPS transport. No redirects, custom trust manager or token logs. */
class SpotifyHttpPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    @Volatile private var attached = false
    @Volatile private var active: Call? = null
    private val client = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.SECONDS)
        .writeTimeout(10, TimeUnit.SECONDS)
        .callTimeout(23, TimeUnit.SECONDS)
        .retryOnConnectionFailure(false)
        .followRedirects(false)
        .followSslRedirects(false)
        .build()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        attached = true
        channel = MethodChannel(binding.binaryMessenger, "musicon/spotify_http")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        attached = false
        channel.setMethodCallHandler(null)
        active?.cancel()
        client.connectionPool.evictAll()
        client.dispatcher.executorService.shutdown()
        worker.shutdownNow()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "request") { result.notImplemented(); return }
        val method = call.argument<String>("method").orEmpty()
        val uri = try { URI(call.argument<String>("url").orEmpty()) } catch (_: Exception) { null }
        val token = uri?.host == "accounts.spotify.com" && uri.rawPath == "/api/token" && method == "POST"
        val api = uri?.host == "api.spotify.com" && uri.rawPath.startsWith("/v1/") && method == "GET"
        if (uri == null || uri.scheme != "https" || uri.userInfo != null ||
            uri.fragment != null || (uri.port != -1 && uri.port != 443) || (!token && !api)) {
            result.error("invalid_request", "Requisicao Spotify invalida.", null); return
        }
        val body = call.argument<ByteArray>("body") ?: ByteArray(0)
        val headers = call.argument<Map<String, String>>("headers") ?: emptyMap()
        if (body.size > 16384 || (api && body.isNotEmpty()) || headers.any {
            it.key.lowercase() !in setOf("authorization", "content-type", "accept") ||
                it.value.contains('\r') || it.value.contains('\n')
        }) {
            result.error("invalid_request", "Requisicao Spotify invalida.", null); return
        }
        worker.execute {
            try {
                val response = execute(uri, method, headers, body)
                main.post { if (attached) result.success(response) }
            } catch (error: Exception) {
                val code = when (error) {
                    is UnknownHostException -> "dns"
                    is SocketTimeoutException -> "timeout"
                    is SSLException -> "tls"
                    else -> "network"
                }
                main.post { if (attached) result.error(code, "Falha na conexao Spotify.", error.javaClass.simpleName) }
            }
        }
    }

    private fun execute(uri: URI, method: String, headers: Map<String, String>, body: ByteArray): Map<String, Any> {
        val builder = Request.Builder().url(uri.toString())
            .header("Accept", "application/json")
            .header("Connection", "close")
        headers.forEach { (name, value) -> builder.header(name, value) }
        if (method == "POST") builder.post(body.toRequestBody()) else builder.get()
        val call = client.newCall(builder.build())
        active = call
        try {
            call.execute().use { response ->
                val output = ByteArrayOutputStream()
                response.body?.byteStream()?.use {
                    val buffer = ByteArray(8192)
                    while (true) {
                        val count = it.read(buffer)
                        if (count == -1) break
                        if (output.size() + count > 4 * 1024 * 1024) throw IOException("Response too large")
                        output.write(buffer, 0, count)
                    }
                }
                val responseHeaders = mutableMapOf<String, String>()
                response.header("Content-Type")?.let { responseHeaders["content-type"] = it }
                return mapOf("status" to response.code, "headers" to responseHeaders, "body" to output.toByteArray())
            }
        } finally {
            active = null
        }
    }
}
