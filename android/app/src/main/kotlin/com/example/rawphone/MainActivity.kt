package com.example.rawphone

import io.flutter.embedding.android.FlutterActivity
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.BatteryManager
import android.os.Build.VERSION
import android.os.Build.VERSION_CODES
import androidx.annotation.NonNull
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "samples.flutter.dev/battery"

    private var audioTrack: AudioTrack? = null;

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            // Note: this method is invoked on the main thread.
            call, result ->
            if (call.method == "initAudioTrack") {
                val bufsize = AudioTrack.getMinBufferSize(8000,
                        AudioFormat.CHANNEL_OUT_MONO,
                        AudioFormat.ENCODING_PCM_16BIT);
                val audio = AudioTrack(AudioManager.STREAM_MUSIC,
                        8000, //sample rate
                        AudioFormat.CHANNEL_OUT_MONO,
                        AudioFormat.ENCODING_PCM_16BIT, // 16-bit
                        bufsize,
                        AudioTrack.MODE_STREAM);
                audio.play()
                audioTrack = audio
                result.success(0)
            } else if (call.method == "writeAudioBytes") {
                val bytes: ByteArray? = call.argument("bytes");
                if (bytes != null) {
                    audioTrack?.write(bytes, 0, bytes.size);
                }
                result.success(0)
            } else if (call.method == "getBatteryLevel") {
//                val bytes: ByteArray? = call.argument("bytes");
//                if (bytes != null) {
//                    play2(bytes);
//                }
                //play1()
                //play1()
                val batteryLevel = getBatteryLevel()
                if (batteryLevel != -1) {
                    result.success(batteryLevel)
                } else {
                    result.error("UNAVAILABLE", "Battery level not available.", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun play1() {
        val bytes = ByteArray(8000 * 2);
        for (i in 0..8000 - 1) {
            bytes.set(i * 2 + 1, Math.floor(50.0 + 50.0 * Math.sin(i.toDouble())).toByte());
        }

        play2(bytes)
    }

    private fun play2(bytes: ByteArray) {
        val bufsize = AudioTrack.getMinBufferSize(8000,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT);

        val audio = AudioTrack(AudioManager.STREAM_MUSIC,
                8000, //sample rate
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT, // 16-bit
                bufsize,
                AudioTrack.MODE_STREAM);
        audio.play()
        audio.write(bytes, 0, bytes.size);
    }

    private fun getBatteryLevel(): Int {
        val batteryLevel: Int
        if (VERSION.SDK_INT >= VERSION_CODES.LOLLIPOP) {
            val batteryManager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            batteryLevel = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        } else {
            val intent = ContextWrapper(applicationContext).registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            batteryLevel = intent!!.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) * 100 / intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        }
        return batteryLevel
    }

}
