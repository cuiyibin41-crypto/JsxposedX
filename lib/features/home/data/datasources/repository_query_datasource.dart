import 'package:JsxposedX/core/models/page_result.dart';
import 'package:JsxposedX/core/network/http_service.dart';
import 'package:JsxposedX/features/home/data/models/post_detail_dto.dart';
import 'package:JsxposedX/features/home/data/models/post_dto.dart';
import 'package:JsxposedX/features/home/domain/models/page_result_dto.dart';
import 'package:JsxposedX/features/home/domain/models/post.dart';

class RepositoryQueryDatasource {
  final HttpService _httpService;

  RepositoryQueryDatasource({required HttpService httpService})
    : _httpService = httpService;
  final String _postApi =
      "https://apiv2.muxue.pro/api/public/post/category/tag/470/posts";

  final String _favoriteApi =
      "https://apiv2.muxue.pro/api/public/post/favorites";

  String _postDetailApi({required int postId}) =>
      "https://apiv2.muxue.pro/api/public/post/$postId/detail";

  Future<PageResultDto<PostDto>> getScriptPosts({
    required int limit,
    required int offset,
  }) async {
    try {
      final result = await _httpService.get(_postApi);
      return PageResultDto.fromJson(
        result.data,
        (data) => PostDto.fromJson(data as Map<String, dynamic>),
      );
    } catch (e) {
      throw Exception(e);
    }
  }

  Future<PageResultDto<PostDto>> getScriptFavoritePosts({
    required int limit,
    required int offset,
  }) async {
    try {
      final result = await _httpService.get(_favoriteApi);
      return PageResultDto.fromJson(
        result.data,
        (data) => PostDto.fromJson(data as Map<String, dynamic>),
      );
    } catch (e) {
      throw Exception(e);
    }
  }

  Future<PostDetailDto> getScriptDetail({required int id}) async {
    try {
      final result = await _httpService.get(_postDetailApi(postId: id));
      return PostDetailDto.fromJson(result.data["data"]);
    } catch (e) {
      throw Exception(e);
    }
  }
}
