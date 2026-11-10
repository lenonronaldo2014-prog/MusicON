package com.musicon.musicon

import android.content.Intent
import android.net.Uri
import android.os.Build
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.spotify.sdk.android.auth.AuthorizationClient
import com.spotify.sdk.android.auth.AuthorizationRequest
import com.spotify.sdk.android.auth.AuthorizationResponse
import com.spotify.sdk.android.auth.PKCEInformation
import com.spotify.sdk.android.auth.app.SpotifyNativeAuthUtil

class MainActivity : AudioServiceActivity() {
    private var spotifyResult: MethodChannel.Result? = null
    private val spotifyRequest = 8201

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != spotifyRequest) return
        val pending = spotifyResult ?: return
        spotifyResult = null
        val response = AuthorizationClient.getResponse(resultCode, data)
        when (response.type) {
            AuthorizationResponse.Type.CODE -> pending.success(mapOf("code" to response.code, "state" to response.state))
            AuthorizationResponse.Type.CANCELLED -> pending.error("cancelled", "Conexao cancelada.", null)
            else -> pending.error("spotify_auth", "O Spotify nao autorizou a conexao pelo aplicativo.", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (!flutterEngine.plugins.has(NewPipeBridge::class.java)) {
            flutterEngine.plugins.add(NewPipeBridge())
        }
        if (!flutterEngine.plugins.has(DeviceAudioPlugin::class.java)) {
            flutterEngine.plugins.add(DeviceAudioPlugin())
        }
        if (!flutterEngine.plugins.has(SpotifyHttpPlugin::class.java)) {
            flutterEngine.plugins.add(SpotifyHttpPlugin())
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "musicon/app")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "spotifyAppAvailable" -> result.success(SpotifyNativeAuthUtil.isSpotifyInstalled(this))
                    "spotifyAppAuthorize" -> {
                        val clientId = call.argument<String>("clientId").orEmpty()
                        val verifier = call.argument<String>("verifier").orEmpty()
                        val challenge = call.argument<String>("challenge").orEmpty()
                        val state = call.argument<String>("state").orEmpty()
                        if (spotifyResult != null || !clientId.matches(Regex("[a-fA-F0-9]{32}")) || verifier.length !in 43..128 || challenge.length != 43 || state.length !in 43..128) {
                            result.error("invalid_auth", "Solicitacao de conexao invalida.", null)
                        } else if (!SpotifyNativeAuthUtil.isSpotifyInstalled(this)) {
                            result.error("not_installed", "Spotify compativel nao encontrado.", null)
                        } else try {
                            val request = AuthorizationRequest.Builder(clientId, AuthorizationResponse.Type.CODE, "musicon://spotify/callback")
                                .setScopes(arrayOf("playlist-read-private", "playlist-read-collaborative"))
                                .setState(state)
                                .setPkceInformation(PKCEInformation.sha256(verifier, challenge))
                                .build()
                            spotifyResult = result
                            AuthorizationClient.openLoginActivity(this, spotifyRequest, request)
                        } catch (_: Exception) {
                            spotifyResult = null
                            result.error("spotify_auth", "Nao foi possivel abrir a conexao Spotify.", null)
                        }
                    }
                    "spotifyAppCancel" -> {
                        val pending = spotifyResult
                        spotifyResult = null
                        if (pending != null) {
                            AuthorizationClient.stopLoginActivity(this, spotifyRequest)
                            pending.error("cancelled", "Conexao cancelada.", null)
                        }
                        result.success(null)
                    }
                    "spotifyReturn" -> {
                        try {
                            startActivity(Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP))
                            result.success(null)
                        } catch (_: Exception) { result.error("return_failed", "Toque em Abrir MusicON no navegador.", null) }
                    }
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
