import 'package:JsxposedX/common/widgets/loading.dart';
import 'package:JsxposedX/common/widgets/quill/quill_content_viewer.dart';
import 'package:JsxposedX/common/widgets/ref_error.dart';
import 'package:JsxposedX/features/home/presentation/providers/repository_query_provider.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ScriptDetailPage extends HookConsumerWidget {
  final int id;

  const ScriptDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postDetailAsync = ref.watch(getScriptDetailProvider(id: id));
    return Scaffold(
      body: postDetailAsync.when(
        data: (postDetail) {
          return CustomScrollView(
            slivers: [
              SliverAppBar(title: Text(postDetail.title)),
              SliverToBoxAdapter(
                child: QuillContentViewer(contentDelta: postDetail.content),
              ),
            ],
          );
        },
        error: (error, stack) => RefError(
          error: error,
          onRetry: () => ref.invalidate(getScriptDetailProvider(id: id)),
        ),
        loading: () => const Loading(),
      ),
    );
  }
}
