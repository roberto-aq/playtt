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

    /**
     * Renombra [filePath] (que está dentro de la carpeta [treeUri]) a
     * [newName]. Devuelve el nombre final que asignó el sistema.
     */
    fun rename(context: Context, treeUri: Uri, folderPath: String, filePath: String, newName: String): String {
        val document = documentUri(treeUri, folderPath, filePath)
        val renamed = DocumentsContract.renameDocument(context.contentResolver, document, newName)
            ?: throw IOException("No se pudo renombrar el archivo")
        context.contentResolver.query(
            renamed,
            arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) return cursor.getString(0)
        }
        return newName
    }

    /** Elimina [filePath], que está dentro de la carpeta [treeUri]. */
    fun delete(context: Context, treeUri: Uri, folderPath: String, filePath: String) {
        val document = documentUri(treeUri, folderPath, filePath)
        if (!DocumentsContract.deleteDocument(context.contentResolver, document)) {
            throw IOException("No se pudo eliminar el archivo")
        }
    }

    /**
     * URI SAF de un archivo dentro de la carpeta. El proveedor de
     * almacenamiento local identifica cada documento como
     * "<volumen>:<ruta relativa>", p. ej. "primary:TikTok Gym/audio.m4a".
     */
    private fun documentUri(treeUri: Uri, folderPath: String, filePath: String): Uri {
        val treeDocId = DocumentsContract.getTreeDocumentId(treeUri)
        val docId = if (treeDocId.startsWith("raw:")) {
            "raw:$filePath"
        } else {
            val relative = File(filePath).relativeTo(File(folderPath)).path
            if (treeDocId.endsWith(":")) "$treeDocId$relative" else "$treeDocId/$relative"
        }
        return DocumentsContract.buildDocumentUriUsingTree(treeUri, docId)
    }
}
