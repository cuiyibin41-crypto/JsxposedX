// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'overlay_window_runtime_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$OverlayWindowRuntimeMessage {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OverlayWindowRuntimeMessage);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'OverlayWindowRuntimeMessage()';
}


}

/// @nodoc
class $OverlayWindowRuntimeMessageCopyWith<$Res>  {
$OverlayWindowRuntimeMessageCopyWith(OverlayWindowRuntimeMessage _, $Res Function(OverlayWindowRuntimeMessage) __);
}


/// Adds pattern-matching-related methods to [OverlayWindowRuntimeMessage].
extension OverlayWindowRuntimeMessagePatterns on OverlayWindowRuntimeMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( OverlayWindowPayloadMessage value)?  payload,TResult Function( OverlayWindowEventMessage value)?  event,TResult Function( OverlayWindowToastMessage value)?  toast,required TResult orElse(),}){
final _that = this;
switch (_that) {
case OverlayWindowPayloadMessage() when payload != null:
return payload(_that);case OverlayWindowEventMessage() when event != null:
return event(_that);case OverlayWindowToastMessage() when toast != null:
return toast(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( OverlayWindowPayloadMessage value)  payload,required TResult Function( OverlayWindowEventMessage value)  event,required TResult Function( OverlayWindowToastMessage value)  toast,}){
final _that = this;
switch (_that) {
case OverlayWindowPayloadMessage():
return payload(_that);case OverlayWindowEventMessage():
return event(_that);case OverlayWindowToastMessage():
return toast(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( OverlayWindowPayloadMessage value)?  payload,TResult? Function( OverlayWindowEventMessage value)?  event,TResult? Function( OverlayWindowToastMessage value)?  toast,}){
final _that = this;
switch (_that) {
case OverlayWindowPayloadMessage() when payload != null:
return payload(_that);case OverlayWindowEventMessage() when event != null:
return event(_that);case OverlayWindowToastMessage() when toast != null:
return toast(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( OverlayWindowPayload payload)?  payload,TResult Function( OverlayWindowEvent event)?  event,TResult Function( OverlayToast toast)?  toast,required TResult orElse(),}) {final _that = this;
switch (_that) {
case OverlayWindowPayloadMessage() when payload != null:
return payload(_that.payload);case OverlayWindowEventMessage() when event != null:
return event(_that.event);case OverlayWindowToastMessage() when toast != null:
return toast(_that.toast);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( OverlayWindowPayload payload)  payload,required TResult Function( OverlayWindowEvent event)  event,required TResult Function( OverlayToast toast)  toast,}) {final _that = this;
switch (_that) {
case OverlayWindowPayloadMessage():
return payload(_that.payload);case OverlayWindowEventMessage():
return event(_that.event);case OverlayWindowToastMessage():
return toast(_that.toast);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( OverlayWindowPayload payload)?  payload,TResult? Function( OverlayWindowEvent event)?  event,TResult? Function( OverlayToast toast)?  toast,}) {final _that = this;
switch (_that) {
case OverlayWindowPayloadMessage() when payload != null:
return payload(_that.payload);case OverlayWindowEventMessage() when event != null:
return event(_that.event);case OverlayWindowToastMessage() when toast != null:
return toast(_that.toast);case _:
  return null;

}
}

}

/// @nodoc


class OverlayWindowPayloadMessage extends OverlayWindowRuntimeMessage {
  const OverlayWindowPayloadMessage(this.payload): super._();
  

 final  OverlayWindowPayload payload;

/// Create a copy of OverlayWindowRuntimeMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OverlayWindowPayloadMessageCopyWith<OverlayWindowPayloadMessage> get copyWith => _$OverlayWindowPayloadMessageCopyWithImpl<OverlayWindowPayloadMessage>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OverlayWindowPayloadMessage&&(identical(other.payload, payload) || other.payload == payload));
}


@override
int get hashCode => Object.hash(runtimeType,payload);

@override
String toString() {
  return 'OverlayWindowRuntimeMessage.payload(payload: $payload)';
}


}

/// @nodoc
abstract mixin class $OverlayWindowPayloadMessageCopyWith<$Res> implements $OverlayWindowRuntimeMessageCopyWith<$Res> {
  factory $OverlayWindowPayloadMessageCopyWith(OverlayWindowPayloadMessage value, $Res Function(OverlayWindowPayloadMessage) _then) = _$OverlayWindowPayloadMessageCopyWithImpl;
@useResult
$Res call({
 OverlayWindowPayload payload
});


$OverlayWindowPayloadCopyWith<$Res> get payload;

}
/// @nodoc
class _$OverlayWindowPayloadMessageCopyWithImpl<$Res>
    implements $OverlayWindowPayloadMessageCopyWith<$Res> {
  _$OverlayWindowPayloadMessageCopyWithImpl(this._self, this._then);

  final OverlayWindowPayloadMessage _self;
  final $Res Function(OverlayWindowPayloadMessage) _then;

/// Create a copy of OverlayWindowRuntimeMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? payload = null,}) {
  return _then(OverlayWindowPayloadMessage(
null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as OverlayWindowPayload,
  ));
}

/// Create a copy of OverlayWindowRuntimeMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OverlayWindowPayloadCopyWith<$Res> get payload {
  
