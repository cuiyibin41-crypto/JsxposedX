// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'overlay_toast.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$OverlayToast {

 String get message; int get durationMs; int get id;
/// Create a copy of OverlayToast
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OverlayToastCopyWith<OverlayToast> get copyWith => _$OverlayToastCopyWithImpl<OverlayToast>(this as OverlayToast, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OverlayToast&&(identical(other.message, message) || other.message == message)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&(identical(other.id, id) || other.id == id));
}


@override
int get hashCode => Object.hash(runtimeType,message,durationMs,id);

@override
String toString() {
  return 'OverlayToast(message: $message, durationMs: $durationMs, id: $id)';
}


}

/// @nodoc
abstract mixin class $OverlayToastCopyWith<$Res>  {
  factory $OverlayToastCopyWith(OverlayToast value, $Res Function(OverlayToast) _then) = _$OverlayToastCopyWithImpl;
@useResult
$Res call({
 String message, int durationMs, int id
});




}
/// @nodoc
class _$OverlayToastCopyWithImpl<$Res>
    implements $OverlayToastCopyWith<$Res> {
  _$OverlayToastCopyWithImpl(this._self, this._then);

  final OverlayToast _self;
  final $Res Function(OverlayToast) _then;

/// Create a copy of OverlayToast
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


/// Adds pattern-matching-related methods to [OverlayToast].
extension OverlayToastPatterns on OverlayToast {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OverlayToast value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OverlayToast() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OverlayToast value)  $default,){
final _that = this;
switch (_that) {
case _OverlayToast():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OverlayToast value)?  $default,){
final _that = this;
switch (_that) {
case _OverlayToast() when $default != null:
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
case _OverlayToast() when $default != null:
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
case _OverlayToast():
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
case _OverlayToast() when $default != null:
return $default(_that.message,_that.durationMs,_that.id);case _:
  return null;

}
}

}

/// @nodoc


class _OverlayToast extends OverlayToast {
  const _OverlayToast({required this.message, required this.durationMs, required this.id}): super._();
  

@override final  String message;
@override final  int durationMs;
@override final  int id;

/// Create a copy of OverlayToast
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OverlayToastCopyWith<_OverlayToast> get copyWith => __$OverlayToastCopyWithImpl<_OverlayToast>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OverlayToast&&(identical(other.message, message) || other.message == message)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&(identical(other.id, id) || other.id == id));
}


@override
int get hashCode => Object.hash(runtimeType,message,durationMs,id);

@override
String toString() {
  return 'OverlayToast(message: $message, durationMs: $durationMs, id: $id)';
}


}

/// @nodoc
abstract mixin class _$OverlayToastCopyWith<$Res> implements $OverlayToastCopyWith<$Res> {
  factory _$OverlayToastCopyWith(_OverlayToast value, $Res Function(_OverlayToast) _then) = __$OverlayToastCopyWithImpl;
@override @useResult
$Res call({
 String message, int durationMs, int id
});




}
/// @nodoc
class __$OverlayToastCopyWithImpl<$Res>
    implements _$OverlayToastCopyWith<$Res> {
  __$OverlayToastCopyWithImpl(this._self, this._then);

  final _OverlayToast _self;
  final $Res Function(_OverlayToast) _then;

/// Create a copy of OverlayToast
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? message = null,Object? durationMs = null,Object? id = null,}) {
  return _then(_OverlayToast(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
