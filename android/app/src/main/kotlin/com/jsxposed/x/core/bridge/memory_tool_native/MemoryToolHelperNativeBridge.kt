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

    external fun getPointerScanSessionStateJson(): String

    external fun getPointerScanTaskStateJson(): String

    external fun getPointerScanResultsJson(offset: Int, limit: Int): String

    external fun readMemoryValuesJson(
        addresses: LongArray,
        types: IntArray,
        lengths: IntArray
    ): String

    external fun writeMemoryValue(
        address: Long,
        type: Int,
        textValue: String?,
        bytesValue: ByteArray?,
        littleEndian: Boolean
    )

    external fun setMemoryFreeze(
        address: Long,
        type: Int,
        textValue: String?,
        bytesValue: ByteArray?,
        littleEndian: Boolean,
        enabled: Boolean
    )

    external fun getFrozenMemoryValuesJson(): String

    external fun firstScan(
        pid: Long,
        type: Int,
        textValue: String?,
        bytesValue: ByteArray?,
        littleEndian: Boolean,
        matchMode: Int,
        rangeSectionKeys: Array<String>,
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

    external fun startPointerScan(
        pid: Long,
        targetAddress: Long,
        pointerWidth: Int,
        maxOffset: Long,
        alignment: Int,
        rangeSectionKeys: Array<String>,
        scanAllReadableRegions: Boolean
    )

    external fun cancelPointerScan()

    external fun resetPointerScanSession()
}
