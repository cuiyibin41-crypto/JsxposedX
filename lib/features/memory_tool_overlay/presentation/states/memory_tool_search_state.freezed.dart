// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'memory_tool_search_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MemoryToolSearchState {

 String get value; MemorySearchMatchModeEnum get selectedMatchMode; MemorySearchFuzzyModeEnum get selectedFuzzyMode; MemorySearchValueCategoryEnum get selectedValueCategory; MemorySearchValueTypeOptionEnum get selectedValueTypeOption; MemorySearchRangePresetEnum get selectedRangePreset; List<MemorySearchRangeSectionEnum> get customRangeSections; bool get isLittleEndian; MemoryToolSearchValidationError? get validationError;
/// Create a copy of MemoryToolSearchState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MemoryToolSearchStateCopyWith<MemoryToolSearchState> get copyWith => _$MemoryToolSearchStateCopyWithImpl<MemoryToolSearchState>(this as MemoryToolSearchState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MemoryToolSearchState&&(identical(other.value, value) || other.value == value)&&(identical(other.selectedMatchMode, selectedMatchMode) || other.selectedMatchMode == selectedMatchMode)&&(identical(other.selectedFuzzyMode, selectedFuzzyMode) || other.selectedFuzzyMode == selectedFuzzyMode)&&(identical(other.selectedValueCategory, selectedValueCategory) || other.selectedValueCategory == selectedValueCategory)&&(identical(other.selectedValueTypeOption, selectedValueTypeOption) || other.selectedValueTypeOption == selectedValueTypeOption)&&(identical(other.selectedRangePreset, selectedRangePreset) || other.selectedRangePreset == selectedRangePreset)&&const DeepCollectionEquality().equals(other.customRangeSections, customRangeSections)&&(identical(other.isLittleEndian, isLittleEndian) || other.isLittleEndian == isLittleEndian)&&(identical(other.validationError, validationError) || other.validationError == validationError));
}


@override
int get hashCode => Object.hash(runtimeType,value,selectedMatchMode,selectedFuzzyMode,selectedValueCategory,selectedValueTypeOption,selectedRangePreset,const DeepCollectionEquality().hash(customRangeSections),isLittleEndian,validationError);

@override
String toString() {
  return 'MemoryToolSearchState(value: $value, selectedMatchMode: $selectedMatchMode, selectedFuzzyMode: $selectedFuzzyMode, selectedValueCategory: $selectedValueCategory, selectedValueTypeOption: $selectedValueTypeOption, selectedRangePreset: $selectedRangePreset, customRangeSections: $customRangeSections, isLittleEndian: $isLittleEndian, validationError: $validationError)';
}


}

/// @nodoc
abstract mixin class $MemoryToolSearchStateCopyWith<$Res>  {
  factory $MemoryToolSearchStateCopyWith(MemoryToolSearchState value, $Res Function(MemoryToolSearchState) _then) = _$MemoryToolSearchStateCopyWithImpl;
@useResult
$Res call({
 String value, MemorySearchMatchModeEnum selectedMatchMode, MemorySearchFuzzyModeEnum selectedFuzzyMode, MemorySearchValueCategoryEnum selectedValueCategory, MemorySearchValueTypeOptionEnum selectedValueTypeOption, MemorySearchRangePresetEnum selectedRangePreset, List<MemorySearchRangeSectionEnum> customRangeSections, bool isLittleEndian, MemoryToolSearchValidationError? validationError
});




}
/// @nodoc
class _$MemoryToolSearchStateCopyWithImpl<$Res>
    implements $MemoryToolSearchStateCopyWith<$Res> {
  _$MemoryToolSearchStateCopyWithImpl(this._self, this._then);

  final MemoryToolSearchState _self;
  final $Res Function(MemoryToolSearchState) _then;

/// Create a copy of MemoryToolSearchState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? value = null,Object? selectedMatchMode = null,Object? selectedFuzzyMode = null,Object? selectedValueCategory = null,Object? selectedValueTypeOption = null,Object? selectedRangePreset = null,Object? customRangeSections = null,Object? isLittleEndian = null,Object? validationError = freezed,}) {
  return _then(_self.copyWith(
value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,selectedMatchMode: null == selectedMatchMode ? _self.selectedMatchMode : selectedMatchMode // ignore: cast_nullable_to_non_nullable
as MemorySearchMatchModeEnum,selectedFuzzyMode: null == selectedFuzzyMode ? _self.selectedFuzzyMode : selectedFuzzyMode // ignore: cast_nullable_to_non_nullable
as MemorySearchFuzzyModeEnum,selectedValueCategory: null == selectedValueCategory ? _self.selectedValueCategory : selectedValueCategory // ignore: cast_nullable_to_non_nullable
as MemorySearchValueCategoryEnum,selectedValueTypeOption: null == selectedValueTypeOption ? _self.selectedValueTypeOption : selectedValueTypeOption // ignore: cast_nullable_to_non_nullable
as MemorySearchValueTypeOptionEnum,selectedRangePreset: null == selectedRangePreset ? _self.selectedRangePreset : selectedRangePreset // ignore: cast_nullable_to_non_nullable
as MemorySearchRangePresetEnum,customRangeSections: null == customRangeSections ? _self.customRangeSections : customRangeSections // ignore: cast_nullable_to_non_nullable
as List<MemorySearchRangeSectionEnum>,isLittleEndian: null == isLittleEndian ? _self.isLittleEndian : isLittleEndian // ignore: cast_nullable_to_non_nullable
as bool,validationError: freezed == validationError ? _self.validationError : validationError // ignore: cast_nullable_to_non_nullable
as MemoryToolSearchValidationError?,
  ));
}

}


