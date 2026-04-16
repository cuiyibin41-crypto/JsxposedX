import 'package:JsxposedX/generated/memory_tool.g.dart';

enum MemorySearchValueTypeOptionEnum {
  i8,
  i16,
  i32,
  i64,
  f32,
  f64,
  bytes,
  xor,
  auto,
  text,
}

extension MemorySearchValueTypeOptionEnumX on MemorySearchValueTypeOptionEnum {
  SearchValueType? get nativeType {
    return switch (this) {
      MemorySearchValueTypeOptionEnum.i8 => SearchValueType.i8,
      MemorySearchValueTypeOptionEnum.i16 => SearchValueType.i16,
      MemorySearchValueTypeOptionEnum.i32 => SearchValueType.i32,
      MemorySearchValueTypeOptionEnum.i64 => SearchValueType.i64,
      MemorySearchValueTypeOptionEnum.f32 => SearchValueType.f32,
      MemorySearchValueTypeOptionEnum.f64 => SearchValueType.f64,
      MemorySearchValueTypeOptionEnum.bytes => SearchValueType.bytes,
      MemorySearchValueTypeOptionEnum.xor => SearchValueType.i32,
      MemorySearchValueTypeOptionEnum.auto => null,
      MemorySearchValueTypeOptionEnum.text => SearchValueType.bytes,
    };
  }

  SearchValueType get requestType {
    return switch (this) {
      MemorySearchValueTypeOptionEnum.auto => SearchValueType.bytes,
      _ => nativeType!,
    };
  }

  bool get isImplemented => true;

  bool get supportsFuzzySearch {
    return switch (this) {
      MemorySearchValueTypeOptionEnum.i8 ||
      MemorySearchValueTypeOptionEnum.i16 ||
      MemorySearchValueTypeOptionEnum.i32 ||
      MemorySearchValueTypeOptionEnum.i64 ||
      MemorySearchValueTypeOptionEnum.f32 ||
      MemorySearchValueTypeOptionEnum.f64 => true,
      MemorySearchValueTypeOptionEnum.bytes ||
      MemorySearchValueTypeOptionEnum.xor ||
      MemorySearchValueTypeOptionEnum.auto ||
      MemorySearchValueTypeOptionEnum.text => false,
    };
  }
}
