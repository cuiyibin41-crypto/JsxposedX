import 'dart:convert';
import 'dart:typed_data';

import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

String resolveMemoryToolSearchResultDisplayValue({
  required SearchResult result,
  required AsyncValue<Map<int, MemoryValuePreview>> livePreviewsAsync,
}) {
  return livePreviewsAsync.when(
    data: (previews) => previews[result.address]?.displayValue ?? '--',
    error: (_, _) => '--',
    loading: () => '...',
  );
}

String resolveMemoryToolSearchResultValueByType({
  required SearchValueType type,
  required Uint8List rawBytes,
  required String fallbackDisplayValue,
}) {
  if (rawBytes.isEmpty) {
    return fallbackDisplayValue;
  }

  final byteData = ByteData.sublistView(rawBytes);
  try {
    return switch (type) {
      SearchValueType.i8 => byteData.getInt8(0).toString(),
      SearchValueType.i16 => rawBytes.length < 2
          ? fallbackDisplayValue
          : byteData.getInt16(0, Endian.little).toString(),
      SearchValueType.i32 => rawBytes.length < 4
          ? fallbackDisplayValue
          : byteData.getInt32(0, Endian.little).toString(),
      SearchValueType.i64 => rawBytes.length < 8
          ? fallbackDisplayValue
          : byteData.getInt64(0, Endian.little).toString(),
      SearchValueType.f32 => rawBytes.length < 4
          ? fallbackDisplayValue
          : _formatFloatingValue(byteData.getFloat32(0, Endian.little)),
      SearchValueType.f64 => rawBytes.length < 8
          ? fallbackDisplayValue
          : _formatFloatingValue(byteData.getFloat64(0, Endian.little)),
      SearchValueType.bytes => _formatBytesDisplayValue(rawBytes),
    };
  } catch (_) {
    return fallbackDisplayValue;
  }
}

int resolveMemoryToolReadLengthForType({
  required SearchValueType type,
  required int bytesLength,
}) {
  return switch (type) {
    SearchValueType.i8 => 1,
    SearchValueType.i16 => 2,
    SearchValueType.i32 || SearchValueType.f32 => 4,
    SearchValueType.i64 || SearchValueType.f64 => 8,
    SearchValueType.bytes => bytesLength < 1 ? 1 : bytesLength,
  };
}

SearchValue buildMemoryToolWriteValue({
  required SearchValueType type,
  required String input,
  required bool littleEndian,
  required SearchValueType sourceType,
  required Uint8List sourceRawBytes,
  required String sourceDisplayValue,
}) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    throw const FormatException('Value is required.');
  }

  if (type != SearchValueType.bytes) {
    return SearchValue(
      type: type,
      textValue: trimmed,
      littleEndian: littleEndian,
    );
  }

  final bytesInputMode = resolveMemoryToolBytesInputMode(
    input: trimmed,
    sourceType: sourceType,
    sourceRawBytes: sourceRawBytes,
    sourceDisplayValue: sourceDisplayValue,
  );

  return switch (bytesInputMode) {
    MemoryToolBytesInputMode.hex => SearchValue(
        type: SearchValueType.bytes,
        bytesValue: _parseHexBytes(trimmed),
        littleEndian: littleEndian,
      ),
    MemoryToolBytesInputMode.utf8 => SearchValue(
        type: SearchValueType.bytes,
        textValue: '__jsx_text_utf8__:$trimmed',
        bytesValue: Uint8List.fromList(utf8.encode(trimmed)),
        littleEndian: littleEndian,
      ),
    MemoryToolBytesInputMode.utf16Le => SearchValue(
        type: SearchValueType.bytes,
        textValue: '__jsx_text_utf16le__:$trimmed',
        bytesValue: Uint8List.fromList(_encodeUtf16Le(trimmed)),
        littleEndian: littleEndian,
      ),
  };
}

bool isMemoryToolNumericValueType(SearchValueType type) {
  return type != SearchValueType.bytes;
}

String resolveMemoryToolIncrementedInput({
  required SearchValueType type,
  required String baseInput,
  required String incrementInput,
  required int index,
}) {
  if (!isMemoryToolNumericValueType(type)) {
    throw const FormatException('增量模式仅支持数值类型。');
  }

  final trimmedBase = baseInput.trim();
  if (trimmedBase.isEmpty) {
    throw const FormatException('请输入起始值。');
  }

  final trimmedIncrement = incrementInput.trim();
  if (trimmedIncrement.isEmpty) {
    throw const FormatException('请输入增量步长。');
  }

  return switch (type) {
    SearchValueType.i8 ||
    SearchValueType.i16 ||
    SearchValueType.i32 ||
    SearchValueType.i64 => _resolveIncrementedIntegerInput(
        baseInput: trimmedBase,
        incrementInput: trimmedIncrement,
        index: index,
      ),
    SearchValueType.f32 || SearchValueType.f64 => _resolveIncrementedFloatInput(
        baseInput: trimmedBase,
        incrementInput: trimmedIncrement,
        index: index,
      ),
    SearchValueType.bytes => throw const FormatException('增量模式仅支持数值类型。'),
  };
}