/// Adds pattern-matching-related methods to [MemoryToolSearchState].
extension MemoryToolSearchStatePatterns on MemoryToolSearchState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MemoryToolSearchState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MemoryToolSearchState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MemoryToolSearchState value)  $default,){
final _that = this;
switch (_that) {
case _MemoryToolSearchState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MemoryToolSearchState value)?  $default,){
final _that = this;
switch (_that) {
case _MemoryToolSearchState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String value,  MemorySearchMatchModeEnum selectedMatchMode,  MemorySearchFuzzyModeEnum selectedFuzzyMode,  MemorySearchValueCategoryEnum selectedValueCategory,  MemorySearchValueTypeOptionEnum selectedValueTypeOption,  MemorySearchRangePresetEnum selectedRangePreset,  List<MemorySearchRangeSectionEnum> customRangeSections,  bool isLittleEndian,  MemoryToolSearchValidationError? validationError)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MemoryToolSearchState() when $default != null:
return $default(_that.value,_that.selectedMatchMode,_that.selectedFuzzyMode,_that.selectedValueCategory,_that.selectedValueTypeOption,_that.selectedRangePreset,_that.customRangeSections,_that.isLittleEndian,_that.validationError);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String value,  MemorySearchMatchModeEnum selectedMatchMode,  MemorySearchFuzzyModeEnum selectedFuzzyMode,  MemorySearchValueCategoryEnum selectedValueCategory,  MemorySearchValueTypeOptionEnum selectedValueTypeOption,  MemorySearchRangePresetEnum selectedRangePreset,  List<MemorySearchRangeSectionEnum> customRangeSections,  bool isLittleEndian,  MemoryToolSearchValidationError? validationError)  $default,) {final _that = this;
switch (_that) {
case _MemoryToolSearchState():
return $default(_that.value,_that.selectedMatchMode,_that.selectedFuzzyMode,_that.selectedValueCategory,_that.selectedValueTypeOption,_that.selectedRangePreset,_that.customRangeSections,_that.isLittleEndian,_that.validationError);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String value,  MemorySearchMatchModeEnum selectedMatchMode,  MemorySearchFuzzyModeEnum selectedFuzzyMode,  MemorySearchValueCategoryEnum selectedValueCategory,  MemorySearchValueTypeOptionEnum selectedValueTypeOption,  MemorySearchRangePresetEnum selectedRangePreset,  List<MemorySearchRangeSectionEnum> customRangeSections,  bool isLittleEndian,  MemoryToolSearchValidationError? validationError)?  $default,) {final _that = this;
switch (_that) {
case _MemoryToolSearchState() when $default != null:
return $default(_that.value,_that.selectedMatchMode,_that.selectedFuzzyMode,_that.selectedValueCategory,_that.selectedValueTypeOption,_that.selectedRangePreset,_that.customRangeSections,_that.isLittleEndian,_that.validationError);case _:
  return null;

}
}

}

/// @nodoc


class _MemoryToolSearchState extends MemoryToolSearchState {
  const _MemoryToolSearchState({this.value = '', this.selectedMatchMode = MemorySearchMatchModeEnum.exact, this.selectedFuzzyMode = MemorySearchFuzzyModeEnum.unknown, this.selectedValueCategory = MemorySearchValueCategoryEnum.integer, this.selectedValueTypeOption = MemorySearchValueTypeOptionEnum.i32, this.selectedRangePreset = MemorySearchRangePresetEnum.all, final  List<MemorySearchRangeSectionEnum> customRangeSections = const <MemorySearchRangeSectionEnum>[], this.isLittleEndian = true, this.validationError}): _customRangeSections = customRangeSections,super._();
  

@override@JsonKey() final  String value;
@override@JsonKey() final  MemorySearchMatchModeEnum selectedMatchMode;
@override@JsonKey() final  MemorySearchFuzzyModeEnum selectedFuzzyMode;
@override@JsonKey() final  MemorySearchValueCategoryEnum selectedValueCategory;
@override@JsonKey() final  MemorySearchValueTypeOptionEnum selectedValueTypeOption;
@override@JsonKey() final  MemorySearchRangePresetEnum selectedRangePreset;
 final  List<MemorySearchRangeSectionEnum> _customRangeSections;
@override@JsonKey() List<MemorySearchRangeSectionEnum> get customRangeSections {
  if (_customRangeSections is EqualUnmodifiableListView) return _customRangeSections;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_customRangeSections);
}

@override@JsonKey() final  bool isLittleEndian;
@override final  MemoryToolSearchValidationError? validationError;

