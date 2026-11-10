package com.musicon.musicon

import android.content.Intent
import android.net.Uri
import android.os.Build
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.spotify.sdk.android.auth.AuthorizationRequest
import com.spotify.sdk.android.auth.AuthorizationResponse
import com.spotify.sdk.android.auth.IntentExtras
import com.spotify.sdk.android.auth.LoginActivity
import com.spotify.sdk.android.auth.PKCEInformation
import com.spotify.sdk.android.auth.app.SpotifyNativeAuthUtil

class MainActivity : AudioServiceActivity() {
    private var spotifyResult: MethodChannel.Result? = null
    private var spotifyState: String? = null
    private var spotifyViaApp = false
    private val spotifyRequest = LoginActivity.REQUEST_CODE

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val uri = intent.data ?: return
        if (uri.scheme != "musicon" || uri.host != "spotify" || uri.path != "/callback") return
        if (spotifyResult == null || uri.getQueryParameter("state") != spotifyState) return
        if (uri.getQueryParameter("error") != null) {
            completeSpotifyError("cancelled")
        } else {
            completeSpotifyCode(uri.getQueryParameter("code"), uri.getQueryParameter("state"))
        }
    }

    private fun completeSpotifyError(code: String) {
        val pending = spotifyResult
        spotifyResult = null; spotifyState = null
        pending?.error(code, "Nao foi possivel concluir a conexao Spotify.", null)
    }

    private fun completeSpotifyCode(code: String?, state: String?) {
        if (state != spotifyState || code.isNullOrBlank() || code.length > 4096) {
            completeSpotifyError("invalid_auth"); return
        }
        val pending = spotifyResult
        spotifyResult = null; spotifyState = null
        pending?.success(mapOf("code" to code, "state" to state))
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != spotifyRequest) return
        if (spotifyResult == null || !spotifyViaApp) return
        if (resultCode == RESULT_CANCELED) { completeSpotifyError("cancelled"); return }
        val reply = data?.getBundleExtra(LoginActivity.EXTRA_REPLY)
        if (resultCode != RESULT_OK || reply?.getString(IntentExtras.KEY_RESPONSE_TYPE) != LoginActivity.RESPONSE_TYPE_CODE) {
            completeSpotifyError("spotify_auth"); return
        }
        completeSpotifyCode(reply.getString(IntentExtras.KEY_AUTHORIZATION_CODE), reply.getString(IntentExtras.KEY_STATE))
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
                    "spotifyAppAuthorize", "spotifyBrowserAuthorize" -> {
                        val useApp = call.method == "spotifyAppAuthorize"
                        val clientId = call.argument<String>("clientId").orEmpty()
                        val verifier = call.argument<String>("verifier").orEmpty()
                        val challenge = call.argument<String>("challenge").orEmpty()
                        val state = call.argument<String>("state").orEmpty()
                        if (spotifyResult != null || !clientId.matches(Regex("[a-fA-F0-9]{32}")) || verifier.length !in 43..128 || challenge.length != 43 || state.length !in 43..128) {
                            result.error("invalid_auth", "Solicitacao de conexao invalida.", null)
                        } else if (useApp && !SpotifyNativeAuthUtil.isSpotifyInstalled(this)) {
                            result.error("not_installed", "Spotify compativel nao encontrado.", null)
                        } else try {
                            val request = AuthorizationRequest.Builder(clientId, AuthorizationResponse.Type.CODE, "musicon://spotify/callback")
                                .setScopes(arrayOf("playlist-read-private", "playlist-read-collaborative"))
                                .setState(state)
                                .setPkceInformation(PKCEInformation.sha256(verifier, challenge))
                                .build()
                            spotifyResult = result
                            spotifyState = state
                            spotifyViaApp = useApp
                            if (useApp) {
                                // Official SDK utility verifies Spotify's signature and passes PKCE.
                                // The reply is received directly instead of a second SDK activity.
                                if (!SpotifyNativeAuthUtil(this, request).startAuthActivity()) {
                                    completeSpotifyError("not_installed")
                                }
                            } else {
                                val debugProbe = call.argument<Boolean>("probeOnly") == true &&
                                    (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
                                // Opt-in debug probe never authorizes an actual Spotify account.
                                val uri = if (debugProbe) Uri.parse("https://example.com/") else request.toUri()
                                startActivity(Intent(Intent.ACTION_VIEW, uri))
                            }
                        } catch (_: Exception) {
                            spotifyResult = null; spotifyState = null
                            result.error("spotify_auth", "Nao foi possivel abrir a conexao Spotify.", null)
                        }
                    }
                    "spotifyAppCancel" -> {
                        val pending = spotifyResult
                        spotifyResult = null; spotifyState = null
                        if (pending != null) {
                            if (spotifyViaApp) finishActivity(spotifyRequest)
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
