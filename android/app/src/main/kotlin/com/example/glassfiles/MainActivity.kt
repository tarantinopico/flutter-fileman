package com.example.glassfiles

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.Settings
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.util.zip.ZipOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "glassfiles/platform"
    private val worker = Executors.newSingleThreadExecutor()
    private var treeResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "storageRoot" -> result.success(Environment.getExternalStorageDirectory().absolutePath)
                    "hasAccess" -> result.success(if (Build.VERSION.SDK_INT >= 30) Environment.isExternalStorageManager() else checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED)
                    "requestAccess" -> {
                        if (Build.VERSION.SDK_INT >= 30) {
                            val uri = Uri.parse("package:$packageName")
                            try { startActivity(Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, uri)) }
                            catch (_: Exception) { startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)) }
                        } else requestPermissions(arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE, Manifest.permission.WRITE_EXTERNAL_STORAGE), 7)
                        result.success(null)
                    }
                    "load" -> result.success(getSharedPreferences("glassfiles", MODE_PRIVATE).getString("state", null))
                    "save" -> { getSharedPreferences("glassfiles", MODE_PRIVATE).edit().putString("state", call.argument<String>("data")).apply(); result.success(null) }
                    "pickTree" -> {
                        if (treeResult != null) { result.error("busy", "Folder picker already open", null); return@setMethodCallHandler }
                        treeResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                        try { startActivityForResult(intent, 42) } catch (e: Exception) { treeResult = null; result.error("picker", e.message, null) }
                    }
                    "listTree" -> background(result) { listTree(Uri.parse(call.argument<String>("uri")!!)) }
                    "open" -> {
                        val source = call.argument<String>("source")!!
                        val uri = if (source.startsWith("content://")) Uri.parse(source) else FileProvider.getUriForFile(this, "$packageName.files", File(source))
                        val mime = call.argument<String>("mime")?.takeIf { it.isNotBlank() } ?: contentResolver.getType(uri) ?: MimeTypeMap.getSingleton().getMimeTypeFromExtension(source.substringAfterLast('.', "").lowercase()) ?: "*/*"
                        val intent = Intent(Intent.ACTION_VIEW).setDataAndType(uri, mime).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        startActivity(Intent.createChooser(intent, call.argument<String>("title") ?: "Open with"))
                        result.success(null)
                    }
                    "share" -> {
                        val paths = call.argument<List<String>>("sources")!!
                        val uris = ArrayList(paths.map { if (it.startsWith("content://")) Uri.parse(it) else FileProvider.getUriForFile(this, "$packageName.files", File(it)) })
                        val intent = if (uris.size == 1) Intent(Intent.ACTION_SEND).setType("*/*").putExtra(Intent.EXTRA_STREAM, uris[0]) else Intent(Intent.ACTION_SEND_MULTIPLE).setType("*/*").putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
                        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        startActivity(Intent.createChooser(intent, call.argument<String>("title") ?: "Share")); result.success(null)
                    }
                    "transfer" -> background(result) { transfer(call.argument<List<String>>("sources")!!, call.argument<String>("destination")!!, call.argument<Boolean>("move") == true); null }
                    "zipCreate" -> background(result) { createZip(call.argument<List<String>>("sources")!!, call.argument<String>("output")!!); null }
                    "zipList" -> background(result) { ZipFile(call.argument<String>("path")!!).use { zip -> zip.entries().asSequence().map { it.name }.take(10001).toList() } }
                    "zipExtract" -> background(result) { extractZip(call.argument<String>("path")!!, call.argument<String>("destination")!!); null }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("platform", e.message ?: e.javaClass.simpleName, null) }
        }
    }

    private fun background(result: MethodChannel.Result, task: () -> Any?) {
        worker.execute {
            try { val value = task(); runOnUiThread { result.success(value) } }
            catch (e: Exception) { runOnUiThread { result.error("operation", e.message ?: e.javaClass.simpleName, null) } }
        }
    }

    @Deprecated("Used for compatibility with Flutter's activity lifecycle")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 42) {
            val pending = treeResult; treeResult = null
            val uri = data?.data
            if (resultCode == Activity.RESULT_OK && uri != null) {
                try {
                    val flags = (data?.flags ?: 0) and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                    contentResolver.takePersistableUriPermission(uri, flags)
                    pending?.success(uri.toString())
                } catch (e: Exception) { pending?.error("permission", e.message, null) }
            } else pending?.success(null)
        }
    }

    private fun listTree(uri: Uri): List<Map<String, Any?>> {
        val docId = if (DocumentsContract.isDocumentUri(this, uri)) DocumentsContract.getDocumentId(uri) else DocumentsContract.getTreeDocumentId(uri)
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(uri, docId)
        val columns = arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME, DocumentsContract.Document.COLUMN_MIME_TYPE, DocumentsContract.Document.COLUMN_SIZE, DocumentsContract.Document.COLUMN_LAST_MODIFIED)
        val items = mutableListOf<Map<String, Any?>>()
        contentResolver.query(children, columns, null, null, null)?.use { cursor ->
            while (cursor.moveToNext()) {
                val id = cursor.getString(0)
                val mime = cursor.getString(2) ?: "application/octet-stream"
                items.add(mapOf("path" to DocumentsContract.buildDocumentUriUsingTree(uri, id).toString(), "name" to (cursor.getString(1) ?: id), "directory" to (mime == DocumentsContract.Document.MIME_TYPE_DIR), "size" to (if (cursor.isNull(3)) 0L else cursor.getLong(3)), "modified" to (if (cursor.isNull(4)) 0L else cursor.getLong(4)), "mime" to mime))
            }
        } ?: throw IllegalStateException("Unable to list this folder")
        return items
    }

    // Never overwrite: reserve every output with createNewFile, verify copies before moves.
    private fun transfer(paths: List<String>, destination: String, move: Boolean) {
        val dest = File(destination).canonicalFile
        require(dest.isDirectory) { "Destination is not a folder" }
        fun digest(file: File): ByteArray {
            val md = java.security.MessageDigest.getInstance("SHA-256")
            file.inputStream().buffered().use { input -> val b = ByteArray(65536); while (true) { val n = input.read(b); if (n < 0) break; md.update(b, 0, n) } }
            return md.digest()
        }
        val copied = mutableListOf<Pair<File, File>>()
        val directories = mutableListOf<File>()
        fun copy(source: File, target: File) {
            require(!java.nio.file.Files.isSymbolicLink(source.toPath())) { "Symbolic links are not supported: ${source.name}" }
            if (source.isDirectory) {
                require(target.mkdir()) { "Already exists or cannot create: ${target.name}" }
                directories.add(source)
                val children = source.listFiles() ?: throw IllegalStateException("Cannot read ${source.name}")
                children.forEach { copy(it, File(target, it.name)) }
            } else {
                require(source.isFile) { "Not a regular file: ${source.name}" }
                require(target.createNewFile()) { "Already exists or cannot create: ${target.name}" }
                try {
                    source.inputStream().buffered().use { input -> target.outputStream().buffered().use { input.copyTo(it) } }
                    require(source.length() == target.length() && digest(source).contentEquals(digest(target))) { "Verification failed: ${source.name}" }
                    copied.add(source to target)
                } catch (e: Exception) { target.delete(); throw e }
            }
        }
        for (path in paths) {
            val source = File(path)
            require(source.exists()) { "Source no longer exists: $path" }
            val canonical = source.canonicalFile
            require(dest.path != canonical.path && !dest.path.startsWith(canonical.path + File.separator)) { "Cannot copy a folder into itself" }
            val target = File(dest, source.name)
            require(!target.exists()) { "Already exists: ${target.name}. No files were overwritten." }
            copied.clear(); directories.clear()
            copy(source, target)
            if (move) {
                // Check all copied files again before removing anything. Never recursively
                // delete a directory: newly arrived files must remain at the source.
                copied.forEach { (from, to) -> require(from.isFile && from.length() == to.length() && digest(from).contentEquals(digest(to))) { "Source changed during transfer: ${from.name}" } }
                copied.forEach { (from, to) ->
                    require(from.isFile && from.length() == to.length() && digest(from).contentEquals(digest(to))) { "Source changed during transfer: ${from.name}" }
                    check(from.delete()) { "Copy verified, but could not remove source: ${from.name}" }
                }
                directories.asReversed().forEach { check(it.delete()) { "Folder was not empty or could not be removed: ${it.name}" } }
            }
        }
    }

    private fun createZip(paths: List<String>, output: String) {
        require(paths.isNotEmpty()) { "No files selected" }
        val target = File(output)
        require(target.createNewFile()) { "Archive already exists" }
        try {
            ZipOutputStream(target.outputStream().buffered()).use { zip ->
                fun add(file: File, name: String) {
                    require(!java.nio.file.Files.isSymbolicLink(file.toPath())) { "Symbolic links are not supported" }
                    require(file.canonicalPath != target.canonicalPath) { "Archive cannot include itself" }
                    if (file.isDirectory) {
                        zip.putNextEntry(ZipEntry("$name/")); zip.closeEntry()
                        val children = file.listFiles() ?: throw IllegalStateException("Cannot read ${file.name}")
                        children.forEach { add(it, "$name/${it.name}") }
                    } else {
                        zip.putNextEntry(ZipEntry(name)); file.inputStream().buffered().use { it.copyTo(zip) }; zip.closeEntry()
                    }
                }
                paths.forEach { val f = File(it); require(f.exists()) { "File no longer exists: $it" }; add(f, f.name) }
            }
        } catch (e: Exception) { target.delete(); throw e }
    }

    private fun extractZip(path: String, destination: String) {
        val root = File(destination).canonicalFile
        require(root.isDirectory) { "Destination is not a folder" }
        var total = 0L; var count = 0
        ZipFile(path).use { zip ->
            val entries = zip.entries()
            while (entries.hasMoreElements()) {
                val entry = entries.nextElement()
                require(++count <= 10000) { "Archive has too many entries" }
                val file = File(root, entry.name).canonicalFile
                require(file.path.startsWith(root.path + File.separator)) { "Unsafe archive path: ${entry.name}" }
                if (entry.isDirectory) {
                    require(file.isDirectory || file.mkdirs()) { "Cannot create folder: ${file.name}" }
                } else {
                    val parent = file.parentFile ?: throw IllegalStateException("Invalid path")
                    require(parent.isDirectory || parent.mkdirs()) { "Cannot create folder" }
                    require(file.createNewFile()) { "File already exists: ${file.name}; extraction stopped" }
                    try {
                        zip.getInputStream(entry).use { input -> file.outputStream().buffered().use { out ->
                            val buffer = ByteArray(65536)
                            while (true) { val n = input.read(buffer); if (n < 0) break; total += n; require(total <= 1024L * 1024 * 1024) { "Extraction limit of 1 GiB exceeded" }; out.write(buffer, 0, n) }
                        } }
                    } catch (e: Exception) { file.delete(); throw e }
                }
            }
        }
    }

    override fun onDestroy() { worker.shutdown(); super.onDestroy() }
}
