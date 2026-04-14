package com.jsxposed.x.core.bridge.memory_tool_native

import android.net.LocalServerSocket
import android.net.LocalSocket
import android.os.SystemClock
import org.json.JSONArray
import org.json.JSONObject
import java.io.Closeable
import java.util.concurrent.atomic.AtomicBoolean

object MemoryToolHelperMain {
    @JvmStatic
    fun main(args: Array<String>) {
        require(args.size >= 2) { "Expected args: <libPath> <socketName>" }
        System.load(args[0])
        MemoryToolDaemonServer(args[1]).run()
    }
}

private class MemoryToolDaemonServer(
    private val socketName: String
) : Closeable {
    companion object {
        private const val IDLE_TIMEOUT_MS = 60_000L
    }

    private val running = AtomicBoolean(true)
    private val serverSocket = LocalServerSocket(socketName)
    @Volatile
    private var lastRequestAt = SystemClock.elapsedRealtime()

    fun run() {
        startWatchdog()
        while (running.get()) {
            val client = try {
                serverSocket.accept()
            } catch (_: Exception) {
                break
            }

            handleClient(client)
        }
    }

    override fun close() {
        running.set(false)
        kotlin.runCatching { serverSocket.close() }
    }

    private fun startWatchdog() {
        Thread {
            while (running.get()) {
                if (SystemClock.elapsedRealtime() - lastRequestAt > IDLE_TIMEOUT_MS) {
                    close()
                    return@Thread
                }
                Thread.sleep(1000)
            }
        }.apply {
            isDaemon = true
            start()
        }
    }

    private fun handleClient(client: LocalSocket) {
        client.use { socket ->
            val reader = socket.inputStream.bufferedReader()
            val writer = socket.outputStream.bufferedWriter()
            val requestText = reader.readLine() ?: return
            lastRequestAt = SystemClock.elapsedRealtime()

            val response = try {
                handleRequest(JSONObject(requestText))
            } catch (t: Throwable) {
                JSONObject().apply {
                    put("ok", false)
                    put("error", t.message ?: t.javaClass.simpleName)
                }
            }

            writer.write(response.toString())
            writer.newLine()
            writer.flush()
        }
    }

    private fun handleRequest(request: JSONObject): JSONObject {
        val method = request.getString("method")
        val params = request.optJSONObject("params") ?: JSONObject()

        val result = when (method) {
            "ping" -> JSONObject().put("pong", true)
            "getMemoryRegions" -> JSONArray(
                MemoryToolHelperNativeBridge.getMemoryRegionsJson(
                    pid = params.getLong("pid"),
                    offset = params.getInt("offset"),
                    limit = params.getInt("limit"),
                    readableOnly = params.optBoolean("readableOnly", true),
                    includeAnonymous = params.optBoolean("includeAnonymous", true),
                    includeFileBacked = params.optBoolean("includeFileBacked", true)
                )
            )

            "getSearchSessionState" -> JSONObject(
                MemoryToolHelperNativeBridge.getSearchSessionStateJson()
            )

            "getSearchTaskState" -> JSONObject(
                MemoryToolHelperNativeBridge.getSearchTaskStateJson()
            )

            "getSearchResults" -> JSONArray(
                MemoryToolHelperNativeBridge.getSearchResultsJson(
                    offset = params.getInt("offset"),
                    limit = params.getInt("limit")
                )
            )

            "readMemoryValues" -> JSONArray(
                MemoryToolHelperNativeBridge.readMemoryValuesJson(
                    addresses = extractLongArray(params.getJSONArray("requests"), "address"),
                    types = extractIntArray(params.getJSONArray("requests"), "type"),
                    lengths = extractIntArray(params.getJSONArray("requests"), "length")
                )
            )

            "firstScan" -> {
                val value = params.getJSONObject("value")
                MemoryToolHelperNativeBridge.firstScan(
                    pid = params.getLong("pid"),
                    type = value.getInt("type"),
                    textValue = value.optString("textValue").ifBlank { null },
                    bytesValue = decodeHex(value.optString("bytesHex")),
                    littleEndian = value.optBoolean("littleEndian", true),
                    matchMode = params.getInt("matchMode"),
                    scanAllReadableRegions = params.optBoolean("scanAllReadableRegions", true)
                )
                JSONObject.NULL
            }

            "nextScan" -> {
                val value = params.getJSONObject("value")
                MemoryToolHelperNativeBridge.nextScan(
                    type = value.getInt("type"),
                    textValue = value.optString("textValue").ifBlank { null },
                    bytesValue = decodeHex(value.optString("bytesHex")),
                    littleEndian = value.optBoolean("littleEndian", true),
                    matchMode = params.getInt("matchMode")
                )
                JSONObject.NULL
            }

            "resetSearchSession" -> {
                MemoryToolHelperNativeBridge.resetSearchSession()
                JSONObject.NULL
            }

            "cancelSearch" -> {
                MemoryToolHelperNativeBridge.cancelSearch()
                JSONObject.NULL
            }

            else -> throw IllegalArgumentException("Unknown method: $method")
        }

        return JSONObject().apply {
            put("ok", true)
            put("result", result)
        }
    }

    private fun extractLongArray(items: JSONArray, fieldName: String): LongArray {
        return LongArray(items.length()) { index ->
            items.getJSONObject(index).getLong(fieldName)
        }
    }

    private fun extractIntArray(items: JSONArray, fieldName: String): IntArray {
        return IntArray(items.length()) { index ->
            items.getJSONObject(index).getInt(fieldName)
        }
    }

    private fun decodeHex(hex: String?): ByteArray? {
        if (hex.isNullOrBlank()) {
            return null
        }

        val normalized = hex.trim()
        require(normalized.length % 2 == 0) { "Invalid hex length." }
        return ByteArray(normalized.length / 2) { index ->
            normalized.substring(index * 2, index * 2 + 2).toInt(16).toByte()
        }
    }
}
