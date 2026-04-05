import 'package:JsxposedX/core/models/page_result.dart';
import 'package:JsxposedX/features/home/domain/models/post.dart';
import 'package:JsxposedX/features/home/domain/models/post_detail.dart';

abstract class RepositoryQueryRepository {
  Future<PageResult<Post>> getScriptPosts({
    required int limit,
    required int offset,
  });

  Future<PostDetail> getScriptDetail({required int id});

  Future<PageResult<Post>> getScriptFavoritePosts({
    required int limit,
    required int offset,
  });
}
