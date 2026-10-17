package com.example.prueba_reproductor

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File
import java.nio.ByteBuffer

/**
 * Copia la pista de audio de un video MP4 a un archivo .m4a sin recodificar:
 * se conserva la calidad original, el archivo queda sin video y el proceso
 * tarda menos de un segundo.
 */
object AudioExtractor {
    fun extract(inputPath: String, outputPath: String) {
        val extractor = MediaExtractor()
        var muxer: MediaMuxer? = null
        var started = false
        try {
            extractor.setDataSource(inputPath)

            val audioTrack = (0 until extractor.trackCount).firstOrNull { i ->
                extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
            } ?: throw IllegalStateException("El video no tiene pista de audio")

            val format = extractor.getTrackFormat(audioTrack)
            extractor.selectTrack(audioTrack)

            muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            val outTrack = muxer.addTrack(format)
            muxer.start()
            started = true

            val bufferSize = if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                maxOf(format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE), 64 * 1024)
            } else {
                256 * 1024
            }
            val buffer = ByteBuffer.allocate(bufferSize)
            val info = MediaCodec.BufferInfo()

            while (true) {
                val size = extractor.readSampleData(buffer, 0)
                if (size < 0) break
                info.set(0, size, extractor.sampleTime, MediaCodec.BUFFER_FLAG_KEY_FRAME)
                muxer.writeSampleData(outTrack, buffer, info)
                extractor.advance()
            }
            muxer.stop()
            started = false
        } catch (e: Exception) {
            File(outputPath).delete()
            throw e
        } finally {
            if (started) runCatching { muxer?.stop() }
            runCatching { muxer?.release() }
            extractor.release()
        }
    }
}
