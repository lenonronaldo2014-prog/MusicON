// SPDX-License-Identifier: GPL-3.0-or-later
package com.musicon.musicon

import android.Manifest
import android.app.Activity
import android.app.RecoverableSecurityException
import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.database.ContentObserver
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.util.concurrent.Executors

class DeviceAudioPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler,
    PluginRegistry.RequestPermissionsResultListener, PluginRegistry.ActivityResultListener {
    private lateinit var context: android.content.Context
    private lateinit var channel: MethodChannel
    private lateinit var events: EventChannel
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var binding: ActivityPluginBinding? = null
    private var sink: EventChannel.EventSink? = null
    private var attached = false
    private var observing = false
    private var permissionResult: MethodChannel.Result? = null
    private var afterPermission: ((Boolean) -> Unit)? = null
    private var deleting: Pair<Uri, MethodChannel.Result>? = null
    private val observer = object : ContentObserver(main) {
        override fun onChange(selfChange: Boolean) { sink?.success("changed") }
    }
    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        context = b.applicationContext; attached = true
        channel = MethodChannel(b.binaryMessenger, "musicon/device_audio")
        channel.setMethodCallHandler(this)
        events = EventChannel(b.binaryMessenger, "musicon/device_audio_changes")
        events.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) { sink = eventSink; observe() }
            override fun onCancel(arguments: Any?) { sink = null }
        })
    }
    private fun observe() {
        if (observing) return
        try { context.contentResolver.registerContentObserver(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, true, observer); observing = true }
        catch (_: SecurityException) { /* Retry after permission is granted. */ }
    }
    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
        attached = false; channel.setMethodCallHandler(null); events.setStreamHandler(null)
        if (observing) context.contentResolver.unregisterContentObserver(observer)
        sink = null; worker.shutdownNow()
    }
    private fun readPermission() = if (Build.VERSION.SDK_INT >= 33) Manifest.permission.READ_MEDIA_AUDIO else Manifest.permission.READ_EXTERNAL_STORAGE
    private fun hasRead() = context.checkSelfPermission(readPermission()) == PackageManager.PERMISSION_GRANTED
    private fun post(action: () -> Unit) { main.post { if (attached) action() } }
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "scan" -> {
                if (hasRead()) scan(result)
                else if (call.argument<Boolean>("requestPermission") == true) request(readPermission(), result) { allowed ->
                    if (allowed) scan(result) else result.success(mapOf("authorized" to false, "tracks" to emptyList<Any>()))
                }
                else result.success(mapOf("authorized" to false, "tracks" to emptyList<Any>()))
            }
            "delete" -> {
                val uri = Uri.parse(call.argument<String>("uri").orEmpty())
                if (!validAudioUri(uri)) { result.error("invalid_audio", "Escolha uma música da biblioteca do aparelho.", null); return }
                if (!hasRead()) { result.error("permission", "Permita o acesso às músicas nas configurações do Android.", null); return }
                if (deleting != null || permissionResult != null) { result.error("busy", "Conclua a solicitação anterior.", null); return }
                if (Build.VERSION.SDK_INT <= 28 && context.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                    request(Manifest.permission.WRITE_EXTERNAL_STORAGE, result) { allowed -> if (allowed) delete(uri, result) else result.success(false) }
                } else delete(uri, result)
            }
            "openSettings" -> try {
                binding?.activity?.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}")))
                result.success(null)
            } catch (_: Exception) { result.error("settings", "Abra as permissões do MusicON nas configurações do Android.", null) }
            else -> result.notImplemented()
        }
    }
    private fun request(permission: String, result: MethodChannel.Result, action: (Boolean) -> Unit) {
        val activity = binding?.activity
        if (activity == null || permissionResult != null) { result.error("busy", "Conclua a solicitação anterior e tente novamente.", null); return }
        permissionResult = result; afterPermission = action
        activity.requestPermissions(arrayOf(permission), 8101)
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
        if (requestCode != 8101 || permissionResult == null) return false
        val action = afterPermission; permissionResult = null; afterPermission = null
        action?.invoke(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
        return true
    }
    private fun scan(result: MethodChannel.Result) {
        observe()
        worker.execute {
            try {
                val collection = if (Build.VERSION.SDK_INT >= 29) MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL) else MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
                val projection = mutableListOf(MediaStore.Audio.Media._ID, MediaStore.Audio.Media.TITLE, MediaStore.Audio.Media.ARTIST, MediaStore.Audio.Media.DISPLAY_NAME)
                if (Build.VERSION.SDK_INT >= 29) projection.add(MediaStore.MediaColumns.VOLUME_NAME)
                val rows = mutableListOf<Map<String, Any>>()
                val found = context.contentResolver.query(collection, projection.toTypedArray(), "${MediaStore.Audio.Media.IS_MUSIC} != 0 AND ${MediaStore.Audio.Media.SIZE} > 0", null, "${MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC") ?: throw IllegalStateException("MediaStore unavailable")
                found.use { cursor ->
                    while (cursor.moveToNext()) {
                        val id = cursor.getLong(0)
                        val title = cursor.getString(1)?.takeIf { it.isNotBlank() } ?: cursor.getString(3)?.substringBeforeLast('.') ?: "Sem título"
                        val artist = cursor.getString(2)?.takeIf { it.isNotBlank() && it != "<unknown>" } ?: "Artista desconhecido"
                        val volume = if (Build.VERSION.SDK_INT >= 29) cursor.getString(4) ?: "external" else "external"
                        val base = if (Build.VERSION.SDK_INT >= 29) MediaStore.Audio.Media.getContentUri(volume) else MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
                        val uri = ContentUris.withAppendedId(base, id)
                        rows.add(mapOf("id" to "device-$volume-$id", "title" to title, "artist" to artist, "uri" to uri.toString()))
                    }
                }
                post { result.success(mapOf("authorized" to true, "tracks" to rows)) }
            } catch (_: SecurityException) { post { result.success(mapOf("authorized" to false, "tracks" to emptyList<Any>())) } }
            catch (_: Exception) { post { result.error("scan", "Não foi possível consultar as músicas do aparelho.", null) } }
        }
    }
    private fun validAudioUri(uri: Uri) = uri.scheme == "content" && uri.authority == "media" && uri.query == null && uri.fragment == null &&
        Regex("^/[A-Za-z0-9_-]+/audio/media/[0-9]+$").matches(uri.path.orEmpty())
    private fun exists(uri: Uri): Boolean = context.contentResolver.query(uri, arrayOf(MediaStore.Audio.Media._ID), null, null, null)?.use { it.moveToFirst() } ?: false
    private fun delete(uri: Uri, result: MethodChannel.Result, approved: Boolean = false) {
        worker.execute {
            try {
                if (!exists(uri)) { post { result.success(true) }; return@execute }
                if (Build.VERSION.SDK_INT >= 30) {
                    val sender = MediaStore.createDeleteRequest(context.contentResolver, listOf(uri)).intentSender
                    post { consent(uri, result, sender) }
                } else {
                    val removed = context.contentResolver.delete(uri, null, null) > 0 || !exists(uri)
                    post { result.success(removed) }
                }
            } catch (e: SecurityException) {
                if (Build.VERSION.SDK_INT == 29 && e is RecoverableSecurityException && !approved) {
                    post { consent(uri, result, e.userAction.actionIntent.intentSender) }
                } else post { result.error("delete", "O Android não permitiu excluir este arquivo.", null) }
            } catch (_: Exception) { post { result.error("delete", "Não foi possível excluir a música do aparelho.", null) } }
        }
    }
    private fun consent(uri: Uri, result: MethodChannel.Result, sender: android.content.IntentSender) {
        val activity = binding?.activity
        if (activity == null || deleting != null) { result.error("busy", "Tente novamente quando a solicitação anterior terminar.", null); return }
        deleting = uri to result
        try { activity.startIntentSenderForResult(sender, 8102, null, 0, 0, 0) }
        catch (_: Exception) { deleting = null; result.error("delete", "Não foi possível abrir a confirmação do Android.", null) }
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != 8102) return false
        val operation = deleting ?: return false; deleting = null
        if (resultCode != Activity.RESULT_OK) { operation.second.success(false); return true }
        if (Build.VERSION.SDK_INT == 29) delete(operation.first, operation.second, approved = true)
        else worker.execute {
            try { val removed = !exists(operation.first); post { operation.second.success(removed) } }
            catch (_: Exception) { post { operation.second.error("delete", "Não foi possível confirmar a exclusão.", null) } }
        }
        return true
    }
    override fun onAttachedToActivity(b: ActivityPluginBinding) { binding = b; b.addRequestPermissionsResultListener(this); b.addActivityResultListener(this) }
    private fun detach() { binding?.removeRequestPermissionsResultListener(this); binding?.removeActivityResultListener(this); binding = null }
    override fun onDetachedFromActivityForConfigChanges() { detach() }
    override fun onReattachedToActivityForConfigChanges(b: ActivityPluginBinding) { onAttachedToActivity(b) }
    override fun onDetachedFromActivity() {
        detach(); permissionResult?.error("cancelled", "Solicitação interrompida.", null); permissionResult = null; afterPermission = null
        deleting?.second?.success(false); deleting = null
    }
}
