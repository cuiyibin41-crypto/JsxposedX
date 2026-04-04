// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'post_detail_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PostDetailDto {

 int get id; String get title; String get description; PostCategoryDto get postCategory; String get cover; int get publishTime; CommonUserDto get uploader; PostStatsDto get postStats; List<int> get badges; String get content;
/// Create a copy of PostDetailDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PostDetailDtoCopyWith<PostDetailDto> get copyWith => _$PostDetailDtoCopyWithImpl<PostDetailDto>(this as PostDetailDto, _$identity);

  /// Serializes this PostDetailDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PostDetailDto&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.postCategory, postCategory) || other.postCategory == postCategory)&&(identical(other.cover, cover) || other.cover == cover)&&(identical(other.publishTime, publishTime) || other.publishTime == publishTime)&&(identical(other.uploader, uploader) || other.uploader == uploader)&&(identical(other.postStats, postStats) || other.postStats == postStats)&&const DeepCollectionEquality().equals(other.badges, badges)&&(identical(other.content, content) || other.content == content));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,description,postCategory,cover,publishTime,uploader,postStats,const DeepCollectionEquality().hash(badges),content);

@override
String toString() {
  return 'PostDetailDto(id: $id, title: $title, description: $description, postCategory: $postCategory, cover: $cover, publishTime: $publishTime, uploader: $uploader, postStats: $postStats, badges: $badges, content: $content)';
}


}

/// @nodoc
abstract mixin class $PostDetailDtoCopyWith<$Res>  {
  factory $PostDetailDtoCopyWith(PostDetailDto value, $Res Function(PostDetailDto) _then) = _$PostDetailDtoCopyWithImpl;
@useResult
$Res call({
 int id, String title, String description, PostCategoryDto postCategory, String cover, int publishTime, CommonUserDto uploader, PostStatsDto postStats, List<int> badges, String content
});


$PostCategoryDtoCopyWith<$Res> get postCategory;$CommonUserDtoCopyWith<$Res> get uploader;$PostStatsDtoCopyWith<$Res> get postStats;

}
/// @nodoc
class _$PostDetailDtoCopyWithImpl<$Res>
    implements $PostDetailDtoCopyWith<$Res> {
  _$PostDetailDtoCopyWithImpl(this._self, this._then);

  final PostDetailDto _self;
  final $Res Function(PostDetailDto) _then;

/// Create a copy of PostDetailDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? description = null,Object? postCategory = null,Object? cover = null,Object? publishTime = null,Object? uploader = null,Object? postStats = null,Object? badges = null,Object? content = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,postCategory: null == postCategory ? _self.postCategory : postCategory // ignore: cast_nullable_to_non_nullable
as PostCategoryDto,cover: null == cover ? _self.cover : cover // ignore: cast_nullable_to_non_nullable
as String,publishTime: null == publishTime ? _self.publishTime : publishTime // ignore: cast_nullable_to_non_nullable
as int,uploader: null == uploader ? _self.uploader : uploader // ignore: cast_nullable_to_non_nullable
as CommonUserDto,postStats: null == postStats ? _self.postStats : postStats // ignore: cast_nullable_to_non_nullable
as PostStatsDto,badges: null == badges ? _self.badges : badges // ignore: cast_nullable_to_non_nullable
as List<int>,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of PostDetailDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PostCategoryDtoCopyWith<$Res> get postCategory {
  
  return $PostCategoryDtoCopyWith<$Res>(_self.postCategory, (value) {
    return _then(_self.copyWith(postCategory: value));
  });
}/// Create a copy of PostDetailDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CommonUserDtoCopyWith<$Res> get uploader {
  
  return $CommonUserDtoCopyWith<$Res>(_self.uploader, (value) {
    return _then(_self.copyWith(uploader: value));
  });
}/// Create a copy of PostDetailDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PostStatsDtoCopyWith<$Res> get postStats {
  
  return $PostStatsDtoCopyWith<$Res>(_self.postStats, (value) {
    return _then(_self.copyWith(postStats: value));
  });
}
}


