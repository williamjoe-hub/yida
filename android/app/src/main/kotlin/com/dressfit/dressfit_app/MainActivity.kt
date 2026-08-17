package com.dressfit.dressfit_app

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Rect
import android.media.ExifInterface
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.nio.FloatBuffer
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.sin

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.dressfit.dressfit_app/garment_processor"
        private const val AUDIO_CHANNEL = "com.dressfit.dressfit_app/app_audio"
        private const val MODEL_ASSET = "u2netp.onnx"
        private const val MODEL_SIZE = 320
        private const val OUTPUT_SIZE = 512
    }

    private val imageExecutor = Executors.newSingleThreadExecutor()
    private val audioExecutor = Executors.newSingleThreadExecutor()
    @Volatile private var startupAudioTrack: AudioTrack? = null
    private val ortEnvironment: OrtEnvironment by lazy { OrtEnvironment.getEnvironment() }
    @Volatile private var ortSession: OrtSession? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL)
            .setMethodCallHandler { call, result ->
                val preferences = getSharedPreferences("audio_settings", MODE_PRIVATE)
                when (call.method) {
                    "playStartupSound" -> {
                        if (preferences.getBoolean("startupEnabled", true)) {
                            audioExecutor.execute { playStartupSound() }
                        }
                        result.success(null)
                    }
                    "playEffect" -> {
                        if (preferences.getBoolean("effectsEnabled", true)) {
                            val effect = call.argument<String>("effect") ?: "complete"
                            audioExecutor.execute { playFeedbackSound(effect) }
                        }
                        result.success(null)
                    }
                    "getAudioSettings" -> result.success(
                        mapOf(
                            "effectsEnabled" to preferences.getBoolean("effectsEnabled", true),
                            "startupEnabled" to preferences.getBoolean("startupEnabled", true),
                            "volume" to preferences.getString("volume", "soft"),
                        ),
                    )
                    "setAudioSetting" -> {
                        val key = call.argument<String>("key")
                        val value = call.argument<Any>("value")
                        if (key != null) {
                            preferences.edit().apply {
                                when (value) {
                                    is Boolean -> putBoolean(key, value)
                                    is String -> putString(key, value)
                                }
                            }.apply()
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, channelResult ->
                when (call.method) {
                    "prepareModel" -> imageExecutor.execute {
                        try {
                            getOrtSession()
                            val probe = Bitmap.createBitmap(48, 48, Bitmap.Config.ARGB_8888).apply {
                                eraseColor(Color.rgb(216, 214, 209))
                            }
                            segmentOffline(probe).recycle()
                            probe.recycle()
                            runOnUiThread { channelResult.success(true) }
                        } catch (error: Exception) {
                            runOnUiThread {
                                channelResult.error("MODEL_FAILED", "本地抠图组件初始化失败", error.message)
                            }
                        }
                    }
                    "processGarment" -> {
                        val inputPath = call.argument<String>("inputPath")
                        val outputPath = call.argument<String>("outputPath")
                        val category = call.argument<String>("category") ?: "top"
                        if (inputPath.isNullOrBlank() || outputPath.isNullOrBlank()) {
                            channelResult.error("BAD_ARGUMENTS", "缺少照片路径", null)
                        } else {
                            processGarment(inputPath, outputPath, category, channelResult)
                        }
                    }
                    else -> channelResult.notImplemented()
                }
            }
    }

    private fun playStartupSound() {
        val sampleRate = 44_100
        val durationSeconds = 0.56
        val sampleCount = (sampleRate * durationSeconds).roundToInt()
        val pcm = ShortArray(sampleCount)
        for (index in pcm.indices) {
            val time = index.toDouble() / sampleRate

            // A soft mid-range bloom feels friendly and avoids an ominous low-frequency rise.
            val bloomProgress = (time / 0.20).coerceIn(0.0, 1.0)
            val bloomFrequency = 261.63 + 16.0 * bloomProgress * bloomProgress
            val bodyEnvelope = softEnvelope(time, 0.024, 0.19, 2.8)
            val body = sin(2.0 * PI * bloomFrequency * time) * bodyEnvelope * 0.31

            // A quiet, open chord arrives early and resolves before it can feel like an alert.
            val chordTime = time - 0.075
            val chordEnvelope = if (chordTime >= 0.0) softEnvelope(chordTime, 0.032, 0.22, 2.7) else 0.0
            val chord = if (chordTime >= 0.0) {
                (
                    sin(2.0 * PI * 329.63 * chordTime) * 0.22 +
                    sin(2.0 * PI * 392.00 * chordTime) * 0.14
                ) * chordEnvelope
            } else 0.0

            // Only a trace of second harmonic remains, keeping the timbre rounded.
            val warmth = sin(2.0 * PI * bloomFrequency * 2.0 * time) * bodyEnvelope * 0.022
            val mixed = ((body + chord + warmth) * 0.48).coerceIn(-1.0, 1.0)
            pcm[index] = (mixed * Short.MAX_VALUE).roundToInt().toShort()
        }

        playPcm(pcm, sampleRate, preferredVolume(0.42f, 0.55f))
    }

    private fun playFeedbackSound(effect: String) {
        val sampleRate = 44_100
        val duration = when (effect) {
            "added" -> 0.30
            "deleted" -> 0.22
            else -> 0.34
        }
        val pcm = ShortArray((sampleRate * duration).roundToInt())
        for (index in pcm.indices) {
            val time = index.toDouble() / sampleRate
            val progress = (time / duration).coerceIn(0.0, 1.0)
            val frequencies = when (effect) {
                "added" -> 349.23 to 466.16
                "deleted" -> 329.63 to 277.18
                else -> 392.00 to 493.88
            }
            val frequency = frequencies.first + (frequencies.second - frequencies.first) * progress
            val releaseStart = duration * if (effect == "deleted") 0.32 else 0.48
            val envelope = softEnvelope(time, 0.018, releaseStart, 3.4)
            val main = sin(2.0 * PI * frequency * time) * 0.34
            val harmony = if (effect == "deleted") 0.0 else sin(2.0 * PI * frequency * 1.25 * time) * 0.10
            pcm[index] = (((main + harmony) * envelope * 0.46).coerceIn(-1.0, 1.0) * Short.MAX_VALUE)
                .roundToInt().toShort()
        }
        playPcm(pcm, sampleRate, preferredVolume(0.34f, 0.46f))
    }

    private fun preferredVolume(soft: Float, standard: Float): Float {
        val value = getSharedPreferences("audio_settings", MODE_PRIVATE).getString("volume", "soft")
        return if (value == "standard") standard else soft
    }

    private fun playPcm(pcm: ShortArray, sampleRate: Int, volume: Float) {
        startupAudioTrack?.runCatching {
            stop()
            release()
        }
        val track = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build(),
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(sampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build(),
            )
            .setBufferSizeInBytes(pcm.size * 2)
            .setTransferMode(AudioTrack.MODE_STATIC)
            .build()
        track.write(pcm, 0, pcm.size)
        startupAudioTrack = track
        track.setVolume(volume)
        track.notificationMarkerPosition = pcm.size - 1
        track.setPlaybackPositionUpdateListener(object : AudioTrack.OnPlaybackPositionUpdateListener {
            override fun onMarkerReached(audioTrack: AudioTrack) {
                audioTrack.stop()
                audioTrack.release()
                startupAudioTrack = null
            }

            override fun onPeriodicNotification(audioTrack: AudioTrack) = Unit
        })
        track.play()
    }

    private fun softEnvelope(time: Double, attack: Double, releaseStart: Double, decay: Double): Double {
        val attackGain = (time / attack).coerceIn(0.0, 1.0)
        val releaseGain = if (time <= releaseStart) 1.0 else exp(-(time - releaseStart) * decay * 8.0)
        return attackGain * attackGain * releaseGain
    }

    @Synchronized
    private fun getOrtSession(): OrtSession {
        ortSession?.let { return it }
        val model = assets.open(MODEL_ASSET).use { it.readBytes() }
        val options = OrtSession.SessionOptions().apply {
            setIntraOpNumThreads(max(2, Runtime.getRuntime().availableProcessors() / 2))
            setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)
        }
        return ortEnvironment.createSession(model, options).also { ortSession = it }
    }

    private fun processGarment(inputPath: String, outputPath: String, category: String, channelResult: MethodChannel.Result) {
        imageExecutor.execute {
            try {
                val bitmap = decodeOrientedBitmap(inputPath) ?: throw IllegalArgumentException("无法读取照片")
                val focusCrop = cropToCameraGuide(bitmap, category)
                if (focusCrop !== bitmap) bitmap.recycle()
                val foreground = segmentOffline(focusCrop)
                focusCrop.recycle()
                val card = createGarmentCard(foreground, category)
                foreground.recycle()
                val outputFile = File(outputPath)
                outputFile.parentFile?.mkdirs()
                FileOutputStream(outputFile).use { stream ->
                    if (!card.compress(Bitmap.CompressFormat.PNG, 100, stream)) throw IllegalStateException("图片保存失败")
                }
                card.recycle()
                runOnUiThread { channelResult.success(outputFile.absolutePath) }
            } catch (error: Exception) {
                runOnUiThread {
                    channelResult.error("PROCESSING_FAILED", "没有识别到完整衣物，请让衣物填满虚线框后重拍", error.message)
                }
            }
        }
    }

    private fun segmentOffline(source: Bitmap): Bitmap {
        val session = getOrtSession()
        val scale = min(MODEL_SIZE.toFloat() / source.width, MODEL_SIZE.toFloat() / source.height)
        val scaledWidth = max(1, (source.width * scale).roundToInt())
        val scaledHeight = max(1, (source.height * scale).roundToInt())
        val scaled = Bitmap.createScaledBitmap(source, scaledWidth, scaledHeight, true)
        val modelBitmap = Bitmap.createBitmap(MODEL_SIZE, MODEL_SIZE, Bitmap.Config.ARGB_8888)
        val padX = (MODEL_SIZE - scaledWidth) / 2
        val padY = (MODEL_SIZE - scaledHeight) / 2
        Canvas(modelBitmap).drawBitmap(scaled, padX.toFloat(), padY.toFloat(), null)
        if (scaled !== source) scaled.recycle()

        val pixels = IntArray(MODEL_SIZE * MODEL_SIZE)
        modelBitmap.getPixels(pixels, 0, MODEL_SIZE, 0, 0, MODEL_SIZE, MODEL_SIZE)
        modelBitmap.recycle()
        val input = FloatArray(3 * MODEL_SIZE * MODEL_SIZE)
        val plane = MODEL_SIZE * MODEL_SIZE
        pixels.forEachIndexed { index, pixel ->
            input[index] = ((Color.red(pixel) / 255f) - 0.485f) / 0.229f
            input[plane + index] = ((Color.green(pixel) / 255f) - 0.456f) / 0.224f
            input[plane * 2 + index] = ((Color.blue(pixel) / 255f) - 0.406f) / 0.225f
        }

        val inputName = session.inputNames.first()
        OnnxTensor.createTensor(
            ortEnvironment,
            FloatBuffer.wrap(input),
            longArrayOf(1, 3, MODEL_SIZE.toLong(), MODEL_SIZE.toLong()),
        ).use { tensor ->
            session.run(mapOf(inputName to tensor)).use { result ->
                val rawMask = FloatArray(MODEL_SIZE * MODEL_SIZE)
                copyFloats(result[0].value, rawMask, intArrayOf(0))
                val minValue = rawMask.minOrNull() ?: 0f
                val maxValue = rawMask.maxOrNull() ?: 1f
                val range = max(0.00001f, maxValue - minValue)
                val alphaPixels = IntArray(MODEL_SIZE * MODEL_SIZE)
                rawMask.forEachIndexed { index, value ->
                    val normalized = ((value - minValue) / range).coerceIn(0f, 1f)
                    val softened = smoothStep(0.10f, 0.72f, normalized)
                    alphaPixels[index] = Color.argb((softened * 255f).roundToInt(), 255, 255, 255)
                }
                val mask = Bitmap.createBitmap(MODEL_SIZE, MODEL_SIZE, Bitmap.Config.ARGB_8888)
                mask.setPixels(alphaPixels, 0, MODEL_SIZE, 0, 0, MODEL_SIZE, MODEL_SIZE)
                val unpadded = Bitmap.createBitmap(mask, padX, padY, scaledWidth, scaledHeight)
                mask.recycle()
                val fullMask = Bitmap.createScaledBitmap(unpadded, source.width, source.height, true)
                if (fullMask !== unpadded) unpadded.recycle()

                val sourcePixels = IntArray(source.width * source.height)
                val maskPixels = IntArray(source.width * source.height)
                source.getPixels(sourcePixels, 0, source.width, 0, 0, source.width, source.height)
                fullMask.getPixels(maskPixels, 0, source.width, 0, 0, source.width, source.height)
                fullMask.recycle()
                for (index in sourcePixels.indices) {
                    val color = sourcePixels[index]
                    sourcePixels[index] = Color.argb(
                        Color.alpha(maskPixels[index]),
                        Color.red(color), Color.green(color), Color.blue(color),
                    )
                }
                return Bitmap.createBitmap(sourcePixels, source.width, source.height, Bitmap.Config.ARGB_8888)
            }
        }
    }

    private fun copyFloats(value: Any?, target: FloatArray, offset: IntArray) {
        when (value) {
            is FloatArray -> {
                val count = min(value.size, target.size - offset[0])
                if (count > 0) {
                    System.arraycopy(value, 0, target, offset[0], count)
                    offset[0] += count
                }
            }
            is Array<*> -> value.forEach { copyFloats(it, target, offset) }
        }
    }

    private fun smoothStep(edge0: Float, edge1: Float, value: Float): Float {
        val x = ((value - edge0) / (edge1 - edge0)).coerceIn(0f, 1f)
        return x * x * (3f - 2f * x)
    }

    private fun cropToCameraGuide(bitmap: Bitmap, category: String): Bitmap {
        val ratios = when (category) {
            "hat" -> 0.78f to 0.38f
            "bottom" -> 0.68f to 0.66f
            "shoes" -> 0.94f to 0.42f
            else -> 0.88f to 0.58f
        }
        val width = (bitmap.width * ratios.first).roundToInt().coerceAtMost(bitmap.width)
        val height = (bitmap.height * ratios.second).roundToInt().coerceAtMost(bitmap.height)
        val centerX = bitmap.width / 2
        val centerY = (bitmap.height * 0.43f).roundToInt()
        val left = (centerX - width / 2).coerceIn(0, bitmap.width - width)
        val top = (centerY - height / 2).coerceIn(0, bitmap.height - height)
        return Bitmap.createBitmap(bitmap, left, top, width, height)
    }

    private fun decodeOrientedBitmap(path: String): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        var sample = 1
        while (max(bounds.outWidth, bounds.outHeight) / sample > 1800) sample *= 2
        val decoded = BitmapFactory.decodeFile(
            path,
            BitmapFactory.Options().apply { inSampleSize = sample; inPreferredConfig = Bitmap.Config.ARGB_8888 },
        ) ?: return null
        val orientation = ExifInterface(path).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.postScale(-1f, 1f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.postScale(1f, -1f)
        }
        if (matrix.isIdentity) return decoded
        val oriented = Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
        if (oriented !== decoded) decoded.recycle()
        return oriented
    }

    private fun createGarmentCard(foreground: Bitmap, category: String): Bitmap {
        val bounds = opaqueBounds(foreground) ?: throw IllegalArgumentException("没有识别到衣物")
        val paddingX = max(6, (bounds.width() * 0.025f).roundToInt())
        val paddingY = max(6, (bounds.height() * 0.025f).roundToInt())
        val left = max(0, bounds.left - paddingX)
        val top = max(0, bounds.top - paddingY)
        val right = min(foreground.width, bounds.right + paddingX)
        val bottom = min(foreground.height, bounds.bottom + paddingY)
        val cropped = Bitmap.createBitmap(foreground, left, top, right - left, bottom - top)
        val limits = when (category) {
            "hat" -> 400 to 330
            "bottom" -> 370 to 430
            "shoes" -> 440 to 350
            else -> 410 to 410
        }
        val scale = min(limits.first.toFloat() / cropped.width, limits.second.toFloat() / cropped.height)
        val width = max(1, (cropped.width * scale).roundToInt())
        val height = max(1, (cropped.height * scale).roundToInt())
        val scaled = Bitmap.createScaledBitmap(cropped, width, height, true)
        if (scaled !== cropped) cropped.recycle()
        val output = Bitmap.createBitmap(OUTPUT_SIZE, OUTPUT_SIZE, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        canvas.drawColor(Color.rgb(245, 243, 239))
        val x = (OUTPUT_SIZE - width) / 2f
        val y = (OUTPUT_SIZE - height) / 2f - if (category == "shoes") 3f else 8f
        val alpha = scaled.extractAlpha()
        val shadow = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(42, 27, 24, 21)
            maskFilter = BlurMaskFilter(7f, BlurMaskFilter.Blur.NORMAL)
        }
        canvas.drawBitmap(alpha, x, y + 7f, shadow)
        alpha.recycle()
        canvas.drawBitmap(scaled, x, y, Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG))
        scaled.recycle()
        return output
    }

    private fun opaqueBounds(bitmap: Bitmap): Rect? {
        val pixels = IntArray(bitmap.width * bitmap.height)
        bitmap.getPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
        var left = bitmap.width; var top = bitmap.height; var right = -1; var bottom = -1
        pixels.forEachIndexed { index, pixel ->
            if (Color.alpha(pixel) > 20) {
                val x = index % bitmap.width; val y = index / bitmap.width
                if (x < left) left = x; if (x > right) right = x
                if (y < top) top = y; if (y > bottom) bottom = y
            }
        }
        return if (right < left || bottom < top) null else Rect(left, top, right + 1, bottom + 1)
    }

    override fun onDestroy() {
        ortSession?.close()
        ortSession = null
        startupAudioTrack?.runCatching {
            stop()
            release()
        }
        startupAudioTrack = null
        imageExecutor.shutdown()
        audioExecutor.shutdown()
        super.onDestroy()
    }
}
