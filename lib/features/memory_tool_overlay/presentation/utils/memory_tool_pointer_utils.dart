import 'dart:typed_data';

import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_search_result_presenter.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart'
    show PointerScanResult, SearchResult, SearchValueType;

bool canInterpretMemoryToolPointer(Uint8List rawBytes) {
  return rawBytes.length == 4 || rawBytes.length == 8;
}

int? decodeMemoryToolPointerAddress(Uint8List rawBytes) {
  if (!canInterpretMemoryToolPointer(rawBytes)) {
    return null;
  }

  final data = ByteData.sublistView(rawBytes);
  try {
    return rawBytes.length == 4
        ? data.getUint32(0, Endian.little)
        : data.getUint64(0, Endian.little);
  } catch (_) {
    return null;
  }
}

Uint8List encodeMemoryToolPointerAddress(int value, int pointerWidth) {
  final bytes = Uint8List(pointerWidth);
  final data = ByteData.sublistView(bytes);
  if (pointerWidth == 4) {
    data.setUint32(0, value, Endian.little);
  } else {
    data.setUint64(0, value, Endian.little);
  }
  return bytes;
}

SearchResult buildSearchResultFromPointerResult({
  required PointerScanResult result,
  required int pointerWidth,
}) {
  final rawBytes = encodeMemoryToolPointerAddress(
    result.baseAddress,
    pointerWidth,
  );
  return SearchResult(
    address: result.pointerAddress,
    regionStart: result.regionStart,
    regionTypeKey: result.regionTypeKey,
    type: pointerWidth == 8 ? SearchValueType.i64 : SearchValueType.i32,
    rawBytes: rawBytes,
    displayValue: formatMemoryToolSearchResultAddress(result.baseAddress),
  );
}
