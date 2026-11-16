// SPDX-License-Identifier: GPL-3.0-or-later
package com.musicon.musicon

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

/** Register media channels even when Android Auto starts without a phone Activity. */
class MusicOnMediaPlugin : FlutterPlugin, ActivityAware {
    private val extractor = NewPipeBridge()
    private val device = DeviceAudioPlugin()
    private val spotifyHttp = SpotifyHttpPlugin()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        extractor.onAttachedToEngine(binding)
        device.onAttachedToEngine(binding)
        spotifyHttp.onAttachedToEngine(binding)
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        extractor.onDetachedFromEngine(binding)
        device.onDetachedFromEngine(binding)
        spotifyHttp.onDetachedFromEngine(binding)
    }
    override fun onAttachedToActivity(binding: ActivityPluginBinding) = device.onAttachedToActivity(binding)
    override fun onDetachedFromActivityForConfigChanges() = device.onDetachedFromActivityForConfigChanges()
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = device.onReattachedToActivityForConfigChanges(binding)
    override fun onDetachedFromActivity() = device.onDetachedFromActivity()
}
