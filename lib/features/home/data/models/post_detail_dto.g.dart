// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post_detail_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PostDetailDto _$PostDetailDtoFromJson(Map<String, dynamic> json) =>
    _PostDetailDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? "",
      description: json['description'] as String? ?? "",
      postCategory: json['postCategory'] == null
          ? const PostCategoryDto()
          : PostCategoryDto.fromJson(
              json['postCategory'] as Map<String, dynamic>,
            ),
      cover: json['cover'] as String? ?? "",
      publishTime: (json['publishTime'] as num?)?.toInt() ?? 0,
      uploader: json['uploader'] == null
          ? const CommonUserDto()
          : CommonUserDto.fromJson(json['uploader'] as Map<String, dynamic>),
      postStats: json['postStats'] == null
          ? const PostStatsDto()
          : PostStatsDto.fromJson(json['postStats'] as Map<String, dynamic>),
      badges:
          (json['badges'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      content: json['content'] as String? ?? "",
    );

Map<String, dynamic> _$PostDetailDtoToJson(_PostDetailDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'postCategory': instance.postCategory,
      'cover': instance.cover,
      'publishTime': instance.publishTime,
      'uploader': instance.uploader,
      'postStats': instance.postStats,
      'badges': instance.badges,
      'content': instance.content,
    };
