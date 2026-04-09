// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'overlay_toast_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OverlayToastDto {

 String get message; int get durationMs; int get id;
/// Create a copy of OverlayToastDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OverlayToastDtoCopyWith<OverlayToastDto> get copyWith => _$OverlayToastDtoCopyWithImpl<OverlayToastDto>(this as OverlayToastDto, _$identity);

  /// Serializes this OverlayToastDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OverlayToastDto&&(identical(other.message, message) || other.message == message)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message,durationMs,id);

@override
String toString() {
  return 'OverlayToastDto(message: $message, durationMs: $durationMs, id: $id)';
}


}

/// @nodoc
abstract mixin class $OverlayToastDtoCopyWith<$Res>  {
  factory $OverlayToastDtoCopyWith(OverlayToastDto value, $Res Function(OverlayToastDto) _then) = _$OverlayToastDtoCopyWithImpl;
@useResult
$Res call({
 String message, int durationMs, int id
});




}
/// @nodoc
class _$OverlayToastDtoCopyWithImpl<$Res>
    implements $OverlayToastDtoCopyWith<$Res> {
  _$OverlayToastDtoCopyWithImpl(this._self, this._then);

  final OverlayToastDto _self;
  final $Res Function(OverlayToastDto) _then;

/// Create a copy of OverlayToastDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? message = null,Object? durationMs = null,Object? id = null,}) {
  return _then(_self.copyWith(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [OverlayToastDto].
extension OverlayToastDtoPatterns on OverlayToastDto {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OverlayToastDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OverlayToastDto() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OverlayToastDto value)  $default,){
final _that = this;
switch (_that) {
case _OverlayToastDto():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OverlayToastDto value)?  $default,){
final _that = this;
switch (_that) {
case _OverlayToastDto() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String message,  int durationMs,  int id)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OverlayToastDto() when $default != null:
return $default(_that.message,_that.durationMs,_that.id);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String message,  int durationMs,  int id)  $default,) {final _that = this;
switch (_that) {
case _OverlayToastDto():
return $default(_that.message,_that.durationMs,_that.id);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String message,  int durationMs,  int id)?  $default,) {final _that = this;
switch (_that) {
case _OverlayToastDto() when $default != null:
return $default(_that.message,_that.durationMs,_that.id);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OverlayToastDto extends OverlayToastDto {
  const _OverlayToastDto({this.message = '', this.durationMs = 2200, this.id = 0}): super._();
  factory _OverlayToastDto.fromJson(Map<String, dynamic> json) => _$OverlayToastDtoFromJson(json);

@override@JsonKey() final  String message;
@override@JsonKey() final  int durationMs;
@override@JsonKey() final  int id;

/// Create a copy of OverlayToastDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OverlayToastDtoCopyWith<_OverlayToastDto> get copyWith => __$OverlayToastDtoCopyWithImpl<_OverlayToastDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OverlayToastDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OverlayToastDto&&(identical(other.message, message) || other.message == message)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message,durationMs,id);

@override
String toString() {
  return 'OverlayToastDto(message: $message, durationMs: $durationMs, id: $id)';
}


}

/// @nodoc
abstract mixin class _$OverlayToastDtoCopyWith<$Res> implements $OverlayToastDtoCopyWith<$Res> {
  factory _$OverlayToastDtoCopyWith(_OverlayToastDto value, $Res Function(_OverlayToastDto) _then) = __$OverlayToastDtoCopyWithImpl;
@override @useResult
$Res call({
 String message, int durationMs, int id
});




}
/// @nodoc
class __$OverlayToastDtoCopyWithImpl<$Res>
    implements _$OverlayToastDtoCopyWith<$Res> {
  __$OverlayToastDtoCopyWithImpl(this._self, this._then);

  final _OverlayToastDto _self;
  final $Res Function(_OverlayToastDto) _then;

/// Create a copy of OverlayToastDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? message = null,Object? durationMs = null,Object? id = null,}) {
  return _then(_OverlayToastDto(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
