import 'package:JsxposedX/core/models/page_result.dart';
import 'package:JsxposedX/features/home/data/datasources/repository_query_datasource.dart';
import 'package:JsxposedX/features/home/domain/models/post.dart';
import 'package:JsxposedX/features/home/domain/models/post_detail.dart';
import 'package:JsxposedX/features/home/domain/repositories/repository_query_repository.dart';

class RepositoryQueryRepositoryImpl implements RepositoryQueryRepository {
  final RepositoryQueryDatasource dataSource;

  RepositoryQueryRepositoryImpl({required this.dataSource});

  @override
  Future<PostDetail> getScriptDetail({required int id}) async {
    final dto = await dataSource.getScriptDetail(id: id);
    return dto.toEntity();
  }

  @override
  Future<PageResult<Post>> getScriptPosts({
    required int limit,
    required int offset,
  }) async {
    final dto = await dataSource.getScriptPosts(limit: limit, offset: offset);
    return dto.toEntity((d) => d.toEntity());
  }

  @override
  Future<PageResult<Post>> getScriptFavoritePosts({
    required int limit,
    required int offset,
  }) async {
    final dto = await dataSource.getScriptFavoritePosts(
      limit: limit,
      offset: offset,
    );
    return dto.toEntity((d) => d.toEntity());
  }
}
