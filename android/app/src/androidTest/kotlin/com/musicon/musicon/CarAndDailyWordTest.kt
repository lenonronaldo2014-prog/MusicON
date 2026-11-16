package com.musicon.musicon

import android.app.Notification
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.browse.MediaBrowser
import android.media.session.MediaController
import android.media.session.PlaybackState
import com.ryanheise.audioservice.AudioServicePlugin
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.util.Calendar
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import org.json.JSONArray
import org.json.JSONObject

@RunWith(AndroidJUnit4::class)
class CarAndDailyWordTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = instrumentation.targetContext

    @Test fun mediaBrowserCanStartServiceBrowseAndControlRealAudio() {
        // Isolated private fixture; restore the user's library after the test.
        val preferences = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val key = "flutter.musicon.library.v1"
        val original = preferences.getString(key, null)
        val fixture = File(context.cacheDir, "car-audio-test.wav")
        val pcmLength = 8000 * 2 * 20
        val wav = ByteBuffer.allocate(44 + pcmLength).order(ByteOrder.LITTLE_ENDIAN)
        wav.put("RIFF".toByteArray()).putInt(36 + pcmLength).put("WAVEfmt ".toByteArray())
            .putInt(16).putShort(1.toShort()).putShort(1.toShort()).putInt(8000).putInt(16000)
            .putShort(2.toShort()).putShort(16.toShort()).put("data".toByteArray()).putInt(pcmLength)
        fixture.writeBytes(wav.array())
        val track = JSONObject().put("id", "car-native-fixture").put("title", "Áudio de teste")
            .put("artist", "MusicON").put("location", fixture.path).put("source", "local")
        preferences.edit().putString(key, JSONObject().put("version", 1)
            .put("tracks", JSONArray().put(track)).put("favorites", JSONArray()).put("playlists", JSONArray()).toString()).commit()
        val connected = CountDownLatch(1)
        var failed = false
        lateinit var browser: MediaBrowser
        instrumentation.runOnMainSync {
            browser = MediaBrowser(context,
                ComponentName(context.packageName, "com.ryanheise.audioservice.AudioService"),
                object : MediaBrowser.ConnectionCallback() {
                    override fun onConnected() { connected.countDown() }
                    override fun onConnectionFailed() { failed = true; connected.countDown() }
                }, null)
            browser.connect()
        }
        try {
            assertTrue("Media service did not connect", connected.await(30, TimeUnit.SECONDS))
            assertFalse("Media service rejected connection", failed)
            assertTrue("Native media plugins missing in a headless engine",
                AudioServicePlugin.getFlutterEngine(context).plugins.has(MusicOnMediaPlugin::class.java))
            val root = children(browser, browser.root)
            assertEquals(listOf("Todas as músicas", "Favoritos", "No aparelho", "Playlists"), root.map { it.description.title.toString() })
            assertTrue(root.all { it.isBrowsable })
            val tracks = children(browser, "all")
            assertTrue(tracks.isNotEmpty())
            assertEquals("Áudio de teste", tracks.first().description.title.toString())
            assertTrue(tracks.all { it.isPlayable })
            // A foreground activity grants playback the same foreground allowance as a car host.
            context.startActivity(Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            val playing = CountDownLatch(1)
            lateinit var controller: MediaController
            instrumentation.runOnMainSync {
                controller = MediaController(context, browser.sessionToken)
                controller.registerCallback(object : MediaController.Callback() {
                    override fun onPlaybackStateChanged(state: PlaybackState?) {
                        if (state?.state == PlaybackState.STATE_PLAYING) playing.countDown()
                    }
                })
                controller.transportControls.playFromMediaId(tracks.first().mediaId!!, null)
            }
            assertTrue("Real audio did not start", playing.await(30, TimeUnit.SECONDS))
            val paused = CountDownLatch(1)
            instrumentation.runOnMainSync {
                controller.registerCallback(object : MediaController.Callback() {
                    override fun onPlaybackStateChanged(state: PlaybackState?) {
                        if (state?.state == PlaybackState.STATE_PAUSED) paused.countDown()
                    }
                })
                controller.transportControls.pause()
            }
            assertTrue("Remote pause did not reach player", paused.await(15, TimeUnit.SECONDS))
            assertNotNull(controller.metadata)
            assertTrue(controller.metadata!!.getLong(android.media.MediaMetadata.METADATA_KEY_DURATION) > 0)
            instrumentation.runOnMainSync { controller.transportControls.stop() }
        } finally {
            instrumentation.runOnMainSync { browser.disconnect() }
            val edit = preferences.edit()
            if (original == null) edit.remove(key) else edit.putString(key, original)
            edit.commit()
            fixture.delete()
        }
    }

    private fun children(browser: MediaBrowser, parent: String): List<MediaBrowser.MediaItem> {
        val loaded = CountDownLatch(1)
        var items: List<MediaBrowser.MediaItem>? = null
        instrumentation.runOnMainSync {
            browser.subscribe(parent, object : MediaBrowser.SubscriptionCallback() {
                override fun onChildrenLoaded(parentId: String, children: MutableList<MediaBrowser.MediaItem>) {
                    items = children.toList(); loaded.countDown()
                }
                override fun onError(parentId: String) { loaded.countDown() }
            })
        }
        assertTrue("Browser timed out for $parent", loaded.await(20, TimeUnit.SECONDS))
        assertNotNull("Browser returned an error for $parent", items)
        return items!!
    }

    @Test fun dailyNotificationIsIndependentDeduplicatedAndCancelable() {
        val prefs = context.getSharedPreferences("daily_word", Context.MODE_PRIVATE)
        val backup = prefs.all.toMap()
        val manager = context.getSystemService(NotificationManager::class.java)
        try {
            prefs.edit().remove("last_delivered").commit()
            DailyWordNotifications.createChannel(context)
            assertTrue("Test requires notification permission", DailyWordNotifications.allowed(context))
            DailyWordNotifications.setEnabled(context, true)
            val morning = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 8); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0)
            }.timeInMillis
            DailyWordNotifications.deliver(context, morning)
            val first = manager.activeNotifications.single { it.id == 8001 }
            assertEquals(DailyWordNotifications.CHANNEL_ID, first.notification.channelId)
            val state = DailyWordNotifications.state(context, morning)
            assertEquals(state["text"], first.notification.extras.getString(Notification.EXTRA_TEXT))
            assertNotEquals("com.musicon.musicon.playback", first.notification.channelId)
            DailyWordNotifications.deliver(context, morning)
            assertEquals(first.postTime, manager.activeNotifications.single { it.id == 8001 }.postTime)
            DailyWordNotifications.setEnabled(context, false)
            assertFalse(manager.activeNotifications.any { it.id == 8001 })
        } finally {
            manager.cancel(8001)
            val edit = prefs.edit().clear()
            for ((key, value) in backup) {
                when (value) {
                    is Boolean -> edit.putBoolean(key, value)
                    is Int -> edit.putInt(key, value)
                    is Long -> edit.putLong(key, value)
                    is String -> edit.putString(key, value)
                }
            }
            edit.commit()
            DailyWordNotifications.schedule(context)
        }
    }
}
