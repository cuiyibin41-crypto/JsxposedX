package com.jsxposed.x.core.bridge.memory_tool_native

object MemoryToolHelperNativeBridge {
    external fun getMemoryRegionsJson(
        pid: Long,
        offset: Int,
        limit: Int,
        readableOnly: Boolean,
        includeAnonymous: Boolean,
        includeFileBacked: Boolean
    ): String

    external fun getSearchSessionStateJson(): String

    external fun getSearchTaskStateJson(): String

    external fun getSearchResultsJson(offset: Int, limit: Int): String

    external fun readMemoryValuesJson(
        addresses: LongArray,
        types: IntArray,
        lengths: IntArray
    ): String

    external fun firstScan(
        pid: Long,
        type: Int,
        textValue: String?,
        bytesValue: ByteArray?,
        littleEndian: Boolean,
        matchMode: Int,
        scanAllReadableRegions: Boolean
    )

    external fun nextScan(
        type: Int,
        textValue: String?,
        bytesValue: ByteArray?,
        littleEndian: Boolean,
        matchMode: Int
    )

    external fun cancelSearch()

    external fun resetSearchSession()
}
