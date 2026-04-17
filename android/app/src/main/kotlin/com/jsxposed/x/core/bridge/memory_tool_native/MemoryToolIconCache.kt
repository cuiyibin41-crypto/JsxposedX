package com.jsxposed.x.core.bridge.memory_tool_native

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.os.Build
import androidx.annotation.RequiresApi
import java.io.ByteArrayOutputStream
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class MemoryToolIconCache(context: Context) {
    private val packageManager = context.packageManager
    private val inMemoryCache = mutableMapOf<String, ByteArray?>()
    private val memoryCacheLock = Any()
    private val prefetchingPackages = mutableSetOf<String>()
    private val prefetchLock = Any()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val cacheDirectory = File(context.cacheDir, "memory_tool/process_icons").apply {
        mkdirs()
    }

    @RequiresApi(Build.VERSION_CODES.P)
    fun getCachedIconBytes(packageName: String): ByteArray? {
        synchronized(memoryCacheLock) {
            if (inMemoryCache.containsKey(packageName)) {
                return inMemoryCache[packageName]
            }
        }

        val cacheFile = resolveCacheFile(packageName) ?: return null
        if (cacheFile.exists()) {
            val cachedBytes = runCatching { cacheFile.readBytes() }.getOrNull()
            synchronized(memoryCacheLock) {
                inMemoryCache[packageName] = cachedBytes
            }
            return cachedBytes
        }

        return null
    }

    @RequiresApi(Build.VERSION_CODES.P)
    fun prefetchIcon(packageName: String) {
        synchronized(prefetchLock) {
            if (prefetchingPackages.contains(packageName)) {
                return
            }
            prefetchingPackages.add(packageName)
        }

        scope.launch {
            try {
                warmIconBytes(packageName)
            } finally {
                synchronized(prefetchLock) {
                    prefetchingPackages.remove(packageName)
                }
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.P)
    private fun warmIconBytes(packageName: String): ByteArray? {
        val cachedBytes = getCachedIconBytes(packageName)
        if (cachedBytes != null) {
            return cachedBytes
        }

        val cacheFile = resolveCacheFile(packageName) ?: return null

        val iconBytes = try {
            drawableToByteArray(packageManager.getApplicationIcon(packageName))
        } catch (_: Exception) {
            null
        } ?: return null

        cacheDirectory.listFiles()
            ?.filter { it.name.startsWith("${sanitizeFileName(packageName)}__") && it != cacheFile }
            ?.forEach { it.delete() }

        runCatching {
            cacheFile.parentFile?.mkdirs()
            cacheFile.writeBytes(iconBytes)
        }

        synchronized(memoryCacheLock) {
            inMemoryCache[packageName] = iconBytes
        }
        return iconBytes
    }

    @RequiresApi(Build.VERSION_CODES.P)
    private fun resolveCacheFile(packageName: String): File? {
        val versionCode = try {
            packageManager.getPackageInfo(packageName, 0).longVersionCode
        } catch (_: Exception) {
            return null
        }

        return File(
            cacheDirectory,
            "${sanitizeFileName(packageName)}__${versionCode}.png"
        )
    }

    private fun sanitizeFileName(value: String): String {
        return value.replace(Regex("[^A-Za-z0-9._-]"), "_")
    }

    private fun drawableToByteArray(drawable: Drawable): ByteArray {
        val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 100
        val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 100
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)

        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        val result = stream.toByteArray()
        bitmap.recycle()
        return result
    }
}