SearchValue buildMemoryToolIncrementalWriteValue({
  required SearchValueType type,
  required String baseInput,
  required String incrementInput,
  required int index,
  required bool littleEndian,
  required SearchValueType sourceType,
  required Uint8List sourceRawBytes,
  required String sourceDisplayValue,
}) {
  final resolvedInput = resolveMemoryToolIncrementedInput(
    type: type,
    baseInput: baseInput,
    incrementInput: incrementInput,
    index: index,
  );
  return buildMemoryToolWriteValue(
    type: type,
    input: resolvedInput,
    littleEndian: littleEndian,
    sourceType: sourceType,
    sourceRawBytes: sourceRawBytes,
    sourceDisplayValue: sourceDisplayValue,
  );
}

MemoryToolBytesInputMode resolveMemoryToolBytesInputMode({
  required String input,
  required SearchValueType sourceType,
  required Uint8List sourceRawBytes,
  required String sourceDisplayValue,
}) {
  if (_looksLikeHexByteSequence(input)) {
    return MemoryToolBytesInputMode.hex;
  }

  if (sourceType == SearchValueType.bytes) {
    final utf16Value = _tryDecodeUtf16Le(sourceRawBytes);
    if (utf16Value != null && utf16Value == sourceDisplayValue) {
      return MemoryToolBytesInputMode.utf16Le;
    }

    final utf8Value = _tryDecodeUtf8(sourceRawBytes);
    if (utf8Value != null && utf8Value == sourceDisplayValue) {
      return MemoryToolBytesInputMode.utf8;
    }
  }

  return MemoryToolBytesInputMode.utf8;
}

String formatMemoryToolSearchResultAddress(int value) {
  return value.toRadixString(16).toUpperCase();
}

String formatMemoryToolSearchResultHex(Uint8List rawBytes) {
  return rawBytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');
}

String formatMemoryToolSearchResultReverseHex(Uint8List rawBytes) {
  return rawBytes.reversed
      .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');
}

String mapMemoryToolSearchResultTypeLabel({
  required SearchValueType type,
  required String displayValue,
}) {
  return switch (type) {
    SearchValueType.i8 => 'I8',
    SearchValueType.i16 => 'I16',
    SearchValueType.i32 => 'I32',
    SearchValueType.i64 => 'I64',
    SearchValueType.f32 => 'F32',
    SearchValueType.f64 => 'F64',
    SearchValueType.bytes => _looksLikeHexByteSequence(displayValue)
        ? 'AOB'
        : 'TEXT',
  };
}

String mapMemoryToolSearchResultRegionTypeLabel(
  BuildContext context,
  String regionTypeKey,
) {
  return switch (regionTypeKey) {
    'anonymous' => context.l10n.memoryToolRangeSectionAnonymous,
    'java' => context.l10n.memoryToolRangeSectionJava,
    'javaHeap' => context.l10n.memoryToolRangeSectionJavaHeap,
    'cAlloc' => context.l10n.memoryToolRangeSectionCAlloc,
    'cHeap' => context.l10n.memoryToolRangeSectionCHeap,
    'cData' => context.l10n.memoryToolRangeSectionCData,
    'cBss' => context.l10n.memoryToolRangeSectionCBss,
    'codeApp' => context.l10n.memoryToolRangeSectionCodeApp,
    'codeSys' => context.l10n.memoryToolRangeSectionCodeSys,
    'stack' => context.l10n.memoryToolRangeSectionStack,
    'ashmem' => context.l10n.memoryToolRangeSectionAshmem,
    'bad' => context.l10n.memoryToolRangeSectionBad,
    'other' => context.l10n.memoryToolRangeSectionOther,
    _ => context.l10n.memoryToolRangeSectionOther,
  };
}

Color mapMemoryToolSearchResultTypeBadgeBackground(SearchValueType type) {
  return switch (type) {
    SearchValueType.i8 ||
    SearchValueType.i16 ||
    SearchValueType.i32 => const Color(0xFFE8F4FF),
    SearchValueType.i64 => const Color(0xFFEAF2FF),
    SearchValueType.f32 || SearchValueType.f64 => const Color(0xFFEAFBF1),
    SearchValueType.bytes => const Color(0xFFFFF1E4),
  };
}

Color mapMemoryToolSearchResultTypeBadgeForeground(SearchValueType type) {
  return switch (type) {
    SearchValueType.i8 ||
    SearchValueType.i16 ||
    SearchValueType.i32 => const Color(0xFF1E6FD9),
    SearchValueType.i64 => const Color(0xFF3157C8),
    SearchValueType.f32 || SearchValueType.f64 => const Color(0xFF1F8A4D),
    SearchValueType.bytes => const Color(0xFFB56816),
  };
}

Color mapMemoryToolSearchResultRegionBadgeBackground(String regionTypeKey) {
  return switch (regionTypeKey) {
    'anonymous' => const Color(0xFFF2F3F7),
    'java' || 'javaHeap' => const Color(0xFFFFF3D9),
    'cAlloc' || 'cHeap' || 'cData' || 'cBss' => const Color(0xFFE9F7EC),
    'codeApp' || 'codeSys' => const Color(0xFFECEBFF),
    'stack' => const Color(0xFFFFE9EE),
    'ashmem' => const Color(0xFFE9F8F7),
    'bad' => const Color(0xFFFFE5E5),
    'other' => const Color(0xFFF4F1FF),
    _ => const Color(0xFFF4F1FF),
  };
}

