package com.example.audio_betters

import android.media.AudioAttributes
import android.media.MediaPlayer
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.IOException

/** AudioBettersPlugin */
class AudioBettersPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var mediaPlayer: MediaPlayer? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "audio_betters")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "play" -> {
                val url = call.argument<String>("url")
                if (url != null) {
                    play(url, result)
                } else {
                    result.error("ARGUMENT_ERROR", "URL is null", null)
                }
            }
            "pause" -> {
                pause()
                result.success(null)
            }
            "resume" -> {
                resume()
                result.success(null)
            }
            "stop" -> {
                stop()
                result.success(null)
            }
            "setVolume" -> {
                val volume = call.argument<Double>("volume")?.toFloat()
                if (volume != null) {
                    setVolume(volume)
                    result.success(null)
                } else {
                    result.error("ARGUMENT_ERROR", "Volume is null", null)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun play(url: String, result: Result) {
        try {
            stop()
            val mp = MediaPlayer()
            mediaPlayer = mp
            mp.setAudioAttributes(
                AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .build()
            )
            mp.setDataSource(url)
            mp.prepareAsync()
            mp.setOnPreparedListener { player: MediaPlayer ->
                player.start()
                result.success(null)
            }
            mp.setOnErrorListener { _: MediaPlayer, what: Int, extra: Int ->
                result.error("MEDIA_ERROR", "MediaPlayer error: $what, $extra", null)
                true
            }
        } catch (e: IOException) {
            result.error("IO_ERROR", e.message, null)
        } catch (e: Exception) {
            result.error("PLAY_ERROR", e.message, null)
        }
    }

    private fun pause() {
        mediaPlayer?.let {
            if (it.isPlaying) {
                it.pause()
            }
        }
    }

    private fun resume() {
        mediaPlayer?.let {
            if (!it.isPlaying) {
                it.start()
            }
        }
    }

    private fun stop() {
        mediaPlayer?.let {
            if (it.isPlaying) {
                it.stop()
            }
            it.release()
        }
        mediaPlayer = null
    }

    private fun setVolume(volume: Float) {
        mediaPlayer?.setVolume(volume, volume)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        stop()
    }
}
