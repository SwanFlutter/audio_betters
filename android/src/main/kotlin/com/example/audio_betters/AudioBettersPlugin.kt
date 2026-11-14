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
import kotlin.math.log10

/** AudioBettersPlugin */
class AudioBettersPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var mediaPlayer: MediaPlayer? = null
    private var mediaRecorder: MediaRecorder? = null
    private var pendingPlayResult: Result? = null
    private var recordingPath: String? = null

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
            "seekTo" -> {
                val position = call.argument<Int>("position") ?: 0
                seekTo(position)
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
            "getRecorderAmplitude" -> {
                val rec = mediaRecorder
                if (rec == null) {
                    result.success(-1.0)
                } else {
                    try {
                        // getMaxAmplitude returns 0..32767 since the last call.
                        val amp = rec.maxAmplitude.toDouble()
                        val db = if (amp > 0) 20.0 * log10(amp / 32767.0) else -100.0
                        // Map -50 dBFS floor -> 0.0 and full scale -> 1.0.
                        val level = ((db + 50.0) / 50.0).coerceIn(0.0, 1.0)
                        result.success(level)
                    } catch (e: Exception) {
                        result.success(-1.0)
                    }
                }
            }
            "getDuration" -> {
                val mp = mediaPlayer
                try {
                    if (mp != null) {
                        result.success(mp.duration)
                    } else {
                        result.success(0)
                    }
                } catch (e: Exception) {
                    result.success(0)
                }
            }
            "getCurrentPosition" -> {
                val mp = mediaPlayer
                try {
                    if (mp != null) {
                        result.success(mp.currentPosition)
                    } else {
                        result.success(0)
                    }
                } catch (e: Exception) {
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
                recorder.setOutputFormat(MediaRecorder.OutputFormat.OGG)
                recorder.setAudioEncoder(MediaRecorder.AudioEncoder.OPUS)
            } else {
                recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            }

            if (maxDuration > 0) {
                recorder.setMaxDuration(maxDuration)
                recorder.setOnInfoListener { _, what, _ ->
                    if (what == MediaRecorder.MEDIA_RECORDER_INFO_MAX_DURATION_REACHED) {
                        stopRecorder(null)
                    }
                }
            }

            recorder.setOutputFile(path)
            recorder.prepare()
            recorder.start()
            recordingPath = path
            result.success(null)
        } catch (e: Exception) {
            mediaRecorder?.release()
            mediaRecorder = null
            recordingPath = null
            result.error("RECORDER_ERROR", e.message, null)
        }
    }

    private fun stopRecorder(result: Result?) {
        val path = recordingPath
        try {
            mediaRecorder?.let {
                it.stop()
                it.release()
            }
            mediaRecorder = null
            recordingPath = null
            result?.success(path)
        } catch (e: Exception) {
            mediaRecorder?.release()
            mediaRecorder = null
            recordingPath = null
            result?.error("STOP_RECORDER_ERROR", e.message, null)
        }
    }

    private fun play(url: String, result: Result) {
        // Resolve a previous still-pending play() with success: being superseded
        // by a new play request is a normal lifecycle event, not an error
        // (and matches every other platform's behavior).
        completePendingPlay()
        pendingPlayResult = result

        try {
            stopPlayback()
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
                if (pendingPlayResult == result) {
                    player.start()
                    result.success(null)
                    pendingPlayResult = null
                }
            }
            mp.setOnErrorListener { _: MediaPlayer, what: Int, extra: Int ->
                if (pendingPlayResult == result) {
                    result.error("MEDIA_ERROR", "MediaPlayer error: $what, $extra", null)
                    pendingPlayResult = null
                }
                true
            }
        } catch (e: IOException) {
            if (pendingPlayResult == result) {
                result.error("IO_ERROR", e.message, null)
                pendingPlayResult = null
            }
        } catch (e: Exception) {
            if (pendingPlayResult == result) {
                result.error("PLAY_ERROR", e.message, null)
                pendingPlayResult = null
            }
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
        // Resolve any play() that is still preparing; otherwise its Dart-side
        // Future would hang forever after we release the MediaPlayer.
        completePendingPlay()
        stopPlayback()
    }

    /** Completes the pending play() call (if any) with success. */
    private fun completePendingPlay() {
        val pending = pendingPlayResult ?: return
        pendingPlayResult = null
        pending.success(null)
    }

    /** Releases the player without touching the pending play() result. */
    private fun stopPlayback() {
        mediaPlayer?.let {
            try {
                if (it.isPlaying) {
                    it.stop()
                }
            } catch (e: Exception) {}
            it.release()
        }
        mediaPlayer = null
    }

    /** Jumps to [position] ms; MediaPlayer keeps its play/pause state. */
    private fun seekTo(position: Int) {
        mediaPlayer?.seekTo(position)
    }

    private fun setVolume(volume: Float) {
        mediaPlayer?.setVolume(volume, volume)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        stop()
        mediaRecorder?.release()
        mediaRecorder = null
        recordingPath = null
        pendingPlayResult = null
    }
}