/// Create a copy of MemoryToolSearchState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MemoryToolSearchStateCopyWith<_MemoryToolSearchState> get copyWith => __$MemoryToolSearchStateCopyWithImpl<_MemoryToolSearchState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MemoryToolSearchState&&(identical(other.value, value) || other.value == value)&&(identical(other.selectedMatchMode, selectedMatchMode) || other.selectedMatchMode == selectedMatchMode)&&(identical(other.selectedFuzzyMode, selectedFuzzyMode) || other.selectedFuzzyMode == selectedFuzzyMode)&&(identical(other.selectedValueCategory, selectedValueCategory) || other.selectedValueCategory == selectedValueCategory)&&(identical(other.selectedValueTypeOption, selectedValueTypeOption) || other.selectedValueTypeOption == selectedValueTypeOption)&&(identical(other.selectedRangePreset, selectedRangePreset) || other.selectedRangePreset == selectedRangePreset)&&const DeepCollectionEquality().equals(other._customRangeSections, _customRangeSections)&&(identical(other.isLittleEndian, isLittleEndian) || other.isLittleEndian == isLittleEndian)&&(identical(other.validationError, validationError) || other.validationError == validationError));
}


@override
int get hashCode => Object.hash(runtimeType,value,selectedMatchMode,selectedFuzzyMode,selectedValueCategory,selectedValueTypeOption,selectedRangePreset,const DeepCollectionEquality().hash(_customRangeSections),isLittleEndian,validationError);

@override
String toString() {
  return 'MemoryToolSearchState(value: $value, selectedMatchMode: $selectedMatchMode, selectedFuzzyMode: $selectedFuzzyMode, selectedValueCategory: $selectedValueCategory, selectedValueTypeOption: $selectedValueTypeOption, selectedRangePreset: $selectedRangePreset, customRangeSections: $customRangeSections, isLittleEndian: $isLittleEndian, validationError: $validationError)';
}


}

/// @nodoc
abstract mixin class _$MemoryToolSearchStateCopyWith<$Res> implements $MemoryToolSearchStateCopyWith<$Res> {
  factory _$MemoryToolSearchStateCopyWith(_MemoryToolSearchState value, $Res Function(_MemoryToolSearchState) _then) = __$MemoryToolSearchStateCopyWithImpl;
@override @useResult
$Res call({
 String value, MemorySearchMatchModeEnum selectedMatchMode, MemorySearchFuzzyModeEnum selectedFuzzyMode, MemorySearchValueCategoryEnum selectedValueCategory, MemorySearchValueTypeOptionEnum selectedValueTypeOption, MemorySearchRangePresetEnum selectedRangePreset, List<MemorySearchRangeSectionEnum> customRangeSections, bool isLittleEndian, MemoryToolSearchValidationError? validationError
});




}
/// @nodoc
class __$MemoryToolSearchStateCopyWithImpl<$Res>
    implements _$MemoryToolSearchStateCopyWith<$Res> {
  __$MemoryToolSearchStateCopyWithImpl(this._self, this._then);

  final _MemoryToolSearchState _self;
  final $Res Function(_MemoryToolSearchState) _then;

/// Create a copy of MemoryToolSearchState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? value = null,Object? selectedMatchMode = null,Object? selectedFuzzyMode = null,Object? selectedValueCategory = null,Object? selectedValueTypeOption = null,Object? selectedRangePreset = null,Object? customRangeSections = null,Object? isLittleEndian = null,Object? validationError = freezed,}) {
  return _then(_MemoryToolSearchState(
value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,selectedMatchMode: null == selectedMatchMode ? _self.selectedMatchMode : selectedMatchMode // ignore: cast_nullable_to_non_nullable
as MemorySearchMatchModeEnum,selectedFuzzyMode: null == selectedFuzzyMode ? _self.selectedFuzzyMode : selectedFuzzyMode // ignore: cast_nullable_to_non_nullable
as MemorySearchFuzzyModeEnum,selectedValueCategory: null == selectedValueCategory ? _self.selectedValueCategory : selectedValueCategory // ignore: cast_nullable_to_non_nullable
as MemorySearchValueCategoryEnum,selectedValueTypeOption: null == selectedValueTypeOption ? _self.selectedValueTypeOption : selectedValueTypeOption // ignore: cast_nullable_to_non_nullable
as MemorySearchValueTypeOptionEnum,selectedRangePreset: null == selectedRangePreset ? _self.selectedRangePreset : selectedRangePreset // ignore: cast_nullable_to_non_nullable
as MemorySearchRangePresetEnum,customRangeSections: null == customRangeSections ? _self._customRangeSections : customRangeSections // ignore: cast_nullable_to_non_nullable
as List<MemorySearchRangeSectionEnum>,isLittleEndian: null == isLittleEndian ? _self.isLittleEndian : isLittleEndian // ignore: cast_nullable_to_non_nullable
as bool,validationError: freezed == validationError ? _self.validationError : validationError // ignore: cast_nullable_to_non_nullable
as MemoryToolSearchValidationError?,
  ));
}


}

// dart format on
