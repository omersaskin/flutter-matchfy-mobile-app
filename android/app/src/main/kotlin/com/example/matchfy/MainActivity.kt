package com.orionapp.kelimeeslestirme

import android.media.MediaPlayer
import android.os.Bundle
import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.*

class MainActivity : FlutterActivity() {
    private lateinit var tts: TextToSpeech
    private val CHANNEL = "com.orionapp.kelimeeslestirme/text_to_speech"
    private var mediaPlayer: MediaPlayer? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        tts = TextToSpeech(applicationContext) { status ->
            if (status == TextToSpeech.SUCCESS) {
                tts.language = Locale.US
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "speak" -> {
                    val text = call.argument<String>("text")
                    if (text != null) {
                        speak(text)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Text is required", null)
                    }
                }
                "playMp3" -> {
                    val mp3File = call.argument<String>("mp3File")
                    if (mp3File != null) {
                        playMp3(mp3File)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "MP3 file is required", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun speak(text: String) {
        tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, null)
    }

    private fun playMp3(mp3File: String) {
        // Eğer bir önceki ses çalıyorsa durdur
        mediaPlayer?.release()
        val resId = resources.getIdentifier(mp3File, "raw", packageName)
        mediaPlayer = MediaPlayer.create(this, resId)
        mediaPlayer?.start()
    }

    override fun onDestroy() {
        tts.stop()
        tts.shutdown()
        mediaPlayer?.release()
        super.onDestroy()
    }
}
