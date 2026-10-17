package com.example.prueba_reproductor

import android.content.Intent
import android.media.MediaMetadataRetriever
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Bundle
import android.util.Log
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// AudioServiceActivity conecta la actividad con el servicio de audio en segundo plano (audio_service).
class MainActivity : AudioServiceActivity() {
    private companion object {
        const val PICK_FOLDER = 4242
        const val TAG = "Reproductor"

        /**
         * Respuesta pendiente mientras el selector de carpetas está abierto.
         * Es estática porque algunos fabricantes destruyen y recrean la
         * actividad mientras el selector está en primer plano; el motor de
         * Flutter (y esta respuesta) siguen vivos igual.
         */
        var pendingPick: MethodChannel.Result? = null

        /**
         * Texto recibido con "Compartir" que Flutter todavía no leyó. Se guarda
         * porque puede llegar antes de que Dart esté listo para escucharlo.
         */
        var pendingSharedText: String? = null

        /** Canal activo, para avisar a Flutter cuando llega un texto compartido. */
        var channel: MethodChannel? = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Arranque en frío: la app se abrió desde el menú Compartir. Si la
        // actividad se está recreando (savedInstanceState != null), su intent
        // es el mismo de antes y ya se procesó.
        if (savedInstanceState == null) handleShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Arranque en caliente: la app ya estaba abierta (launchMode="singleTask").
        handleShareIntent(intent)
    }

    /** Guarda el texto de un intent ACTION_SEND y avisa a Flutter. */
    private fun handleShareIntent(intent: Intent?) {
        if (intent?.action != Intent.ACTION_SEND) return
        if (intent.type?.startsWith("text/") != true) return
        // Abrir la app desde Recientes repite el último intent: no es un envío nuevo.
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return

        val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return
        Log.d(TAG, "share: texto recibido (${text.length} caracteres)")
        pendingSharedText = text
        // Si Dart aún no registró su handler, el aviso se pierde, pero no
        // importa: al arrancar, Dart pide el texto pendiente con takeSharedText.
        channel?.invokeMethod("sharedTextAvailable", null)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "prueba_reproductor/media")
        channel = methodChannel
        methodChannel
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "takeSharedText" -> {
                        // Entrega el texto una sola vez.
                        result.success(pendingSharedText)
                        pendingSharedText = null
                    }
                    "pickFolder" -> {
                        // Si quedó una selección anterior sin respuesta, se da por cancelada.
                        pendingPick?.success(null)
                        pendingPick = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(
                            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
                        )
                        try {
                            Log.d(TAG, "pickFolder: abriendo el selector")
                            startActivityForResult(intent, PICK_FOLDER)
                        } catch (e: Exception) {
                            Log.e(TAG, "pickFolder: no se pudo abrir el selector", e)
                            pendingPick = null
                            result.error("PICK_FAILED", e.message, null)
                        }
                    }
                    "saveToFolder" -> {
                        val treeUri = Uri.parse(call.argument<String>("treeUri")!!)
                        val source = File(call.argument<String>("source")!!)
                        val name = call.argument<String>("name")!!
                        val mime = call.argument<String>("mime")!!
                        inBackground(result) { StorageFolders.copyInto(this, treeUri, source, name, mime) }
                    }
                    "extractAudio" -> {
                        val input = call.argument<String>("input")!!
                        val output = call.argument<String>("output")!!
                        inBackground(result) { AudioExtractor.extract(input, output) }
                    }
                    "scanFile" -> {
                        // Avisa al sistema para que otras apps de música vean el archivo.
                        val path = call.argument<String>("path")!!
                        MediaScannerConnection.scanFile(this, arrayOf(path), null, null)
                        result.success(null)
                    }
                    "getDurations" -> {
                        val paths = call.argument<List<String>>("paths")!!
                        inBackground(result) { paths.map(::readDurationMs) }
                    }
                    // Ajustes simples guardados con las SharedPreferences nativas.
                    "getSetting" -> {
                        val key = call.argument<String>("key")!!
                        result.success(settings().getString(key, null))
                    }
                    "setSetting" -> {
                        val key = call.argument<String>("key")!!
                        val value = call.argument<String>("value")
                        settings().edit().apply {
                            if (value == null) remove(key) else putString(key, value)
                        }.apply()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != PICK_FOLDER) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val treeUri = data?.data
        Log.d(TAG, "pickFolder: resultado=$resultCode uri=$treeUri pendiente=${pendingPick != null}")
        val result = pendingPick ?: return
        pendingPick = null

        if (resultCode != RESULT_OK || treeUri == null) {
            result.success(null) // El usuario canceló.
            return
        }
        try {
            // Conserva el permiso de lectura/escritura aunque se reinicie el teléfono.
            contentResolver.takePersistableUriPermission(
                treeUri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
            val path = StorageFolders.pathFromTreeUri(treeUri)
            Log.d(TAG, "pickFolder: ruta=$path")
            result.success(mapOf("uri" to treeUri.toString(), "path" to path))
        } catch (e: Exception) {
            Log.e(TAG, "pickFolder: no se pudo guardar el permiso", e)
            result.error("PICK_FAILED", e.message, null)
        }
    }

    /** Ejecuta [work] fuera del hilo principal y responde a Flutter con su resultado. */
    private fun inBackground(result: MethodChannel.Result, work: () -> Any?) {
        Thread {
            try {
                val value = work()
                runOnUiThread { result.success(if (value is Unit) null else value) }
            } catch (e: Exception) {
                runOnUiThread { result.error("NATIVE_ERROR", e.message, null) }
            }
        }.start()
    }

    private fun settings() = getSharedPreferences("app_settings", MODE_PRIVATE)

    /** Duración en milisegundos leída de los metadatos, o null si no se puede. */
    private fun readDurationMs(path: String): Long? {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(path)
            retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull()
        } catch (e: Exception) {
            null
        } finally {
            runCatching { retriever.release() }
        }
    }
}
