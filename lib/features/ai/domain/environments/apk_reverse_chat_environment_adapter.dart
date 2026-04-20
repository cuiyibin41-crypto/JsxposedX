import 'dart:async';

import 'package:JsxposedX/features/ai/domain/contracts/ai_chat_environment_adapter.dart';
import 'package:JsxposedX/features/ai/domain/models/ai_chat_environment_snapshot.dart';
import 'package:JsxposedX/features/ai/domain/models/ai_context.dart';
import 'package:JsxposedX/features/ai/domain/environments/apk_reverse_prompt_builder.dart';
import 'package:JsxposedX/features/ai/domain/environments/apk_reverse_tool_handlers.dart';
import 'package:JsxposedX/features/ai/domain/services/tool_executor.dart';
import 'package:JsxposedX/features/apk_analysis/domain/repositories/apk_analysis_action_repository.dart';
import 'package:JsxposedX/features/apk_analysis/domain/repositories/apk_analysis_query_repository.dart';
import 'package:JsxposedX/features/so_analysis/data/datasources/so_analysis_datasource.dart';

import 'apk_reverse_chat_tools_spec.dart';

class ApkReverseChatEnvironmentAdapter implements AiChatEnvironmentAdapter {
  ApkReverseChatEnvironmentAdapter({
    required this.packageName,
    required this.isZh,
    required ApkAnalysisActionRepository apkActionRepository,
    required ApkAnalysisQueryRepository apkQueryRepository,
    required SoAnalysisDatasource soDataSource,
  }) : _apkActionRepository = apkActionRepository,
       _apkQueryRepository = apkQueryRepository,
       _soDataSource = soDataSource;

  final String packageName;
  final bool isZh;
  final ApkAnalysisActionRepository _apkActionRepository;
  final ApkAnalysisQueryRepository _apkQueryRepository;
  final SoAnalysisDatasource _soDataSource;

  String? _sessionId;
  List<String> _dexPaths = const [];
  bool _isDisposed = false;

  @override
  String get scopeId => packageName;

  @override
  String get environmentVersion =>
      'apk_reverse:${isZh ? "zh" : "en"}:so_tools_v1';

  String? get sessionId => _sessionId;

  List<String> get dexPaths => _dexPaths;

  @override
  Future<AiChatEnvironmentSnapshot> initialize() async {
    if (_isDisposed) {
      throw StateError('APK reverse chat environment already disposed');
    }

    final previousSessionId = _sessionId;
    if (previousSessionId != null && previousSessionId.isNotEmpty) {
      await _apkActionRepository.closeApkSession(previousSessionId);
    }

    final nextSessionId = await _apkActionRepository.openApkSession(packageName);
    _sessionId = nextSessionId;

    final manifest = await _apkQueryRepository.parseManifest(nextSessionId);
    final assets = await _apkQueryRepository.getApkAssets(nextSessionId);
    final soFiles = assets
        .where((asset) => asset.name.endsWith('.so'))
        .map((asset) => asset.path)
        .toList(growable: false);
    _dexPaths = assets
        .where((asset) => asset.name.endsWith('.dex'))
        .map((asset) => asset.path)
        .toList(growable: false);

    final apkContext = AiApkContext.fromManifest(manifest, soFiles: soFiles);
    final apiSummary = await ApkReversePromptBuilder.loadApiSummary();
    final systemPrompt = ApkReversePromptBuilder(isZh: isZh)
        .withApkContext(apkContext)
        .withApiSummary(apiSummary)
        .withTools()
        .buildSystemPrompt();

    return AiChatEnvironmentSnapshot.ready(
      scopeId: scopeId,
      environmentVersion: environmentVersion,
      systemPrompt: systemPrompt,
      toolsSpec: ApkReverseChatToolsSpec(includeSoTools: true),
      toolExecutor: ToolExecutor(
        handlers: buildApkReverseToolHandlers(
          context: ApkReverseToolRuntimeContext(
            repo: _apkQueryRepository,
            soDataSource: _soDataSource,
            sessionId: nextSessionId,
            dexPaths: _dexPaths,
          ),
          includeSoTools: true,
        ),
      ),
    );
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    final activeSessionId = _sessionId;
    _sessionId = null;
    _dexPaths = const [];
    if (activeSessionId == null || activeSessionId.isEmpty) {
      return;
    }
    await _apkActionRepository.closeApkSession(activeSessionId);
  }
}
