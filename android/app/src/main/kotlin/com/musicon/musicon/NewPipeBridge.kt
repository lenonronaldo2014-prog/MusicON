// SPDX-License-Identifier: GPL-3.0-or-later
package com.musicon.musicon

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.schabi.newpipe.extractor.NewPipe
import org.schabi.newpipe.extractor.downloader.Downloader
import org.schabi.newpipe.extractor.downloader.Request
import org.schabi.newpipe.extractor.downloader.Response
import org.schabi.newpipe.extractor.localization.Localization
import org.schabi.newpipe.extractor.search.SearchInfo
import org.schabi.newpipe.extractor.stream.StreamInfo
import org.schabi.newpipe.extractor.stream.StreamInfoItem
import org.schabi.newpipe.extractor.stream.DeliveryMethod
import org.schabi.newpipe.extractor.services.youtube.YoutubeParsingHelper
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URI
import java.util.concurrent.Executors

class NewPipeBridge : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    @Volatile private var attached = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        NewPipe.init(ExtractorDownloader(), Localization("pt", "BR"))
        channel = MethodChannel(binding.binaryMessenger, "musicon/newpipe")
        channel.setMethodCallHandler(this)
        attached = true
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        attached = false
        channel.setMethodCallHandler(null)
        worker.shutdownNow()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method !in setOf("search", "resolve")) { result.notImplemented(); return }
        val value = call.argument<String>("value")?.trim().orEmpty()
        if (value.isEmpty() || value.length > 500) {
            result.error("invalid_input", "Informe uma busca ou link válido.", null); return
        }
        worker.execute {
            try {
                val response = if (call.method == "search") search(value) else resolve(value)
                main.post { if (attached) result.success(response) }
            } catch (e: Exception) {
                // Do not log signed media URLs, cookies, or upstream response bodies.
                Log.w("MusicONExtractor", "${call.method} failed: ${e.javaClass.simpleName}")
                val message = when {
                    e is IllegalArgumentException -> "Use uma busca ou um link público de vídeo do YouTube."
                    e is IOException -> "A fonte não respondeu. Confira a conexão e tente novamente."
                    else -> "A fonte não disponibilizou este áudio. O conteúdo pode estar restrito ou o extrator precisar de atualização."
                }
                main.post { if (attached) result.error("extraction_failed", message, e.javaClass.simpleName) }
            } catch (e: LinkageError) {
                Log.w("MusicONExtractor", "Unsupported API: ${e.javaClass.simpleName}")
                main.post { if (attached) result.error("compatibility", "A fonte encontrou uma incompatibilidade neste Android. Atualize o MusicON e tente novamente.", e.javaClass.simpleName) }
            }
        }
    }

    private fun search(query: String): List<Map<String, Any?>> {
        val service = NewPipe.getService(0)
        val handler = service.searchQHFactory.fromQuery(query, listOf("videos"), "")
        val info = SearchInfo.getInfo(service, handler)
        return info.relatedItems.filterIsInstance<StreamInfoItem>().take(20).map { item ->
            mapOf("title" to item.name, "artist" to item.uploaderName,
                "url" to item.url, "duration" to item.duration,
                "artwork" to item.thumbnails.maxByOrNull { it.width }?.url)
        }
    }

    private fun resolve(url: String): Map<String, Any?> {
        val parsed = URI(url)
        val host = parsed.host?.lowercase().orEmpty()
        require(parsed.scheme == "https" && parsed.userInfo == null &&
            (host == "youtu.be" || host == "youtube.com" || host.endsWith(".youtube.com")))
        val service = NewPipe.getService(0)
        require(service.streamLHFactory.acceptUrl(url))
        val info = StreamInfo.getInfo(service, url)
        // Prototype: ordinary audio streams only; no DRM, accounts or protected-content handling.
        val audio = info.audioStreams.filter {
            it.isUrl && it.deliveryMethod == DeliveryMethod.PROGRESSIVE_HTTP &&
                it.content.startsWith("https://")
        }.maxByOrNull { it.averageBitrate }
            ?: throw IOException("No compatible audio stream")
        val headers = mutableMapOf("User-Agent" to if (YoutubeParsingHelper.isVisionOsStreamingUrl(audio.content))
            YoutubeParsingHelper.getVisionOsUserAgent(null) else "Mozilla/5.0")
        if (YoutubeParsingHelper.isWebStreamingUrl(audio.content)) {
            headers["Origin"] = "https://www.youtube.com"
            headers["Referer"] = "https://www.youtube.com"
        }
        return mapOf("title" to info.name, "artist" to info.uploaderName,
            "url" to info.url, "stream" to audio.content,
            "artwork" to info.thumbnails.maxByOrNull { it.width }?.url,
            "duration" to info.duration, "format" to audio.format?.name, "headers" to headers)
    }
}

private class ExtractorDownloader : Downloader() {
    override fun execute(request: Request): Response {
        val connection = URI(request.url()).toURL().openConnection() as HttpURLConnection
        connection.connectTimeout = 15000
        connection.readTimeout = 15000
        connection.requestMethod = request.httpMethod()
        connection.setRequestProperty("User-Agent", "Mozilla/5.0")
        connection.setRequestProperty("Accept-Encoding", "identity")
        request.headers().forEach { (name, values) ->
            values.forEachIndexed { i, value ->
                if (i == 0) connection.setRequestProperty(name, value)
                else connection.addRequestProperty(name, value)
            }
        }
        try {
            request.dataToSend()?.let { data ->
                connection.doOutput = true
                connection.outputStream.use { it.write(data) }
            }
            val status = connection.responseCode
            val input = if (status >= 400) connection.errorStream else connection.inputStream
            val bytes = input?.use { it.readLimited(8 * 1024 * 1024) } ?: ByteArray(0)
            val headers = connection.headerFields.filterKeys { it != null }
            return Response(status, connection.responseMessage, headers,
                String(bytes, Charsets.UTF_8), connection.url.toString())
        } finally { connection.disconnect() }
    }
}
