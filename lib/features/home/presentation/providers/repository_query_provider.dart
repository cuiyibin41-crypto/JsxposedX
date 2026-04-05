import 'package:JsxposedX/core/models/page_result.dart';
import 'package:JsxposedX/features/home/domain/models/post.dart';
import 'package:JsxposedX/features/home/domain/models/post_detail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:JsxposedX/core/network/http_service.dart';
import 'package:JsxposedX/features/home/data/datasources/repository_query_datasource.dart';
import 'package:JsxposedX/features/home/data/repositories/repository_query_repository_impl.dart';
import 'package:JsxposedX/features/home/domain/repositories/repository_query_repository.dart';

part 'repository_query_provider.g.dart';

@riverpod
RepositoryQueryRepository repositoryQueryRepository(Ref ref) {
  final httpService = ref.watch(httpServiceProvider);
  final dataSource = RepositoryQueryDatasource(httpService: httpService);
  return RepositoryQueryRepositoryImpl(dataSource: dataSource);
}

@riverpod
Future<PostDetail> getScriptDetail(Ref ref, {required int id}) async {
  return await ref
      .read(repositoryQueryRepositoryProvider)
      .getScriptDetail(id: id);
}

@riverpod
Future<PageResult<Post>> getScriptPosts(
  Ref ref, {
  required int limit,
  required int offset,
}) async {
  return ref
      .read(repositoryQueryRepositoryProvider)
      .getScriptPosts(limit: limit, offset: offset);
}

@riverpod
Future<PageResult<Post>> getScriptFavoritePosts(
  Ref ref, {
  required int limit,
  required int offset,
}) async {
  return ref
      .read(repositoryQueryRepositoryProvider)
      .getScriptFavoritePosts(limit: limit, offset: offset);
}
