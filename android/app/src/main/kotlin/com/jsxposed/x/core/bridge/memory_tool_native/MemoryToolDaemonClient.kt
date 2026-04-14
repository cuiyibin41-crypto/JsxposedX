package com.jsxposed.x.core.bridge.memory_tool_native

import android.net.LocalSocket
import android.net.LocalSocketAddress
import org.json.JSONArray
import org.json.JSONObject

class MemoryToolDaemonClient(
    private val helperManager: MemoryToolHelperManager
) {
    companion object {
        private const val METHOD_PING = "ping"
        private const val METHOD_GET_MEMORY_REGIONS = "getMemoryRegions"
        private const val METHOD_GET_SEARCH_SESSION_STATE = "getSearchSessionState"
        private const val METHOD_GET_SEARCH_TASK_STATE = "getSearchTaskState"
        private const val METHOD_GET_SEARCH_RESULTS = "getSearchResults"
        private const val METHOD_READ_MEMORY_VALUES = "readMemoryValues"
        private const val METHOD_FIRST_SCAN = "firstScan"
        private const val METHOD_NEXT_SCAN = "nextScan"
        private const val METHOD_CANCEL_SEARCH = "cancelSearch"
        private const val METHOD_RESET_SEARCH_SESSION = "resetSearchSession"

        fun ping(socketName: String): Boolean {
            return try {
                val response = sendRequest(socketName, METHOD_PING, null)
                response.optBoolean("ok", false)
            } catch (_: Exception) {
                false
            }
        }

        private fun sendRequest(
            socketName: String,
            method: String,
            params: JSONObject?
        ): JSONObject {
            val socket = LocalSocket()
            socket.connect(LocalSocketAddress(socketName, LocalSocketAddress.Namespace.ABSTRACT))
            socket.use { localSocket ->
                val writer = localSocket.outputStream.bufferedWriter()
                val reader = localSocket.inputStream.bufferedReader()
                val request = JSONObject().apply {
                    put("method", method)
                    if (params != null) {
                        put("params", params)
                    }
                }
                writer.write(request.toString())
                writer.newLine()
                writer.flush()

                val responseText = reader.readLine()
                    ?: throw IllegalStateException("Empty response from memory helper.")
                return JSONObject(responseText)
            }
        }

        private fun decodeHex(hex: String?): ByteArray {
            if (hex.isNullOrBlank()) {
                return ByteArray(0)
            }

            val normalized = hex.trim()
            require(normalized.length % 2 == 0) { "Invalid hex length." }
            return ByteArray(normalized.length / 2) { index ->
                normalized.substring(index * 2, index * 2 + 2).toInt(16).toByte()
            }
        }

        private fun encodeHex(bytes: ByteArray?): String? {
            if (bytes == null) {
                return null
            }

            return bytes.joinToString(separator = "") { byte ->
                "%02x".format(byte.toInt() and 0xFF)
            }
        }
    }

    fun getMemoryRegions(query: MemoryRegionQuery): List<MemoryRegion> {
        helperManager.ensureDaemon()
        val result = sendOrThrow(
            METHOD_GET_MEMORY_REGIONS,
            JSONObject().apply {
                put("pid", query.pid)
                put("offset", query.offset)
                put("limit", query.limit)
                put("readableOnly", query.readableOnly)
                put("includeAnonymous", query.includeAnonymous)
                put("includeFileBacked", query.includeFileBacked)
            }
        ).optJSONArray("result") ?: JSONArray()

        return List(result.length()) { index ->
            val item = result.getJSONObject(index)
            MemoryRegion(
                startAddress = item.getLong("startAddress"),
                endAddress = item.getLong("endAddress"),
                perms = item.getString("perms"),
                size = item.getLong("size"),
                path = item.optString("path").ifBlank { null },
                isAnonymous = item.getBoolean("isAnonymous")
            )
        }
    }

    fun getSearchSessionState(): SearchSessionState {
        if (!helperManager.isDaemonAlive()) {
            return SearchSessionState(
                hasActiveSession = false,
                pid = 0,
                type = SearchValueType.I32,
                regionCount = 0,
                resultCount = 0,
                exactMode = true
            )
        }

        val item = sendOrThrow(METHOD_GET_SEARCH_SESSION_STATE, null).getJSONObject("result")
        return SearchSessionState(
            hasActiveSession = item.getBoolean("hasActiveSession"),
            pid = item.getLong("pid"),
            type = SearchValueType.entries[item.getInt("type")],
            regionCount = item.getLong("regionCount"),
            resultCount = item.getLong("resultCount"),
            exactMode = item.getBoolean("exactMode")
        )
    }

    fun getSearchTaskState(): SearchTaskState {
        if (!helperManager.isDaemonAlive()) {
            return SearchTaskState(
                status = SearchTaskStatus.IDLE,
                isFirstScan = true,
                pid = 0,
                processedRegions = 0,
                totalRegions = 0,
                processedEntries = 0,
                totalEntries = 0,
                processedBytes = 0,
                totalBytes = 0,
                resultCount = 0,
                elapsedMilliseconds = 0,
                canCancel = false,
                message = ""
            )
        }

        val item = sendOrThrow(METHOD_GET_SEARCH_TASK_STATE, null).getJSONObject("result")
        return SearchTaskState(
            status = SearchTaskStatus.entries[item.getInt("status")],
            isFirstScan = item.getBoolean("isFirstScan"),
            pid = item.getLong("pid"),
            processedRegions = item.getLong("processedRegions"),
            totalRegions = item.getLong("totalRegions"),
            processedEntries = item.getLong("processedEntries"),
            totalEntries = item.getLong("totalEntries"),
            processedBytes = item.getLong("processedBytes"),
            totalBytes = item.getLong("totalBytes"),
            resultCount = item.getLong("resultCount"),
            elapsedMilliseconds = item.getLong("elapsedMilliseconds"),
            canCancel = item.getBoolean("canCancel"),
            message = item.optString("message")
        )
    }

    fun getSearchResults(offset: Int, limit: Int): List<SearchResult> {
        if (!helperManager.isDaemonAlive()) {
            return emptyList()
        }

        val result = sendOrThrow(
            METHOD_GET_SEARCH_RESULTS,
            JSONObject().apply {
                put("offset", offset)
                put("limit", limit)
            }
        ).optJSONArray("result") ?: JSONArray()

        return List(result.length()) { index ->
            val item = result.getJSONObject(index)
            SearchResult(
                address = item.getLong("address"),
                regionStart = item.getLong("regionStart"),
                type = SearchValueType.entries[item.getInt("type")],
                rawBytes = decodeHex(item.optString("rawBytesHex")),
                displayValue = item.getString("displayValue")
            )
        }
    }

    fun readMemoryValues(requests: List<MemoryReadRequest>): List<MemoryValuePreview> {
        if (requests.isEmpty()) {
            return emptyList()
        }

        helperManager.ensureDaemon()
        val result = sendOrThrow(
            METHOD_READ_MEMORY_VALUES,
            JSONObject().apply {
                put(
                    "requests",
                    JSONArray().apply {
                        requests.forEach { request ->
                            put(
                                JSONObject().apply {
                                    put("address", request.address)
                                    put("type", request.type.ordinal)
                                    put("length", request.length)
                                }
                            )
                        }
                    }
                )
            }
        ).optJSONArray("result") ?: JSONArray()

        return List(result.length()) { index ->
            val item = result.getJSONObject(index)
            MemoryValuePreview(
                address = item.getLong("address"),
                type = SearchValueType.entries[item.getInt("type")],
                rawBytes = decodeHex(item.optString("rawBytesHex")),
                displayValue = item.getString("displayValue")
            )
        }
    }

    fun firstScan(request: FirstScanRequest) {
        helperManager.ensureDaemon()
        sendOrThrow(
            METHOD_FIRST_SCAN,
            JSONObject().apply {
                put("pid", request.pid)
                put("value", buildSearchValueJson(request.value))
                put("matchMode", request.matchMode.ordinal)
                put("scanAllReadableRegions", request.scanAllReadableRegions)
            }
        )
    }

    fun nextScan(request: NextScanRequest) {
        helperManager.ensureDaemon()
        sendOrThrow(
            METHOD_NEXT_SCAN,
            JSONObject().apply {
                put("value", buildSearchValueJson(request.value))
                put("matchMode", request.matchMode.ordinal)
            }
        )
    }

    fun cancelSearch() {
        if (!helperManager.isDaemonAlive()) {
            return
        }

        sendOrThrow(METHOD_CANCEL_SEARCH, null)
    }

    fun resetSearchSession() {
        if (!helperManager.isDaemonAlive()) {
            return
        }

        sendOrThrow(METHOD_RESET_SEARCH_SESSION, null)
    }

    private fun sendOrThrow(method: String, params: JSONObject?): JSONObject {
        val response = sendRequest(helperManager.socketName(), method, params)
        if (!response.optBoolean("ok", false)) {
            throw IllegalStateException(response.optString("error", "Unknown memory helper error."))
        }
        return response
    }

    private fun buildSearchValueJson(value: SearchValue): JSONObject {
        return JSONObject().apply {
            put("type", value.type.ordinal)
            put("textValue", value.textValue)
            put("bytesHex", encodeHex(value.bytesValue))
            put("littleEndian", value.littleEndian)
        }
    }
}