Color mapMemoryToolSearchResultRegionBadgeForeground(String regionTypeKey) {
  return switch (regionTypeKey) {
    'anonymous' => const Color(0xFF5F6675),
    'java' || 'javaHeap' => const Color(0xFF9A6A00),
    'cAlloc' || 'cHeap' || 'cData' || 'cBss' => const Color(0xFF2C8A52),
    'codeApp' || 'codeSys' => const Color(0xFF5A46CC),
    'stack' => const Color(0xFFC14568),
    'ashmem' => const Color(0xFF1E8C84),
    'bad' => const Color(0xFFC13F3F),
    'other' => const Color(0xFF6E56CF),
    _ => const Color(0xFF6E56CF),
  };
}

bool _looksLikeHexByteSequence(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return false;
  }
  return RegExp(r'^[0-9A-F]{2}( [0-9A-F]{2})*$').hasMatch(normalized);
}

String _formatFloatingValue(double value) {
  final normalized = value.toStringAsPrecision(12);
  if (normalized.contains(RegExp(r'[eE]'))) {
    final match = RegExp(r'^([^eE]+)([eE].+)$').firstMatch(normalized);
    if (match == null) {
      return normalized;
    }
    final mantissa = match
        .group(1)!
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return '$mantissa${match.group(2)!}';
  }

  return normalized
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String _formatBytesDisplayValue(Uint8List rawBytes) {
  final utf8Value = _tryDecodeUtf8(rawBytes);
  if (utf8Value != null && utf8Value.isNotEmpty) {
    return utf8Value;
  }

  final utf16Value = _tryDecodeUtf16Le(rawBytes);
  if (utf16Value != null && utf16Value.isNotEmpty) {
    return utf16Value;
  }

  return formatMemoryToolSearchResultHex(rawBytes);
}

String? _tryDecodeUtf8(Uint8List rawBytes) {
  try {
    final decoded = utf8.decode(rawBytes, allowMalformed: false);
    return _isReadableText(decoded) ? decoded : null;
  } catch (_) {
    return null;
  }
}

String? _tryDecodeUtf16Le(Uint8List rawBytes) {
  if (rawBytes.length < 2 || rawBytes.length.isOdd) {
    return null;
  }

  final codeUnits = <int>[];
  for (int index = 0; index < rawBytes.length; index += 2) {
    codeUnits.add(rawBytes[index] | (rawBytes[index + 1] << 8));
  }

  final decoded = String.fromCharCodes(codeUnits);
  return _isReadableText(decoded) ? decoded : null;
}

bool _isReadableText(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return false;
  }

  for (final codePoint in trimmed.runes) {
    if (codePoint == 0) {
      return false;
    }
    final isControl = codePoint < 32 && codePoint != 9 && codePoint != 10 && codePoint != 13;
    if (isControl) {
      return false;
    }
  }
  return true;
}

Uint8List _parseHexBytes(String value) {
  final sanitized = value
      .replaceAll(RegExp(r'0x', caseSensitive: false), '')
      .replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  if (sanitized.isEmpty || sanitized.length.isOdd) {
    throw const FormatException('Invalid byte sequence.');
  }

  final bytes = <int>[];
  for (int index = 0; index < sanitized.length; index += 2) {
    final byte = int.tryParse(
      sanitized.substring(index, index + 2),
      radix: 16,
    );
    if (byte == null) {
      throw const FormatException('Invalid byte sequence.');
    }
    bytes.add(byte);
  }
  return Uint8List.fromList(bytes);
}

String _resolveIncrementedIntegerInput({
  required String baseInput,
  required String incrementInput,
  required int index,
}) {
  final baseValue = int.tryParse(baseInput);
  if (baseValue == null) {
    throw const FormatException('起始值必须是整数。');
  }

  final incrementValue = int.tryParse(incrementInput);
  if (incrementValue == null) {
    throw const FormatException('增量步长必须是整数。');
  }

  return (baseValue + (incrementValue * index)).toString();
}

String _resolveIncrementedFloatInput({
  required String baseInput,
  required String incrementInput,
  required int index,
}) {
  final baseValue = double.tryParse(baseInput);
  if (baseValue == null) {
    throw const FormatException('起始值必须是数字。');
  }

  final incrementValue = double.tryParse(incrementInput);
  if (incrementValue == null) {
    throw const FormatException('增量步长必须是数字。');
  }

  return _formatFloatingValue(baseValue + (incrementValue * index));
}

List<int> _encodeUtf16Le(String value) {
  final bytes = <int>[];
  for (final unit in value.codeUnits) {
    bytes.add(unit & 0xFF);
    bytes.add((unit >> 8) & 0xFF);
  }
  return bytes;
}

enum MemoryToolBytesInputMode {
  hex,
  utf8,
  utf16Le,
}