/// Adds pattern-matching-related methods to [PostDetailDto].
extension PostDetailDtoPatterns on PostDetailDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PostDetailDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PostDetailDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PostDetailDto value)  $default,){
final _that = this;
switch (_that) {
case _PostDetailDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PostDetailDto value)?  $default,){
final _that = this;
switch (_that) {
case _PostDetailDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String title,  String description,  PostCategoryDto postCategory,  String cover,  int publishTime,  CommonUserDto uploader,  PostStatsDto postStats,  List<int> badges,  String content)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PostDetailDto() when $default != null:
return $default(_that.id,_that.title,_that.description,_that.postCategory,_that.cover,_that.publishTime,_that.uploader,_that.postStats,_that.badges,_that.content);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String title,  String description,  PostCategoryDto postCategory,  String cover,  int publishTime,  CommonUserDto uploader,  PostStatsDto postStats,  List<int> badges,  String content)  $default,) {final _that = this;
switch (_that) {
case _PostDetailDto():
return $default(_that.id,_that.title,_that.description,_that.postCategory,_that.cover,_that.publishTime,_that.uploader,_that.postStats,_that.badges,_that.content);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String title,  String description,  PostCategoryDto postCategory,  String cover,  int publishTime,  CommonUserDto uploader,  PostStatsDto postStats,  List<int> badges,  String content)?  $default,) {final _that = this;
switch (_that) {
case _PostDetailDto() when $default != null:
return $default(_that.id,_that.title,_that.description,_that.postCategory,_that.cover,_that.publishTime,_that.uploader,_that.postStats,_that.badges,_that.content);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PostDetailDto extends PostDetailDto {
  const _PostDetailDto({this.id = 0, this.title = "", this.description = "", this.postCategory = const PostCategoryDto(), this.cover = "", this.publishTime = 0, this.uploader = const CommonUserDto(), this.postStats = const PostStatsDto(), final  List<int> badges = const [], this.content = ""}): _badges = badges,super._();
  factory _PostDetailDto.fromJson(Map<String, dynamic> json) => _$PostDetailDtoFromJson(json);

@override@JsonKey() final  int id;
@override@JsonKey() final  String title;
@override@JsonKey() final  String description;
@override@JsonKey() final  PostCategoryDto postCategory;
@override@JsonKey() final  String cover;
@override@JsonKey() final  int publishTime;
@override@JsonKey() final  CommonUserDto uploader;
@override@JsonKey() final  PostStatsDto postStats;
 final  List<int> _badges;
@override@JsonKey() List<int> get badges {
  if (_badges is EqualUnmodifiableListView) return _badges;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_badges);
}

@override@JsonKey() final  String content;

/// Create a copy of PostDetailDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PostDetailDtoCopyWith<_PostDetailDto> get copyWith => __$PostDetailDtoCopyWithImpl<_PostDetailDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PostDetailDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PostDetailDto&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.postCategory, postCategory) || other.postCategory == postCategory)&&(identical(other.cover, cover) || other.cover == cover)&&(identical(other.publishTime, publishTime) || other.publishTime == publishTime)&&(identical(other.uploader, uploader) || other.uploader == uploader)&&(identical(other.postStats, postStats) || other.postStats == postStats)&&const DeepCollectionEquality().equals(other._badges, _badges)&&(identical(other.content, content) || other.content == content));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,description,postCategory,cover,publishTime,uploader,postStats,const DeepCollectionEquality().hash(_badges),content);

@override
String toString() {
  return 'PostDetailDto(id: $id, title: $title, description: $description, postCategory: $postCategory, cover: $cover, publishTime: $publishTime, uploader: $uploader, postStats: $postStats, badges: $badges, content: $content)';
}


}

/// @nodoc
abstract mixin class _$PostDetailDtoCopyWith<$Res> implements $PostDetailDtoCopyWith<$Res> {
  factory _$PostDetailDtoCopyWith(_PostDetailDto value, $Res Function(_PostDetailDto) _then) = __$PostDetailDtoCopyWithImpl;
@override @useResult
$Res call({
 int id, String title, String description, PostCategoryDto postCategory, String cover, int publishTime, CommonUserDto uploader, PostStatsDto postStats, List<int> badges, String content
});


@override $PostCategoryDtoCopyWith<$Res> get postCategory;@override $CommonUserDtoCopyWith<$Res> get uploader;@override $PostStatsDtoCopyWith<$Res> get postStats;

}
/// @nodoc
class __$PostDetailDtoCopyWithImpl<$Res>
    implements _$PostDetailDtoCopyWith<$Res> {
  __$PostDetailDtoCopyWithImpl(this._self, this._then);

  final _PostDetailDto _self;
  final $Res Function(_PostDetailDto) _then;

/// Create a copy of PostDetailDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? description = null,Object? postCategory = null,Object? cover = null,Object? publishTime = null,Object? uploader = null,Object? postStats = null,Object? badges = null,Object? content = null,}) {
  return _then(_PostDetailDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,postCategory: null == postCategory ? _self.postCategory : postCategory // ignore: cast_nullable_to_non_nullable
as PostCategoryDto,cover: null == cover ? _self.cover : cover // ignore: cast_nullable_to_non_nullable
as String,publishTime: null == publishTime ? _self.publishTime : publishTime // ignore: cast_nullable_to_non_nullable
as int,uploader: null == uploader ? _self.uploader : uploader // ignore: cast_nullable_to_non_nullable
as CommonUserDto,postStats: null == postStats ? _self.postStats : postStats // ignore: cast_nullable_to_non_nullable
as PostStatsDto,badges: null == badges ? _self._badges : badges // ignore: cast_nullable_to_non_nullable
as List<int>,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of PostDetailDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PostCategoryDtoCopyWith<$Res> get postCategory {
  
  return $PostCategoryDtoCopyWith<$Res>(_self.postCategory, (value) {
    return _then(_self.copyWith(postCategory: value));
  });
}/// Create a copy of PostDetailDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CommonUserDtoCopyWith<$Res> get uploader {
  
  return $CommonUserDtoCopyWith<$Res>(_self.uploader, (value) {
    return _then(_self.copyWith(uploader: value));
  });
}/// Create a copy of PostDetailDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PostStatsDtoCopyWith<$Res> get postStats {
  
  return $PostStatsDtoCopyWith<$Res>(_self.postStats, (value) {
    return _then(_self.copyWith(postStats: value));
  });
}
}

// dart format on
