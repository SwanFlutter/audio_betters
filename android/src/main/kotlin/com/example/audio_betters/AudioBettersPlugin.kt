package com.example.audio_betters

import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.Build
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
    private var mediaRecorder: MediaRecorder? = null

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
            "startRecorder" -> {
                val path = call.argument<String>("path")
                val format = call.argument<String>("format") ?: "aac"
                val maxDuration = call.argument<Int>("maxDuration") ?: -1
                if (path != null) {
                    startRecorder(path, format, maxDuration, result)
                } else {
                    result.error("ARGUMENT_ERROR", "Path is null", null)
                }
            }
            "stopRecorder" -> {
                stopRecorder(result)
            }
            "getDuration" -> {
                val mp = mediaPlayer
                if (mp != null) {
                    result.success(mp.duration)
                } else {
                    result.success(0)
                }
            }
            "getCurrentPosition" -> {
                val mp = mediaPlayer
                if (mp != null) {
                    result.success(mp.currentPosition)
                } else {
                    result.success(0)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun startRecorder(path: String, format: String, maxDuration: Int, result: Result) {
        try {
            val recorder = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                MediaRecorder()
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }
            
            mediaRecorder = recorder
            recorder.setAudioSource(MediaRecorder.AudioSource.MIC)
            
            if (format == "wav" && android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                recorder.setOutputFormat(MediaRecorder.OutputFormat.OGG) // OGG/OPUS is better than nothing if WAV not available
                // Note: For true WAV, MediaRecorder isn't great. Mapping to OGG for "high quality" request or standardizing.
                // Actually, let's stick to AAC and 3GP for simplicity or try a better mapping.
                recorder.setAudioEncoder(MediaRecorder.AudioEncoder.OPUS)
            } else {
                recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            }
            
            if (maxDuration > 0) {
                recorder.setMaxDuration(maxDuration)
                recorder.setOnInfoListener { _, what, _ ->
                    if (what == MediaRecorder.MEDIA_RECORDER_INFO_MAX_DURATION_REACHED) {
                        // We could send a message back to Dart here if we had a StreamChannel
                        stopRecorder(null) 
                    }
                }
            }

            recorder.setOutputFile(path)
            recorder.prepare()
            recorder.start()
            result.success(null)
        } catch (e: Exception) {
            result.error("RECORDER_ERROR", e.message, null)
        }
    }

    private fun stopRecorder(result: Result?) {
        try {
            mediaRecorder?.let {
                it.stop()
                it.release()
            }
            mediaRecorder = null
            result?.success(null)
        } catch (e: Exception) {
            result?.error("STOP_RECORDER_ERROR", e.message, null)
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
        mediaRecorder?.release()
        mediaRecorder = null
    }
}
