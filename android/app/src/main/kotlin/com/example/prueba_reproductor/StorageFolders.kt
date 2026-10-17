package com.example.prueba_reproductor

import android.content.Context
import android.net.Uri
import android.os.Environment
import android.provider.DocumentsContract
import java.io.File
import java.io.IOException

/**
 * Carpetas elegidas con el selector del sistema (Storage Access Framework).
 *
 * Desde Android 11 una app no puede crear archivos con rutas normales en
 * carpetas propias de la raíz (p. ej. "/TikTok Gym"), pero sí a través del
 * permiso que el usuario concede al elegir la carpeta en el selector.
 */
object StorageFolders {
    /** "primary:TikTok Gym" → "/storage/emulated/0/TikTok Gym". */
    fun pathFromTreeUri(treeUri: Uri): String? {
        val docId = DocumentsContract.getTreeDocumentId(treeUri)
        if (docId.startsWith("raw:")) return docId.removePrefix("raw:")

        val parts = docId.split(":", limit = 2)
        if (parts.size != 2) return null
        val (volume, relative) = parts
        val base = if (volume.equals("primary", ignoreCase = true)) {
            @Suppress("DEPRECATION")
            Environment.getExternalStorageDirectory().path
        } else {
            "/storage/$volume" // Tarjeta SD u otro volumen.
        }
        return if (relative.isEmpty()) base else "$base/$relative"
    }

    /**
     * Copia [source] dentro de la carpeta [treeUri] como [name].
     * Devuelve el nombre final: si ya existe uno igual, el sistema agrega " (1)".
     */
    fun copyInto(context: Context, treeUri: Uri, source: File, name: String, mime: String): String {
        val resolver = context.contentResolver
        val folder = DocumentsContract.buildDocumentUriUsingTree(
            treeUri,
            DocumentsContract.getTreeDocumentId(treeUri),
        )
        val document = DocumentsContract.createDocument(resolver, folder, mime, name)
            ?: throw IOException("No se pudo crear el archivo en la carpeta")

        try {
            val output = resolver.openOutputStream(document)
                ?: throw IOException("No se pudo escribir el archivo")
            output.use { out -> source.inputStream().use { it.copyTo(out) } }
        } catch (e: Exception) {
            runCatching { DocumentsContract.deleteDocument(resolver, document) }
            throw e
        }

        resolver.query(
            document,
            arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) return cursor.getString(0)
        }
        return name
    }
}