  return $OverlayWindowPayloadCopyWith<$Res>(_self.payload, (value) {
    return _then(_self.copyWith(payload: value));
  });
}
}

/// @nodoc


class OverlayWindowEventMessage extends OverlayWindowRuntimeMessage {
  const OverlayWindowEventMessage(this.event): super._();
  

 final  OverlayWindowEvent event;

/// Create a copy of OverlayWindowRuntimeMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OverlayWindowEventMessageCopyWith<OverlayWindowEventMessage> get copyWith => _$OverlayWindowEventMessageCopyWithImpl<OverlayWindowEventMessage>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OverlayWindowEventMessage&&(identical(other.event, event) || other.event == event));
}


@override
int get hashCode => Object.hash(runtimeType,event);

@override
String toString() {
  return 'OverlayWindowRuntimeMessage.event(event: $event)';
}


}

/// @nodoc
abstract mixin class $OverlayWindowEventMessageCopyWith<$Res> implements $OverlayWindowRuntimeMessageCopyWith<$Res> {
  factory $OverlayWindowEventMessageCopyWith(OverlayWindowEventMessage value, $Res Function(OverlayWindowEventMessage) _then) = _$OverlayWindowEventMessageCopyWithImpl;
@useResult
$Res call({
 OverlayWindowEvent event
});


$OverlayWindowEventCopyWith<$Res> get event;

}
/// @nodoc
class _$OverlayWindowEventMessageCopyWithImpl<$Res>
    implements $OverlayWindowEventMessageCopyWith<$Res> {
  _$OverlayWindowEventMessageCopyWithImpl(this._self, this._then);

  final OverlayWindowEventMessage _self;
  final $Res Function(OverlayWindowEventMessage) _then;

/// Create a copy of OverlayWindowRuntimeMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? event = null,}) {
  return _then(OverlayWindowEventMessage(
null == event ? _self.event : event // ignore: cast_nullable_to_non_nullable
as OverlayWindowEvent,
  ));
}

/// Create a copy of OverlayWindowRuntimeMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OverlayWindowEventCopyWith<$Res> get event {
  
  return $OverlayWindowEventCopyWith<$Res>(_self.event, (value) {
    return _then(_self.copyWith(event: value));
  });
}
}

/// @nodoc


class OverlayWindowToastMessage extends OverlayWindowRuntimeMessage {
  const OverlayWindowToastMessage(this.toast): super._();
  

 final  OverlayToast toast;

/// Create a copy of OverlayWindowRuntimeMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OverlayWindowToastMessageCopyWith<OverlayWindowToastMessage> get copyWith => _$OverlayWindowToastMessageCopyWithImpl<OverlayWindowToastMessage>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OverlayWindowToastMessage&&(identical(other.toast, toast) || other.toast == toast));
}


@override
int get hashCode => Object.hash(runtimeType,toast);

@override
String toString() {
  return 'OverlayWindowRuntimeMessage.toast(toast: $toast)';
}


}

/// @nodoc
abstract mixin class $OverlayWindowToastMessageCopyWith<$Res> implements $OverlayWindowRuntimeMessageCopyWith<$Res> {
  factory $OverlayWindowToastMessageCopyWith(OverlayWindowToastMessage value, $Res Function(OverlayWindowToastMessage) _then) = _$OverlayWindowToastMessageCopyWithImpl;
@useResult
$Res call({
 OverlayToast toast
});


$OverlayToastCopyWith<$Res> get toast;

}
/// @nodoc
class _$OverlayWindowToastMessageCopyWithImpl<$Res>
    implements $OverlayWindowToastMessageCopyWith<$Res> {
  _$OverlayWindowToastMessageCopyWithImpl(this._self, this._then);

  final OverlayWindowToastMessage _self;
  final $Res Function(OverlayWindowToastMessage) _then;

/// Create a copy of OverlayWindowRuntimeMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? toast = null,}) {
  return _then(OverlayWindowToastMessage(
null == toast ? _self.toast : toast // ignore: cast_nullable_to_non_nullable
as OverlayToast,
  ));
}

/// Create a copy of OverlayWindowRuntimeMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OverlayToastCopyWith<$Res> get toast {
  
  return $OverlayToastCopyWith<$Res>(_self.toast, (value) {
    return _then(_self.copyWith(toast: value));
  });
}
}

// dart format on
