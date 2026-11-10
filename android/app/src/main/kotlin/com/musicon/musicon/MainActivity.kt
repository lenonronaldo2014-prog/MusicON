package com.musicon.musicon

import android.content.Intent
import android.net.Uri
import android.os.Build
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (!flutterEngine.plugins.has(NewPipeBridge::class.java)) {
            flutterEngine.plugins.add(NewPipeBridge())
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "musicon/app")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "spotifySessionRead", "spotifySessionWrite", "spotifySessionClear" -> {
                        try {
                            val store = SpotifySessionStore(applicationContext)
                            when (call.method) {
                                "spotifySessionRead" -> result.success(store.read())
                                "spotifySessionWrite" -> { store.write(call.argument<String>("value").orEmpty()); result.success(null) }
                                else -> { store.clear(); result.success(null) }
                            }
                        } catch (_: Exception) { result.error("secure_store", "Nao foi possivel salvar a conexao Spotify.", null) }
                    }
                    "spotifyAuthorize" -> {
                        val uri = Uri.parse(call.argument<String>("url").orEmpty())
                        if (uri.scheme != "https" || uri.host != "accounts.spotify.com" || uri.userInfo != null || uri.path != "/authorize") {
                            result.error("invalid_url", "Endereco de login invalido.", null)
                        } else try { startActivity(Intent(Intent.ACTION_VIEW, uri)); result.success(null) }
                        catch (_: Exception) { result.error("no_browser", "Instale um navegador para conectar ao Spotify.", null) }
                    }
                    "version" -> {
                        @Suppress("DEPRECATION")
                        val info = packageManager.getPackageInfo(packageName, 0)
                        @Suppress("DEPRECATION")
                        val code = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
                        result.success(mapOf("name" to info.versionName, "build" to code))
                    }
                    "openRelease" -> {
                        val url = call.argument<String>("url").orEmpty()
                        val uri = Uri.parse(url)
                        if (uri.scheme != "https" || uri.host != "github.com" ||
                            uri.userInfo != null || !uri.path.orEmpty().startsWith("/lenonronaldo2014-prog/MusicON/releases/download/")) {
                            result.error("invalid_url", "Endereco de atualizacao invalido.", null)
                        } else {
                            try {
                                startActivity(Intent(Intent.ACTION_VIEW, uri))
                                result.success(null)
                            } catch (_: Exception) {
                                result.error("no_browser", "Nao foi possivel abrir o navegador.", null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
