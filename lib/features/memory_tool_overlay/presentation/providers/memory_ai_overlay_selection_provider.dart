import 'package:JsxposedX/features/memory_tool_overlay/presentation/models/memory_tool_display_item.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_browse_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_saved_items_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_search_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_search_result_presenter.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

enum MemoryAiOverlaySelectionSource { search, browse, saved }

class MemoryAiOverlaySelectionTag {
  const MemoryAiOverlaySelectionTag({
    required this.source,
    required this.address,
    required this.addressLabel,
    required this.valueLabel,
    required this.typeLabel,
  });

  final MemoryAiOverlaySelectionSource source;
  final int address;
  final String addressLabel;
  final String valueLabel;
  final String typeLabel;
}

final memoryAiOverlaySelectionTagsProvider =
    Provider<List<MemoryAiOverlaySelectionTag>>((ref) {
      final selectedProcess = ref.watch(memoryToolSelectedProcessProvider);
      if (selectedProcess == null) {
        return const <MemoryAiOverlaySelectionTag>[];
      }

      final tags = <MemoryAiOverlaySelectionTag>[
        ..._collectSearchTags(ref),
        ..._collectBrowseTags(ref),
        ..._collectSavedTags(ref),
      ];
      return List<MemoryAiOverlaySelectionTag>.unmodifiable(tags);
    });

final memoryAiOverlayHasSelectedValueProvider = Provider<bool>((ref) {
  return ref.watch(memoryAiOverlaySelectionTagsProvider).isNotEmpty;
});

List<MemoryAiOverlaySelectionTag> _collectSearchTags(Ref ref) {
  if (!ref.watch(hasMatchingSearchSessionProvider)) {
    return const <MemoryAiOverlaySelectionTag>[];
  }

  final selectedAddresses = ref.watch(
    memoryToolResultSelectionProvider.select(
      (state) => state.selectedAddresses,
    ),
  );
  if (selectedAddresses.isEmpty) {
    return const <MemoryAiOverlaySelectionTag>[];
  }

  final searchResults = ref
      .watch(currentSearchResultsProvider)
      .maybeWhen(
        data: (results) => results,
        orElse: () => const <SearchResult>[],
      );
  final searchPreviews = ref
      .watch(currentSearchResultLivePreviewsProvider)
      .maybeWhen(
        data: (previews) => previews,
        orElse: () => const <int, MemoryValuePreview>{},
      );
  final resultByAddress = <int, SearchResult>{
    for (final result in searchResults) result.address: result,
  };

  return [
    for (final address in selectedAddresses)
      if (resultByAddress[address] case final result?)
        _buildSearchTag(result: result, preview: searchPreviews[address]),
  ];
}

List<MemoryAiOverlaySelectionTag> _collectBrowseTags(Ref ref) {
  final selectedAddresses = ref.watch(
    memoryToolBrowseControllerProvider.select(
      (state) => state.selectionState.selectedAddresses,
    ),
  );
  if (selectedAddresses.isEmpty) {
    return const <MemoryAiOverlaySelectionTag>[];
  }

  final browseResults = ref.watch(currentBrowseResultsProvider);
  final browsePreviews = ref
      .watch(currentBrowseResultLivePreviewsProvider)
      .maybeWhen(
        data: (previews) => previews,
        orElse: () => const <int, MemoryValuePreview>{},
      );
  final resultByAddress = <int, MemoryToolDisplayItem>{
    for (final result in browseResults) result.address: result,
  };

  return [
    for (final address in selectedAddresses)
      if (resultByAddress[address] case final result?)
        _buildBrowseTag(result: result, preview: browsePreviews[address]),
  ];
}

List<MemoryAiOverlaySelectionTag> _collectSavedTags(Ref ref) {
  final selectedAddresses = ref.watch(
    memoryToolSavedItemSelectionProvider.select(
      (state) => state.selectedAddresses,
    ),
  );
  if (selectedAddresses.isEmpty) {
    return const <MemoryAiOverlaySelectionTag>[];
  }

  final savedItems = ref.watch(savedItemsForSelectedProcessProvider);
  final savedPreviews = ref
      .watch(currentSavedItemLivePreviewsProvider)
      .maybeWhen(
        data: (previews) => previews,
        orElse: () => const <int, MemoryValuePreview>{},
      );
  final itemByAddress = {for (final item in savedItems) item.address: item};

  return [
    for (final address in selectedAddresses)
      if (itemByAddress[address] case final item?)
        MemoryAiOverlaySelectionTag(
          source: MemoryAiOverlaySelectionSource.saved,
          address: address,
          addressLabel: '0x${formatMemoryToolSearchResultAddress(address)}',
          valueLabel: savedPreviews[address]?.displayValue ?? item.displayValue,
          typeLabel: mapMemoryToolSearchResultTypeLabel(
            type: item.type,
            displayValue:
                savedPreviews[address]?.displayValue ?? item.displayValue,
          ),
        ),
  ];
}

MemoryAiOverlaySelectionTag _buildSearchTag({
  required SearchResult result,
  required MemoryValuePreview? preview,
}) {
  final displayValue = resolveMemoryToolPreferredDisplayValue(
    result: result,
    livePreview: preview,
    fallbackDisplayValue: result.displayValue,
  );
  return MemoryAiOverlaySelectionTag(
    source: MemoryAiOverlaySelectionSource.search,
    address: result.address,
    addressLabel: '0x${formatMemoryToolSearchResultAddress(result.address)}',
    valueLabel: displayValue,
    typeLabel: mapMemoryToolSearchResultTypeLabel(
      type: result.type,
      displayValue: displayValue,
    ),
  );
}

MemoryAiOverlaySelectionTag _buildBrowseTag({
  required MemoryToolDisplayItem result,
  required MemoryValuePreview? preview,
}) {
  final displayValue = result.isInstruction
      ? result.effectiveDisplayValue
      : preview?.displayValue ?? result.effectiveDisplayValue;
  return MemoryAiOverlaySelectionTag(
    source: MemoryAiOverlaySelectionSource.browse,
    address: result.address,
    addressLabel: '0x${formatMemoryToolSearchResultAddress(result.address)}',
    valueLabel: displayValue,
    typeLabel: mapMemoryToolSearchResultTypeLabel(
      type: result.type,
      displayValue: displayValue,
    ),
  );
}
