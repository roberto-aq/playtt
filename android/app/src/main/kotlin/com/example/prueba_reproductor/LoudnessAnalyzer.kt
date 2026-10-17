package com.example.prueba_reproductor

import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.log10

/**
 * Mide cuán fuerte suena un archivo de audio, en dBFS (0 = máximo digital).
 *
 * Decodifica el audio a PCM, lo divide en bloques de 400 ms, descarta los
 * bloques casi silenciosos y promedia la energía del resto. Es una versión
 * simplificada de la medición LUFS (EBU R128) sin el filtro de ponderación K:
 * suficiente para igualar audios entre sí.
 */
object LoudnessAnalyzer {
    private const val BLOCK_SECONDS = 0.4

    /** Bloques por debajo de este nivel cuentan como silencio y se ignoran. */
    private const val SILENCE_DB = -60.0

    /** Con los primeros 3 minutos alcanza para estimar y el análisis es rápido. */
    private const val MAX_SECONDS = 180L

    private const val TIMEOUT_US = 10_000L

    /** Sonoridad en dBFS, o `null` si no se pudo decodificar o es silencio. */
    fun measure(path: String): Double? {
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        try {
            extractor.setDataSource(path)
            val track = (0 until extractor.trackCount).firstOrNull { i ->
                extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
            } ?: return null

            val format = extractor.getTrackFormat(track)
            extractor.selectTrack(track)
            codec = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
            codec.configure(format, null, null, 0)
            codec.start()

            val blocks = BlockMeter(
                sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE),
                channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT),
            )
            var floatPcm = false
            val info = MediaCodec.BufferInfo()
            var inputDone = false

            while (true) {
                if (!inputDone) {
                    val inIndex = codec.dequeueInputBuffer(TIMEOUT_US)
                    if (inIndex >= 0) {
                        val input = codec.getInputBuffer(inIndex)!!
                        val size = extractor.readSampleData(input, 0)
                        val tooLong = extractor.sampleTime > MAX_SECONDS * 1_000_000
                        if (size < 0 || tooLong) {
                            codec.queueInputBuffer(inIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            codec.queueInputBuffer(inIndex, 0, size, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }

                val outIndex = codec.dequeueOutputBuffer(info, TIMEOUT_US)
                if (outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    // El formato real de salida (puede diferir del archivo).
                    val out = codec.outputFormat
                    blocks.reconfigure(
                        out.getInteger(MediaFormat.KEY_SAMPLE_RATE),
                        out.getInteger(MediaFormat.KEY_CHANNEL_COUNT),
                    )
                    floatPcm = out.containsKey(MediaFormat.KEY_PCM_ENCODING) &&
                        out.getInteger(MediaFormat.KEY_PCM_ENCODING) == AudioFormat.ENCODING_PCM_FLOAT
                } else if (outIndex >= 0) {
                    if (info.size > 0) {
                        val output = codec.getOutputBuffer(outIndex)!!
                        output.position(info.offset)
                        output.limit(info.offset + info.size)
                        blocks.add(output.order(ByteOrder.nativeOrder()), floatPcm)
                    }
                    codec.releaseOutputBuffer(outIndex, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
                }
            }
            return blocks.loudnessDb()
        } catch (e: Exception) {
            return null
        } finally {
            runCatching { codec?.stop() }
            runCatching { codec?.release() }
            extractor.release()
        }
    }

    /** Acumula la energía de las muestras en bloques de [BLOCK_SECONDS]. */
    private class BlockMeter(sampleRate: Int, channels: Int) {
        private var samplesPerBlock = 0
        private var sumSquares = 0.0
        private var count = 0
        private val blockEnergies = ArrayList<Double>()

        init {
            reconfigure(sampleRate, channels)
        }

        fun reconfigure(sampleRate: Int, channels: Int) {
            samplesPerBlock = maxOf(1, (sampleRate * channels * BLOCK_SECONDS).toInt())
        }

        fun add(buffer: ByteBuffer, floatPcm: Boolean) {
            if (floatPcm) {
                val samples = buffer.asFloatBuffer()
                while (samples.hasRemaining()) addSample(samples.get().toDouble())
            } else {
                val samples = buffer.asShortBuffer()
                while (samples.hasRemaining()) addSample(samples.get() / 32768.0)
            }
        }

        private fun addSample(sample: Double) {
            sumSquares += sample * sample
            count++
            if (count >= samplesPerBlock) {
                blockEnergies.add(sumSquares / count)
                sumSquares = 0.0
                count = 0
            }
        }

        fun loudnessDb(): Double? {
            val silence = Math.pow(10.0, SILENCE_DB / 10)
            val audible = blockEnergies.filter { it > silence }
            if (audible.isEmpty()) return null
            return 10 * log10(audible.average())
        }
    }
}
